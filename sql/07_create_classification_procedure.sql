-- Phase 3.3: Create Main Classification Stored Procedure
-- This procedure orchestrates the entire classification workflow:
-- 1. Preprocessing - identify no_context and obvious patterns
-- 2. Rule-based classification for obvious cases
-- 3. Gemini LLM classification for ambiguous cases
-- 4. Validation and fallback rules
-- 5. Output combination and audit logging

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_classify_search_reasons`(
  source_table STRING,
  destination_table STRING
)
BEGIN
  DECLARE row_count INT64;
  DECLARE preprocessed_count INT64;
  DECLARE llm_count INT64;
  DECLARE fallback_count INT64;
  DECLARE no_context_count INT64;
  DECLARE start_time TIMESTAMP;

  SET start_time = CURRENT_TIMESTAMP();

  -- Step 1: Preprocessing - identify no_context and obvious patterns
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE preprocessing_stage AS
    SELECT
      *,
      `durango-deflock.FlockML.is_no_context`(reason, case_num) AS has_no_context,
      CASE
        -- Pre-classify obvious cases to save LLM calls
        WHEN reason IS NULL OR LENGTH(TRIM(reason)) < 2 THEN 'Invalid_Reason'
        WHEN TRIM(reason) IN ('.', '..', '...', 'n/a', 'N/A', 'na', 'NA', '-', '--', 'tbd', 'TBD')
             THEN 'Invalid_Reason'
        WHEN (reason LIKE '%%25%%' AND LENGTH(reason) > 5)
             OR (case_num LIKE '%%25%%' OR case_num LIKE '%%24%%')
             THEN 'Case_Number'
        WHEN REGEXP_CONTAINS(reason, r'^[+-]?\\d+$') AND LENGTH(reason) < 5
             THEN 'Invalid_Reason'
        WHEN REGEXP_CONTAINS(reason, r'(?i)^(?:[qwertyuiop]{8,}|[asdfghjkl]{8,}|[zxcvbnm]{8,})$')
             THEN 'Invalid_Reason'
        ELSE NULL  -- Needs LLM classification
      END AS preprocessed_category,
      LOWER(TRIM(reason)) AS normalized_reason
    FROM `%s`
  """, source_table);

  SET preprocessed_count = @@script.bytes_processed;

  -- Step 2: Separate records that need LLM classification
  CREATE OR REPLACE TEMP TABLE needs_llm_classification AS
  SELECT
    id,
    normalized_reason,
    `durango-deflock.FlockML.build_classification_prompt`(normalized_reason) AS classification_prompt
  FROM preprocessing_stage
  WHERE preprocessed_category IS NULL;

  SET llm_count = (SELECT COUNT(*) FROM needs_llm_classification);

  -- Step 3: Classify with Gemini LLM (only if we have records to classify)
  IF llm_count > 0 THEN
    CREATE OR REPLACE TEMP TABLE llm_classified AS
    SELECT
      id,
     JSON_EXTRACT_SCALAR(ml_generate_text_result, '$.content') AS gemini_category
FROM ML.GENERATE_TEXT(
      MODEL `durango-deflock.FlockML.gemini_reason_classifier`,
      (SELECT id, classification_prompt AS prompt FROM needs_llm_classification),
      STRUCT(
        0.0 AS temperature,
        50 AS max_output_tokens
      )
    );
  ELSE
    CREATE OR REPLACE TEMP TABLE llm_classified AS
    SELECT
      CAST(NULL AS STRING) AS id,
      CAST(NULL AS STRING) AS gemini_category
    WHERE FALSE;
  END IF;

  -- Step 4: Validate LLM output and apply fallback rules
  CREATE OR REPLACE TEMP TABLE validated_classifications AS
  SELECT
    n.id,
    n.normalized_reason,
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
      WHEN LOWER(n.normalized_reason) LIKE '%homicide%'
           OR LOWER(n.normalized_reason) LIKE '%murder%'
           OR LOWER(n.normalized_reason) LIKE '%shoot%'
           OR LOWER(n.normalized_reason) LIKE '%assault%'
           OR LOWER(n.normalized_reason) LIKE '%robb%'
           THEN 'Violent_Crime'
      WHEN LOWER(n.normalized_reason) LIKE '%stolen%'
           OR LOWER(n.normalized_reason) LIKE '%theft%'
           OR LOWER(n.normalized_reason) LIKE '%burg%'
           OR LOWER(n.normalized_reason) LIKE '%auto%'
           OR LOWER(n.normalized_reason) LIKE '%carj%'
           THEN 'Property_Crime'
      WHEN LOWER(n.normalized_reason) LIKE '%warrant%'
           OR LOWER(n.normalized_reason) LIKE '%wanted%'
           OR LOWER(n.normalized_reason) LIKE '%fugit%'
           OR LOWER(n.normalized_reason) LIKE '%atl%'
           OR LOWER(n.normalized_reason) LIKE '%bolo%'
           OR LOWER(n.normalized_reason) LIKE '%elud%'
           THEN 'Person_Search'
      WHEN LOWER(n.normalized_reason) LIKE '%drug%'
           OR LOWER(n.normalized_reason) LIKE '%narc%'
           OR LOWER(n.normalized_reason) LIKE '%meth%'
           THEN 'Drugs'
      WHEN LOWER(n.normalized_reason) LIKE '%missing%'
           OR LOWER(n.normalized_reason) LIKE '%amber%'
           OR LOWER(n.normalized_reason) LIKE '%welfare%'
           THEN 'Vulnerable_Persons'
      WHEN LOWER(n.normalized_reason) LIKE '%domesti%'
           THEN 'Domestic_Violence'
      WHEN LOWER(n.normalized_reason) LIKE '%sex%'
           THEN 'Sex_Crime'
      WHEN LOWER(n.normalized_reason) LIKE '%fraud%'
           OR LOWER(n.normalized_reason) LIKE '%scam%'
           THEN 'Financial_Crime'
      WHEN LOWER(n.normalized_reason) LIKE '%hit%'
           OR LOWER(n.normalized_reason) LIKE '%reck%'
           OR LOWER(n.normalized_reason) LIKE '%aban%'
           THEN 'Vehicle_Related'
      WHEN LOWER(n.normalized_reason) LIKE '%weapon%'
           THEN 'Weapons_Offense'
      WHEN LOWER(n.normalized_reason) LIKE '%arson%'
           OR LOWER(n.normalized_reason) LIKE '%fire%'
           THEN 'Arson'
      WHEN LOWER(n.normalized_reason) LIKE '%kidnap%'
           THEN 'Kidnapping'
      WHEN LOWER(n.normalized_reason) LIKE '%stalk%'
           THEN 'Stalking'
      WHEN LOWER(n.normalized_reason) LIKE '%traffick%'
           THEN 'Human_Trafficking'
      WHEN LOWER(n.normalized_reason) LIKE '%smugg%'
           THEN 'Smuggling'
      WHEN LOWER(n.normalized_reason) LIKE '%aoa%'
           OR LOWER(n.normalized_reason) LIKE '%interdic%'
           OR LOWER(n.normalized_reason) LIKE '%tip%'
           THEN 'Interagency'
      WHEN LOWER(n.normalized_reason) LIKE '%train%'
           OR LOWER(n.normalized_reason) LIKE '%test%'
           OR LOWER(n.normalized_reason) LIKE '%10-%'
           THEN 'Administrative'
      WHEN LOWER(n.normalized_reason) LIKE '%inv%'
           OR LOWER(n.normalized_reason) LIKE '%case%'
           OR LOWER(n.normalized_reason) LIKE '%criminal%'
           OR LOWER(n.normalized_reason) LIKE '%patrol%'
           OR LOWER(n.normalized_reason) LIKE '%sus%'
           OR LOWER(n.normalized_reason) LIKE '%tbd%'
           OR LOWER(n.normalized_reason) LIKE '%info%'
           OR LOWER(n.normalized_reason) LIKE '%leo%'
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
  FROM needs_llm_classification n
  LEFT JOIN llm_classified l ON n.id = l.id;

  SET fallback_count = (SELECT COUNT(*) FROM validated_classifications WHERE used_fallback_rules);

  -- Step 5: Combine preprocessed and LLM-classified records
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `%s` AS
    SELECT
      s.* EXCEPT (preprocessed_category, has_no_context, normalized_reason),
      COALESCE(s.preprocessed_category, v.final_category) AS reason_category,
      s.has_no_context,
      COALESCE(v.used_fallback_rules, FALSE) AS used_fallback_rules,
      CASE
        WHEN COALESCE(s.preprocessed_category, v.final_category)
             IN ('Invalid_Reason', 'Case_Number', 'OTHER')
        THEN COALESCE(s.preprocessed_category, v.final_category)
        ELSE 'Valid_Reason'
      END AS reason_bucket,
      CURRENT_TIMESTAMP() AS classification_timestamp
    FROM preprocessing_stage s
    LEFT JOIN validated_classifications v ON s.id = v.id
  """, destination_table);

  SET row_count = (SELECT COUNT(*) FROM `durango-deflock.FlockML.classification_runs` UNION ALL SELECT 1);
  SET no_context_count = (SELECT COUNT(*) FROM preprocessing_stage WHERE has_no_context);

  -- Step 6: Log to audit table
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
    cost_estimate_usd
  )
  SELECT
    source_table,
    destination_table,
    start_time,
    CURRENT_TIMESTAMP(),
    (SELECT COUNT(*) FROM preprocessing_stage),
    (SELECT COUNT(*) FROM preprocessing_stage WHERE preprocessed_category IS NOT NULL),
    llm_count,
    fallback_count,
    no_context_count,
    ROUND((SELECT COUNT(*) FROM preprocessing_stage) * 0.000003, 4);

  -- Log completion message
  SELECT FORMAT('✓ Classification complete for %s -> %s', source_table, destination_table) AS status;

END;

