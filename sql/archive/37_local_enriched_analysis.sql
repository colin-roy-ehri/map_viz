-- ============================================================================
-- Local Colorado Organization Analysis: Based on Enriched Tables
-- ============================================================================
-- Similar analysis to high-risk file, but using enriched tables (October and August)
-- Focuses on reason category breakdown and trends by org_name for local agencies

-- ============================================================================
-- OCTOBER: Reason Breakdown by Local Colorado Organizations
-- ============================================================================
-- All records from October enriched table
-- Shows overall search reason distribution for each local organization
SELECT
  'October 2025' AS dataset,
  org_name,
  reason_category,
  COUNT(*) as search_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY org_name), 1) as pct_of_org_searches,
  COUNTIF(is_participating_agency) as participating_count,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) as pct_participating,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num_count,
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) = '') * 100.0 / COUNT(*), 1) as pct_no_case_num
FROM `durango-deflock.DurangoPD.October2025_enriched`
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
-- AUGUST: Reason Breakdown by Local Colorado Organizations
-- ============================================================================
-- All records from August enriched table
-- Shows overall search reason distribution for each local organization
SELECT
  'August 2025' AS dataset,
  org_name,
  reason_category,
  COUNT(*) as search_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY org_name), 1) as pct_of_org_searches,
  COUNTIF(is_participating_agency) as participating_count,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) as pct_participating,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num_count,
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) = '') * 100.0 / COUNT(*), 1) as pct_no_case_num
FROM `durango-deflock.DurangoPD.August2025_enriched`
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
-- OCTOBER: Summary by Local Organization
-- ============================================================================
-- Overall metrics for each local organization from October
SELECT
  'October 2025' AS dataset,
  org_name,
  COUNT(*) as total_searches,
  COUNT(DISTINCT reason_category) as distinct_reasons_used,
  COUNTIF(is_participating_agency) as participating_searches,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) as pct_participating,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num_searches,
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) = '') * 100.0 / COUNT(*), 1) as pct_missing_case_num,
  COUNT(DISTINCT matched_agency) as unique_matched_agencies,
  STRING_AGG(DISTINCT reason_category, ', ' ORDER BY reason_category LIMIT 10) as all_reason_categories
FROM `durango-deflock.DurangoPD.October2025_enriched`
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

-- ============================================================================
-- AUGUST: Summary by Local Organization
-- ============================================================================
-- Overall metrics for each local organization from August
SELECT
  'August 2025' AS dataset,
  org_name,
  COUNT(*) as total_searches,
  COUNT(DISTINCT reason_category) as distinct_reasons_used,
  COUNTIF(is_participating_agency) as participating_searches,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) as pct_participating,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num_searches,
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) = '') * 100.0 / COUNT(*), 1) as pct_missing_case_num,
  COUNT(DISTINCT matched_agency) as unique_matched_agencies,
  STRING_AGG(DISTINCT reason_category, ', ' ORDER BY reason_category LIMIT 10) as all_reason_categories
FROM `durango-deflock.DurangoPD.August2025_enriched`
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

-- ============================================================================
-- COMPARATIVE: Local Organization Metrics Both Months
-- ============================================================================
-- Compare October and August side-by-side for local organizations
WITH october_summary AS (
  SELECT
    'October 2025' AS dataset,
    org_name,
    COUNT(*) as total_searches,
    COUNTIF(is_participating_agency) as participating_searches,
    ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) as pct_participating,
    COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num_searches
  FROM `durango-deflock.DurangoPD.October2025_enriched`
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
),
august_summary AS (
  SELECT
    'August 2025' AS dataset,
    org_name,
    COUNT(*) as total_searches,
    COUNTIF(is_participating_agency) as participating_searches,
    ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) as pct_participating,
    COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num_searches
  FROM `durango-deflock.DurangoPD.August2025_enriched`
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
)
SELECT
  dataset,
  org_name,
  total_searches,
  participating_searches,
  pct_participating,
  no_case_num_searches,
  ROUND(no_case_num_searches * 100.0 / total_searches, 1) as pct_missing_case_num
FROM (
  SELECT * FROM october_summary
  UNION ALL
  SELECT * FROM august_summary
)
ORDER BY dataset, org_name, total_searches DESC;

