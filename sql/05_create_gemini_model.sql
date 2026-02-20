-- Phase 3.1: Create Gemini Remote Model
-- This creates a remote model connection to Gemini 2.5 Flash for classification
-- Temperature 0.0 ensures deterministic results for repeatability

CREATE OR REPLACE MODEL `durango-deflock.FlockML.gemini_reason_classifier`
REMOTE WITH CONNECTION `durango-deflock.us-central1.vertex-ai-connection`
OPTIONS (
  endpoint = 'gemini-2.5-flash'  -- Cost-optimized for batch classification
);

-- Test the model with a simple classification
-- Uncomment the query below to test the model after creation

SELECT ml_generate_text_result
FROM ML.GENERATE_TEXT(
  MODEL `durango-deflock.FlockML.gemini_reason_classifier`,
  (SELECT 'Classify this: stolen vehicle' AS prompt),
  STRUCT(0.0 AS temperature, 50 AS max_output_tokens)
);

