-- Phase 4.1: Create Text Embedding Model for Fuzzy Matching
-- This creates a remote model connection to Gemini text-embedding-004
-- Used for semantic similarity matching between org_names and participating agency names

CREATE OR REPLACE MODEL `durango-deflock.FlockML.text_embedding_model`
REMOTE WITH CONNECTION `durango-deflock.us-central1.vertex-ai-connection`
OPTIONS (
  endpoint = 'text-embedding-004'  -- Gemini text embedding model for semantic similarity
);

-- Test the embedding model with sample agency names
-- This verifies the model works before using it in the matching procedure

SELECT
  content,
  ARRAY_LENGTH(ml_generate_embedding_result) as embedding_dimensions
FROM ML.GENERATE_EMBEDDING(
  MODEL `durango-deflock.FlockML.text_embedding_model`,
  (
    SELECT 'Houston TX PD' AS content
    UNION ALL
    SELECT 'Houston Police Department'
    UNION ALL
    SELECT 'Seminole County FL SO'
    UNION ALL
    SELECT 'Seminole County Sheriff Office'
  )
);
