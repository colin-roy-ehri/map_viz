DECLARE tables_to_process ARRAY<STRING> DEFAULT [
  'October2025'
];

DECLARE table_name STRING;
DECLARE source_qualified STRING;
DECLARE dest_qualified STRING;

-- Process each table
FOR table_config IN (SELECT * FROM UNNEST(tables_to_process) AS table_name)
DO
  BEGIN
    SET table_name = table_config.table_name;
    SET source_qualified = CONCAT('durango-deflock.DurangoPD.', table_name);
    SET dest_qualified = CONCAT('durango-deflock.DurangoPD.', table_name, '_classified');

    -- Classify reasons
    CALL `durango-deflock.FlockML.sp_classify_search_reasons`(
      source_qualified,
      dest_qualified
    );

    -- Generate no context analysis
    CALL `durango-deflock.FlockML.sp_analyze_no_context`(
      dest_qualified,
      CONCAT('durango-deflock.DurangoPD.', table_name, '_no_context_analysis')
    );

    SELECT FORMAT('✓ Completed: %s', table_name) AS status;

  EXCEPTION WHEN ERROR THEN
    SELECT FORMAT('✗ Failed: %s - %s', table_name, @@error.message) AS status;
  END;
END FOR;

-- Summary report
SELECT
  source_table,
  execution_timestamp,
  completion_timestamp,
  total_rows,
  no_context_rows,
  ROUND(no_context_rows / total_rows * 100, 2) AS no_context_pct,
  llm_classified_rows,
  fallback_rows,
  ROUND((total_rows * 0.000003), 4) AS estimated_cost_usd,
  TIMESTAMP_DIFF(completion_timestamp, execution_timestamp, SECOND) AS execution_seconds
FROM `durango-deflock.FlockML.classification_runs`
WHERE DATE(execution_timestamp) = CURRENT_DATE()
ORDER BY execution_timestamp DESC;

