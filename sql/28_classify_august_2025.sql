-- ============================================================================
-- Phase 1: Classify August 2025 Data with Reason Categorization
-- ============================================================================
-- Purpose: Parse org_names and categorize reasons from August 2025 dataset
-- Output: August2025_classified table with parsed and categorized data

CREATE OR REPLACE TABLE `durango-deflock.DurangoPD.August2025_classified` AS
SELECT
  * EXCEPT(reason),
  -- Categorize the reason field into buckets
  CASE
    WHEN (reason IS NULL OR LENGTH(reason) < 3) THEN 'no_reason'
    WHEN (reason LIKE '%25%' AND length(reason) > 5) OR ((case_num LIKE '%25%' OR case_num LIKE '%24%') AND length(case_num) > 5) THEN 'Case_Number'
    WHEN (LOWER(reason) LIKE '%homicide%' OR LOWER(reason) LIKE '%murder%') THEN 'Homicide'
    WHEN LOWER(reason) LIKE '%aban%' THEN 'Abandoned_Vehicle'
    WHEN (LOWER(reason) LIKE 'a&d' OR lower(reason) LIKE '%apprehension%' OR lower(reason) LIKE '%warrant%' OR lower(reason) LIKE '%wanted%') THEN 'Warrant'
    WHEN lower(reason) LIKE '%amber%' THEN 'Amber_Alert'
    WHEN lower(reason) LIKE '%sex%' THEN 'Sex_Crime'
    WHEN lower(reason) LIKE '%aoa%' THEN 'Assist_Other_Agencies'
    WHEN lower(reason) LIKE '%assault%' THEN 'Assault'
    WHEN lower(reason) LIKE '%robb%' OR LOWER(reason) LIKE '%jugg%' THEN 'Robbery'
    WHEN (lower(reason) LIKE '%atl%' OR lower(reason) LIKE '%bolo%') THEN 'Attempt_To_Locate'
    WHEN lower(reason) LIKE '%arson%' OR lower(reason) LIKE '%fire%' THEN 'Arson'
    WHEN lower(reason) LIKE '%auto%' OR lower(reason) LIKE '%carj%' OR lower(reason) LIKE '%mv%' OR lower(reason) LIKE '%stolen%' THEN 'Auto_Theft'
    WHEN lower(reason) LIKE '%burg%' OR lower(reason) LIKE '%b&e%' OR lower(reason) LIKE '%b/e%' THEN 'Burglary'
    WHEN lower(reason) LIKE '%drug%' OR lower(reason) LIKE '%meth%' OR lower(reason) LIKE '%narc%' THEN 'Drugs'
    WHEN lower(reason) LIKE '%domesti%' OR lower(reason) LIKE '%family%' THEN 'Domestic_Violence'
    WHEN lower(reason) LIKE '%felon%' THEN 'Felony'
    WHEN lower(reason) LIKE '%elud%' OR lower(reason) LIKE '%evad%' OR lower(reason) LIKE '%flee%' OR lower(reason) LIKE '%pursuit%' THEN 'Evasion_Pursuit'
    WHEN lower(reason) LIKE '%fraud%' OR lower(reason) LIKE '%scam%' THEN 'Fraud_Scam'
    WHEN lower(reason) LIKE '%fug%' THEN 'Fugitive'
    WHEN lower(reason) LIKE '%hit%' THEN 'Hit_And_Run'
    WHEN lower(reason) LIKE '%traffick%' THEN 'Human_Trafficking'
    WHEN lower(reason) LIKE '%interdic%' THEN 'Interdiction'
    WHEN lower(reason) LIKE '%theft%' OR lower(reason) LIKE '%larcen%' OR LOWER(reason) LIKE '%steal%' OR LOWER(reason) LIKE '%shopl%' THEN 'Theft'
    WHEN lower(reason) LIKE '%kidnap%' THEN 'Kidnapping'
    WHEN lower(reason) LIKE '%missing%' OR lower(reason) LIKE '%suic%' THEN 'Missing_Person'
    WHEN lower(reason) LIKE '%shoot%' THEN 'Shooting'
    WHEN lower(reason) LIKE '%stalk%' THEN 'Stalking'
    WHEN lower(reason) LIKE '%test%' OR lower(reason) LIKE '%training%' THEN 'Training'
    WHEN lower(reason) LIKE '%tag%' THEN 'Vehicle_Tags'
    WHEN lower(reason) LIKE '%welfare%' THEN 'Welfare_Check'
    WHEN LOWER(reason) LIKE 'reck%' THEN 'Reckless_Driving'
    WHEN LOWER(reason) LIKE '%smugg%' THEN 'Smuggling'
    WHEN LOWER(reason) LIKE '%tip%' THEN 'Tip'
    WHEN LOWER(reason) LIKE '%weapon%' THEN 'Weapons_Offense'
    WHEN LOWER(reason) LIKE '%10-%' OR (LOWER(reason) LIKE '10%' AND LENGTH(reason) = 4) THEN '10Code'
    WHEN lower(reason) LIKE '%inv%' OR lower(reason) LIKE '%case%' OR lower(reason) LIKE '%crime%' OR lower(reason) LIKE '%criminal%'
         OR lower(reason) LIKE '%reason%' OR lower(reason) LIKE '%find%' OR lower(reason) LIKE '%follow%' OR lower(reason) LIKE '%other%'
         OR lower(reason) LIKE '%intel%' OR lower(reason) LIKE '%ident%' OR lower(reason) LIKE '%inquir%' OR lower(reason) LIKE '%search%'
         OR lower(reason) LIKE '%locate%' OR lower(reason) LIKE '%enforceme%' OR lower(reason) LIKE '%patrol%' OR lower(reason) LIKE '%person%'
         OR lower(reason) LIKE '%sus%' OR lower(reason) LIKE '%tbd%' OR lower(reason) LIKE 'traffic' OR lower(reason) LIKE '%travel%'
         OR lower(reason) LIKE '%voi%' OR lower(reason) LIKE '%work%' OR lower(reason) LIKE '%info%' OR lower(reason) LIKE '%leo%'
         OR lower(reason) LIKE '%police%' OR lower(reason) LIKE '%query%' OR lower(reason) LIKE '%...%'
         OR (LENGTH(reason) >= 5 AND NOT REGEXP_CONTAINS(LOWER(reason), r'[aeiou]'))
         OR (REGEXP_CONTAINS(reason, '^[+-]?\\d+$') AND LENGTH(reason) < 5)
         OR REGEXP_CONTAINS(reason,'(?i)^(?:[qwertyuiop]{8,}|[asdfghjkl]{8,}|[zxcvbnm]{8,})$') THEN 'Invalid_Reason'
    ELSE 'OTHER'
  END AS reason_bucket,
  -- Group reasons into higher-level categories for cleaner analysis
  CASE
    WHEN (reason IS NULL OR LENGTH(reason) < 3) THEN 'Interagency'
    WHEN lower(reason) LIKE '%aoa%' THEN 'Interagency'
    WHEN (LOWER(reason) LIKE '%homicide%' OR LOWER(reason) LIKE '%murder%'
          OR lower(reason) LIKE '%assault%' OR lower(reason) LIKE '%robb%'
          OR lower(reason) LIKE '%kidnap%' OR lower(reason) LIKE '%shoot%'
          OR lower(reason) LIKE '%traffick%' OR lower(reason) LIKE '%weapon%') THEN 'Violent_Crime'
    WHEN (lower(reason) LIKE '%theft%' OR lower(reason) LIKE '%larcen%'
          OR LOWER(reason) LIKE '%steal%' OR LOWER(reason) LIKE '%shopl%'
          OR lower(reason) LIKE '%burg%' OR lower(reason) LIKE '%auto%'
          OR lower(reason) LIKE '%carj%' OR lower(reason) LIKE '%mv%'
          OR lower(reason) LIKE '%stolen%' OR lower(reason) LIKE '%arson%') THEN 'Property_Crime'
    WHEN (lower(reason) LIKE '%drug%' OR lower(reason) LIKE '%meth%'
          OR lower(reason) LIKE '%narc%' OR lower(reason) LIKE '%smugg%') THEN 'Drug_Crime'
    WHEN (lower(reason) LIKE '%warrant%' OR lower(reason) LIKE '%wanted%'
          OR lower(reason) LIKE '%fug%' OR lower(reason) LIKE '%apprehension%') THEN 'Warrant_Fugitive'
    WHEN (lower(reason) LIKE '%missing%' OR lower(reason) LIKE '%welfare%'
          OR lower(reason) LIKE '%suic%' OR lower(reason) LIKE '%atl%'
          OR lower(reason) LIKE '%bolo%') THEN 'Welfare_Missing'
    WHEN (lower(reason) LIKE '%sex%' OR lower(reason) LIKE '%domesti%'
          OR lower(reason) LIKE '%family%' OR lower(reason) LIKE '%stalk%'
          OR lower(reason) LIKE '%amber%') THEN 'Crimes_Against_Persons'
    WHEN (lower(reason) LIKE '%test%' OR lower(reason) LIKE '%training%') THEN 'Training'
    WHEN (lower(reason) LIKE '%fraud%' OR lower(reason) LIKE '%scam%') THEN 'Fraud_Financial'
    WHEN lower(reason) LIKE '%hit%' THEN 'Traffic_Related'
    WHEN (LOWER(reason) LIKE 'reck%' OR lower(reason) LIKE '%tag%') THEN 'Traffic_Related'
    WHEN (lower(reason) LIKE '%elud%' OR lower(reason) LIKE '%evad%'
          OR lower(reason) LIKE '%flee%' OR lower(reason) LIKE '%pursuit%'
          OR lower(reason) LIKE '%interdic%') THEN 'Evasion_Pursuit'
    WHEN (lower(reason) LIKE '%tip%' OR lower(reason) LIKE '%felon%') THEN 'Investigation'
    WHEN (reason LIKE '%25%' AND length(reason) > 5) OR ((case_num LIKE '%25%' OR case_num LIKE '%24%') AND length(case_num) > 5) THEN 'Case_Number_Only'
    WHEN lower(reason) LIKE '%inv%' OR lower(reason) LIKE '%case%' OR lower(reason) LIKE '%crime%'
         OR lower(reason) LIKE '%Invalid%' OR lower(reason) LIKE '%search%' THEN 'Invalid_Reason'
    ELSE 'Other'
  END AS reason_category,
  -- Original reason value
  reason
FROM `durango-deflock.DurangoPD.August2025`;

-- ============================================================================
-- Verification Query: Check categorization distribution
-- ============================================================================
-- Run this to verify reason categorization is working correctly
SELECT
  reason_bucket,
  reason_category,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
  COUNT(DISTINCT org_name) AS unique_agencies,
  ARRAY_AGG(DISTINCT reason LIMIT 3) AS sample_reasons
FROM `durango-deflock.DurangoPD.August2025_classified`
GROUP BY reason_bucket, reason_category
ORDER BY record_count DESC;
