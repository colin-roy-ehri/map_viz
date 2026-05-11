-- ============================================================================
-- Phase 3.1: Parameterized Standard Analysis Procedure
-- ============================================================================
-- Purpose: Consolidate duplicate analysis queries from sql/37_local_enriched_analysis.sql
--
-- Previous: 6 identical queries duplicated for October and August datasets
--   - sql/37 lines 8-33: October analysis
--   - sql/37 lines 35-61: August analysis (identical structure, different table)
--
-- Now: Single procedure generates all standard analyses for ANY dataset
--
-- Output Tables:
--   1. local_reason_breakdown - Search count by reason and org
--   2. local_org_summary - Overall statistics by organization
--   3. local_participation_status - Participation agency tracking
--   4. local_reason_bucket_distribution - Distribution across reason buckets
--   5. local_invalid_case_analysis - Invalid and case numbers
--   6. local_high_risk_categories - High-risk crime categories
--
-- Usage:
--   CALL FlockML.sp_generate_standard_analysis(
--     'durango-deflock.DurangoPD.October2025_enriched',
--     'durango-deflock.DurangoPD',
--     'October 2025'
--   );
-- ============================================================================

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_generate_standard_analysis`(
  enriched_table STRING,
  output_dataset STRING,
  dataset_label STRING
)
BEGIN
  DECLARE start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

  -- ========================================================================
  -- Analysis 1: Reason breakdown by local Colorado organizations
  -- ========================================================================
  EXECUTE IMMEDIATE FORMAT('''
    CREATE OR REPLACE TABLE `%s.local_reason_breakdown` AS
    SELECT
      '%s' AS dataset,
      org_name,
      reason_category,
      COUNT(*) as search_count,
      ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY org_name), 1) as pct_of_org,
      COUNTIF(is_participating_agency) as participating_count,
      COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num_count,
      CURRENT_TIMESTAMP() AS analysis_timestamp
    FROM `%s`
    GROUP BY org_name, reason_category
    ORDER BY org_name, search_count DESC
  ''', output_dataset, dataset_label, enriched_table);

  -- ========================================================================
  -- Analysis 2: Organization summary statistics
  -- ========================================================================
  EXECUTE IMMEDIATE FORMAT('''
    CREATE OR REPLACE TABLE `%s.local_org_summary` AS
    SELECT
      '%s' AS dataset,
      org_name,
      COUNT(*) as total_searches,
      COUNT(DISTINCT reason_category) as distinct_reasons_used,
      COUNTIF(is_participating_agency) as participating_searches,
      ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) as pct_participating,
      COUNT(DISTINCT DATE(search_date)) as days_with_searches,
      CURRENT_TIMESTAMP() AS analysis_timestamp
    FROM `%s`
    GROUP BY org_name
    ORDER BY total_searches DESC
  ''', output_dataset, dataset_label, enriched_table);

  -- ========================================================================
  -- Analysis 3: Participation status breakdown
  -- ========================================================================
  EXECUTE IMMEDIATE FORMAT('''
    CREATE OR REPLACE TABLE `%s.local_participation_status` AS
    SELECT
      '%s' AS dataset,
      is_participating_agency,
      COUNT(*) as total_searches,
      COUNT(DISTINCT org_name) as unique_orgs,
      COUNT(DISTINCT reason_category) as distinct_reasons,
      ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as pct_of_all_searches,
      CURRENT_TIMESTAMP() AS analysis_timestamp
    FROM `%s`
    GROUP BY is_participating_agency
    ORDER BY total_searches DESC
  ''', output_dataset, dataset_label, enriched_table);

  -- ========================================================================
  -- Analysis 4: Reason bucket distribution
  -- ========================================================================
  EXECUTE IMMEDIATE FORMAT('''
    CREATE OR REPLACE TABLE `%s.local_reason_bucket_distribution` AS
    SELECT
      '%s' AS dataset,
      reason_bucket,
      reason_category,
      COUNT(*) as count,
      ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY reason_bucket), 1) as pct_of_bucket,
      ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as pct_of_all,
      CURRENT_TIMESTAMP() AS analysis_timestamp
    FROM `%s`
    GROUP BY reason_bucket, reason_category
    ORDER BY count DESC
  ''', output_dataset, dataset_label, enriched_table);

  -- ========================================================================
  -- Analysis 5: Invalid and case number records
  -- ========================================================================
  EXECUTE IMMEDIATE FORMAT('''
    CREATE OR REPLACE TABLE `%s.local_invalid_case_analysis` AS
    SELECT
      '%s' AS dataset,
      reason_category,
      COUNT(*) as record_count,
      COUNT(DISTINCT org_name) as unique_orgs,
      ROUND(AVG(LENGTH(CAST(reason AS STRING))) OVER (), 1) as avg_reason_length,
      CURRENT_TIMESTAMP() AS analysis_timestamp
    FROM `%s`
    WHERE reason_category IN ('Invalid_Reason', 'Case_Number', 'OTHER')
    GROUP BY reason_category
    ORDER BY record_count DESC
  ''', output_dataset, dataset_label, enriched_table);

  -- ========================================================================
  -- Analysis 6: High-risk crime categories
  -- ========================================================================
  EXECUTE IMMEDIATE FORMAT('''
    CREATE OR REPLACE TABLE `%s.local_high_risk_categories` AS
    SELECT
      '%s' AS dataset,
      reason_category,
      COUNT(*) as search_count,
      COUNT(DISTINCT org_name) as unique_agencies,
      COUNTIF(is_participating_agency) as participating_agencies,
      ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as pct_of_all_searches,
      STRING_AGG(DISTINCT org_name, ', ' ORDER BY org_name) as agencies_involved,
      CURRENT_TIMESTAMP() AS analysis_timestamp
    FROM `%s`
    WHERE reason_category IN (
      'Violent_Crime', 'Sex_Crime', 'Human_Trafficking', 'Weapons_Offense',
      'Kidnapping', 'Domestic_Violence'
    )
    GROUP BY reason_category
    ORDER BY search_count DESC
  ''', output_dataset, dataset_label, enriched_table);

  -- ========================================================================
  -- Log completion
  -- ========================================================================
  SELECT FORMAT(
    '✓ Standard analysis complete for %s\n  Analysis timestamp: %s\n  6 analysis tables created in %s\n  Duration: %d seconds',
    dataset_label,
    FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', start_time),
    output_dataset,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, SECOND)
  ) AS status;

END;
