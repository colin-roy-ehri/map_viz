-- Phase 5.2: Identify and Populate Org Name Clusters
-- Finds similar org_names (same location, different types) and suggests potential matches

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_identify_org_name_clusters`()
BEGIN

  -- Step 1: Parse all unique org_names from classified table
  CREATE OR REPLACE TEMP TABLE parsed_org_names AS
  SELECT DISTINCT
    org_name,
    -- Extract state code (assuming format: "Location STATE TYPE")
    TRIM(SUBSTR(org_name, -5, 2)) AS state_code,
    -- Extract agency type (last token)
    TRIM(SPLIT(org_name, ' ')[OFFSET(ARRAY_LENGTH(SPLIT(org_name, ' '))-1)]) AS agency_type,
    -- Extract location (everything except last 2 tokens)
    TRIM(SUBSTR(org_name, 1, LENGTH(org_name) - 5)) AS location_raw
  FROM `durango-deflock.DurangoPD.October2025_classified`
  WHERE org_name IS NOT NULL
  ORDER BY org_name;

  -- Step 2: Normalize locations to find clusters
  CREATE OR REPLACE TEMP TABLE location_clusters AS
  SELECT
    GENERATE_UUID() AS cluster_id,
    location_raw AS location_cluster,
    state_code,
    ARRAY_AGG(DISTINCT org_name) AS org_names_in_cluster,
    ARRAY_AGG(DISTINCT agency_type) AS agency_types_in_cluster,
    COUNT(DISTINCT org_name) AS cluster_size
  FROM parsed_org_names
  GROUP BY location_raw, state_code
  HAVING COUNT(DISTINCT org_name) > 1  -- Only clusters with multiple org_names
  ORDER BY cluster_size DESC;

  -- Step 3: For each cluster, find potential matches in participating agencies
  CREATE OR REPLACE TEMP TABLE cluster_with_potential_matches AS
  SELECT
    lc.cluster_id,
    lc.location_cluster,
    lc.org_names_in_cluster,
    lc.agency_types_in_cluster,
    lc.state_code,
    lc.cluster_size,
    -- Find potential participating agencies that match this location/state
    ARRAY(
      SELECT AS STRUCT
        pa.`LAW ENFORCEMENT AGENCY` AS agency_name,
        pa.STATE AS state,
        pa.TYPE AS type,
        -- Create confidence note based on what matches
        CASE
          WHEN pa.STATE = lc.state_code THEN 'State matches'
          ELSE 'State different'
        END AS confidence_note
      FROM `durango-deflock.FlockML.participatingAgencies` pa
      WHERE
        -- Match on state
        pa.STATE = lc.state_code
        -- Match on location (contains location cluster name)
        AND (
          pa.`LAW ENFORCEMENT AGENCY` LIKE CONCAT('%', lc.location_cluster, '%')
          OR pa.`LAW ENFORCEMENT AGENCY` LIKE CONCAT('%',
              SPLIT(lc.location_cluster, ' ')[OFFSET(0)], '%')  -- First word of location
        )
      ORDER BY
        CASE WHEN pa.`LAW ENFORCEMENT AGENCY` LIKE CONCAT(lc.location_cluster, '%') THEN 0 ELSE 1 END,
        LENGTH(pa.`LAW ENFORCEMENT AGENCY`)
      LIMIT 5
    ) AS potential_matches
  FROM location_clusters lc;

  -- Step 4: Populate disambiguation table
  DELETE FROM `durango-deflock.FlockML.org_name_disambiguation` WHERE TRUE;

  INSERT INTO `durango-deflock.FlockML.org_name_disambiguation`
  SELECT
    cluster_id AS disambiguation_id,
    location_cluster,
    org_names_in_cluster AS org_names,
    agency_types_in_cluster AS org_types,
    state_code,
    potential_matches,
    NULL AS manual_selection,  -- To be filled in by user
    CONCAT('Cluster of ', cluster_size, ' similar org_names') AS notes,
    'pending' AS status
  FROM cluster_with_potential_matches
  ORDER BY cluster_size DESC;

  -- Step 5: Log summary
  SELECT
    (SELECT COUNT(*) FROM `durango-deflock.FlockML.org_name_disambiguation`) AS total_clusters,
    (SELECT COUNT(*) FROM parsed_org_names) AS total_org_names,
    (SELECT SUM(cluster_size) FROM location_clusters) AS org_names_in_clusters
  AS summary;

END;
