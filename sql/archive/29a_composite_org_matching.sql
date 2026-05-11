-- ============================================================================
-- Phase 1.5: August Organization Matching
-- ============================================================================
-- Purpose: Create match table for all org_names in August dataset
-- Approach: Extract unique August org_names, run rule-based matching once
-- Output: august_org_name_matches (authoritative source for August)

-- ============================================================================
-- STEP 1: Extract Unique Org_Names from August Dataset
-- ============================================================================
CREATE OR REPLACE TABLE `durango-deflock.FlockML.august_unique_org_names` AS
SELECT DISTINCT org_name
FROM `durango-deflock.DurangoPD.August2025_classified`
WHERE org_name IS NOT NULL
ORDER BY org_name;

-- ============================================================================
-- STEP 2: Run Rule-Based Matching on August Org_Names
-- ============================================================================
CREATE OR REPLACE TABLE `durango-deflock.FlockML.august_org_name_matches` AS
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
  FROM `durango-deflock.FlockML.august_unique_org_names`
),
parsed_with_state AS (
  SELECT
    p.*,
    sm.state_name
  FROM parsed p
  LEFT JOIN state_mapping sm ON p.state_code = sm.state_code
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
      (p.agency_type = 'PD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%')
      OR (p.agency_type = 'SO' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%SHERIFF%')
      OR (p.agency_type = 'HSP' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%PATROL%')
      OR (p.agency_type = 'SPD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%')
      OR (p.agency_type = 'DA' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%ATTORNEY%')
      OR (p.agency_type = 'MPD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%')
    )
)
SELECT
  org_name,
  matched_agency,
  matched_state,
  matched_type,
  confidence,
  match_type,
  is_participating_agency
FROM synonym_matches
WHERE rn = 1
UNION ALL
SELECT
  org_name,
  NULL AS matched_agency,
  NULL AS matched_state,
  NULL AS matched_type,
  0.0 AS confidence,
  'none' AS match_type,
  FALSE AS is_participating_agency
FROM parsed
WHERE org_name NOT IN (SELECT org_name FROM synonym_matches);

-- ============================================================================
-- VERIFICATION QUERY 1: August Match Summary
-- ============================================================================
-- Overall statistics
SELECT
  'August Unique Org_Names' as metric,
  COUNT(*) as count
FROM `durango-deflock.FlockML.august_unique_org_names`
UNION ALL
SELECT
  'Total Matched',
  COUNT(DISTINCT org_name)
FROM `durango-deflock.FlockML.august_org_name_matches`
WHERE match_type != 'none'
UNION ALL
SELECT
  'Unmatched',
  COUNT(DISTINCT org_name)
FROM `durango-deflock.FlockML.august_org_name_matches`
WHERE match_type = 'none'
UNION ALL
SELECT
  'Match Coverage %',
  ROUND(COUNT(DISTINCT CASE WHEN match_type != 'none' THEN org_name END) * 100.0 /
        COUNT(DISTINCT org_name), 2)
FROM `durango-deflock.FlockML.august_org_name_matches`;

-- ============================================================================
-- VERIFICATION QUERY 2: Matched Agencies
-- ============================================================================
-- Show all matched orgs
SELECT
  org_name,
  matched_agency,
  matched_state,
  confidence,
  match_type
FROM `durango-deflock.FlockML.august_org_name_matches`
WHERE match_type != 'none'
ORDER BY org_name;

-- ============================================================================
-- VERIFICATION QUERY 3: Unmatched Agencies
-- ============================================================================
-- Show what couldn't be matched
SELECT
  org_name
FROM `durango-deflock.FlockML.august_org_name_matches`
WHERE match_type = 'none'
ORDER BY org_name;

-- ============================================================================
-- VERIFICATION QUERY 4: Match Type Breakdown
-- ============================================================================
-- Summary by match type
SELECT
  match_type,
  COUNT(*) as org_name_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM `durango-deflock.FlockML.august_org_name_matches`
GROUP BY match_type
ORDER BY org_name_count DESC;
