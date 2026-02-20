-- Phase 4.1: Create "No Context" Analysis Report Procedure
-- This procedure generates detailed analysis of searches lacking context
-- (neither case_num nor adequate reason)

CREATE OR REPLACE PROCEDURE `durango-deflock.FlockML.sp_analyze_no_context`(
  classified_table STRING,
  output_table STRING
)
BEGIN
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `%s` AS
    WITH no_context_records AS (
      SELECT *
      FROM `%s`
      WHERE has_no_context = TRUE
    )

    SELECT
      -- Summary metrics
      COUNT(*) AS total_no_context_searches,
      ROUND(COUNT(*) / (SELECT COUNT(*) FROM `%s`) * 100, 2) AS pct_of_all_searches,

      -- Breakdown by organization
      org_name,
      COUNT(*) AS searches_by_org,
      ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct_of_no_context,

      -- Reason patterns (what little exists)
      COUNT(CASE WHEN reason IS NULL THEN 1 END) AS completely_null_reason,
      COUNT(CASE WHEN reason IS NOT NULL THEN 1 END) AS inadequate_reason,
      ARRAY_AGG(DISTINCT reason IGNORE NULLS LIMIT 20) AS sample_inadequate_reasons,

      -- Case number patterns
      COUNT(CASE WHEN case_num IS NULL THEN 1 END) AS null_case_num,
      COUNT(CASE WHEN case_num IS NOT NULL THEN 1 END) AS has_case_num,

      -- Temporal patterns
      MIN(CAST(search_time AS TIMESTAMP)) AS earliest_search,
      MAX(CAST(search_time AS TIMESTAMP)) AS latest_search,

      -- Search scope
      ROUND(AVG(total_networks_searched), 0) AS avg_networks,
      ROUND(AVG(total_devices_searched), 0) AS avg_devices,
      SUM(total_devices_searched) AS total_devices_across_all

    FROM no_context_records
    GROUP BY org_name
    ORDER BY searches_by_org DESC
  """, output_table, classified_table, classified_table);

  SELECT FORMAT('✓ No-context analysis complete for %s -> %s', classified_table, output_table) AS status;

END;
