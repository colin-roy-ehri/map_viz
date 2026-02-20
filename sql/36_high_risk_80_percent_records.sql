-- ============================================================================
-- All 80%+ Suspicion Records from Both October and August 2025
-- ============================================================================
-- Extracts all high-risk records (suspicion_score >= 80) from both datasets
-- for detailed review and official reporting

-- ============================================================================
-- EXTRACT 1: All 80%+ Suspicion Records - October 2025
-- ============================================================================
SELECT
  'October 2025' AS dataset,
  suspicion_score,
  suspicion_category,
  org_name,
  matched_agency,
  matched_state,
  matched_type,
  case_num,
  reason,
  reason_category,
  reason_bucket,
  is_participating_agency,
  risk_factors,
  person_searched,
  search_date
FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
WHERE suspicion_score >= 80
ORDER BY suspicion_score DESC, org_name, search_date DESC;

-- ============================================================================
-- EXTRACT 2: All 80%+ Suspicion Records - August 2025
-- ============================================================================
SELECT
  'August 2025' AS dataset,
  suspicion_score,
  suspicion_category,
  org_name,
  matched_agency,
  matched_state,
  matched_type,
  case_num,
  reason,
  reason_category,
  reason_bucket,
  is_participating_agency,
  risk_factors,
  person_searched,
  search_date
FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
WHERE suspicion_score >= 80
ORDER BY suspicion_score DESC, org_name, search_date DESC;

-- ============================================================================
-- COMBINED: All 80%+ Suspicion Records Both Months (Unified View)
-- ============================================================================
WITH october_high_risk AS (
  SELECT
    'October 2025' AS dataset,
    suspicion_score,
    suspicion_category,
    org_name,
    matched_agency,
    matched_state,
    matched_type,
    case_num,
    reason,
    reason_category,
    reason_bucket,
    is_participating_agency,
    risk_factors,
    person_searched,
    search_date
  FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
  WHERE suspicion_score >= 80
),
august_high_risk AS (
  SELECT
    'August 2025' AS dataset,
    suspicion_score,
    suspicion_category,
    org_name,
    matched_agency,
    matched_state,
    matched_type,
    case_num,
    reason,
    reason_category,
    reason_bucket,
    is_participating_agency,
    risk_factors,
    person_searched,
    search_date
  FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
  WHERE suspicion_score >= 80
)
SELECT
  dataset,
  suspicion_score,
  suspicion_category,
  org_name,
  matched_agency,
  matched_state,
  matched_type,
  case_num,
  reason,
  reason_category,
  reason_bucket,
  is_participating_agency,
  risk_factors,
  person_searched,
  search_date,
  CASE
    WHEN suspicion_score = 100 THEN 'CRITICAL - All factors present'
    WHEN suspicion_score >= 90 THEN 'VERY HIGH - Multiple major factors'
    WHEN suspicion_score >= 80 THEN 'HIGH - Significant risk indicators'
  END AS risk_assessment
FROM (
  SELECT * FROM october_high_risk
  UNION ALL
  SELECT * FROM august_high_risk
)
ORDER BY suspicion_score DESC, dataset, search_date DESC;

-- ============================================================================
-- SUMMARY: Count by Risk Level (80%+)
-- ============================================================================
WITH october_high_risk AS (
  SELECT
    'October 2025' AS dataset,
    suspicion_score,
    suspicion_category
  FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
  WHERE suspicion_score >= 80
),
august_high_risk AS (
  SELECT
    'August 2025' AS dataset,
    suspicion_score,
    suspicion_category
  FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
  WHERE suspicion_score >= 80
)
SELECT
  dataset,
  CASE
    WHEN suspicion_score = 100 THEN 'Critical (100%)'
    WHEN suspicion_score >= 90 THEN 'Very High (90-99%)'
    WHEN suspicion_score >= 80 THEN 'High (80-89%)'
  END AS risk_level,
  COUNT(*) as record_count,
  COUNT(DISTINCT org_name) as involved_organizations
FROM (
  SELECT * FROM october_high_risk
  UNION ALL
  SELECT * FROM august_high_risk
)
GROUP BY dataset, risk_level
ORDER BY dataset, 
  CASE WHEN risk_level = 'Critical (100%)' THEN 1
       WHEN risk_level = 'Very High (90-99%)' THEN 2
       WHEN risk_level = 'High (80-89%)' THEN 3 END DESC;

