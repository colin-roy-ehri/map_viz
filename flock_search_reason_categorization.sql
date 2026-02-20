WITH base AS (
SELECT *,
CASE 
  WHEN (reason IS NULL OR LENGTH(reason) < 3) THEN 'no_reason'
  WHEN (reason LIKE '%25%' AND length(reason) > 5) OR ((case_num LIKE '%25%' OR case_num LIKE '%24%') AND length(case_num) > 5) THEN 'Case_Number'
  WHEN (LOWER(reason) LIKE '%homicide%' OR LOWER(reason) LIKE '%murder%') THEN 'Homicide'
  WHEN LOWER(reason) LIKE '%aban%' THEN 'Abandoned_Vehicle'
  WHEN (LOWER(reason) LIKE 'a&d' OR lower(reason) LIKE '%apprehension%' OR lower(reason) LIKE '%warrant%' OR lower(reason) LIKE '%wanted%')
 THEN 'Warrant'
  WHEN lower(reason) LIKE '%amber%' THEN 'Amber_Alert'
  WHEN lower(reason) LIKE '%sex%' THEN 'Sex_Crime'
  WHEN lower(reason) LIKE '%aoa%' THEN 'Assist_Other_Agencies'
  WHEN lower(reason) LIKE '%assault%' THEN 'Assault'
  WHEN lower(reason) LIKE '%robb%' OR LOWER(reason) LIKE '%jugg%' THEN 'Robbery'
  WHEN (lower(reason) LIKE '%atl%' OR lower(reason) LIKE '%bolo%') THEN 'Attempt_To_Locate'
  WHEN lower(reason) LIKE '%arson%' OR  lower(reason) LIKE '%fire%' THEN 'Arson'
  WHEN lower(reason) LIKE '%auto%' OR lower(reason) LIKE '%carj%' OR lower(reason) LIKE '%mv%' OR lower(reason) LIKE '%stolen%' THEN 'Auto_Theft'
  WHEN lower(reason) LIKE '%burg%' OR lower(reason) LIKE '%b&e%' OR lower(reason) LIKE '%b/e%' THEN 'Burglary'
  WHEN lower(reason) LIKE '%drug%' OR lower(reason) LIKE '%meth%'OR lower(reason) LIKE '%narc%' THEN 'Drugs'
  WHEN lower(reason) LIKE '%domesti%' OR  lower(reason) LIKE '%family%'THEN 'Domestic_Violence'
  WHEN lower(reason) LIKE '%felon%' THEN 'Felony'
  WHEN lower(reason) LIKE '%elud%' OR  lower(reason) LIKE '%evad%' OR  lower(reason) LIKE '%flee%' OR lower(reason) LIKE '%pursuit%' THEN 'Evasion_Pursuit'
  WHEN lower(reason) LIKE '%fraud%' OR lower(reason) LIKE '%scam%' THEN 'Fraud_Scam'
  WHEN lower(reason) LIKE '%fug%' THEN 'Fugitive'
  WHEN lower(reason) LIKE '%hit%' THEN 'Hit_And_Run'
  WHEN lower(reason) LIKE '%traffick%' THEN 'Human_Trafficking'
  WHEN lower(reason) LIKE '%interdic%' THEN 'Interdiction'
  WHEN lower(reason) LIKE '%theft%' OR lower(reason) LIKE '%larcen%' OR LOWER(reason) LIKE '%steal%' OR LOWER(reason) LIKE '%shopl%' THEN 'Theft'
  WHEN lower(reason) LIKE '%kidnap%' THEN 'Kidnapping'
  WHEN lower(reason) LIKE '%missing%' OR lower(reason) LIKE '%suic%'  THEN 'Missing_Person'
  WHEN lower(reason) LIKE '%shoot%' THEN 'Shooting'
  WHEN lower(reason) LIKE '%stalk%' THEN 'Stalking'
  WHEN lower(reason) LIKE '%test%' OR lower(reason) LIKE '%training%' THEN 'Training'
  WHEN lower(reason) LIKE '%tag%' THEN 'Vehicle Tags'
  WHEN lower(reason) LIKE '%welfare%' THEN 'Welfare_Check'
  WHEN LOWER(reason) LIKE 'reck%' THEN 'Reckless_Driving'
  WHEN LOWER(reason) LIKE '%smugg%' THEN 'Smuggling'
  WHEN LOWER(reason) LIKE '%tip%' THEN 'Tip'
  WHEN LOWER(reason) LIKE '%weapon%' THEN 'Weapons_Offense'
  WHEN LOWER(reason) LIKE '%10-%' OR (LOWER(reason) LIKE '10%' AND LENGTH(reason) = 4) THEN '10Code'
  WHEN lower(reason) LIKE '%inv%' OR lower(reason) LIKE '%case%' OR lower(reason) LIKE '%crime%' OR lower(reason) LIKE '%criminal%' OR lower(reason) LIKE '%reason%' OR  lower(reason) LIKE '%find%' OR lower(reason) LIKE '%follow%' OR lower(reason) LIKE '%other%' OR lower(reason) LIKE '%intel%' OR lower(reason) LIKE '%ident%' OR lower(reason) LIKE '%inquir%' OR lower(reason) LIKE '%search%' OR lower(reason) LIKE '%locate%' OR lower(reason) LIKE '%enforceme%' OR lower(reason) LIKE '%patrol%' OR lower(reason) LIKE '%person%' OR lower(reason) LIKE '%sus%' OR lower(reason) LIKE '%tbd%' OR lower(reason) LIKE 'traffic' OR lower(reason) LIKE '%travel%' OR lower(reason) LIKE '%voi%' OR lower(reason) LIKE '%work%' OR (LENGTH(reason) >= 5 AND NOT REGEXP_CONTAINS(LOWER(reason), r'[aeiou]')) OR LOWER(reason) LIKE '%info%' OR LOWER(reason) LIKE '%leo%' OR LOWER(reason) LIKE '%police%' OR LOWER(reason) LIKE '%query%' OR (REGEXP_CONTAINS(reason, '^[+-]?\\d+$') AND LENGTH(reason) < 5) OR REGEXP_CONTAINS(reason,'(?i)^(?:[qwertyuiop]{8,}|[asdfghjkl]{8,}|[zxcvbnm]{8,})$') OR LOWER(reason) LIKE '%...%' THEN 'Invalid_Reason'
  ELSE 'OTHER' END AS reason_type,
ABS(DATE_DIFF(CAST(start_timestamp AS DATE),CAST(end_timestamp AS DATE),DAY)) AS search_days,
FROM `durango-deflock.TelluridePD.2025_Aggregate` 
WHERE lower(org_name) LIKE '%durango%'
),

reason_buckets AS (
SELECT 
*,
CASE WHEN reason_type IN ("Invalid_Reason",'Case_Number','OTHER','no_reason') THEN reason_type ELSE 'Generic_Reason' END AS Reason_Bucket
FROM base
)

SELECT 
reason_bucket,
COUNT(org_name)
FROM reason_buckets
-- WHERE reason_type = 'Case_Number'
GROUP BY 1
ORDER BY 2 DESC