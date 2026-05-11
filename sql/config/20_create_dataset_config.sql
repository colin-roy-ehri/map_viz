-- ============================================================================
-- Phase 1.2: Create Dataset Configuration Table
-- ============================================================================
-- Purpose: Central configuration for all datasets in the pipeline
--
-- This table drives the entire orchestration system:
-- 1. Python orchestrator reads enabled datasets from this table
-- 2. Each dataset row specifies which raw table to process
-- 3. Output location and naming conventions are configured here
-- 4. Priority determines processing order for parallel execution
--
-- Example Usage:
--   INSERT INTO FlockML.dataset_pipeline_config VALUES
--   ('durango-oct-2025', 'durango-deflock', 'DurangoPD', 'October2025',
--    TRUE, 1, NULL, '_classified', 'Durango PD October 2025', 'colin',
--    CURRENT_TIMESTAMP(), NULL);
-- ============================================================================

CREATE OR REPLACE TABLE `durango-deflock.FlockML.dataset_pipeline_config` (
  config_id STRING NOT NULL,
  dataset_project STRING DEFAULT 'durango-deflock',
  dataset_name STRING NOT NULL,
  source_table_name STRING NOT NULL,

  -- Pipeline control
  enabled BOOLEAN DEFAULT TRUE,
  priority INT64 DEFAULT 100,

  -- Output configuration
  output_dataset_name STRING,  -- NULL = same as source
  output_suffix STRING DEFAULT '_classified',

  -- Metadata
  description STRING,
  owner STRING,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  last_processed_timestamp TIMESTAMP
);

-- Set primary key
ALTER TABLE `durango-deflock.FlockML.dataset_pipeline_config`
ADD PRIMARY KEY(config_id) NOT ENFORCED;

-- ============================================================================
-- Initial Configuration - Register existing datasets
-- ============================================================================
INSERT INTO `durango-deflock.FlockML.dataset_pipeline_config` VALUES
  ('durango-oct-2025', 'durango-deflock', 'DurangoPD', 'October2025',
   TRUE, 1, NULL, '_classified', 'Durango PD October 2025', 'colin',
   CURRENT_TIMESTAMP(), NULL),
  ('durango-aug-2025', 'durango-deflock', 'DurangoPD', 'August2025',
   TRUE, 2, NULL, '_classified', 'Durango PD August 2025', 'colin',
   CURRENT_TIMESTAMP(), NULL);

-- Add comments for clarity
ALTER TABLE `durango-deflock.FlockML.dataset_pipeline_config`
SET OPTIONS(
  description="Central configuration for all datasets in the processing pipeline"
);
