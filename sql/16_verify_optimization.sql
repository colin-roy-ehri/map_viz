-- Phase 5: Verification and Monitoring Queries
-- Use these queries to verify classification optimization and geocoding coverage

-- ============================================================================
-- SECTION 1: CLASSIFICATION OPTIMIZATION VERIFICATION
-- ============================================================================

-- Query 1.1: Verify unique reason extraction
-- Expected: Shows ratio of unique reasons to total rows (should be 5-8% for police data)
SELECT
  'Unique Reason Analysis' AS query,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT LOWER(TRIM(reason))) AS unique_reasons,
  ROUND(COUNT(DISTINCT LOWER(TRIM(reason))) / COUNT(*) * 100, 2) AS unique_percentage
FROM `durango-deflock.DurangoPD.October2025`;

-- Query 1.2: Verify optimization metrics from last classification run
-- Expected: reduction_percentage > 95%, cost_estimate_usd < $0.10
SELECT
  source_table,
  destination_table,
  TIMESTAMP_DIFF(completion_timestamp, execution_timestamp, SECOND) AS execution_seconds,
  total_rows,
  unique_reasons,
  reduction_percentage,
  ROUND((1 - CAST(unique_reasons AS FLOAT64) / CAST(total_rows AS FLOAT64)) * 100, 2) AS calculated_reduction,
  cost_estimate_usd,
  CASE
    WHEN reduction_percentage > 95 THEN '✓ Excellent'
    WHEN reduction_percentage > 90 THEN '✓ Good'
    WHEN reduction_percentage > 80 THEN '⚠ Acceptable'
    ELSE '✗ Poor'
  END AS reduction_quality
FROM `durango-deflock.FlockML.classification_runs`
WHERE procedure_name LIKE '%optimized%'
   OR unique_reasons IS NOT NULL
ORDER BY execution_timestamp DESC
LIMIT 5;

-- Query 1.3: Compare original vs optimized procedure costs
-- Expected: optimized procedure should be 95%+ cheaper
WITH classification_stats AS (
  SELECT
    'Original Procedure' AS procedure_type,
    SUM(CAST(total_rows AS FLOAT64)) AS total_rows_processed,
    SUM(CAST(llm_classified_rows AS FLOAT64)) AS llm_rows_processed,
    SUM(cost_estimate_usd) AS total_cost,
    COUNT(*) AS run_count,
    AVG(cost_estimate_usd) AS avg_cost_per_run
  FROM `durango-deflock.FlockML.classification_runs`
  WHERE unique_reasons IS NULL  -- Original procedure

  UNION ALL

  SELECT
    'Optimized Procedure' AS procedure_type,
    SUM(CAST(total_rows AS FLOAT64)) AS total_rows_processed,
    SUM(CAST(unique_reasons AS FLOAT64)) AS llm_rows_processed,
    SUM(cost_estimate_usd) AS total_cost,
    COUNT(*) AS run_count,
    AVG(cost_estimate_usd) AS avg_cost_per_run
  FROM `durango-deflock.FlockML.classification_runs`
  WHERE unique_reasons IS NOT NULL  -- Optimized procedure
)
SELECT
  procedure_type,
  total_rows_processed,
  llm_rows_processed,
  ROUND(llm_rows_processed / total_rows_processed * 100, 2) AS llm_percentage,
  ROUND(total_cost, 2) AS total_cost,
  ROUND(avg_cost_per_run, 4) AS avg_cost_per_run,
  run_count
FROM classification_stats;

-- Query 1.4: Classification result distribution
-- Shows breakdown of classified vs fallback vs no_context
SELECT
  'Classification Distribution' AS query,
  total_rows,
  preprocessed_rows AS rule_based,
  ROUND(preprocessed_rows / total_rows * 100, 2) AS rule_based_pct,
  llm_classified_rows AS llm_classified,
  ROUND(llm_classified_rows / total_rows * 100, 2) AS llm_pct,
  fallback_rows AS fallback_applied,
  ROUND(fallback_rows / llm_classified_rows * 100, 2) AS fallback_rate_pct,
  no_context_rows,
  ROUND(no_context_rows / total_rows * 100, 2) AS no_context_pct
FROM `durango-deflock.FlockML.classification_runs`
WHERE unique_reasons IS NOT NULL
ORDER BY execution_timestamp DESC
LIMIT 1;

-- Query 1.5: Category distribution in classified output
-- Expected: Valid_Reason > 80%, distribution across categories
SELECT
  reason_category,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
  MIN(classification_timestamp) AS first_classified,
  MAX(classification_timestamp) AS last_classified
