-- ============================================================================
-- Phase 4.2: Multi-Dataset Orchestrator
-- ============================================================================
-- Purpose: Process all enabled datasets in order of priority
--
-- Features:
--   1. Processes datasets sequentially or can be parallelized via Python
--   2. Supports dry-run mode to preview what will be processed
--   3. Continues on error (logs failures but doesn't stop pipeline)
--   4. Generates summary report at the end
--
-- Usage:
--   -- Process all datasets
--   CALL FlockML.sp_process_all_datasets(FALSE);
--
--   -- Dry run (show what would be processed)
--   CALL FlockML.sp_process_all_datasets(TRUE);
-- ============================================================================

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_process_all_datasets`(
  p_dry_run BOOLEAN
)
BEGIN
  DECLARE v_total_datasets INT64;
  DECLARE v_successful INT64 DEFAULT 0;
  DECLARE v_failed INT64 DEFAULT 0;
  DECLARE v_start_time TIMESTAMP;
  DECLARE v_completion_time TIMESTAMP;
  DECLARE v_config_id STRING;

  SET v_start_time = CURRENT_TIMESTAMP();

  -- Get total count
  SET v_total_datasets = (
    SELECT COUNT(*) FROM `durango-deflock.FlockML.dataset_pipeline_config` WHERE enabled = TRUE
  );

  -- Log pipeline start
  INSERT INTO `durango-deflock.FlockML.dataset_processing_log` (
    run_id, config_id, execution_timestamp, processing_status
  )
  VALUES (
    GENERATE_UUID(), 'PIPELINE_START', v_start_time, 'RUNNING'
  );

  IF p_dry_run THEN
    -- Show what would be processed
    SELECT config_id, source_table_name, priority
    FROM `durango-deflock.FlockML.dataset_pipeline_config`
    WHERE enabled = TRUE
    ORDER BY priority;

    SELECT FORMAT('✓ DRY RUN: Would process %d datasets', v_total_datasets) AS status;
  ELSE
    -- Process each dataset
    FOR config_row IN (
      SELECT config_id FROM `durango-deflock.FlockML.dataset_pipeline_config`
      WHERE enabled = TRUE ORDER BY priority
    ) DO
      BEGIN
        CALL `durango-deflock.FlockML.sp_process_single_dataset`(config_row.config_id);
        SET v_successful = v_successful + 1;
      EXCEPTION WHEN ERROR THEN
        SET v_failed = v_failed + 1;
        INSERT INTO `durango-deflock.FlockML.dataset_processing_log` (
          run_id, config_id, execution_timestamp, processing_status, error_message
        )
        VALUES (
          GENERATE_UUID(), config_row.config_id, CURRENT_TIMESTAMP(), 'ERROR', @@error.message
        );
      END;
    END FOR;

    SET v_completion_time = CURRENT_TIMESTAMP();

    -- Log final result
    INSERT INTO `durango-deflock.FlockML.dataset_processing_log` (
      run_id, config_id, execution_timestamp, completion_timestamp, processing_status
    )
    VALUES (
      GENERATE_UUID(), 'PIPELINE_END', v_start_time, v_completion_time,
      IF(v_failed = 0, 'SUCCESS', 'PARTIAL_SUCCESS')
    );

    -- Show summary
    SELECT FORMAT(
      '✓ PIPELINE COMPLETE: %d/%d successful, %d failed, %d seconds',
      v_successful, v_total_datasets, v_failed,
      TIMESTAMP_DIFF(v_completion_time, v_start_time, SECOND)
    ) AS summary;
  END IF;

END;
