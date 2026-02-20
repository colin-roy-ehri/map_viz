-- Phase 5.4: Simplified Two-Pass Rule-Based Matching
-- Approach: Build intermediate tables to avoid giant JOINs
-- This should be more efficient than the complex query in sql/25

-- Step 1: Parse unique org_names from classified data
CREATE OR REPLACE TABLE `durango-deflock.FlockML.parsed_org_names` AS
SELECT
  org_name,
  REGEXP_EXTRACT(org_name, r'([A-Z]{2})') AS state_code,
  TRIM(REGEXP_EXTRACT(org_name, r'\s([A-Z]+)$')) AS agency_type,
  TRIM(REGEXP_EXTRACT(org_name, r'^(.*?)\s[A-Z]{2}\s')) AS location_raw
FROM (
  SELECT DISTINCT org_name
  FROM `durango-deflock.DurangoPD.October2025_classified`
  WHERE org_name IS NOT NULL
);

-- Step 2: Add state name mapping
CREATE OR REPLACE TABLE `durango-deflock.FlockML.parsed_org_names_with_state` AS
WITH state_codes AS (
  SELECT 'AL' AS code, 'ALABAMA' AS name UNION ALL
  SELECT 'AK', 'ALASKA' UNION ALL
  SELECT 'AZ', 'ARIZONA' UNION ALL
  SELECT 'AR', 'ARKANSAS' UNION ALL
  SELECT 'CA', 'CALIFORNIA' UNION ALL
  SELECT 'CO', 'COLORADO' UNION ALL
  SELECT 'CT', 'CONNECTICUT' UNION ALL
  SELECT 'DE', 'DELAWARE' UNION ALL
  SELECT 'FL', 'FLORIDA' UNION ALL
  SELECT 'GA', 'GEORGIA' UNION ALL
  SELECT 'HI', 'HAWAII' UNION ALL
  SELECT 'ID', 'IDAHO' UNION ALL
  SELECT 'IL', 'ILLINOIS' UNION ALL
  SELECT 'IN', 'INDIANA' UNION ALL
  SELECT 'IA', 'IOWA' UNION ALL
  SELECT 'KS', 'KANSAS' UNION ALL
  SELECT 'KY', 'KENTUCKY' UNION ALL
  SELECT 'LA', 'LOUISIANA' UNION ALL
  SELECT 'ME', 'MAINE' UNION ALL
  SELECT 'MD', 'MARYLAND' UNION ALL
  SELECT 'MA', 'MASSACHUSETTS' UNION ALL
  SELECT 'MI', 'MICHIGAN' UNION ALL
  SELECT 'MN', 'MINNESOTA' UNION ALL
  SELECT 'MS', 'MISSISSIPPI' UNION ALL
  SELECT 'MO', 'MISSOURI' UNION ALL
  SELECT 'MT', 'MONTANA' UNION ALL
  SELECT 'NE', 'NEBRASKA' UNION ALL
  SELECT 'NV', 'NEVADA' UNION ALL
  SELECT 'NH', 'NEW HAMPSHIRE' UNION ALL
  SELECT 'NJ', 'NEW JERSEY' UNION ALL
  SELECT 'NM', 'NEW MEXICO' UNION ALL
  SELECT 'NY', 'NEW YORK' UNION ALL
  SELECT 'NC', 'NORTH CAROLINA' UNION ALL
  SELECT 'ND', 'NORTH DAKOTA' UNION ALL
  SELECT 'OH', 'OHIO' UNION ALL
  SELECT 'OK', 'OKLAHOMA' UNION ALL
  SELECT 'OR', 'OREGON' UNION ALL
  SELECT 'PA', 'PENNSYLVANIA' UNION ALL
  SELECT 'RI', 'RHODE ISLAND' UNION ALL
  SELECT 'SC', 'SOUTH CAROLINA' UNION ALL
  SELECT 'SD', 'SOUTH DAKOTA' UNION ALL
  SELECT 'TN', 'TENNESSEE' UNION ALL
  SELECT 'TX', 'TEXAS' UNION ALL
  SELECT 'UT', 'UTAH' UNION ALL
  SELECT 'VT', 'VERMONT' UNION ALL
  SELECT 'VA', 'VIRGINIA' UNION ALL
  SELECT 'WA', 'WASHINGTON' UNION ALL
  SELECT 'WV', 'WEST VIRGINIA' UNION ALL
  SELECT 'WI', 'WISCONSIN' UNION ALL
  SELECT 'WY', 'WYOMING' UNION ALL
  SELECT 'DC', 'DISTRICT OF COLUMBIA' UNION ALL
  SELECT 'SL', 'SOUTH CAROLINA'
)
SELECT
  p.org_name,
  p.state_code,
  sc.name AS state_name,
  p.agency_type,
  p.location_raw
