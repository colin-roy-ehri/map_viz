-- ============================================================================
-- Comparative Suspicion Ranking Summary: October vs August 2025
-- ============================================================================
-- Brings together suspicion scores from both datasets for comparison

-- ============================================================================
-- SUMMARY 1: Overall Comparison Statistics
-- ============================================================================
WITH october_summary AS (
  SELECT
    'October 2025' AS dataset,
    COUNT(*) as total_searches,
    COUNT(DISTINCT org_name) as unique_agencies,
    COUNTIF(is_participating_agency) as participating_searches,
    COUNTIF(suspicion_score >= 60) as high_risk_searches,
    COUNTIF(suspicion_score >= 80) as very_high_risk_searches,
    COUNTIF(suspicion_score = 100) as critical_risk_searches,
    COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_number
  FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
),
august_summary AS (
  SELECT
    'August 2025' AS dataset,
    COUNT(*) as total_searches,
    COUNT(DISTINCT org_name) as unique_agencies,
    COUNTIF(is_participating_agency) as participating_searches,
    COUNTIF(suspicion_score >= 60) as high_risk_searches,
    COUNTIF(suspicion_score >= 80) as very_high_risk_searches,
    COUNTIF(suspicion_score = 100) as critical_risk_searches,
    COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_number
  FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
)
SELECT
  dataset,
  total_searches,
  unique_agencies,
  participating_searches,
  ROUND(participating_searches * 100.0 / total_searches, 1) as participating_pct,
  high_risk_searches,
  ROUND(high_risk_searches * 100.0 / total_searches, 1) as high_risk_pct,
  very_high_risk_searches,
  ROUND(very_high_risk_searches * 100.0 / total_searches, 1) as very_high_risk_pct,
  critical_risk_searches,
  ROUND(critical_risk_searches * 100.0 / total_searches, 1) as critical_pct,
  no_case_number,
  ROUND(no_case_number * 100.0 / total_searches, 1) as no_case_pct
FROM (
  SELECT * FROM october_summary
  UNION ALL
  SELECT * FROM august_summary
)
ORDER BY dataset;

-- ============================================================================
-- SUMMARY 2: Suspicion Category Distribution Comparison
-- ============================================================================
WITH october_dist AS (
  SELECT
    'October 2025' AS dataset,
    suspicion_category,
    COUNT(*) as search_count
  FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
  GROUP BY dataset, suspicion_category
),
august_dist AS (
  SELECT
    'August 2025' AS dataset,
    suspicion_category,
    COUNT(*) as search_count
  FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
  GROUP BY dataset, suspicion_category
)
SELECT
  dataset,
  suspicion_category,
  search_count,
  ROUND(search_count * 100.0 / SUM(search_count) OVER (PARTITION BY dataset), 1) as pct_of_dataset
FROM (
  SELECT * FROM october_dist
  UNION ALL
  SELECT * FROM august_dist
)
ORDER BY dataset, search_count DESC;

-- ============================================================================
-- SUMMARY 3: Risk Factor Breakdown Both Months
-- ============================================================================
WITH october_factors AS (
  SELECT
    'October 2025' AS dataset,
    COUNTIF(is_participating_agency) as participating_agency_count,
    COUNTIF(TRIM(COALESCE(case_num, '')) = '') as missing_case_num_count,
    COUNTIF(reason_category = 'Interagency') as interagency_count,
    COUNTIF(reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER')) as invalid_reason_count
  FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
),
august_factors AS (
  SELECT
    'August 2025' AS dataset,
    COUNTIF(is_participating_agency) as participating_agency_count,
    COUNTIF(TRIM(COALESCE(case_num, '')) = '') as missing_case_num_count,
    COUNTIF(reason_category = 'Interagency') as interagency_count,
    COUNTIF(reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER')) as invalid_reason_count
  FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
)
SELECT
  dataset,
  participating_agency_count,
  missing_case_num_count,
  interagency_count,
  invalid_reason_count
FROM (
  SELECT * FROM october_factors
  UNION ALL
  SELECT * FROM august_factors
)
ORDER BY dataset;

-- ============================================================================
-- SUMMARY 4: High Risk Agency Comparison
-- ============================================================================
WITH october_agencies AS (
  SELECT
    'October 2025' AS dataset,
    matched_agency,
    matched_state,
    COUNT(*) as total_searches,
    COUNTIF(suspicion_score >= 60) as high_risk_count
  FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
  WHERE is_participating_agency = TRUE
  GROUP BY dataset, matched_agency, matched_state
),
august_agencies AS (
  SELECT
    'August 2025' AS dataset,
    matched_agency,
    matched_state,
    COUNT(*) as total_searches,
    COUNTIF(suspicion_score >= 60) as high_risk_count
  FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
  WHERE is_participating_agency = TRUE
  GROUP BY dataset, matched_agency, matched_state
)
SELECT
  dataset,
  matched_agency,
  matched_state,
  total_searches,
  high_risk_count,
  ROUND(high_risk_count * 100.0 / total_searches, 1) as high_risk_pct
FROM (
  SELECT * FROM october_agencies
  UNION ALL
  SELECT * FROM august_agencies
)
WHERE high_risk_count > 0
ORDER BY dataset, high_risk_count DESC;

-- ============================================================================
-- SUMMARY 5: Attorney General Report Format (Both Months)
-- ============================================================================
WITH october_stats AS (
  SELECT
    'October 2025' AS month,
    COUNT(*) as total_searches,
    COUNT(DISTINCT org_name) as unique_orgs,
    COUNT(DISTINCT CASE WHEN is_participating_agency THEN org_name END) as participating_orgs,
    COUNTIF(is_participating_agency) as participating_searches,
    COUNTIF(suspicion_score >= 60) as high_risk_searches,
    COUNTIF(suspicion_score >= 80) as eighty_plus_risk,
    COUNTIF(suspicion_score = 100) as very_high_risk_searches,
    COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_number,
    COUNTIF(reason_category = 'Interagency') as aoa_searches
  FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
),
august_stats AS (
  SELECT
    'August 2025' AS month,
    COUNT(*) as total_searches,
    COUNT(DISTINCT org_name) as unique_orgs,
    COUNT(DISTINCT CASE WHEN is_participating_agency THEN org_name END) as participating_orgs,
    COUNTIF(is_participating_agency) as participating_searches,
    COUNTIF(suspicion_score >= 60) as high_risk_searches,
    COUNTIF(suspicion_score >= 80) as eighty_plus_risk,
    COUNTIF(suspicion_score = 100) as very_high_risk_searches,
    COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_number,
    COUNTIF(reason_category = 'Interagency') as aoa_searches
  FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
)
SELECT
  month,
  CAST(total_searches AS STRING) as total_searches,
  CAST(unique_orgs AS STRING) as unique_agencies,
  CAST(participating_orgs AS STRING) as participating_agencies,
  CAST(participating_searches AS STRING) as searches_by_participating,
  CAST(high_risk_searches AS STRING) as high_risk_60_plus,
  CAST(eighty_plus_risk AS STRING) as very_high_risk_80_plus,
  CAST(very_high_risk_searches AS STRING) as critical_100_percent,
  CAST(no_case_number AS STRING) as searches_no_case_num,
  CAST(aoa_searches AS STRING) as aoa_interagency_searches
FROM (
  SELECT * FROM october_stats
  UNION ALL
  SELECT * FROM august_stats
)
ORDER BY month;
