-- ============================================================================
-- Phase 2.1: Classification Procedure with Global Cache
-- ============================================================================
-- Purpose: Modified version of sp_classify_search_reasons_optimized that:
-- 1. Checks global_reason_classifications cache for pre-classified reasons
-- 2. Only classifies NEW reasons with LLM
-- 3. Updates global cache with new classifications
-- 4. Dramatically reduces cost for subsequent datasets
--
-- Name: sp_classify_search_reasons_incremental
-- Previous: sp_classify_search_reasons_optimized (sql/14_create_optimized_classification_procedure.sql)
--
-- Usage:
--   CALL FlockML.sp_classify_search_reasons_incremental(
--     'durango-deflock.DurangoPD.October2025',
--     'durango-deflock.DurangoPD.October2025_classified',
--     TRUE
--   );
-- ============================================================================

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_classify_search_reasons_incremental`(
  source_table STRING,
  destination_table STRING,
  use_global_cache BOOLEAN
)
BEGIN
  DECLARE total_row_count INT64;
  DECLARE unique_reason_count INT64;
  DECLARE cached_reason_count INT64;
  DECLARE preprocessed_count INT64;
  DECLARE llm_count INT64;
  DECLARE fallback_count INT64;
  DECLARE no_context_count INT64;
  DECLARE new_reasons_classified INT64;
  DECLARE reduction_percentage FLOAT64;
  DECLARE start_time TIMESTAMP;
  DECLARE source_dataset STRING;

  SET start_time = CURRENT_TIMESTAMP();

  -- Step 1: Load source data and compute unique reasons
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE source_data AS
    SELECT
      *,
      LOWER(TRIM(reason)) AS normalized_reason,
      `durango-deflock.FlockML.is_no_context`(reason, case_num) AS has_no_context
    FROM `%s`
  """, source_table);

  SET total_row_count = (SELECT COUNT(*) FROM source_data);

  -- Step 2: Extract unique reasons with occurrence counts
  CREATE OR REPLACE TEMP TABLE unique_reasons_with_counts AS
  SELECT
    normalized_reason,
    COUNT(*) AS occurrence_count,
    MAX(reason) AS original_reason_sample
  FROM source_data
  WHERE normalized_reason IS NOT NULL
  GROUP BY normalized_reason;

  SET unique_reason_count = (SELECT COUNT(*) FROM unique_reasons_with_counts);

  -- Step 2.5: NEW - Check global cache for pre-classified reasons (COST OPTIMIZATION)
  IF use_global_cache THEN
    CREATE OR REPLACE TEMP TABLE cached_classifications AS
    SELECT
      normalized_reason,
      reason_category
    FROM `durango-deflock.FlockML.global_reason_classifications`
    WHERE classification_version = 'v1';

    SET cached_reason_count = (SELECT COUNT(*) FROM cached_classifications);

    -- Modify Step 3 to exclude cached reasons
    CREATE OR REPLACE TEMP TABLE unique_reasons_preprocessed AS
    SELECT
      normalized_reason,
      occurrence_count,
      original_reason_sample,
      CASE
        -- Pre-classify obvious cases to save LLM calls
        WHEN normalized_reason IS NULL OR LENGTH(TRIM(normalized_reason)) < 2 THEN 'Invalid_Reason'
        WHEN TRIM(normalized_reason) IN ('.', '..', '...', 'n/a', 'N/A', 'na', 'NA', '-', '--', 'tbd', 'TBD')
             THEN 'Invalid_Reason'
        WHEN (normalized_reason LIKE '%25%' AND LENGTH(normalized_reason) > 5)
             OR (normalized_reason LIKE '%24%')
             THEN 'Case_Number'
        WHEN REGEXP_CONTAINS(normalized_reason, r'^[+-]?\\d+$') AND LENGTH(normalized_reason) < 5
             THEN 'Invalid_Reason'
        WHEN REGEXP_CONTAINS(normalized_reason, r'(?i)^(?:[qwertyuiop]{8,}|[asdfghjkl]{8,}|[zxcvbnm]{8,})$')
             THEN 'Invalid_Reason'
        ELSE NULL  -- Needs LLM classification
      END AS preprocessed_category
    FROM unique_reasons_with_counts
    WHERE normalized_reason NOT IN (SELECT normalized_reason FROM cached_classifications);
  ELSE
    -- Original behavior - no cache lookup
    CREATE OR REPLACE TEMP TABLE unique_reasons_preprocessed AS
    SELECT
      normalized_reason,
      occurrence_count,
      original_reason_sample,
      CASE
        WHEN normalized_reason IS NULL OR LENGTH(TRIM(normalized_reason)) < 2 THEN 'Invalid_Reason'
        WHEN TRIM(normalized_reason) IN ('.', '..', '...', 'n/a', 'N/A', 'na', 'NA', '-', '--', 'tbd', 'TBD')
             THEN 'Invalid_Reason'
        WHEN (normalized_reason LIKE '%25%' AND LENGTH(normalized_reason) > 5)
             OR (normalized_reason LIKE '%24%')
             THEN 'Case_Number'
        WHEN REGEXP_CONTAINS(normalized_reason, r'^[+-]?\\d+$') AND LENGTH(normalized_reason) < 5
             THEN 'Invalid_Reason'
        WHEN REGEXP_CONTAINS(normalized_reason, r'(?i)^(?:[qwertyuiop]{8,}|[asdfghjkl]{8,}|[zxcvbnm]{8,})$')
             THEN 'Invalid_Reason'
        ELSE NULL
      END AS preprocessed_category
    FROM unique_reasons_with_counts;

    SET cached_reason_count = 0;
  END IF;

  SET preprocessed_count = (SELECT COUNT(*) FROM unique_reasons_preprocessed WHERE preprocessed_category IS NOT NULL);

  -- Step 4: Extract unique reasons needing LLM classification
  CREATE OR REPLACE TEMP TABLE unique_needs_llm_classification AS
  SELECT
    normalized_reason,
    occurrence_count,
    `durango-deflock.FlockML.build_classification_prompt`(normalized_reason) AS classification_prompt
  FROM unique_reasons_preprocessed
  WHERE preprocessed_category IS NULL;

  SET llm_count = (SELECT COUNT(*) FROM unique_needs_llm_classification);

  -- Step 5: Classify unique reasons with Gemini LLM
  IF llm_count > 0 THEN
    CREATE OR REPLACE TEMP TABLE unique_llm_classified AS
    SELECT
      normalized_reason,
      JSON_EXTRACT_SCALAR(ml_generate_text_result, '$.content') AS gemini_category
    FROM ML.GENERATE_TEXT(
      MODEL `durango-deflock.FlockML.gemini_reason_classifier`,
      (SELECT normalized_reason, classification_prompt AS prompt FROM unique_needs_llm_classification),
      STRUCT(
        0.0 AS temperature,
        50 AS max_output_tokens
      )
    );
  ELSE
    CREATE OR REPLACE TEMP TABLE unique_llm_classified AS
    SELECT
      CAST(NULL AS STRING) AS normalized_reason,
      CAST(NULL AS STRING) AS gemini_category
    FROM (SELECT 1 AS dummy)
    WHERE FALSE;
  END IF;

  -- Step 6: Validate LLM output and apply fallback rules to unique reasons
  CREATE OR REPLACE TEMP TABLE unique_validated_classifications AS
  SELECT
    u.normalized_reason,
    u.occurrence_count,
    l.gemini_category,
    CASE
      -- Validate Gemini output is a known category
      WHEN TRIM(CAST(l.gemini_category AS STRING)) IN (
        'Property_Crime', 'Violent_Crime', 'Vehicle_Related', 'Person_Search',
        'Vulnerable_Persons', 'Drugs', 'Sex_Crime', 'Human_Trafficking',
        'Domestic_Violence', 'Financial_Crime', 'Stalking', 'Kidnapping',
        'Arson', 'Weapons_Offense', 'Smuggling', 'Interagency',
        'Administrative', 'Case_Number', 'Invalid_Reason', 'OTHER'
      ) THEN TRIM(CAST(l.gemini_category AS STRING))

      -- Fallback to rule-based if Gemini returns invalid category
      WHEN LOWER(u.normalized_reason) LIKE '%homicide%'
           OR LOWER(u.normalized_reason) LIKE '%murder%'
           OR LOWER(u.normalized_reason) LIKE '%shoot%'
           OR LOWER(u.normalized_reason) LIKE '%assault%'
           OR LOWER(u.normalized_reason) LIKE '%robb%'
           THEN 'Violent_Crime'
      WHEN LOWER(u.normalized_reason) LIKE '%stolen%'
           OR LOWER(u.normalized_reason) LIKE '%theft%'
           OR LOWER(u.normalized_reason) LIKE '%burg%'
           OR LOWER(u.normalized_reason) LIKE '%auto%'
           OR LOWER(u.normalized_reason) LIKE '%carj%'
           THEN 'Property_Crime'
      WHEN LOWER(u.normalized_reason) LIKE '%warrant%'
           OR LOWER(u.normalized_reason) LIKE '%wanted%'
           OR LOWER(u.normalized_reason) LIKE '%fugit%'
           OR LOWER(u.normalized_reason) LIKE '%atl%'
           OR LOWER(u.normalized_reason) LIKE '%bolo%'
           OR LOWER(u.normalized_reason) LIKE '%elud%'
           THEN 'Person_Search'
      WHEN LOWER(u.normalized_reason) LIKE '%drug%'
           OR LOWER(u.normalized_reason) LIKE '%narc%'
           OR LOWER(u.normalized_reason) LIKE '%meth%'
           THEN 'Drugs'
      WHEN LOWER(u.normalized_reason) LIKE '%missing%'
           OR LOWER(u.normalized_reason) LIKE '%amber%'
           OR LOWER(u.normalized_reason) LIKE '%welfare%'
           THEN 'Vulnerable_Persons'
      WHEN LOWER(u.normalized_reason) LIKE '%domesti%'
           THEN 'Domestic_Violence'
      WHEN LOWER(u.normalized_reason) LIKE '%sex%'
           THEN 'Sex_Crime'
      WHEN LOWER(u.normalized_reason) LIKE '%fraud%'
           OR LOWER(u.normalized_reason) LIKE '%scam%'
           THEN 'Financial_Crime'
      WHEN LOWER(u.normalized_reason) LIKE '%hit%'
           OR LOWER(u.normalized_reason) LIKE '%reck%'
           OR LOWER(u.normalized_reason) LIKE '%aban%'
           THEN 'Vehicle_Related'
      WHEN LOWER(u.normalized_reason) LIKE '%weapon%'
           THEN 'Weapons_Offense'
      WHEN LOWER(u.normalized_reason) LIKE '%arson%'
           OR LOWER(u.normalized_reason) LIKE '%fire%'
           THEN 'Arson'
      WHEN LOWER(u.normalized_reason) LIKE '%kidnap%'
           THEN 'Kidnapping'
      WHEN LOWER(u.normalized_reason) LIKE '%stalk%'
           THEN 'Stalking'
      WHEN LOWER(u.normalized_reason) LIKE '%traffick%'
           THEN 'Human_Trafficking'
      WHEN LOWER(u.normalized_reason) LIKE '%smugg%'
           THEN 'Smuggling'
      WHEN LOWER(u.normalized_reason) LIKE '%aoa%'
           OR LOWER(u.normalized_reason) LIKE '%interdic%'
           OR LOWER(u.normalized_reason) LIKE '%tip%'
           THEN 'Interagency'
      WHEN LOWER(u.normalized_reason) LIKE '%train%'
           OR LOWER(u.normalized_reason) LIKE '%test%'
           OR LOWER(u.normalized_reason) LIKE '%10-%'
           THEN 'Administrative'
      WHEN LOWER(u.normalized_reason) LIKE '%inv%'
           OR LOWER(u.normalized_reason) LIKE '%case%'
           OR LOWER(u.normalized_reason) LIKE '%criminal%'
           OR LOWER(u.normalized_reason) LIKE '%patrol%'
           OR LOWER(u.normalized_reason) LIKE '%sus%'
           OR LOWER(u.normalized_reason) LIKE '%tbd%'
           OR LOWER(u.normalized_reason) LIKE '%info%'
           OR LOWER(u.normalized_reason) LIKE '%leo%'
           THEN 'Invalid_Reason'
      ELSE 'OTHER'
    END AS final_category,
    CASE
      WHEN TRIM(CAST(l.gemini_category AS STRING)) NOT IN (
        'Property_Crime', 'Violent_Crime', 'Vehicle_Related', 'Person_Search',
        'Vulnerable_Persons', 'Drugs', 'Sex_Crime', 'Human_Trafficking',
        'Domestic_Violence', 'Financial_Crime', 'Stalking', 'Kidnapping',
        'Arson', 'Weapons_Offense', 'Smuggling', 'Interagency',
        'Administrative', 'Case_Number', 'Invalid_Reason', 'OTHER'
      ) THEN TRUE ELSE FALSE
    END AS used_fallback_rules
  FROM unique_needs_llm_classification u
  LEFT JOIN unique_llm_classified l ON u.normalized_reason = l.normalized_reason
  UNION ALL
  SELECT
    normalized_reason,
    occurrence_count,
    preprocessed_category AS gemini_category,
    preprocessed_category AS final_category,
    FALSE AS used_fallback_rules
  FROM unique_reasons_preprocessed
  WHERE preprocessed_category IS NOT NULL;

  SET fallback_count = (SELECT COUNT(*) FROM unique_validated_classifications WHERE used_fallback_rules);
  SET new_reasons_classified = (SELECT COUNT(*) FROM unique_validated_classifications);

  -- Step 6.5: NEW - Add cached classifications to the lookup table
  CREATE OR REPLACE TEMP TABLE reason_classification_lookup AS
  SELECT
    normalized_reason,
    final_category AS reason_category,
    occurrence_count,
    used_fallback_rules
  FROM unique_validated_classifications
  UNION ALL
  SELECT
    normalized_reason,
    reason_category,
    NULL AS occurrence_count,
    FALSE AS used_fallback_rules
  FROM `durango-deflock.FlockML.global_reason_classifications`
  WHERE use_global_cache
    AND classification_version = 'v1'
    AND normalized_reason NOT IN (SELECT normalized_reason FROM unique_validated_classifications);

  -- Step 7: Create output table joining full dataset with classification lookup
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `%s` AS
    SELECT
      s.* EXCEPT (has_no_context, normalized_reason),
      COALESCE(l.reason_category, 'OTHER') AS reason_category,
      s.has_no_context,
      COALESCE(l.used_fallback_rules, FALSE) AS used_fallback_rules,
      CASE
        WHEN COALESCE(l.reason_category, 'OTHER')
             IN ('Invalid_Reason', 'Case_Number', 'OTHER')
        THEN COALESCE(l.reason_category, 'OTHER')
        ELSE 'Valid_Reason'
      END AS reason_bucket,
      CURRENT_TIMESTAMP() AS classification_timestamp
    FROM source_data s
    LEFT JOIN reason_classification_lookup l ON s.normalized_reason = l.normalized_reason
  """, destination_table);

  -- Step 7.5: NEW - Update global cache with new classifications
  IF use_global_cache AND new_reasons_classified > 0 THEN
    MERGE `durango-deflock.FlockML.global_reason_classifications` AS target
    USING unique_validated_classifications AS source
    ON target.normalized_reason = source.normalized_reason
    WHEN NOT MATCHED THEN
      INSERT (normalized_reason, reason_category, first_seen_dataset,
              first_classified_timestamp, classification_count, last_updated,
              classification_version)
      VALUES (source.normalized_reason, source.final_category,
              REGEXP_EXTRACT(source_table, r'\.([^.]+)$'),
              CURRENT_TIMESTAMP(), source.occurrence_count, CURRENT_TIMESTAMP(), 'v1')
    WHEN MATCHED THEN
      UPDATE SET
        classification_count = target.classification_count + source.occurrence_count,
        last_updated = CURRENT_TIMESTAMP();
  END IF;

  SET no_context_count = (SELECT COUNT(*) FROM source_data WHERE has_no_context);
  SET reduction_percentage = ROUND((1 - CAST(unique_reason_count AS FLOAT64) / CAST(total_row_count AS FLOAT64)) * 100, 2);

  -- Step 8: Log to audit table with optimization metrics
  INSERT INTO `durango-deflock.FlockML.classification_runs` (
    source_table,
    destination_table,
    execution_timestamp,
    completion_timestamp,
    total_rows,
    preprocessed_rows,
    llm_classified_rows,
    fallback_rows,
    no_context_rows,
    unique_reasons,
    reduction_percentage,
    cost_estimate_usd
  )
  VALUES (
    source_table,
    destination_table,
    start_time,
    CURRENT_TIMESTAMP(),
    total_row_count,
    preprocessed_count,
    llm_count,
    fallback_count,
    no_context_count,
    unique_reason_count,
    reduction_percentage,
    ROUND(CAST(llm_count AS FLOAT64) * 0.000003, 4)
  );

  -- Log completion with cache hit metrics
  SELECT FORMAT(
    '✓ Incremental classification complete for %s -> %s\n  Total rows: %d\n  Unique reasons: %d\n  Cache hits: %d\n  New classified: %d\n  Reduction: %f%%\n  LLM calls: %d',
    source_table,
    destination_table,
    total_row_count,
    unique_reason_count,
    cached_reason_count,
    new_reasons_classified,
    reduction_percentage,
    llm_count
  ) AS status;

END;