FROM `durango-deflock.FlockML.parsed_org_names` p
LEFT JOIN state_codes sc ON p.state_code = sc.code;

-- Step 3: Find matches by state and location
CREATE OR REPLACE TABLE `durango-deflock.FlockML.org_name_matches_temp` AS
SELECT
  p.org_name,
  p.state_code,
  p.state_name,
  p.agency_type,
  p.location_raw,
  pa.`LAW ENFORCEMENT AGENCY`,
  pa.STATE,
  pa.TYPE,
  -- Score based on how well the location matches
  CASE
    WHEN LOWER(TRIM(pa.`LAW ENFORCEMENT AGENCY`)) = LOWER(p.location_raw)
      THEN 2  -- Perfect location match
    WHEN LOWER(TRIM(pa.`LAW ENFORCEMENT AGENCY`)) LIKE CONCAT('%', LOWER(p.location_raw), '%')
      THEN 1  -- Location contained in name
    ELSE 0
  END AS location_score,
  -- Score based on type match
  CASE
    WHEN p.agency_type = 'PD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%'
      THEN 1
    WHEN p.agency_type = 'SO' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%SHERIFF%'
      THEN 1
    WHEN p.agency_type = 'HSP' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%PATROL%'
      THEN 1
    WHEN p.agency_type = 'SPD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%'
      THEN 1
    WHEN p.agency_type = 'DA' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%ATTORNEY%'
      THEN 1
    WHEN p.agency_type = 'MPD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%'
      THEN 1
    ELSE 0
  END AS type_score
FROM `durango-deflock.FlockML.parsed_org_names_with_state` p
JOIN `durango-deflock.FlockML.participatingAgencies` pa
  ON p.state_name = pa.STATE
WHERE location_score > 0;

-- Step 4: Select best match for each org_name (and handle unmatched)
CREATE OR REPLACE TABLE `durango-deflock.FlockML.org_name_rule_based_matches` AS
SELECT
  org_name,
  CASE
    WHEN matched_agency IS NOT NULL
      THEN matched_agency
    ELSE NULL
  END AS matched_agency,
  CASE
    WHEN matched_state IS NOT NULL
      THEN matched_state
    ELSE NULL
  END AS matched_state,
  CASE
    WHEN matched_type IS NOT NULL
      THEN matched_type
    ELSE NULL
  END AS matched_type,
  CASE
    WHEN matched_agency IS NOT NULL AND type_score = 1
      THEN 0.95
    WHEN matched_agency IS NOT NULL
      THEN 0.85
    ELSE 0.0
  END AS confidence,
  CASE
    WHEN matched_agency IS NOT NULL
      THEN 'synonym'
    ELSE 'none'
  END AS match_type,
  CASE
    WHEN matched_agency IS NOT NULL THEN TRUE
    ELSE FALSE
  END AS is_participating_agency
FROM (
  SELECT
    org_name,
    `LAW ENFORCEMENT AGENCY` AS matched_agency,
    STATE AS matched_state,
    TYPE AS matched_type,
    type_score,
    ROW_NUMBER() OVER (PARTITION BY org_name ORDER BY (location_score + type_score) DESC, `LAW ENFORCEMENT AGENCY`) AS rn
  FROM `durango-deflock.FlockML.org_name_matches_temp`
  UNION ALL
  -- Add unmatched org_names
  SELECT
    org_name,
    NULL,
    NULL,
    NULL,
    0,
    1
  FROM `durango-deflock.FlockML.parsed_org_names`
  WHERE org_name NOT IN (SELECT DISTINCT org_name FROM `durango-deflock.FlockML.org_name_matches_temp`)
)
WHERE rn = 1;
