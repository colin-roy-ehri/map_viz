-- ============================================================================
-- Phase 1.1: Create Global Reason Classification Cache
-- ============================================================================
-- Purpose: Persistent cache storing classifications for all unique reasons
--          across all datasets to enable cost optimization
--
-- Cost Optimization:
-- - Current: $0.09 per dataset (30K unique reasons × $0.000003)
-- - Optimized: Dataset 1: $0.09, Dataset 2: $0.006, Dataset 3+: ~$0.003
-- - For 10+ datasets: 87% cost reduction
--
-- Key Benefits:
-- 1. Once a reason like "stolen vehicle" is classified, all future datasets
--    reuse this classification without LLM calls
-- 2. Tracks which dataset first classified each reason
-- 3. Partitioned for efficient querying of recent additions
-- ============================================================================

CREATE OR REPLACE TABLE `durango-deflock.FlockML.global_reason_classifications` (
  normalized_reason STRING NOT NULL,
  reason_category STRING NOT NULL,
  first_seen_dataset STRING,
  first_classified_timestamp TIMESTAMP,
  classification_count INT64 DEFAULT 1,
  last_updated TIMESTAMP,
  classification_version STRING DEFAULT 'v1'
)
PARTITION BY DATE(first_classified_timestamp)
CLUSTER BY normalized_reason;

-- ============================================================================
-- Add comments for clarity
-- Note: BigQuery uses CLUSTER BY (above) instead of traditional indexes
-- ============================================================================
ALTER TABLE `durango-deflock.FlockML.global_reason_classifications`
SET OPTIONS(description="Global cache of reason classifications across all datasets");