-- ============================================================================
-- DETAILED BREAKDOWN: Top Organizations with 80%+ Records
-- ============================================================================
WITH combined_high_risk AS (
  SELECT
    'October 2025' AS dataset,
    matched_agency,
    matched_state,
    is_participating_agency,
    suspicion_score
  FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
  WHERE suspicion_score >= 80
  UNION ALL
  SELECT
    'August 2025' AS dataset,
    matched_agency,
    matched_state,
    is_participating_agency,
    suspicion_score
  FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
  WHERE suspicion_score >= 80
)
SELECT
  dataset,
  matched_agency,
  matched_state,
  CASE WHEN is_participating_agency THEN 'Participating' ELSE 'Non-Participating' END as agency_status,
  COUNT(*) as high_risk_count,
  COUNTIF(suspicion_score = 100) as critical_100,
  COUNTIF(suspicion_score >= 90) as ninety_plus,
  COUNTIF(suspicion_score >= 80 AND suspicion_score < 90) as eighty_range
FROM combined_high_risk
GROUP BY dataset, matched_agency, matched_state, is_participating_agency
ORDER BY dataset, high_risk_count DESC;

-- ============================================================================
-- OCTOBER LOCAL ANALYSIS: Reason Breakdown by Local Colorado Organizations
-- ============================================================================
-- Focus on Durango-area agencies and nearby Colorado regions
-- Shows overall search reason trends for each local organization (all records)
SELECT
  org_name,
  reason_category,
  COUNT(*) as search_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY org_name), 1) as pct_of_org_searches,
  COUNTIF(is_participating_agency) as participating_count,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) as pct_participating,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num_count,
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) = '') * 100.0 / COUNT(*), 1) as pct_no_case_num,
  COUNTIF(suspicion_score >= 80) as high_risk_80_plus,
  ROUND(AVG(suspicion_score), 1) as avg_suspicion_score
FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
WHERE LOWER(org_name) LIKE '%durango%'
   OR LOWER(org_name) LIKE '%telluride%'
   OR LOWER(org_name) LIKE '%la plata%'
   OR LOWER(org_name) LIKE '%montezuma%'
   OR LOWER(org_name) LIKE '%pagosa%'
   OR LOWER(org_name) LIKE '%grand junction%'
   OR LOWER(org_name) LIKE '%archuleta%'
   OR LOWER(org_name) LIKE '%montrose%'
   OR LOWER(org_name) LIKE '%mesa county%'
GROUP BY org_name, reason_category
ORDER BY org_name, search_count DESC;

-- ============================================================================
-- OCTOBER LOCAL ANALYSIS: Summary by Local Organization
-- ============================================================================
-- Shows total searches, reason distribution, participation, and risk metrics for local agencies
SELECT
  org_name,
  COUNT(*) as total_searches,
  COUNT(DISTINCT reason_category) as distinct_reasons_used,
  COUNTIF(is_participating_agency) as participating_searches,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) as pct_participating,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num_searches,
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) = '') * 100.0 / COUNT(*), 1) as pct_missing_case_num,
  COUNTIF(suspicion_score >= 80) as high_risk_80_plus,
  ROUND(COUNTIF(suspicion_score >= 80) * 100.0 / COUNT(*), 1) as pct_high_risk_80_plus,
  COUNTIF(suspicion_score >= 60) as high_risk_60_plus,
  ROUND(COUNTIF(suspicion_score >= 60) * 100.0 / COUNT(*), 1) as pct_high_risk_60_plus,
  ROUND(AVG(suspicion_score), 1) as avg_suspicion_score,
  STRING_AGG(DISTINCT reason_category, ', ' ORDER BY reason_category LIMIT 10) as all_reason_categories
FROM `durango-deflock.FlockML.suspicion_ranking_analysis`
WHERE LOWER(org_name) LIKE '%durango%'
   OR LOWER(org_name) LIKE '%telluride%'
   OR LOWER(org_name) LIKE '%la plata%'
   OR LOWER(org_name) LIKE '%montezuma%'
   OR LOWER(org_name) LIKE '%pagosa%'
   OR LOWER(org_name) LIKE '%grand junction%'
   OR LOWER(org_name) LIKE '%archuleta%'
   OR LOWER(org_name) LIKE '%montrose%'
   OR LOWER(org_name) LIKE '%mesa county%'
GROUP BY org_name
ORDER BY total_searches DESC;
