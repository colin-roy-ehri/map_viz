-- ============================================================================
-- Phase 4.1: Single-Dataset Processor
-- ============================================================================
-- Purpose: Master orchestrator for processing a single dataset
--
-- Steps:
--   1. Classify reasons (using global cache for cost optimization)
--   2. Match agencies (updates global org_name cache)
--   3. Create enriched view (joins classifications + agency matches)
--   4. Generate standard analysis (all 6 analysis tables)
--
-- Usage:
--   CALL FlockML.sp_process_single_dataset('durango-oct-2025');
-- ============================================================================

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_process_single_dataset`(
  p_config_id STRING
)
BEGIN
  DECLARE v_source_table STRING;
  DECLARE v_dataset_name STRING;
  DECLARE v_source_table_name STRING;
  DECLARE v_dataset_project STRING;
  DECLARE v_output_dataset_name STRING;
  DECLARE v_output_suffix STRING;
  DECLARE v_classified_table STRING;
  DECLARE v_enriched_table STRING;
  DECLARE v_analysis_dataset STRING;
  DECLARE v_dataset_label STRING;
  DECLARE v_start_time TIMESTAMP;
  DECLARE v_completion_time TIMESTAMP;
  DECLARE v_total_rows INT64 DEFAULT 0;
  DECLARE v_new_reasons INT64 DEFAULT 0;
  DECLARE v_run_id STRING;

  SET v_start_time = CURRENT_TIMESTAMP();
  SET v_run_id = GENERATE_UUID();

  BEGIN
    -- Step 1: Fetch configuration
    CREATE TEMP TABLE _config AS
    SELECT
      dataset_name, source_table_name, dataset_project,
      COALESCE(output_dataset_name, dataset_name) AS output_dataset_name,
      output_suffix
    FROM `durango-deflock.FlockML.dataset_pipeline_config`
    WHERE config_id = p_config_id AND enabled = TRUE
    LIMIT 1;

    IF (SELECT COUNT(*) FROM _config) = 0 THEN
      RAISE USING MESSAGE = FORMAT('Config ID not found: %s', p_config_id);
    END IF;

    -- Extract config values
    SET (v_dataset_name, v_source_table_name, v_dataset_project, v_output_dataset_name, v_output_suffix) = (
      SELECT AS STRUCT dataset_name, source_table_name, dataset_project, output_dataset_name, output_suffix
      FROM _config LIMIT 1
    );

    -- Construct table names (without backticks - procedures add their own)
    SET v_source_table = FORMAT('%s.%s.%s', v_dataset_project, v_dataset_name, v_source_table_name);
    SET v_classified_table = FORMAT('%s.%s.%s%s', v_dataset_project, v_dataset_name, v_source_table_name, v_output_suffix);
    SET v_enriched_table = FORMAT('%s.%s.%s%s_enriched', v_dataset_project, v_dataset_name, v_source_table_name, v_output_suffix);
    SET v_analysis_dataset = FORMAT('%s.%s_analysis', v_dataset_project, v_dataset_name);
    SET v_dataset_label = FORMAT('%s (%s)', v_source_table_name, CAST(CURRENT_DATE() AS STRING));

    -- Note: Row count will be logged from source table
    SET v_total_rows = 0;

    -- Step 2: Classify reasons
    CALL `durango-deflock.FlockML.sp_classify_search_reasons_incremental`(
      v_source_table, v_classified_table, TRUE
    );

    -- Step 3: Match agencies
    CALL `durango-deflock.FlockML.sp_match_agencies_incremental`(v_classified_table);

    -- Step 4: Create enriched table
    EXECUTE IMMEDIATE FORMAT('''
      CREATE OR REPLACE TABLE `%s` AS
      SELECT
        c.* EXCEPT (org_name),
        c.org_name,
        COALESCE(m.matched_agency, 'Unknown') AS matched_agency_type,
        COALESCE(m.matched_type, 'Unknown') AS matched_location,
        COALESCE(m.is_participating_agency, FALSE) AS is_participating_agency,
        COALESCE(m.confidence, 0.0) AS match_confidence,
        CURRENT_TIMESTAMP() AS enrichment_timestamp
      FROM `%s` c
      LEFT JOIN `durango-deflock.FlockML.org_name_rule_based_matches` m
        ON c.org_name = m.org_name
    ''', v_enriched_table, v_classified_table);

    -- Step 5: Generate analysis
    CALL `durango-deflock.FlockML.sp_generate_standard_analysis`(
      v_enriched_table, v_analysis_dataset, v_dataset_label
    );

    -- Step 6: Update config
    UPDATE `durango-deflock.FlockML.dataset_pipeline_config`
    SET last_processed_timestamp = CURRENT_TIMESTAMP()
    WHERE config_id = p_config_id;

    -- Step 7: Log success
    SET v_completion_time = CURRENT_TIMESTAMP();
    INSERT INTO `durango-deflock.FlockML.dataset_processing_log` (
      run_id, config_id, execution_timestamp, completion_timestamp,
      total_rows, new_reasons_classified, classification_cost_usd,
      processing_status
    )
    VALUES (
      v_run_id, p_config_id, v_start_time, v_completion_time,
      v_total_rows, v_new_reasons, 0.0, 'SUCCESS'
    );

    SELECT FORMAT('✓ Completed: %s in %d seconds', p_config_id,
      TIMESTAMP_DIFF(v_completion_time, v_start_time, SECOND)) AS status;

  EXCEPTION WHEN ERROR THEN
    -- Log error
    INSERT INTO `durango-deflock.FlockML.dataset_processing_log` (
      run_id, config_id, execution_timestamp, completion_timestamp,
      processing_status, error_message
    )
    VALUES (
      v_run_id, p_config_id, v_start_time, CURRENT_TIMESTAMP(),
      'ERROR', @@error.message
    );
    RAISE USING MESSAGE = @@error.message;
  END;

END;
