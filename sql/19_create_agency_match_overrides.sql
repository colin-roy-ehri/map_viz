-- Phase 4.3: Create Manual Override Table for Agency Matching
-- This table allows manual correction of automatic fuzzy matches for edge cases
-- where automatic matching produces false positives or false negatives

CREATE OR REPLACE TABLE `durango-deflock.FlockML.agency_match_overrides` (
  org_name STRING NOT NULL,
  manual_match BOOL NOT NULL,
  matched_agency STRING,
  override_reason STRING,
  override_timestamp TIMESTAMP,
  PRIMARY KEY (org_name) NOT ENFORCED
);

-- Example manual overrides for testing (commented out):
--
-- INSERT INTO `durango-deflock.FlockML.agency_match_overrides`
-- (org_name, manual_match, matched_agency, override_reason, override_timestamp)
-- VALUES
--   ('Miami-Dade FL PD', FALSE, NULL, 'False positive - different type (PD vs SO)', CURRENT_TIMESTAMP()),
--   ('Unknown Agency TX', FALSE, NULL, 'Non-participating agency', CURRENT_TIMESTAMP()),
--   ('Pinellas County FL SO', TRUE, 'Pinellas County Sheriff Office', 'Manual confirmation', CURRENT_TIMESTAMP());
