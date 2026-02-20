-- Phase 5.2: Create Reusable Template for Other Agencies
-- Template for processing any table from any agency (DurangoPD, TelluridePD, ICE, etc.)
-- Simply update the variables and execute

-- Configuration Variables - UPDATE THESE FOR YOUR AGENCY/TABLE
DECLARE agency_project STRING DEFAULT 'durango-deflock';
DECLARE agency_dataset STRING DEFAULT 'DurangoPD';       -- Change to TelluridePD, ICE, etc.
DECLARE source_table STRING DEFAULT 'October2025'; -- Change to your table name
DECLARE dest_dataset STRING DEFAULT 'DurangoPD';  -- Should match source dataset

-- Construct fully qualified table names
DECLARE source_qualified STRING;
DECLARE dest_classified STRING;
DECLARE dest_analysis STRING;

SET source_qualified = CONCAT(agency_project, '.', agency_dataset, '.', source_table);
SET dest_classified = CONCAT(agency_project, '.', dest_dataset, '_Classified.', source_table, '_classified');
SET dest_analysis = CONCAT(agency_project, '.', dest_dataset, '_Classified.', source_table, '_no_context_analysis');

-- Execute classification
BEGIN
  CALL `durango-deflock.FlockML.sp_classify_search_reasons`(
    source_qualified,
    dest_classified
  );

  -- Execute no-context analysis
  CALL `durango-deflock.FlockML.sp_analyze_no_context`(
    dest_classified,
    dest_analysis
  );

  SELECT FORMAT('✓ Successfully classified %s', source_qualified) AS status;

EXCEPTION WHEN ERROR THEN
  SELECT FORMAT('✗ Classification failed: %s', @@error.message) AS error_message;
END;

-- Show results summary
SELECT
  source_table,
  execution_timestamp,
  total_rows,
  no_context_rows,
  llm_classified_rows,
  cost_estimate_usd
FROM `durango-deflock.FlockML.classification_runs`
WHERE destination_table = dest_classified
ORDER BY execution_timestamp DESC
LIMIT 1;
