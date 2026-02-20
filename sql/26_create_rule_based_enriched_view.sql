-- Phase 5.4: Create Rule-Based Enriched View
-- Joins classified data with rule-based matches for analysis

CREATE OR REPLACE VIEW `durango-deflock.DurangoPD.October2025_enriched_rule_based` AS
SELECT
  c.*,
  COALESCE(m.is_participating_agency, FALSE) AS is_participating_agency,
  m.matched_agency,
  m.matched_state,
  m.matched_type,
  m.confidence AS match_confidence,
  m.match_type,
  m.match_reason
FROM `durango-deflock.DurangoPD.October2025_classified` c
LEFT JOIN `durango-deflock.FlockML.org_name_rule_based_matches` m
  ON c.org_name = m.org_name;
