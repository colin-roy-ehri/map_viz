-- Phase 5.3: Add Synonym Matching (Confidence 0.95)
-- Match based on: State + Location Contains + Type Synonym matching agency name
-- Fixed: Account for actual data structure - STATE is full name (FLORIDA not FL), type is in agency name

CREATE OR REPLACE TABLE `durango-deflock.FlockML.org_name_rule_based_matches` AS
WITH state_mapping AS (
  SELECT * FROM (
    SELECT 'AL' AS state_code, 'ALABAMA' AS state_name
    UNION ALL SELECT 'AK', 'ALASKA'
    UNION ALL SELECT 'AZ', 'ARIZONA'
    UNION ALL SELECT 'AR', 'ARKANSAS'
    UNION ALL SELECT 'CA', 'CALIFORNIA'
    UNION ALL SELECT 'CO', 'COLORADO'
    UNION ALL SELECT 'CT', 'CONNECTICUT'
    UNION ALL SELECT 'DE', 'DELAWARE'
    UNION ALL SELECT 'FL', 'FLORIDA'
    UNION ALL SELECT 'GA', 'GEORGIA'
    UNION ALL SELECT 'HI', 'HAWAII'
    UNION ALL SELECT 'ID', 'IDAHO'
    UNION ALL SELECT 'IL', 'ILLINOIS'
    UNION ALL SELECT 'IN', 'INDIANA'
    UNION ALL SELECT 'IA', 'IOWA'
    UNION ALL SELECT 'KS', 'KANSAS'
    UNION ALL SELECT 'KY', 'KENTUCKY'
    UNION ALL SELECT 'LA', 'LOUISIANA'
    UNION ALL SELECT 'ME', 'MAINE'
    UNION ALL SELECT 'MD', 'MARYLAND'
    UNION ALL SELECT 'MA', 'MASSACHUSETTS'
    UNION ALL SELECT 'MI', 'MICHIGAN'
    UNION ALL SELECT 'MN', 'MINNESOTA'
    UNION ALL SELECT 'MS', 'MISSISSIPPI'
    UNION ALL SELECT 'MO', 'MISSOURI'
    UNION ALL SELECT 'MT', 'MONTANA'
    UNION ALL SELECT 'NE', 'NEBRASKA'
    UNION ALL SELECT 'NV', 'NEVADA'
    UNION ALL SELECT 'NH', 'NEW HAMPSHIRE'
    UNION ALL SELECT 'NJ', 'NEW JERSEY'
    UNION ALL SELECT 'NM', 'NEW MEXICO'
    UNION ALL SELECT 'NY', 'NEW YORK'
    UNION ALL SELECT 'NC', 'NORTH CAROLINA'
    UNION ALL SELECT 'ND', 'NORTH DAKOTA'
    UNION ALL SELECT 'OH', 'OHIO'
    UNION ALL SELECT 'OK', 'OKLAHOMA'
    UNION ALL SELECT 'OR', 'OREGON'
    UNION ALL SELECT 'PA', 'PENNSYLVANIA'
    UNION ALL SELECT 'RI', 'RHODE ISLAND'
    UNION ALL SELECT 'SC', 'SOUTH CAROLINA'
    UNION ALL SELECT 'SD', 'SOUTH DAKOTA'
    UNION ALL SELECT 'TN', 'TENNESSEE'
    UNION ALL SELECT 'TX', 'TEXAS'
    UNION ALL SELECT 'UT', 'UTAH'
    UNION ALL SELECT 'VT', 'VERMONT'
    UNION ALL SELECT 'VA', 'VIRGINIA'
    UNION ALL SELECT 'WA', 'WASHINGTON'
    UNION ALL SELECT 'WV', 'WEST VIRGINIA'
    UNION ALL SELECT 'WI', 'WISCONSIN'
    UNION ALL SELECT 'WY', 'WYOMING'
    UNION ALL SELECT 'DC', 'DISTRICT OF COLUMBIA'
    UNION ALL SELECT 'SL', 'SOUTH CAROLINA'
  )
),
parsed AS (
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
parsed_with_state AS (
  SELECT
    p.*,
    sm.state_name
  FROM parsed p
  LEFT JOIN state_mapping sm ON p.state_code = sm.state_code
),
exact_matches AS (
  SELECT
    p.org_name,
    pa.`LAW ENFORCEMENT AGENCY` AS matched_agency,
    pa.STATE AS matched_state,
    pa.TYPE AS matched_type,
    1.0 AS confidence,
    'exact' AS match_type,
    TRUE AS is_participating_agency
  FROM parsed_with_state p
  JOIN `durango-deflock.FlockML.participatingAgencies` pa
    ON p.org_name = pa.`LAW ENFORCEMENT AGENCY`
),
synonym_matches AS (
  SELECT
    p.org_name,
    pa.`LAW ENFORCEMENT AGENCY` AS matched_agency,
    pa.STATE AS matched_state,
    pa.TYPE AS matched_type,
    0.95 AS confidence,
    'synonym' AS match_type,
    TRUE AS is_participating_agency,
    ROW_NUMBER() OVER (PARTITION BY p.org_name ORDER BY pa.`LAW ENFORCEMENT AGENCY`) AS rn
  FROM parsed_with_state p
  JOIN `durango-deflock.FlockML.participatingAgencies` pa
    ON p.state_name = pa.STATE
    AND LOWER(TRIM(pa.`LAW ENFORCEMENT AGENCY`)) LIKE CONCAT('%', LOWER(p.location_raw), '%')
    AND (
      -- Type synonym matching - check agency name instead of TYPE column
      (p.agency_type = 'PD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%')
      OR (p.agency_type = 'SO' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%SHERIFF%')
      OR (p.agency_type = 'HSP' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%PATROL%')
      OR (p.agency_type = 'SPD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%')
      OR (p.agency_type = 'DA' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%ATTORNEY%')
      OR (p.agency_type = 'MPD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%')
    )
  WHERE p.org_name NOT IN (SELECT org_name FROM exact_matches)
)
SELECT
  org_name,
  matched_agency,
  matched_state,
  matched_type,
  confidence,
  match_type,
  is_participating_agency
FROM exact_matches

UNION ALL

SELECT * EXCEPT(rn)
FROM synonym_matches
WHERE rn = 1  -- Take first match only

UNION ALL

-- Add unmatched org_names
SELECT
  p.org_name,
  NULL AS matched_agency,
  NULL AS matched_state,
  NULL AS matched_type,
  0.0 AS confidence,
  'none' AS match_type,
  FALSE AS is_participating_agency
FROM parsed p
WHERE p.org_name NOT IN (SELECT org_name FROM exact_matches)
  AND p.org_name NOT IN (SELECT org_name FROM synonym_matches);
