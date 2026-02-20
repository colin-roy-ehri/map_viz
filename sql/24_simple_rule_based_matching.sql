-- Phase 5.2 (Ultra-Simplified): Rule-Based Org Name Matching - Single Pass
-- Parse, match, and output results in one simple query

CREATE OR REPLACE TABLE `durango-deflock.FlockML.org_name_rule_based_matches` AS
WITH parsed AS (
  -- Parse unique org_names
  SELECT
    org_name,
    REGEXP_EXTRACT(org_name, r'([A-Z]{2})') AS state_code,
    TRIM(REGEXP_EXTRACT(org_name, r'\s([A-Z]+)$')) AS agency_type,
    TRIM(REGEXP_EXTRACT(org_name, r'^(.*?)\s[A-Z]{2}\s')) AS location_raw
  FROM (
    SELECT DISTINCT org_name
    FROM `durango-deflock.DurangoPD.October2025_classified`
    WHERE org_name IS NOT NULL
  )
),
matched AS (
  -- Try exact match first
  SELECT
    p.org_name,
    pa.`LAW ENFORCEMENT AGENCY` AS matched_agency,
    pa.STATE AS matched_state,
    pa.TYPE AS matched_type,
    1.0 AS confidence,
    'exact' AS match_type,
    TRUE AS is_participating_agency,
    1 AS match_priority
  FROM parsed p
  JOIN `durango-deflock.FlockML.participatingAgencies` pa
    ON p.org_name = pa.`LAW ENFORCEMENT AGENCY`
)
SELECT
  org_name,
  matched_agency,
  matched_state,
  matched_type,
  confidence,
  match_type,
  is_participating_agency
FROM matched

UNION ALL

-- Add unmatched org_names
SELECT
  org_name,
  NULL AS matched_agency,
  NULL AS matched_state,
  NULL AS matched_type,
  0.0 AS confidence,
  'none' AS match_type,
  FALSE AS is_participating_agency
FROM parsed
WHERE org_name NOT IN (SELECT org_name FROM matched);
