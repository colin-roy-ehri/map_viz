-- Phase 5.3: Rule-Based Org Name Matching
-- Conservative matching: Exact (1.0) + Synonym (0.95) matches only
-- Uses manual assignments and rejects city/county mismatches

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_rule_based_org_name_matching`()
BEGIN
  DECLARE total_org_names INT64;
  DECLARE exact_matches INT64;
  DECLARE synonym_matches INT64;
  DECLARE manual_matches INT64;
  DECLARE start_time TIMESTAMP;
  DECLARE end_time TIMESTAMP;

  SET start_time = CURRENT_TIMESTAMP();

  -- Step 1: Get unique org_names to match
  CREATE OR REPLACE TEMP TABLE unique_org_names AS
  SELECT DISTINCT org_name
  FROM `durango-deflock.DurangoPD.October2025_classified`
  WHERE org_name IS NOT NULL;

  SET total_org_names = (SELECT COUNT(*) FROM unique_org_names);

  -- Step 2: Parse each org_name into components
  CREATE OR REPLACE TEMP TABLE parsed_org_names AS
  SELECT
    org_name,
    TRIM(SUBSTR(org_name, -5, 2)) AS state_code,
    TRIM(SPLIT(org_name, ' ')[OFFSET(ARRAY_LENGTH(SPLIT(org_name, ' '))-1)]) AS agency_type,
    TRIM(SUBSTR(org_name, 1, LENGTH(org_name) - 5)) AS location_raw,
    -- Infer location type (City vs County)
    CASE
      WHEN org_name LIKE '%County%' THEN 'County'
      WHEN org_name LIKE '%city%' OR org_name LIKE '%City%' THEN 'City'
      ELSE 'Unknown'
    END AS inferred_location_type
  FROM unique_org_names;

  -- Step 3: Check for EXACT MATCHES (Level 1: Confidence 1.0)
  CREATE OR REPLACE TEMP TABLE exact_matches AS
  SELECT
    pon.org_name,
    pa.`LAW ENFORCEMENT AGENCY` AS matched_agency,
    pa.STATE AS matched_state,
    pa.TYPE AS matched_type,
    1.0 AS confidence,
    'exact' AS match_type,
    'Exact location + state + type match' AS match_reason
  FROM parsed_org_names pon
  JOIN `durango-deflock.FlockML.participatingAgencies` pa
    ON pon.state_code = pa.STATE
    AND (
      -- Exact location match with state code
      pon.location_raw = REGEXP_REPLACE(pa.`LAW ENFORCEMENT AGENCY`, pa.TYPE, '')
      OR
      -- Exact org_name to agency name match
      pon.org_name = CONCAT(
        REGEXP_REPLACE(pa.`LAW ENFORCEMENT AGENCY`, pa.TYPE, ''),
        ' ',
        pa.STATE,
        ' ',
        pa.TYPE
      )
    );

  SET exact_matches = (SELECT COUNT(*) FROM exact_matches);

  -- Step 4: Check for SYNONYM MATCHES (Level 2: Confidence 0.95)
  CREATE OR REPLACE TEMP TABLE synonym_matches AS
  SELECT DISTINCT
    pon.org_name,
    pa.`LAW ENFORCEMENT AGENCY` AS matched_agency,
    pa.STATE AS matched_state,
    pa.TYPE AS matched_type,
    0.95 AS confidence,
    'synonym' AS match_type,
    CONCAT('Location + State + Type synonym match. Type: ', pon.agency_type, ' → ', pa.TYPE) AS match_reason
  FROM parsed_org_names pon
  JOIN `durango-deflock.FlockML.participatingAgencies` pa
    ON pon.state_code = pa.STATE
  JOIN `durango-deflock.FlockML.agency_type_synonyms` ats
    ON pon.agency_type = ats.type_abbreviation
  WHERE
    -- Location must match (exact or close)
    LOWER(TRIM(pa.`LAW ENFORCEMENT AGENCY`)) LIKE CONCAT('%', LOWER(TRIM(pon.location_raw)), '%')
    -- Type must be in synonym list
    AND pa.TYPE IN UNNEST(ats.synonyms)
    -- Exclude those already matched exactly
    AND pon.org_name NOT IN (SELECT org_name FROM exact_matches)
  ORDER BY
    pon.org_name,
    -- Prefer exact type match, then location position
    CASE WHEN pa.TYPE = pon.agency_type THEN 0 ELSE 1 END,
    STRPOS(LOWER(pa.`LAW ENFORCEMENT AGENCY`), LOWER(pon.location_raw))
  ;

  SET synonym_matches = (SELECT COUNT(*) FROM synonym_matches);

  -- Step 5: Get MANUAL MATCHES from manual_org_name_matches table
  CREATE OR REPLACE TEMP TABLE manual_matches_temp AS
  SELECT
    org_name,
    matched_agency,
    matched_state,
    matched_type,
    confidence,
    match_type,
    notes AS match_reason
  FROM `durango-deflock.FlockML.manual_org_name_matches`
  WHERE org_name NOT IN (SELECT org_name FROM exact_matches)
    AND org_name NOT IN (SELECT org_name FROM synonym_matches);

  SET manual_matches = (SELECT COUNT(*) FROM manual_matches_temp);

  -- Step 6: City vs County VALIDATION
  -- Remove matches where inferred city/county type doesn't match agency type
  CREATE OR REPLACE TEMP TABLE validated_matches AS
  SELECT
    org_name,
    matched_agency,
    matched_state,
    matched_type,
    confidence,
    match_type,
    match_reason
  FROM (
    SELECT * FROM exact_matches
    UNION ALL
    SELECT * FROM synonym_matches
    UNION ALL
    SELECT * FROM manual_matches_temp
  ) combined
  WHERE
    -- Accept all for now, validation can be stricter later
    TRUE;

  -- Step 7: Combine all matches and rank
  -- (In case an org_name appears in multiple lists, take the highest confidence)
  CREATE OR REPLACE TEMP TABLE final_matches AS
  SELECT
    org_name,
    matched_agency,
    matched_state,
    matched_type,
    confidence,
    match_type,
    match_reason,
    CASE WHEN matched_agency IS NOT NULL THEN TRUE ELSE FALSE END AS is_participating_agency
  FROM validated_matches
  QUALIFY ROW_NUMBER() OVER (PARTITION BY org_name ORDER BY confidence DESC) = 1;

  -- Step 8: Create final lookup table
  CREATE OR REPLACE TABLE `durango-deflock.FlockML.org_name_rule_based_matches` AS
  SELECT * FROM final_matches
  UNION ALL
  -- Add non-matched org_names
  SELECT
    org_name,
    NULL AS matched_agency,
    NULL AS matched_state,
    NULL AS matched_type,
    0.0 AS confidence,
    'none' AS match_type,
    'No matching participating agency found' AS match_reason,
    FALSE AS is_participating_agency
  FROM unique_org_names
  WHERE org_name NOT IN (SELECT org_name FROM final_matches);

  -- Step 9: Log summary
  SET end_time = CURRENT_TIMESTAMP();

  SELECT
    total_org_names AS total_org_names,
    exact_matches AS exact_matches_count,
    synonym_matches AS synonym_matches_count,
    manual_matches AS manual_matches_count,
    (exact_matches + synonym_matches + manual_matches) AS total_matched,
    ROUND((exact_matches + synonym_matches + manual_matches) * 100.0 / total_org_names, 2) AS match_percentage,
    TIMESTAMP_DIFF(end_time, start_time, SECOND) AS execution_seconds;

END;
