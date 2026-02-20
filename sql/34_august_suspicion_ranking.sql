-- ============================================================================
-- August 2025: Suspicion Ranking Analysis
-- ============================================================================
-- Same suspicion scoring logic applied to August data
-- Risk Factors (cumulative scoring):
-- 1. Participating agency: +40 points
-- 2. No case number: +30 points
-- 3. AOA/Interagency reason: +20 points
-- 4. Invalid/ambiguous reason: +10 points
-- Max Score: 100

-- Phase 1: Create suspicion score calculation view for August
CREATE OR REPLACE VIEW `durango-deflock.FlockML.august_suspicion_ranking_analysis` AS
SELECT
  c.* EXCEPT (classification_timestamp),
  COALESCE(m.is_participating_agency, FALSE) AS is_participating_agency,
  m.matched_agency,
  m.matched_state,
  m.matched_type,
  -- Calculate suspicion score
  LEAST(
    CAST(COALESCE(m.is_participating_agency, FALSE) AS INT64) * 40 +
    CASE WHEN TRIM(COALESCE(c.case_num, '')) = '' THEN 30 ELSE 0 END +
    CASE WHEN LOWER(c.reason_category) = 'interagency' THEN 20 ELSE 0 END +
    CASE WHEN c.reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER') THEN 10 ELSE 0 END,
    100
  ) AS suspicion_score,
  -- Identify which factors triggered suspicion
  ARRAY_TO_STRING(
    ARRAY_CONCAT(
      IF(COALESCE(m.is_participating_agency, FALSE), ['Participating Agency'], []),
      IF(TRIM(COALESCE(c.case_num, '')) = '', ['No Case Number'], []),
      IF(LOWER(c.reason_category) = 'interagency', ['AOA/Interagency'], []),
      IF(c.reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER'), ['Invalid Reason'], [])
    ),
    '|'
  ) AS risk_factors,
  -- Categorize suspicion level
  CASE
    WHEN LEAST(
      CAST(COALESCE(m.is_participating_agency, FALSE) AS INT64) * 40 +
      CASE WHEN TRIM(COALESCE(c.case_num, '')) = '' THEN 30 ELSE 0 END +
      CASE WHEN LOWER(c.reason_category) = 'interagency' THEN 20 ELSE 0 END +
      CASE WHEN c.reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER') THEN 10 ELSE 0 END,
      100
    ) = 0 THEN 'No Suspicion'
    WHEN LEAST(
      CAST(COALESCE(m.is_participating_agency, FALSE) AS INT64) * 40 +
      CASE WHEN TRIM(COALESCE(c.case_num, '')) = '' THEN 30 ELSE 0 END +
      CASE WHEN LOWER(c.reason_category) = 'interagency' THEN 20 ELSE 0 END +
      CASE WHEN c.reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER') THEN 10 ELSE 0 END,
      100
    ) <= 30 THEN 'Low Suspicion'
    WHEN LEAST(
      CAST(COALESCE(m.is_participating_agency, FALSE) AS INT64) * 40 +
      CASE WHEN TRIM(COALESCE(c.case_num, '')) = '' THEN 30 ELSE 0 END +
      CASE WHEN LOWER(c.reason_category) = 'interagency' THEN 20 ELSE 0 END +
      CASE WHEN c.reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER') THEN 10 ELSE 0 END,
      100
    ) <= 60 THEN 'Moderate Suspicion'
    WHEN LEAST(
      CAST(COALESCE(m.is_participating_agency, FALSE) AS INT64) * 40 +
      CASE WHEN TRIM(COALESCE(c.case_num, '')) = '' THEN 30 ELSE 0 END +
      CASE WHEN LOWER(c.reason_category) = 'interagency' THEN 20 ELSE 0 END +
      CASE WHEN c.reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER') THEN 10 ELSE 0 END,
      100
    ) < 100 THEN 'High Suspicion'
    ELSE 'Very High Suspicion'
  END AS suspicion_category
FROM `durango-deflock.DurangoPD.August2025_classified` c
LEFT JOIN `durango-deflock.FlockML.august_org_name_matches` m
  ON c.org_name = m.org_name;

-- ============================================================================
-- QUERY 1: Executive Summary Statistics
-- ============================================================================
SELECT
  'AUGUST 2025 SUSPICION RANKING SUMMARY' as report_title,
  CURRENT_TIMESTAMP() as report_generated,
  COUNT(*) as total_searches,
  COUNT(DISTINCT org_name) as unique_agencies,
  COUNTIF(is_participating_agency) as participating_agency_searches,
  ROUND(COUNTIF(is_participating_agency) * 100 / COUNT(*), 2) as participating_pct,
  COUNTIF(suspicion_score = 0) as zero_suspicion_searches,
  COUNTIF(suspicion_score > 0 AND suspicion_score <= 30) as low_suspicion_searches,
  COUNTIF(suspicion_score > 30 AND suspicion_score <= 60) as moderate_suspicion_searches,
  COUNTIF(suspicion_score > 60 AND suspicion_score < 100) as high_suspicion_searches,
  COUNTIF(suspicion_score = 100) as very_high_suspicion_searches,
  COUNTIF(suspicion_score >= 60) as total_high_risk_searches,
  ROUND(COUNTIF(suspicion_score >= 60) * 100 / COUNT(*), 2) as high_risk_pct
FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`;

-- ============================================================================
-- QUERY 2: Suspicion Distribution Table
-- ============================================================================
SELECT
  suspicion_category as risk_level,
  COUNT(*) as search_count,
  COUNT(DISTINCT org_name) as unique_agencies,
  ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2) as pct_of_total,
  ROUND(AVG(suspicion_score), 1) as avg_suspicion_score,
  MIN(suspicion_score) as min_score,
  MAX(suspicion_score) as max_score
FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
GROUP BY suspicion_category
ORDER BY CASE suspicion_category
  WHEN 'No Suspicion' THEN 0
  WHEN 'Low Suspicion' THEN 1
  WHEN 'Moderate Suspicion' THEN 2
  WHEN 'High Suspicion' THEN 3
  WHEN 'Very High Suspicion' THEN 4
END;

-- ============================================================================
-- QUERY 3: Risk Factor Analysis
-- ============================================================================
SELECT
  'Case Number Presence' as factor_category,
  CASE WHEN TRIM(COALESCE(case_num, '')) = '' THEN 'Missing' ELSE 'Present' END as factor,
  COUNT(*) as searches,
  ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2) as pct,
  ROUND(AVG(suspicion_score), 1) as avg_suspicion
FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
GROUP BY CASE WHEN TRIM(COALESCE(case_num, '')) = '' THEN 'Missing' ELSE 'Present' END
UNION ALL
SELECT
  'Participating Agency',
  CASE WHEN is_participating_agency THEN 'Yes' ELSE 'No' END,
  COUNT(*),
  ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2),
  ROUND(AVG(suspicion_score), 1)
FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
GROUP BY is_participating_agency
UNION ALL
SELECT
  'Reason Type',
  CASE
    WHEN reason_category = 'Interagency' THEN 'AOA/Interagency'
    WHEN reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER') THEN 'Invalid/Ambiguous'
    ELSE 'Valid Reason'
  END,
  COUNT(*),
  ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2),
  ROUND(AVG(suspicion_score), 1)
FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
GROUP BY CASE
    WHEN reason_category = 'Interagency' THEN 'AOA/Interagency'
    WHEN reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER') THEN 'Invalid/Ambiguous'
    ELSE 'Valid Reason'
  END
ORDER BY factor_category, factor;

-- ============================================================================
-- QUERY 4: Top 50 Highest Risk Searches
-- ============================================================================
SELECT
  suspicion_score,
  suspicion_category,
  org_name,
  matched_agency,
  matched_state,
  case_num,
  reason,
  reason_category,
  is_participating_agency,
  risk_factors
FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
WHERE suspicion_score >= 60
ORDER BY suspicion_score DESC, org_name
LIMIT 50;

-- ============================================================================
-- QUERY 5: High Risk by Participating Agency
-- ============================================================================
SELECT
  matched_agency,
  matched_state,
  COUNT(*) as total_searches,
  COUNTIF(suspicion_score >= 60) as high_risk_searches,
  ROUND(COUNTIF(suspicion_score >= 60) * 100 / COUNT(*), 1) as high_risk_pct,
  ROUND(AVG(suspicion_score), 1) as avg_suspicion_score,
  COUNT(DISTINCT case_num) as distinct_case_numbers,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') as searches_missing_case_number
FROM `durango-deflock.FlockML.august_suspicion_ranking_analysis`
WHERE is_participating_agency = TRUE
GROUP BY matched_agency, matched_state
ORDER BY high_risk_searches DESC, total_searches DESC
LIMIT 30;
