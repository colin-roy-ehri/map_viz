-- Phase 6.1: Accuracy Evaluation Query
-- Compare Gemini classifications against rule-based CASE logic
-- Use on a sample to assess accuracy before full deployment

-- First, create accuracy evaluation table for a sample
CREATE OR REPLACE TABLE `durango-deflock.FlockML.accuracy_evaluation` AS
WITH sample AS (
  SELECT *
  FROM `durango-deflock.DurangoPD.October2025`
  TABLESAMPLE SYSTEM (5 PERCENT)
),

-- Apply OLD rule-based categorization (map to new merged categories)
rule_based AS (
  SELECT
    id,
    reason,
    CASE
      WHEN (reason IS NULL OR LENGTH(reason) < 3) THEN 'Invalid_Reason'
      WHEN (reason LIKE '%25%' AND length(reason) > 5) OR ((case_num LIKE '%25%' OR case_num LIKE '%24%') AND length(case_num) > 5) THEN 'Case_Number'
      -- Violent Crime mapping
      WHEN (LOWER(reason) LIKE '%homicide%' OR LOWER(reason) LIKE '%murder%') THEN 'Violent_Crime'
      WHEN lower(reason) LIKE '%assault%' THEN 'Violent_Crime'
      WHEN lower(reason) LIKE '%robb%' OR LOWER(reason) LIKE '%jugg%' THEN 'Violent_Crime'
      WHEN lower(reason) LIKE '%shoot%' THEN 'Violent_Crime'
      -- Property Crime mapping
      WHEN lower(reason) LIKE '%auto%' OR lower(reason) LIKE '%carj%' OR lower(reason) LIKE '%mv%' OR lower(reason) LIKE '%stolen%' THEN 'Property_Crime'
      WHEN lower(reason) LIKE '%burg%' OR lower(reason) LIKE '%b&e%' OR lower(reason) LIKE '%b/e%' THEN 'Property_Crime'
      WHEN lower(reason) LIKE '%theft%' OR lower(reason) LIKE '%larcen%' OR LOWER(reason) LIKE '%steal%' OR LOWER(reason) LIKE '%shopl%' THEN 'Property_Crime'
      -- Person Search mapping
      WHEN (LOWER(reason) LIKE 'a&d' OR lower(reason) LIKE '%apprehension%' OR lower(reason) LIKE '%warrant%' OR lower(reason) LIKE '%wanted%') THEN 'Person_Search'
      WHEN (lower(reason) LIKE '%atl%' OR lower(reason) LIKE '%bolo%') THEN 'Person_Search'
      WHEN lower(reason) LIKE '%fug%' THEN 'Person_Search'
      WHEN lower(reason) LIKE '%elud%' OR lower(reason) LIKE '%evad%' OR lower(reason) LIKE '%flee%' OR lower(reason) LIKE '%pursuit%' THEN 'Person_Search'
      -- Vehicle Related mapping
      WHEN LOWER(reason) LIKE '%aban%' THEN 'Vehicle_Related'
      WHEN lower(reason) LIKE '%hit%' THEN 'Vehicle_Related'
      WHEN LOWER(reason) LIKE 'reck%' THEN 'Vehicle_Related'
      WHEN lower(reason) LIKE '%tag%' THEN 'Vehicle_Related'
      -- Vulnerable Persons mapping
      WHEN lower(reason) LIKE '%amber%' THEN 'Vulnerable_Persons'
      WHEN lower(reason) LIKE '%missing%' OR lower(reason) LIKE '%suic%' THEN 'Vulnerable_Persons'
      WHEN lower(reason) LIKE '%welfare%' THEN 'Vulnerable_Persons'
      -- High Priority Crimes mapping (keep separate)
      WHEN lower(reason) LIKE '%sex%' THEN 'Sex_Crime'
      WHEN lower(reason) LIKE '%drug%' OR lower(reason) LIKE '%meth%' OR lower(reason) LIKE '%narc%' THEN 'Drugs'
      WHEN lower(reason) LIKE '%trafficking%' THEN 'Human_Trafficking'
      -- Other Specific mapping
      WHEN lower(reason) LIKE '%domesti%' OR lower(reason) LIKE '%family%' THEN 'Domestic_Violence'
      WHEN lower(reason) LIKE '%stalk%' THEN 'Stalking'
      WHEN lower(reason) LIKE '%kidnap%' THEN 'Kidnapping'
      WHEN lower(reason) LIKE '%arson%' OR lower(reason) LIKE '%fire%' THEN 'Arson'
      WHEN LOWER(reason) LIKE '%weapon%' THEN 'Weapons_Offense'
      WHEN LOWER(reason) LIKE '%smugg%' THEN 'Smuggling'
      -- Financial Crime mapping
      WHEN lower(reason) LIKE '%fraud%' OR lower(reason) LIKE '%scam%' THEN 'Financial_Crime'
      -- Interagency mapping
      WHEN lower(reason) LIKE '%aoa%' THEN 'Interagency'
      WHEN lower(reason) LIKE '%interdic%' THEN 'Interagency'
      WHEN LOWER(reason) LIKE '%tip%' THEN 'Interagency'
      -- Administrative mapping
      WHEN lower(reason) LIKE '%test%' OR lower(reason) LIKE '%training%' THEN 'Administrative'
      WHEN LOWER(reason) LIKE '%10-%' OR (LOWER(reason) LIKE '10%' AND LENGTH(reason) = 4) THEN 'Administrative'
      -- Invalid/Other mapping
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
    END AS rule_based_category
  FROM sample
),

-- Get Gemini classifications from classified table
gemini_classified AS (
  SELECT id, reason_category AS gemini_category
  FROM `durango-deflock.DurangoPD.October2025_classified`
  WHERE id IN (SELECT id FROM sample)
)

SELECT
  r.id,
  r.reason,
  r.rule_based_category,
  g.gemini_category,
  CASE
    WHEN r.rule_based_category = g.gemini_category THEN TRUE
    ELSE FALSE
  END AS categories_match
FROM rule_based r
LEFT JOIN gemini_classified g ON r.id = g.id;

-- Calculate accuracy metrics
SELECT
  COUNT(*) AS total_samples,
  SUM(CASE WHEN categories_match THEN 1 ELSE 0 END) AS matching_classifications,
  ROUND(SUM(CASE WHEN categories_match THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS accuracy_pct,
  SUM(CASE WHEN NOT categories_match THEN 1 ELSE 0 END) AS mismatches
FROM `durango-deflock.FlockML.accuracy_evaluation`;

-- Show confusion matrix (top mismatches)
SELECT
  rule_based_category,
  gemini_category,
  COUNT(*) AS mismatch_count,
  ARRAY_AGG(reason LIMIT 5) AS example_reasons
FROM `durango-deflock.FlockML.accuracy_evaluation`
WHERE NOT categories_match
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;
