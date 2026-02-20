-- Phase 4.5: Pre-compute and Cache Participating Agency Embeddings
-- Optional: Pre-compute embeddings for all participating agencies
-- Benefits: Faster matching when running multiple times, reduces API calls
-- Run this once after creating the embedding model

CREATE OR REPLACE TABLE `durango-deflock.FlockML.participating_agency_embeddings` AS
SELECT
  `LAW ENFORCEMENT AGENCY` AS agency_name,
  STATE,
  TYPE,
  ml_generate_embedding_result AS embedding,
  CURRENT_TIMESTAMP() AS embedding_timestamp
FROM ML.GENERATE_EMBEDDING(
  MODEL `durango-deflock.FlockML.text_embedding_model`,
  (
    SELECT `LAW ENFORCEMENT AGENCY` AS content
    FROM `durango-deflock.FlockML.participatingAgencies`
    WHERE `LAW ENFORCEMENT AGENCY` IS NOT NULL
  )
);

-- Verify the cached embeddings
SELECT
  COUNT(*) AS total_agencies,
  ARRAY_LENGTH(embedding) AS embedding_dimensions,
  MAX(embedding_timestamp) AS last_generated
FROM `durango-deflock.FlockML.participating_agency_embeddings`;
