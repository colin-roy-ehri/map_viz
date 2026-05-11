-- ============================================================================
-- Phase 2: Enrich August Data with Participation Status
-- ============================================================================
-- Purpose: Join August classified data with matching results
-- NOTE: Must run 29a_composite_org_matching.sql FIRST to create august_org_name_matches
-- Output: August2025_enriched table with participation status

CREATE OR REPLACE TABLE `durango-deflock.DurangoPD.August2025_enriched` AS
SELECT
  c.*,
  COALESCE(m.is_participating_agency, FALSE) AS is_participating_agency,
  m.matched_agency,
  m.matched_state,
  m.matched_type,
  m.confidence AS match_confidence,
  CASE
    WHEN COALESCE(m.is_participating_agency, FALSE) THEN 'Participating'
    ELSE 'Non-Participating'
  END AS agency_status
FROM `durango-deflock.DurangoPD.August2025_classified` c
LEFT JOIN `durango-deflock.FlockML.august_org_name_matches` m
  ON c.org_name = m.org_name;

-- ============================================================================
-- Verification Query 1: Overall participation summary
-- ============================================================================
SELECT
  agency_status,
  COUNT(*) AS search_count,
  COUNT(DISTINCT org_name) AS unique_agencies,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_searches,
  ROUND(AVG(CASE WHEN TRIM(COALESCE(case_num, '')) = '' THEN 1 ELSE 0 END) * 100, 1) AS pct_without_case_num
FROM `durango-deflock.DurangoPD.August2025_enriched`
GROUP BY agency_status
ORDER BY search_count DESC;

-- ============================================================================
-- Verification Query 2: Top agencies by search volume
-- ============================================================================
SELECT
  org_name,
  matched_agency,
  agency_status,
  COUNT(*) AS search_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY agency_status), 1) AS pct_within_status
FROM `durango-deflock.DurangoPD.August2025_enriched`
GROUP BY org_name, matched_agency, agency_status
ORDER BY search_count DESC
LIMIT 30;

-- ============================================================================
-- Verification Query 3: Participation by state
-- ============================================================================
SELECT
  CASE
    WHEN matched_state IS NOT NULL THEN matched_state
    ELSE 'Non-Participating'
  END AS state,
  COUNT(*) AS search_count,
  COUNT(DISTINCT org_name) AS unique_agencies,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM `durango-deflock.DurangoPD.August2025_enriched`
GROUP BY matched_state
ORDER BY search_count DESC;
