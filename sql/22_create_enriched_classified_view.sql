-- Phase 4.6: Create Enriched Classified View with Agency Matching
-- This creates a convenient view that joins the fuzzy matching results
-- to the classified table, making it easy to analyze participating agency searches

-- Option A: View (Recommended)
-- Keeps data unified without modifying the original classified table
CREATE OR REPLACE VIEW `durango-deflock.DurangoPD.October2025_enriched` AS
SELECT
  c.*,
  COALESCE(m.is_participating_agency, FALSE) AS is_participating_agency,
  m.matched_agency,
  m.matched_state,
  m.matched_type,
  ROUND(m.similarity, 4) AS match_confidence
FROM `durango-deflock.DurangoPD.October2025_classified` c
LEFT JOIN `durango-deflock.FlockML.org_name_to_participating_agency` m
  ON c.org_name = m.org_name;

-- Example queries using the enriched view:

-- Query 1: Total searches by participating agency status
-- SELECT
--   is_participating_agency,
--   COUNT(*) AS search_count,
--   ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
-- FROM `durango-deflock.DurangoPD.October2025_enriched`
-- GROUP BY is_participating_agency;

-- Query 2: Top participating agencies by search volume
-- SELECT
--   matched_agency,
--   matched_state,
--   COUNT(*) AS search_count,
--   ROUND(AVG(match_confidence), 4) AS avg_confidence
-- FROM `durango-deflock.DurangoPD.October2025_enriched`
-- WHERE is_participating_agency = TRUE
-- GROUP BY matched_agency, matched_state
-- ORDER BY search_count DESC
-- LIMIT 20;

-- Query 3: Search reason distribution by participating status
-- SELECT
--   is_participating_agency,
--   reason,
--   reason_category,
--   COUNT(*) AS count
-- FROM `durango-deflock.DurangoPD.October2025_enriched`
-- GROUP BY is_participating_agency, reason, reason_category
-- ORDER BY is_participating_agency DESC, count DESC;

-- Query 4: Low confidence matches for review
-- SELECT
--   org_name,
--   matched_agency,
--   match_confidence,
--   COUNT(*) AS search_count
-- FROM `durango-deflock.DurangoPD.October2025_enriched`
-- WHERE is_participating_agency = TRUE AND match_confidence < 0.85
-- GROUP BY org_name, matched_agency, match_confidence
-- ORDER BY match_confidence ASC;
