-- ============================================================================
-- Phase 1.3: Create Processing Audit Table
-- ============================================================================
-- Purpose: Track all dataset processing runs with detailed metrics
--
-- Used to:
-- 1. Monitor pipeline health and performance
-- 2. Track cost optimization (cache hits vs LLM calls)
-- 3. Debug failures with error messages
-- 4. Generate cost reports and analytics
-- ============================================================================

CREATE OR REPLACE TABLE `durango-deflock.FlockML.dataset_processing_log` (
  run_id STRING DEFAULT GENERATE_UUID(),
  config_id STRING NOT NULL,
  execution_timestamp TIMESTAMP NOT NULL,
  completion_timestamp TIMESTAMP,

  total_rows INT64,
  unique_reasons INT64,
  cache_hits INT64,
  new_reasons_classified INT64,

  classification_cost_usd FLOAT64,
  processing_status STRING,  -- 'SUCCESS', 'ERROR', 'RUNNING'
  error_message STRING,
  error_stack_trace STRING
)
PARTITION BY DATE(execution_timestamp)
CLUSTER BY config_id, processing_status;

-- ============================================================================
-- Add comments for clarity
-- ============================================================================
ALTER TABLE `durango-deflock.FlockML.dataset_processing_log`
SET OPTIONS(
  description="Audit log for all dataset processing runs with cost and performance metrics"
);
