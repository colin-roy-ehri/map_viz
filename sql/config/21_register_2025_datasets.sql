-- ============================================================================
-- Register All 2025 Monthly Datasets
-- ============================================================================
-- Purpose: Add January through September 2025 datasets to the pipeline config
--          (October and August already registered in 20_create_dataset_config.sql)
--
-- Uses MERGE to safely insert without duplicating existing entries.
-- ============================================================================

MERGE `durango-deflock.FlockML.dataset_pipeline_config` AS target
USING (
  SELECT * FROM UNNEST([
    STRUCT('durango-jan-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'January2025' AS source_table_name,  TRUE AS enabled, 9  AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD January 2025'   AS description, 'colin' AS owner),
    STRUCT('durango-feb-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'February2025' AS source_table_name, TRUE AS enabled, 8  AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD February 2025'  AS description, 'colin' AS owner),
    STRUCT('durango-mar-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'March2025' AS source_table_name,    TRUE AS enabled, 7  AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD March 2025'     AS description, 'colin' AS owner),
    STRUCT('durango-apr-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'April2025' AS source_table_name,    TRUE AS enabled, 6  AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD April 2025'     AS description, 'colin' AS owner),
    STRUCT('durango-may-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'May2025' AS source_table_name,      TRUE AS enabled, 5  AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD May 2025'       AS description, 'colin' AS owner),
    STRUCT('durango-jun-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'June2025' AS source_table_name,     TRUE AS enabled, 4  AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD June 2025'      AS description, 'colin' AS owner),
    STRUCT('durango-jul-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'July2025' AS source_table_name,     TRUE AS enabled, 3  AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD July 2025'      AS description, 'colin' AS owner),
    STRUCT('durango-sep-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'September2025' AS source_table_name, TRUE AS enabled, 10 AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD September 2025' AS description, 'colin' AS owner),
    STRUCT('durango-nov-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'November2025' AS source_table_name, TRUE AS enabled, 11 AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD November 2025'  AS description, 'colin' AS owner),
    STRUCT('durango-dec-2025' AS config_id, 'durango-deflock' AS dataset_project, 'DurangoPD' AS dataset_name, 'December2025' AS source_table_name, TRUE AS enabled, 12 AS priority, CAST(NULL AS STRING) AS output_dataset_name, '_classified' AS output_suffix, 'Durango PD December 2025'  AS description, 'colin' AS owner)
  ])
) AS source
ON target.config_id = source.config_id
WHEN NOT MATCHED THEN INSERT (
  config_id, dataset_project, dataset_name, source_table_name,
  enabled, priority, output_dataset_name, output_suffix,
  description, owner, created_timestamp, last_processed_timestamp
) VALUES (
  source.config_id, source.dataset_project, source.dataset_name, source.source_table_name,
  source.enabled, source.priority, source.output_dataset_name, source.output_suffix,
  source.description, source.owner, CURRENT_TIMESTAMP(), NULL
);

-- Verify registration
SELECT
  config_id,
  source_table_name,
  priority,
  enabled,
  description
FROM `durango-deflock.FlockML.dataset_pipeline_config`
ORDER BY priority ASC;