FROM `durango-deflock.DurangoPD.October2025_classified`
GROUP BY reason_category
ORDER BY record_count DESC;

-- ============================================================================
-- SECTION 2: GEOCODING COVERAGE & QUALITY
-- ============================================================================

-- Query 2.1: Geocoding coverage summary
-- Expected: >90% of agencies geocoded
SELECT
  'Geocoding Coverage' AS query,
  COUNT(*) AS total_agencies,
  COUNT(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 END) AS geocoded,
  ROUND(COUNT(CASE WHEN latitude IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) AS geocode_coverage_pct,
  COUNT(CASE WHEN geocode_confidence = 'high' THEN 1 END) AS high_confidence,
  COUNT(CASE WHEN geocode_confidence = 'medium' THEN 1 END) AS medium_confidence,
  COUNT(CASE WHEN geocode_confidence = 'low' THEN 1 END) AS low_confidence
FROM `durango-deflock.FlockML.agency_locations`;

-- Query 2.2: Geocoding confidence distribution
-- Expected: Majority high/medium confidence
SELECT
  geocode_confidence,
  COUNT(*) AS agency_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
  COUNT(CASE WHEN latitude BETWEEN 24 AND 50 AND longitude BETWEEN -125 AND -65 THEN 1 END) AS valid_us_coords
FROM `durango-deflock.FlockML.agency_locations`
WHERE geocode_source IN ('nominatim', 'manual')
GROUP BY geocode_confidence
ORDER BY agency_count DESC;

-- Query 2.3: Validate coordinate bounds (US only)
-- Expected: All coordinates within US geographic bounds
SELECT
  CASE
    WHEN latitude BETWEEN 24 AND 50 AND longitude BETWEEN -125 AND -65 THEN 'Valid US Coordinates'
    WHEN latitude IS NULL OR longitude IS NULL THEN 'Missing Coordinates'
    ELSE 'Invalid Coordinates (out of bounds)'
  END AS coordinate_validity,
  COUNT(*) AS agency_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM `durango-deflock.FlockML.agency_locations`
GROUP BY coordinate_validity;

-- Query 2.4: List agencies still missing geocoding
-- Review and manually geocode these
SELECT
  org_name,
  city,
  state,
  geocode_source,
  notes
FROM `durango-deflock.FlockML.agency_locations`
WHERE latitude IS NULL
   OR longitude IS NULL
ORDER BY org_name;

-- Query 2.5: Sample of successfully geocoded agencies
-- Spot check coordinates accuracy
SELECT
  org_name,
  city,
  state,
  latitude,
  longitude,
  geocode_confidence,
  display_name,
  geocode_timestamp
FROM `durango-deflock.FlockML.agency_locations`
WHERE geocode_source = 'nominatim'
  AND latitude IS NOT NULL
ORDER BY RAND()
LIMIT 20;

-- ============================================================================
-- SECTION 3: INTEGRATION & END-TO-END VERIFICATION
-- ============================================================================

-- Query 3.1: Classification + Geocoding Integration
-- Expected: High geocode coverage for all major categories
SELECT
  c.reason_category,
  COUNT(*) AS search_count,
  COUNT(DISTINCT c.org_name) AS unique_agencies,
  COUNT(DISTINCT CASE WHEN l.latitude IS NOT NULL THEN l.org_name END) AS geocoded_agencies,
  ROUND(
    COUNT(DISTINCT CASE WHEN l.latitude IS NOT NULL THEN l.org_name END) * 100.0 /
    COUNT(DISTINCT c.org_name),
    2
  ) AS geocode_coverage_pct,
  COUNT(CASE WHEN l.geocode_confidence = 'high' THEN 1 END) AS high_confidence_searches
FROM `durango-deflock.DurangoPD.October2025_classified` c
LEFT JOIN `durango-deflock.FlockML.agency_locations` l ON c.org_name = l.org_name
GROUP BY c.reason_category
ORDER BY search_count DESC;

-- Query 3.2: Ready for map visualization
-- Shows records that have both classification AND coordinates
SELECT
  c.reason_category,
  c.org_name,
  c.reason,
  l.city,
  l.state,
  l.latitude,
  l.longitude,
  l.geocode_confidence,
  c.search_time
FROM `durango-deflock.DurangoPD.October2025_classified` c
INNER JOIN `durango-deflock.FlockML.agency_locations` l ON c.org_name = l.org_name
WHERE c.reason_category IN ('Violent_Crime', 'Property_Crime')
  AND l.latitude IS NOT NULL
LIMIT 100;

-- Query 3.3: Data quality metrics
-- Comprehensive view of system health
SELECT
  'Data Quality Summary' AS metric,
  (SELECT COUNT(*) FROM `durango-deflock.DurangoPD.October2025_classified`) AS total_classified,
  (SELECT COUNT(DISTINCT org_name) FROM `durango-deflock.FlockML.agency_locations` WHERE latitude IS NOT NULL) AS unique_geocoded_agencies,
  (SELECT COUNT(DISTINCT reason_category) FROM `durango-deflock.DurangoPD.October2025_classified`) AS unique_categories,
  (SELECT ROUND(AVG(TIMESTAMP_DIFF(completion_timestamp, execution_timestamp, SECOND)), 2)
   FROM `durango-deflock.FlockML.classification_runs` WHERE unique_reasons IS NOT NULL) AS avg_run_duration_sec;

-- ============================================================================
-- SECTION 4: COST & PERFORMANCE TRACKING
-- ============================================================================

-- Query 4.1: Cost savings summary
-- Expected: 95%+ reduction in LLM costs
WITH cost_analysis AS (
  SELECT
    'Classification' AS component,
    COUNT(*) AS run_count,
    SUM(CAST(total_rows AS FLOAT64)) AS total_rows_processed,
    SUM(cost_estimate_usd) AS total_cost,
    ROUND(SUM(cost_estimate_usd) / COUNT(*), 4) AS avg_cost_per_run,
    ROUND(AVG(reduction_percentage), 2) AS avg_reduction_percentage
  FROM `durango-deflock.FlockML.classification_runs`
  WHERE unique_reasons IS NOT NULL
)
SELECT
  component,
  run_count,
  total_rows_processed,
  ROUND(total_cost, 2) AS total_cost_usd,
  avg_cost_per_run AS cost_per_run_usd,
  avg_reduction_percentage,
  CASE
    WHEN avg_reduction_percentage >= 95 THEN '✓ Target achieved (95%+)'
    WHEN avg_reduction_percentage >= 90 THEN '✓ Close to target (90%+)'
    ELSE '⚠ Below target'
  END AS status
FROM cost_analysis;

-- Query 4.2: Performance metrics over time
-- Track trends in execution speed
SELECT
  DATE(execution_timestamp) AS run_date,
  COUNT(*) AS run_count,
  AVG(TIMESTAMP_DIFF(completion_timestamp, execution_timestamp, SECOND)) AS avg_duration_sec,
  MIN(TIMESTAMP_DIFF(completion_timestamp, execution_timestamp, SECOND)) AS min_duration_sec,
  MAX(TIMESTAMP_DIFF(completion_timestamp, execution_timestamp, SECOND)) AS max_duration_sec,
  ROUND(AVG(cost_estimate_usd), 4) AS avg_cost_per_run
FROM `durango-deflock.FlockML.classification_runs`
WHERE unique_reasons IS NOT NULL
GROUP BY run_date
ORDER BY run_date DESC;

-- ============================================================================
-- SECTION 5: DATA FRESHNESS & STALENESS
-- ============================================================================

-- Query 5.1: Last classification run details
-- Check recency of optimized classifications
SELECT
  source_table,
  destination_table,
  execution_timestamp,
  completion_timestamp,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), completion_timestamp, MINUTE) AS minutes_ago,
  TIMESTAMP_DIFF(completion_timestamp, execution_timestamp, SECOND) AS duration_sec,
  total_rows,
  unique_reasons,
  reduction_percentage
FROM `durango-deflock.FlockML.classification_runs`
WHERE unique_reasons IS NOT NULL
ORDER BY execution_timestamp DESC
LIMIT 1;

-- Query 5.2: Last geocoding update
-- Check recency of agency geocoding data
SELECT
  COUNT(*) AS total_agencies,
  MAX(geocode_timestamp) AS most_recent_geocode,
  MIN(geocode_timestamp) AS oldest_geocode,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(geocode_timestamp), HOUR) AS hours_since_latest
FROM `durango-deflock.FlockML.agency_locations`;

-- Query 5.3: Agencies with stale geocoding
-- Show agencies that haven't been re-verified in >30 days
SELECT
  org_name,
  city,
  state,
  geocode_timestamp,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), geocode_timestamp, DAY) AS days_old,
  geocode_confidence
FROM `durango-deflock.FlockML.agency_locations`
WHERE TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), geocode_timestamp, DAY) > 30
ORDER BY geocode_timestamp ASC;
