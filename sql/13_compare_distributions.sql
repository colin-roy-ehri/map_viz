-- Phase 6.2: Category Distribution Comparison
-- Compare OLD vs NEW category distributions to identify significant changes

WITH old_distribution AS (
  SELECT
    'OLD_CASE_LOGIC' AS method,
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
    END AS category,
    COUNT(*) AS count
  FROM `durango-deflock.DurangoPD.October2025`
  GROUP BY category
),

new_distribution AS (
  SELECT
    'NEW_GEMINI_ML' AS method,
    reason_category AS category,
    COUNT(*) AS count
  FROM `durango-deflock.DurangoPD.October2025_classified`
  GROUP BY category
)

SELECT
  COALESCE(o.category, n.category) AS category,
  o.count AS old_count,
  n.count AS new_count,
  n.count - o.count AS difference,
  CASE
    WHEN o.count IS NULL THEN 'NEW'
    WHEN n.count IS NULL THEN 'REMOVED'
    WHEN ABS(n.count - o.count) / o.count > 0.1 THEN 'SIGNIFICANT_CHANGE'
    ELSE 'STABLE'
  END AS change_type,
  ROUND((n.count - o.count) / o.count * 100, 2) AS pct_change
FROM old_distribution o
FULL OUTER JOIN new_distribution n ON o.category = n.category
WHERE o.count IS NOT NULL OR n.count IS NOT NULL
ORDER BY ABS(n.count - o.count) DESC;
