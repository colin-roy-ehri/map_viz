-- Phase 5.1: Create Disambiguation Tables for Ambiguous Org Names
-- Identifies org_name clusters (e.g., "Houston PD", "Houston SO") with potential matches

-- Table 1: Org Name Disambiguation (for manual review and assignment)
-- Groups similar org_names and suggests potential participating agency matches
CREATE OR REPLACE TABLE `durango-deflock.FlockML.org_name_disambiguation` (
  disambiguation_id STRING NOT NULL,
  location_cluster STRING NOT NULL,           -- e.g., "Houston", "Seminole County"
  org_names ARRAY<STRING>,                    -- All similar org_names: ["Houston PD", "Houston SO", "Houston HSP"]
  org_types ARRAY<STRING>,                    -- Agency types in cluster: ["PD", "SO", "HSP"]
  state_code STRING,                          -- Common state code: "TX", "FL"
  potential_matches ARRAY<STRUCT<
    agency_name STRING,                       -- Participating agency name
    state STRING,                             -- Agency state
    type STRING,                              -- Agency type
    confidence_note STRING                    -- Why it might match
  >>,                                         -- Potential participating agencies
  manual_selection STRUCT<
    selected_agency STRING,                   -- User-selected match after review
    selected_org_name STRING,                 -- Which org_name was matched
    assignment_date TIMESTAMP,                -- When manually assigned
    assigned_by STRING                        -- Who assigned it
  >,
  notes STRING,                               -- User notes about this cluster
  status STRING,                              -- "pending", "reviewed", "assigned", "rejected"
  PRIMARY KEY (disambiguation_id) NOT ENFORCED
);

-- Table 2: Manual Match Assignments
-- Final authoritative matches after manual review
CREATE OR REPLACE TABLE `durango-deflock.FlockML.manual_org_name_matches` (
  org_name STRING NOT NULL,
  matched_agency STRING NOT NULL,
  matched_state STRING,
  matched_type STRING,
  match_type STRING,                          -- "exact", "synonym", "disambiguation", "rejected"
  confidence FLOAT64,                         -- 1.0 (exact), 0.95 (synonym), 0.85 (disambiguation)
  match_timestamp TIMESTAMP,
  assigned_by STRING,
  notes STRING,
  PRIMARY KEY (org_name) NOT ENFORCED
);

-- Table 3: Agency Type Synonyms (reference table)
CREATE OR REPLACE TABLE `durango-deflock.FlockML.agency_type_synonyms` (
  type_abbreviation STRING NOT NULL,
  synonyms ARRAY<STRING>,
  description STRING,
  PRIMARY KEY (type_abbreviation) NOT ENFORCED
);

-- Table 4: Location Stop Words (for normalization)
CREATE OR REPLACE TABLE `durango-deflock.FlockML.location_stop_words` (
  stop_word STRING NOT NULL,
  replacement STRING,                        -- Optional: what to replace it with
  keep_in_match BOOL,                         -- Whether to keep when matching
  PRIMARY KEY (stop_word) NOT ENFORCED
);

-- Populate agency type synonyms
INSERT INTO `durango-deflock.FlockML.agency_type_synonyms`
VALUES
  ('PD', ['Police Department', 'Police', 'PD'], 'Police Department'),
  ('SO', ['Sheriff\'s Office', 'Sheriff Office', 'Sheriff', 'SO'], 'Sheriff\'s Office'),
  ('HSP', ['Highway Patrol', 'State Patrol', 'Patrol', 'HSP'], 'Highway/State Patrol'),
  ('SPD', ['Police Department', 'Police', 'SPD'], 'Special Police Department'),
  ('DA', ['Department', 'Division', 'DA'], 'District Attorney/Division'),
  ('SD', ['Sheriff Division', 'Sheriff Department', 'SD'], 'Sheriff Division'),
  ('MPD', ['Police Department', 'Police', 'MPD'], 'Metro Police Department'),
  ('PD/SO', ['Police Department', 'Sheriff\'s Office', 'Police', 'Sheriff'], 'Mixed');

-- Populate location stop words
INSERT INTO `durango-deflock.FlockML.location_stop_words`
VALUES
  ('County', 'County', TRUE),
  ('City', 'City', FALSE),
  ('Department', 'Department', FALSE),
  ('Division', 'Division', FALSE),
  ('Bureau', 'Bureau', FALSE);
