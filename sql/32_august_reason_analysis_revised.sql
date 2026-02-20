-- ============================================================================
-- August 2025: Reason Category Analysis with Case Number Reclassification
-- ============================================================================
-- Purpose: Analyze participation by reason with reclassification logic:
--   - 'invalid' or 'other' reasons WITH case number → reclassify as 'Only_Case_Number'
--   - 'invalid' or 'other' reasons WITHOUT case number → remain as classified
--   - Valid reasons WITH case number → kept as valid reason (don't report specially)
-- This enables better understanding of which searches have data support

-- ============================================================================
-- ANALYSIS 1: Participation Rate by Reclassified Reason Category
-- ============================================================================
WITH reclassified_reasons AS (
  SELECT
    *,
    -- Reclassify invalid/other reasons if they have a case number
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reclassified_reason_category,
    -- Flag whether this row had a case number
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num
  FROM `durango-deflock.DurangoPD.August2025_enriched`
)
SELECT
  reclassified_reason_category AS `Reason Category`,
  COUNT(*) AS `Total Searches`,
  COUNTIF(is_participating_agency) AS `Participating Searches`,
  COUNTIF(NOT is_participating_agency) AS `Non-Participating Searches`,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS `Participation %`,
  COUNT(DISTINCT org_name) AS `Unique Agencies`,
  COUNTIF(has_case_num) AS `With Case Number`,
  ROUND(COUNTIF(has_case_num) * 100.0 / COUNT(*), 1) AS `With Case # %`,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS `% of Total Searches`
FROM reclassified_reasons
GROUP BY reclassified_reason_category
ORDER BY `Total Searches` DESC;

-- ============================================================================
-- ANALYSIS 2: Detailed Breakdown by Original and Reclassified Reason
-- ============================================================================
WITH reclassified_reasons AS (
  SELECT
    *,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reclassified_reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num
  FROM `durango-deflock.DurangoPD.August2025_enriched`
)
SELECT
  reason_category AS `Original Reason`,
  reclassified_reason_category AS `Reclassified Reason`,
  COUNT(*) AS `Count`,
  COUNTIF(is_participating_agency) AS `Participating`,
  COUNTIF(has_case_num) AS `With Case Number`,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS `Participation %`
FROM reclassified_reasons
WHERE reason_category != reclassified_reason_category  -- Show only reclassified rows
GROUP BY reason_category, reclassified_reason_category
ORDER BY `Count` DESC;

-- ============================================================================
-- ANALYSIS 3: Case Number Presence by Reclassified Reason
-- ============================================================================
WITH reclassified_reasons AS (
  SELECT
    *,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reclassified_reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num
  FROM `durango-deflock.DurangoPD.August2025_enriched`
)
SELECT
  reclassified_reason_category AS `Reason Category`,
  CASE WHEN has_case_num THEN 'Has Case Number' ELSE 'No Case Number' END AS `Case Number Status`,
  COUNT(*) AS `Search Count`,
  COUNTIF(is_participating_agency) AS `Participating`,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY reclassified_reason_category), 1) AS `% Within Reason`
FROM reclassified_reasons
GROUP BY reclassified_reason_category, has_case_num
ORDER BY reclassified_reason_category, has_case_num DESC;

-- ============================================================================
-- ANALYSIS 4: Valid Reason Categories (excluding only-case-number entries)
-- ============================================================================
WITH reclassified_reasons AS (
  SELECT
    *,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reclassified_reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num
  FROM `durango-deflock.DurangoPD.August2025_enriched`
)
SELECT
  reclassified_reason_category AS `Reason Category`,
  COUNT(*) AS `Total Searches`,
  COUNTIF(is_participating_agency) AS `Participating Searches`,
  COUNTIF(NOT is_participating_agency) AS `Non-Participating Searches`,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS `Participation %`,
  COUNTIF(has_case_num) AS `With Case Number`,
  ROUND(COUNTIF(has_case_num) * 100.0 / COUNT(*), 1) AS `With Case # %`
FROM reclassified_reasons
WHERE reclassified_reason_category NOT IN ('Only_Case_Number', 'no_reason')
GROUP BY reclassified_reason_category
ORDER BY `Total Searches` DESC;

-- ============================================================================
-- ANALYSIS 5: Invalid/Case-Number-Only Searches
-- ============================================================================
WITH reclassified_reasons AS (
  SELECT
    *,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reclassified_reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num
  FROM `durango-deflock.DurangoPD.August2025_enriched`
)
SELECT
  reclassified_reason_category AS `Reason Category`,
  COUNT(*) AS `Search Count`,
  COUNTIF(is_participating_agency) AS `Participating`,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS `Participation %`,
  COUNTIF(has_case_num) AS `With Case Number`,
  COUNTIF(NOT has_case_num) AS `Without Case Number`,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS `% of All Searches`
FROM reclassified_reasons
WHERE reclassified_reason_category IN ('Only_Case_Number', 'no_reason', 'Invalid_Reason')
GROUP BY reclassified_reason_category
ORDER BY `Search Count` DESC;

-- ============================================================================
-- ANALYSIS 6: Participation Breakdown - All Reasons
-- ============================================================================
WITH reclassified_reasons AS (
  SELECT
    *,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reclassified_reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num
  FROM `durango-deflock.DurangoPD.August2025_enriched`
)
SELECT
  CASE
    WHEN reclassified_reason_category IN ('Only_Case_Number', 'no_reason') THEN 'Insufficient Information'
    WHEN reclassified_reason_category IN ('Invalid_Reason') THEN 'Invalid Reason'
    ELSE 'Valid Reason'
  END AS `Reason Quality`,
  COUNT(*) AS `Search Count`,
  COUNTIF(is_participating_agency) AS `Participating`,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS `Participation %`,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS `% of Total`
FROM reclassified_reasons
GROUP BY `Reason Quality`
ORDER BY `Search Count` DESC;

-- ============================================================================
-- ANALYSIS 7: Summary Table for Export (Consistent with October)
-- ============================================================================
WITH reclassified_reasons AS (
  SELECT
    *,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reclassified_reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num
  FROM `durango-deflock.DurangoPD.August2025_enriched`
)
SELECT
  reclassified_reason_category AS `Reason Category`,
  COUNT(*) AS `Total Searches`,
  COUNTIF(is_participating_agency) AS `Participating Searches`,
  COUNTIF(NOT is_participating_agency) AS `Non-Participating Searches`,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS `Participation %`,
  COUNTIF(has_case_num) AS `With Case Number`,
  ROUND(COUNTIF(has_case_num) * 100.0 / COUNT(*), 1) AS `With Case # %`,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS `% of Total Searches`
FROM reclassified_reasons
GROUP BY reclassified_reason_category
ORDER BY `Total Searches` DESC;
