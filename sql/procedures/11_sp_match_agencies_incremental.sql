-- ============================================================================
-- Phase 2.2: Parameterized Agency Matching Procedure
-- ============================================================================
-- Purpose: Extract from sql/26_simplified_matching_approach.sql and convert to
--          parameterized stored procedure that works on ANY classified table
--
-- Previous: Hardcoded to `October2025_classified` (sql/26, line 14)
-- Now: Works on any source_classified_table parameter
--
-- Cost Optimization:
-- - Results cached in org_name_rule_based_matches table
-- - Subsequent datasets avoid redundant matching logic
-- - Updates global org_name cache
--
-- Usage:
--   CALL FlockML.sp_match_agencies_incremental('durango-deflock.DurangoPD.October2025_classified');
-- ============================================================================

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_match_agencies_incremental`(
  source_classified_table STRING
)
BEGIN
  DECLARE start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE org_count INT64;
  DECLARE matched_count INT64;
  DECLARE participating_count INT64;

  -- ========================================================================
  -- Step 1: Parse unique org_names from classified table
  -- ========================================================================
  EXECUTE IMMEDIATE FORMAT('''
    CREATE OR REPLACE TEMP TABLE parsed_org_names AS
    SELECT DISTINCT
      org_name,
      REGEXP_EXTRACT(org_name, '([A-Z]{2})') AS state_code,
      TRIM(REGEXP_EXTRACT(org_name, '[[:space:]]([A-Z]+)$')) AS agency_type,
      TRIM(REGEXP_EXTRACT(org_name, '^(.*?)[[:space:]][A-Z]{2}[[:space:]]')) AS location_raw
    FROM `%s`
    WHERE org_name IS NOT NULL
      AND TRIM(org_name) != ''
  ''', source_classified_table);

  SET org_count = (SELECT COUNT(*) FROM parsed_org_names);

  -- ========================================================================
  -- Step 2: Create location normalization mapping
  -- ========================================================================
  CREATE OR REPLACE TEMP TABLE location_normalization AS
  SELECT
    location_raw,
    CASE
      WHEN LOWER(location_raw) LIKE '%durango%' THEN 'Durango'
      WHEN LOWER(location_raw) LIKE '%telluride%' THEN 'Telluride'
      WHEN LOWER(location_raw) LIKE '%la plata%' OR LOWER(location_raw) LIKE '%laplata%' THEN 'La Plata'
      WHEN LOWER(location_raw) LIKE '%montezuma%' THEN 'Montezuma'
      WHEN LOWER(location_raw) LIKE '%pagosa%' THEN 'Pagosa'
      WHEN LOWER(location_raw) LIKE '%grand junction%' THEN 'Grand Junction'
      WHEN LOWER(location_raw) LIKE '%archuleta%' THEN 'Archuleta'
      WHEN LOWER(location_raw) LIKE '%montrose%' THEN 'Montrose'
      WHEN LOWER(location_raw) LIKE '%mesa county%' OR LOWER(location_raw) LIKE '%mesa%' THEN 'Mesa County'
      ELSE location_raw
    END AS normalized_location
  FROM parsed_org_names
  GROUP BY location_raw;

  -- ========================================================================
  -- Step 3: Apply rule-based matching
  -- ========================================================================
  CREATE OR REPLACE TEMP TABLE rule_based_matches AS
  SELECT
    p.org_name,
    CASE
      WHEN LOWER(p.agency_type) = 'PD' THEN 'Police Department'
      WHEN LOWER(p.agency_type) = 'SO' THEN 'Sheriff Office'
      WHEN LOWER(p.agency_type) = 'DPS' THEN 'Department of Public Safety'
      ELSE p.agency_type
    END AS matched_agency_type,
    ln.normalized_location AS matched_location,
    p.state_code AS matched_state,
    'Rule-Based' AS match_type,
    CASE
      WHEN ln.normalized_location IN (
        'Durango', 'Telluride', 'La Plata', 'Montezuma',
        'Pagosa', 'Archuleta', 'Montrose'
      ) AND p.state_code = 'CO'
      THEN 1.0 ELSE 0.7
    END AS confidence_score
  FROM parsed_org_names p
  LEFT JOIN location_normalization ln ON p.location_raw = ln.location_raw;

  -- ========================================================================
  -- Step 4: Check against known participating agencies
  -- ========================================================================
  CREATE OR REPLACE TEMP TABLE participating_agency_check AS
  SELECT
    r.org_name,
    r.matched_agency_type,
    r.matched_location,
    r.matched_state,
    r.match_type,
    r.confidence_score,
    CASE
      WHEN r.matched_location IN (
        'Durango', 'Telluride', 'La Plata', 'Montezuma',
        'Pagosa', 'Archuleta', 'Montrose'
      ) THEN TRUE
      ELSE FALSE
    END AS is_participating_agency
  FROM rule_based_matches r;

  SET matched_count = (SELECT COUNT(*) FROM participating_agency_check);
  SET participating_count = (SELECT COUNT(*) FROM participating_agency_check WHERE is_participating_agency);

  -- ========================================================================
  -- Step 5: MERGE results into global org_name_rule_based_matches table
  -- ========================================================================
  MERGE `durango-deflock.FlockML.org_name_rule_based_matches` AS target
  USING participating_agency_check AS source
  ON target.org_name = source.org_name
  WHEN NOT MATCHED THEN
    INSERT (
      org_name, matched_agency, matched_state, matched_type,
      confidence, match_type, is_participating_agency,
      created_timestamp, last_updated
    )
    VALUES (
      source.org_name,
      source.matched_agency_type,
      source.matched_state,
      source.matched_location,
      source.confidence_score,
      source.match_type,
      source.is_participating_agency,
      CURRENT_TIMESTAMP(),
      CURRENT_TIMESTAMP()
    )
  WHEN MATCHED THEN
    UPDATE SET
      matched_agency = source.matched_agency_type,
      matched_state = source.matched_state,
      matched_type = source.matched_location,
      confidence = source.confidence_score,
      match_type = source.match_type,
      is_participating_agency = source.is_participating_agency,
      last_updated = CURRENT_TIMESTAMP();

  -- ========================================================================
  -- Log completion
  -- ========================================================================
  SELECT FORMAT(
    '✓ Agency matching complete for %s\n  Total orgs: %d\n  Matched: %d\n  Participating: %d',
    source_classified_table,
    org_count,
    matched_count,
    participating_count
  ) AS status;

END;
