-- ============================================================================
-- Phase 3: Analysis of Participation by Reason Category
-- ============================================================================
-- Purpose: Break down searches by reason and show participation rates
-- Outputs: Multiple analysis views and result sets

-- ============================================================================
-- ANALYSIS 1: Participation Rate by Reason Category (High-Level)
-- ============================================================================
-- Show which types of searches involve participating agencies most
SELECT
  reason_category,
  COUNT(*) AS total_searches,
  COUNTIF(is_participating_agency) AS participating_searches,
  COUNTIF(NOT is_participating_agency) AS non_participating_searches,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 2) AS participating_pct,
  COUNT(DISTINCT org_name) AS unique_agencies,
  COUNT(DISTINCT CASE WHEN is_participating_agency THEN org_name END) AS unique_participating_agencies
FROM `durango-deflock.DurangoPD.August2025_enriched`
GROUP BY reason_category
ORDER BY total_searches DESC;

-- ============================================================================
-- ANALYSIS 2: Participation Rate by Reason Bucket (Detailed)
-- ============================================================================
-- More granular breakdown including invalid reasons and case number only
SELECT
  reason_bucket,
  COUNT(*) AS total_searches,
  COUNTIF(is_participating_agency) AS participating_searches,
  COUNTIF(NOT is_participating_agency) AS non_participating_searches,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 2) AS participating_pct,
  COUNT(DISTINCT org_name) AS unique_agencies,
  -- Show if this reason type tends to have case numbers
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) != '') * 100.0 / COUNT(*), 1) AS pct_with_case_num
FROM `durango-deflock.DurangoPD.August2025_enriched`
GROUP BY reason_bucket
ORDER BY total_searches DESC;

-- ============================================================================
-- ANALYSIS 3: Reasonless Searches - Key High-Risk Category
-- ============================================================================
-- Identify searches with no valid reason or invalid reason + no case number
SELECT
  CASE
    WHEN reason_bucket = 'no_reason' THEN 'No Reason Provided (NULL)'
    WHEN reason_bucket = 'Invalid_Reason' THEN 'Invalid Reason'
    WHEN reason_bucket = 'Case_Number' THEN 'Case Number Only'
    WHEN reason_bucket = 'OTHER' THEN 'Unknown/OTHER'
  END AS reason_quality,
  COUNT(*) AS search_count,
  COUNTIF(is_participating_agency) AS participating_count,
  COUNTIF(NOT is_participating_agency) AS non_participating_count,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 2) AS participating_pct,
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) = '') * 100.0 / COUNT(*), 1) AS pct_no_case_num,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_all_searches
FROM `durango-deflock.DurangoPD.August2025_enriched`
WHERE reason_bucket IN ('no_reason', 'Invalid_Reason', 'Case_Number', 'OTHER')
GROUP BY reason_quality
ORDER BY search_count DESC;

-- ============================================================================
-- ANALYSIS 4: Valid vs Invalid Reason Searches
-- ============================================================================
-- High-level summary: legitimate reasons vs problematic searches
SELECT
  CASE
    WHEN reason_bucket IN ('Invalid_Reason', 'Case_Number', 'OTHER', 'no_reason') THEN 'No/Invalid Reason'
    ELSE 'Valid Reason'
  END AS reason_validity,
  COUNT(*) AS search_count,
  COUNTIF(is_participating_agency) AS participating_searches,
  COUNTIF(NOT is_participating_agency) AS non_participating_searches,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 2) AS participating_pct,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') AS searches_without_case_num,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM `durango-deflock.DurangoPD.August2025_enriched`
GROUP BY reason_validity
ORDER BY search_count DESC;

-- ============================================================================
-- ANALYSIS 5: Cross-tabulation: Reason Type × Participation Status
-- ============================================================================
-- See which reason types align most with participating vs non-participating agencies
WITH reason_participation AS (
  SELECT
    reason_category,
    agency_status,
    COUNT(*) AS search_count
  FROM `durango-deflock.DurangoPD.August2025_enriched`
  GROUP BY reason_category, agency_status
)
SELECT
  reason_category,
  SUM(CASE WHEN agency_status = 'Participating' THEN search_count ELSE 0 END) AS participating,
  SUM(CASE WHEN agency_status = 'Non-Participating' THEN search_count ELSE 0 END) AS non_participating,
  SUM(search_count) AS total,
  ROUND(SUM(CASE WHEN agency_status = 'Participating' THEN search_count ELSE 0 END) * 100.0 / SUM(search_count), 2) AS participating_pct
FROM reason_participation
GROUP BY reason_category
ORDER BY total DESC;

-- ============================================================================
-- ANALYSIS 6: Case Number Presence by Participation Status
-- ============================================================================
-- Understanding data quality (case numbers) by agency type
SELECT
  agency_status,
  CASE
    WHEN TRIM(COALESCE(case_num, '')) = '' THEN 'No Case Number'
    ELSE 'Has Case Number'
  END AS case_number_status,
  COUNT(*) AS search_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY agency_status), 2) AS pct_within_agency_status
FROM `durango-deflock.DurangoPD.August2025_enriched`
GROUP BY agency_status, case_number_status
ORDER BY agency_status, search_count DESC;

-- ============================================================================
-- ANALYSIS 7: High-Risk Searches (No Reason + No Case Number + Participating)
-- ============================================================================
-- Flag searches that combine multiple risk factors
SELECT
  reason_bucket,
  reason_category,
  agency_status,
  COUNT(*) AS search_count,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') AS without_case_num,
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) = '') * 100.0 / COUNT(*), 1) AS pct_missing_case_num
FROM `durango-deflock.DurangoPD.August2025_enriched`
WHERE reason_bucket IN ('no_reason', 'Invalid_Reason')
  AND agency_status = 'Participating'
GROUP BY reason_bucket, reason_category, agency_status
ORDER BY search_count DESC;

-- ============================================================================
-- ANALYSIS 8: Summary Table for Export
-- ============================================================================
-- Clean summary table suitable for CSV export
SELECT
  reason_category AS `Reason Category`,
  COUNT(*) AS `Total Searches`,
  COUNTIF(is_participating_agency) AS `Participating Searches`,
  COUNTIF(NOT is_participating_agency) AS `Non-Participating Searches`,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS `Participation %`,
  COUNTIF(TRIM(COALESCE(case_num, '')) = '') AS `No Case Number`,
  ROUND(COUNTIF(TRIM(COALESCE(case_num, '')) = '') * 100.0 / COUNT(*), 1) AS `No Case # %`
FROM `durango-deflock.DurangoPD.August2025_enriched`
GROUP BY reason_category
ORDER BY `Total Searches` DESC;


