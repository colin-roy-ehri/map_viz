-- ============================================================================
-- Comparative Analysis: October vs August 2025 with Reclassification
-- ============================================================================
-- Purpose: Compare both datasets using consistent metrics with reclassification logic
-- Shows how case number presence affects reason classification

-- ============================================================================
-- COMPARISON 1: Summary Statistics Both Datasets
-- ============================================================================
WITH october_reclassified AS (
  SELECT
    'October 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reclassified_reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num,
    is_participating_agency
  FROM `durango-deflock.DurangoPD.October2025_enriched`
),
august_reclassified AS (
  SELECT
    'August 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reclassified_reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num,
    is_participating_agency
  FROM `durango-deflock.DurangoPD.August2025_enriched`
),
combined AS (
  SELECT * FROM october_reclassified
  UNION ALL
  SELECT * FROM august_reclassified
)
SELECT
  dataset,
  COUNT(*) AS total_searches,
  COUNTIF(is_participating_agency) AS participating_searches,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS participation_pct,
  COUNTIF(has_case_num) AS searches_with_case_num,
  ROUND(COUNTIF(has_case_num) * 100.0 / COUNT(*), 1) AS pct_with_case_num,
  COUNTIF(reclassified_reason_category = 'Only_Case_Number') AS reclassified_count,
  ROUND(COUNTIF(reclassified_reason_category = 'Only_Case_Number') * 100.0 / COUNT(*), 1) AS pct_reclassified
FROM combined
GROUP BY dataset
ORDER BY dataset;

-- ============================================================================
-- COMPARISON 2: Participation Rate by Reason Category
-- ============================================================================
WITH october_reclassified AS (
  SELECT
    'October 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reason_category,
    is_participating_agency
  FROM `durango-deflock.DurangoPD.October2025_enriched`
),
august_reclassified AS (
  SELECT
    'August 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reason_category,
    is_participating_agency
  FROM `durango-deflock.DurangoPD.August2025_enriched`
),
combined AS (
  SELECT * FROM october_reclassified
  UNION ALL
  SELECT * FROM august_reclassified
)
SELECT
  dataset,
  reason_category,
  COUNT(*) AS total_searches,
  COUNTIF(is_participating_agency) AS participating,
  COUNTIF(NOT is_participating_agency) AS non_participating,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS participation_pct
FROM combined
GROUP BY dataset, reason_category
ORDER BY dataset, total_searches DESC;

-- ============================================================================
-- COMPARISON 3: Case Number Presence Across Datasets
-- ============================================================================
WITH october_reclassified AS (
  SELECT
    'October 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num
  FROM `durango-deflock.DurangoPD.October2025_enriched`
),
august_reclassified AS (
  SELECT
    'August 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reason_category,
    TRIM(COALESCE(case_num, '')) != '' AS has_case_num
  FROM `durango-deflock.DurangoPD.August2025_enriched`
),
combined AS (
  SELECT * FROM october_reclassified
  UNION ALL
  SELECT * FROM august_reclassified
)
SELECT
  dataset,
  reason_category,
  CASE WHEN has_case_num THEN 'With Case Number' ELSE 'No Case Number' END AS case_status,
  COUNT(*) AS count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY dataset, reason_category), 1) AS pct_within_reason
FROM combined
GROUP BY dataset, reason_category, case_status
ORDER BY dataset, reason_category, has_case_num DESC;

-- ============================================================================
-- COMPARISON 4: Reason Quality Distribution (Valid vs Invalid Info)
-- ============================================================================
WITH october_reclassified AS (
  SELECT
    'October 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reason_category,
    is_participating_agency
  FROM `durango-deflock.DurangoPD.October2025_enriched`
),
august_reclassified AS (
  SELECT
    'August 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Only_Case_Number'
      ELSE reason_category
    END AS reason_category,
    is_participating_agency
  FROM `durango-deflock.DurangoPD.August2025_enriched`
),
combined AS (
  SELECT * FROM october_reclassified
  UNION ALL
  SELECT * FROM august_reclassified
)
SELECT
  dataset,
  CASE
    WHEN reason_category IN ('Only_Case_Number', 'no_reason') THEN 'Insufficient Information'
    WHEN reason_category = 'Invalid_Reason' THEN 'Invalid Reason'
    ELSE 'Valid Reason'
  END AS reason_quality,
  COUNT(*) AS search_count,
  COUNTIF(is_participating_agency) AS participating,
  ROUND(COUNTIF(is_participating_agency) * 100.0 / COUNT(*), 1) AS participation_pct,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY dataset), 1) AS pct_of_dataset
FROM combined
GROUP BY dataset, reason_quality
ORDER BY dataset, search_count DESC;

-- ============================================================================
-- COMPARISON 5: Distribution Changes from Reclassification
-- ============================================================================
WITH october_changes AS (
  SELECT
    'October 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Reclassified'
      ELSE 'Unchanged'
    END AS classification_status,
    COUNT(*) AS count
  FROM `durango-deflock.DurangoPD.October2025_enriched`
  GROUP BY dataset, classification_status
),
august_changes AS (
  SELECT
    'August 2025' AS dataset,
    CASE
      WHEN reason_bucket IN ('Invalid_Reason', 'OTHER')
        AND TRIM(COALESCE(case_num, '')) != ''
      THEN 'Reclassified'
      ELSE 'Unchanged'
    END AS classification_status,
    COUNT(*) AS count
  FROM `durango-deflock.DurangoPD.August2025_enriched`
  GROUP BY dataset, classification_status
)
SELECT
  dataset,
  classification_status,
  count AS record_count,
  ROUND(count * 100.0 / SUM(count) OVER (PARTITION BY dataset), 1) AS pct_of_dataset
FROM (
  SELECT * FROM october_changes
  UNION ALL
  SELECT * FROM august_changes
)
ORDER BY dataset, classification_status;
