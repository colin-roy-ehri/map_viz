-- Phase 4.1: Create Agency Locations Lookup Table
-- Stores geocoded coordinates for unique police agencies
-- Enables map visualization with lat/lng data
-- Populated by Python script: python/geocode_agencies.py

CREATE OR REPLACE TABLE `durango-deflock.FlockML.agency_locations` (
  org_name STRING NOT NULL,
  city STRING,
  state STRING,
  latitude FLOAT64,
  longitude FLOAT64,
  geocode_confidence STRING,
  geocode_source STRING NOT NULL,
  display_name STRING,
  geocode_timestamp TIMESTAMP,
  notes STRING,
  PRIMARY KEY (org_name) NOT ENFORCED
)
PARTITION BY DATE(geocode_timestamp)
OPTIONS(
  description="Geocoded agency locations for map visualization. Populated by geocode_agencies.py script.",
  require_partition_filter=FALSE
);

-- Create index view for common queries
CREATE OR REPLACE VIEW `durango-deflock.FlockML.agency_locations_summary` AS
SELECT
  org_name,
  city,
  state,
  latitude,
  longitude,
  geocode_confidence,
  CASE
    WHEN latitude BETWEEN 24 AND 50 AND longitude BETWEEN -125 AND -65 THEN 'Valid'
    WHEN latitude IS NULL AND longitude IS NULL THEN 'Missing'
    ELSE 'Invalid'
  END AS coordinate_validity,
  geocode_source,
  geocode_timestamp
FROM `durango-deflock.FlockML.agency_locations`
WHERE latitude IS NOT NULL AND longitude IS NOT NULL
ORDER BY geocode_timestamp DESC;

-- Create view for monitoring geocoding coverage
CREATE OR REPLACE VIEW `durango-deflock.FlockML.geocoding_coverage_by_confidence` AS
SELECT
  geocode_confidence,
  COUNT(*) AS agency_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
  COUNT(CASE WHEN latitude BETWEEN 24 AND 50 AND longitude BETWEEN -125 AND -65 THEN 1 END) AS valid_coords
FROM `durango-deflock.FlockML.agency_locations`
WHERE geocode_source IN ('nominatim', 'manual')
GROUP BY geocode_confidence
ORDER BY agency_count DESC;