-- ============================================================================
-- PARTICIPATON STATUS BREAKDOWN: Local Orgs October
-- ============================================================================
-- Shows how searches break down between participating and non-participating agencies
SELECT
  'October 2025' AS dataset,
  org_name,
  CASE WHEN is_participating_agency THEN 'Participating' ELSE 'Non-Participating' END as agency_status,
  COUNT(*) as search_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY org_name), 1) as pct_of_org,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num
FROM `durango-deflock.DurangoPD.October2025_enriched`
WHERE LOWER(org_name) LIKE '%durango%'
   OR LOWER(org_name) LIKE '%telluride%'
   OR LOWER(org_name) LIKE '%la plata%'
   OR LOWER(org_name) LIKE '%montezuma%'
   OR LOWER(org_name) LIKE '%pagosa%'
   OR LOWER(org_name) LIKE '%grand junction%'
   OR LOWER(org_name) LIKE '%archuleta%'
   OR LOWER(org_name) LIKE '%montrose%'
   OR LOWER(org_name) LIKE '%mesa county%'
GROUP BY org_name, is_participating_agency
ORDER BY org_name, search_count DESC;

-- ============================================================================
-- PARTICIPATION STATUS BREAKDOWN: Local Orgs August
-- ============================================================================
-- Shows how searches break down between participating and non-participating agencies
SELECT
  'August 2025' AS dataset,
  org_name,
  CASE WHEN is_participating_agency THEN 'Participating' ELSE 'Non-Participating' END as agency_status,
  COUNT(*) as search_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY org_name), 1) as pct_of_org,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') as no_case_num
FROM `durango-deflock.DurangoPD.August2025_enriched`
WHERE LOWER(org_name) LIKE '%durango%'
   OR LOWER(org_name) LIKE '%telluride%'
   OR LOWER(org_name) LIKE '%la plata%'
   OR LOWER(org_name) LIKE '%montezuma%'
   OR LOWER(org_name) LIKE '%pagosa%'
   OR LOWER(org_name) LIKE '%grand junction%'
   OR LOWER(org_name) LIKE '%archuleta%'
   OR LOWER(org_name) LIKE '%montrose%'
   OR LOWER(org_name) LIKE '%mesa county%'
GROUP BY org_name, is_participating_agency
ORDER BY org_name, search_count DESC;

-- ============================================================================
-- REASON BUCKET DISTRIBUTION: Local Orgs October
-- ============================================================================
-- Groups by reason_bucket to see if organizations use invalid/case-only reasons
SELECT
  'October 2025' AS dataset,
  org_name,
  reason_bucket,
  reason_category,
  COUNT(*) as search_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY org_name), 1) as pct_of_org,
  COUNTIF(is_participating_agency) as participating_count
FROM `durango-deflock.DurangoPD.October2025_enriched`
WHERE LOWER(org_name) LIKE '%durango%'
   OR LOWER(org_name) LIKE '%telluride%'
   OR LOWER(org_name) LIKE '%la plata%'
   OR LOWER(org_name) LIKE '%montezuma%'
   OR LOWER(org_name) LIKE '%pagosa%'
   OR LOWER(org_name) LIKE '%grand junction%'
   OR LOWER(org_name) LIKE '%archuleta%'
   OR LOWER(org_name) LIKE '%montrose%'
   OR LOWER(org_name) LIKE '%mesa county%'
GROUP BY org_name, reason_bucket
ORDER BY org_name, search_count DESC;

-- ============================================================================
-- REASON BUCKET DISTRIBUTION: Local Orgs August
-- ============================================================================
-- Groups by reason_bucket to see if organizations use invalid/case-only reasons
SELECT
  'August 2025' AS dataset,
  org_name,
  reason_bucket,
  COUNT(*) as search_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY org_name), 1) as pct_of_org,
  COUNTIF(is_participating_agency) as participating_count
FROM `durango-deflock.DurangoPD.August2025_enriched`
WHERE LOWER(org_name) LIKE '%durango%'
   OR LOWER(org_name) LIKE '%telluride%'
   OR LOWER(org_name) LIKE '%la plata%'
   OR LOWER(org_name) LIKE '%montezuma%'
   OR LOWER(org_name) LIKE '%pagosa%'
   OR LOWER(org_name) LIKE '%grand junction%'
   OR LOWER(org_name) LIKE '%archuleta%'
   OR LOWER(org_name) LIKE '%montrose%'
   OR LOWER(org_name) LIKE '%mesa county%'
GROUP BY org_name, reason_bucket
ORDER BY org_name, search_count DESC;
