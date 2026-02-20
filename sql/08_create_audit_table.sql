-- Phase 3.4: Create Audit Log Table
-- Tracks all classification runs for monitoring, cost tracking, and debugging

CREATE OR REPLACE TABLE `durango-deflock.FlockML.classification_runs` (
  source_table STRING NOT NULL,
  destination_table STRING NOT NULL,
  execution_timestamp TIMESTAMP NOT NULL,
  completion_timestamp TIMESTAMP,
  total_rows INT64,
  preprocessed_rows INT64,
  llm_classified_rows INT64,
  fallback_rows INT64,
  no_context_rows INT64,
  unique_reasons INT64,
  reduction_percentage FLOAT64,
  cost_estimate_usd FLOAT64
)
PARTITION BY DATE(execution_timestamp)
OPTIONS(
  description="Audit log for classification jobs tracking performance, costs, and coverage",
  require_partition_filter=FALSE
);

-- Create index-like structure for quick lookups
CREATE OR REPLACE VIEW `durango-deflock.FlockML.classification_summary` AS
SELECT
  source_table,
  destination_table,
  execution_timestamp,
  completion_timestamp,
  TIMESTAMP_DIFF(completion_timestamp, execution_timestamp, SECOND) AS execution_seconds,
  total_rows,
  unique_reasons,
  ROUND((1 - COALESCE(unique_reasons, 0) / total_rows) * 100, 2) AS uniqueness_pct,
  reduction_percentage,
  preprocessed_rows,
  ROUND(preprocessed_rows / total_rows * 100, 2) AS preprocessed_pct,
  llm_classified_rows,
  ROUND(llm_classified_rows / total_rows * 100, 2) AS llm_classified_pct,
  fallback_rows,
  ROUND(fallback_rows / llm_classified_rows * 100, 2) AS fallback_rate,
  no_context_rows,
  ROUND(no_context_rows / total_rows * 100, 2) AS no_context_pct,
  cost_estimate_usd
FROM `durango-deflock.FlockML.classification_runs`
ORDER BY execution_timestamp DESC;
