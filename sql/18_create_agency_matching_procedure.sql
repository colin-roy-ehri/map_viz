-- Phase 4.2: Create Agency Matching Stored Procedure
-- This procedure orchestrates fuzzy matching between classified org_names and participating agencies
-- using semantic similarity with Gemini text embeddings
--
-- Note: Currently optimized for October2025_classified table
-- Workaround: Uses intermediate tables to avoid BigQuery procedure scoping issues with ML functions

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_match_participating_agencies`()
BEGIN
  DECLARE start_time TIMESTAMP;
  DECLARE end_time TIMESTAMP;
  DECLARE total_org_names INT64;
  DECLARE matched_agencies INT64;

  SET start_time = CURRENT_TIMESTAMP();

  -- Step 1: Extract unique org_names (simple table creation)
  CREATE OR REPLACE TEMP TABLE source_org_names AS
  SELECT DISTINCT org_name
  FROM `durango-deflock.DurangoPD.October2025_classified`
  WHERE org_name IS NOT NULL;

  -- Step 2: Generate embeddings for org_names
  CREATE OR REPLACE TEMP TABLE org_name_embeddings AS
  SELECT
    source_org_names.org_name,
    ml_generate_embedding_result AS embedding
  FROM ML.GENERATE_EMBEDDING(
    MODEL `durango-deflock.FlockML.text_embedding_model`,
    (SELECT org_name AS content FROM source_org_names)
  ) embedding_results
  JOIN source_org_names
    ON source_org_names.org_name = embedding_results.content;

  SET total_org_names = (SELECT COUNT(*) FROM org_name_embeddings);

  -- Step 3: Generate embeddings for participating agencies
  CREATE OR REPLACE TEMP TABLE participating_agency_embeddings AS
  SELECT
    source_agencies.`LAW ENFORCEMENT AGENCY` AS agency_name,
    source_agencies.STATE,
    source_agencies.TYPE,
    ml_generate_embedding_result AS embedding
  FROM ML.GENERATE_EMBEDDING(
    MODEL `durango-deflock.FlockML.text_embedding_model`,
    (SELECT `LAW ENFORCEMENT AGENCY` AS content FROM `durango-deflock.FlockML.participatingAgencies` WHERE `LAW ENFORCEMENT AGENCY` IS NOT NULL)
  ) embedding_results
  JOIN `durango-deflock.FlockML.participatingAgencies` source_agencies
    ON source_agencies.`LAW ENFORCEMENT AGENCY` = embedding_results.content;

  -- Step 4: Compute cosine similarity scores
  CREATE OR REPLACE TEMP TABLE similarity_scores AS
  SELECT
    o.org_name,
    p.agency_name,
    p.STATE,
    p.TYPE,
    (1 - ML.DISTANCE(o.embedding, p.embedding, 'COSINE')) AS similarity
  FROM org_name_embeddings o
  CROSS JOIN participating_agency_embeddings p;

  -- Step 5: Find best match for each org_name
  CREATE OR REPLACE TEMP TABLE best_matches AS
  SELECT
    org_name,
    agency_name AS matched_agency,
    STATE AS matched_state,
    TYPE AS matched_type,
    similarity,
    CASE WHEN similarity >= 0.85 THEN TRUE ELSE FALSE END AS is_match
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY org_name ORDER BY similarity DESC) AS rank
    FROM similarity_scores
  )
  WHERE rank = 1;

  -- Step 6: Apply manual overrides
  CREATE OR REPLACE TEMP TABLE final_matches AS
  SELECT
    COALESCE(manual.org_name, best.org_name) AS org_name,
    CASE
      WHEN manual.org_name IS NOT NULL THEN manual.manual_match
      ELSE best.is_match
    END AS is_participating_agency,
    CASE
      WHEN manual.org_name IS NOT NULL THEN manual.matched_agency
      ELSE best.matched_agency
    END AS matched_agency,
    CASE
      WHEN manual.org_name IS NOT NULL THEN NULL
      ELSE best.matched_state
    END AS matched_state,
    CASE
      WHEN manual.org_name IS NOT NULL THEN NULL
      ELSE best.matched_type
    END AS matched_type,
    best.similarity,
    CURRENT_TIMESTAMP() AS match_timestamp
  FROM best_matches best
  LEFT JOIN `durango-deflock.FlockML.agency_match_overrides` manual
    ON best.org_name = manual.org_name;

  SET matched_agencies = (
    SELECT COUNT(*) FROM final_matches WHERE is_participating_agency = TRUE
  );

  -- Step 7: Create final lookup table
  CREATE OR REPLACE TABLE `durango-deflock.FlockML.org_name_to_participating_agency` AS
  SELECT * FROM final_matches;

  -- Step 8: Log execution summary
  SET end_time = CURRENT_TIMESTAMP();

END;
