-- Phase 4.4: Verification Queries for Agency Matching Quality
-- Use these queries to analyze and validate the fuzzy matching results

-- Query 1: Overall matching coverage and statistics
-- Shows what percentage of org_names matched to participating agencies
SELECT
  'Matching Coverage' AS metric,
  COUNT(DISTINCT org_name) AS total_unique_agencies,
  COUNT(DISTINCT CASE WHEN is_participating_agency THEN org_name END) AS matched_agencies,
  ROUND(COUNT(DISTINCT CASE WHEN is_participating_agency THEN org_name END) * 100.0 /
        COUNT(DISTINCT org_name), 2) AS match_percentage,
  ROUND(AVG(similarity), 4) AS avg_similarity
FROM `durango-deflock.FlockML.org_name_to_participating_agency`;

-- Query 2: Similarity distribution for matched agencies
-- Shows confidence levels of matches
SELECT
  CASE
    WHEN similarity >= 0.95 THEN 'Very High (0.95+)'
    WHEN similarity >= 0.90 THEN 'High (0.90-0.95)'
    WHEN similarity >= 0.85 THEN 'Medium-High (0.85-0.90)'
    WHEN similarity >= 0.75 THEN 'Medium (0.75-0.85)'
    ELSE 'Low (<0.75)'
  END AS similarity_bucket,
  COUNT(*) AS count,
  ROUND(AVG(similarity), 4) AS avg_similarity,
  ROUND(MIN(similarity), 4) AS min_similarity,
  ROUND(MAX(similarity), 4) AS max_similarity
FROM `durango-deflock.FlockML.org_name_to_participating_agency`
WHERE is_participating_agency = TRUE
GROUP BY similarity_bucket
ORDER BY avg_similarity DESC;

-- Query 3: Sample matches for manual review (all matches)
-- Shows matched org_names with their matched agencies for validation
SELECT
  org_name,
  matched_agency,
  matched_state,
  matched_type,
  ROUND(similarity, 4) AS similarity,
  CASE
    WHEN similarity >= 0.90 THEN '✓ HIGH'
    WHEN similarity >= 0.85 THEN '⚠ MEDIUM'
    WHEN similarity >= 0.75 THEN '⚠ LOW'
    ELSE '✗ VERY LOW'
  END AS confidence
FROM `durango-deflock.FlockML.org_name_to_participating_agency`
WHERE is_participating_agency = TRUE
ORDER BY similarity DESC
LIMIT 100;

-- Query 4: High-risk matches requiring manual review
-- Shows matches with similarity between 0.75-0.85 that should be reviewed
SELECT
  org_name,
  matched_agency,
  matched_state,
  matched_type,
  ROUND(similarity, 4) AS similarity
FROM `durango-deflock.FlockML.org_name_to_participating_agency`
WHERE is_participating_agency = TRUE
  AND similarity BETWEEN 0.75 AND 0.85
ORDER BY similarity ASC
LIMIT 50;

-- Query 5: Unmatched agencies
-- Shows org_names that did NOT match to participating agencies
SELECT
  org_name,
  matched_agency,
  ROUND(similarity, 4) AS highest_similarity,
  is_participating_agency
FROM `durango-deflock.FlockML.org_name_to_participating_agency`
WHERE is_participating_agency = FALSE
ORDER BY similarity DESC
LIMIT 50;

-- Query 6: Search volume by participating agency status
-- Shows distribution of searches across participating vs non-participating agencies
-- (This query needs to be run after integrating the matching results with the classified table)
-- SELECT
--   CASE
--     WHEN m.is_participating_agency THEN 'Participating Agency'
--     ELSE 'Non-Participating Agency'
--   END AS agency_status,
--   COUNT(*) AS search_count,
--   COUNT(DISTINCT c.org_name) AS unique_agencies,
--   ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage_of_searches
-- FROM `durango-deflock.DurangoPD.October2025_classified` c
-- LEFT JOIN `durango-deflock.FlockML.org_name_to_participating_agency` m
--   ON c.org_name = m.org_name
-- GROUP BY m.is_participating_agency;

-- Query 7: Manual overrides applied
-- Shows which org_names have manual overrides applied
SELECT
  org_name,
  is_participating_agency,
  matched_agency,
  override_reason
FROM `durango-deflock.FlockML.agency_match_overrides`
ORDER BY org_name;

-- Query 8: Threshold tuning analysis
-- Shows how many matches would result at different similarity thresholds
SELECT
  threshold,
  COUNT(*) AS matches_at_threshold,
  ROUND(AVG(similarity), 4) AS avg_similarity,
  ROUND(MIN(similarity), 4) AS min_similarity,
  ROUND(MAX(similarity), 4) AS max_similarity
FROM (
  SELECT
    similarity,
    CASE
      WHEN similarity >= 0.95 THEN 0.95
      WHEN similarity >= 0.90 THEN 0.90
      WHEN similarity >= 0.85 THEN 0.85
      WHEN similarity >= 0.80 THEN 0.80
      WHEN similarity >= 0.75 THEN 0.75
      ELSE 0.70
    END AS threshold
  FROM `durango-deflock.FlockML.org_name_to_participating_agency`
  WHERE similarity >= 0.70
)
GROUP BY threshold
ORDER BY threshold DESC;

-- Query 9: Agency type distribution of matches
-- Shows if "PD" org_names are matching to Police departments and "SO" to Sheriff's offices
SELECT
  CASE
    WHEN org_name LIKE '%PD%' THEN 'Police Department'
    WHEN org_name LIKE '%SO%' THEN "Sheriff's Office"
    WHEN org_name LIKE '%County%' THEN 'County Agency'
    WHEN org_name LIKE '%City%' THEN 'City Agency'
    ELSE 'Other'
  END AS org_type,
  matched_type,
  COUNT(*) AS match_count,
  ROUND(AVG(similarity), 4) AS avg_similarity
FROM `durango-deflock.FlockML.org_name_to_participating_agency`
WHERE is_participating_agency = TRUE
GROUP BY org_type, matched_type
ORDER BY match_count DESC;

-- Query 10: State-based validation
-- Shows matches by state to ensure geographic plausibility
SELECT
  SUBSTRING(org_name, -2) AS org_state_code,
  matched_state,
  CASE
    WHEN SUBSTRING(org_name, -2) = matched_state THEN 'Same State ✓'
    ELSE 'Different State ⚠'
  END AS state_match,
  COUNT(*) AS count,
  ROUND(AVG(similarity), 4) AS avg_similarity
FROM `durango-deflock.FlockML.org_name_to_participating_agency`
WHERE is_participating_agency = TRUE
GROUP BY org_state_code, matched_state
ORDER BY count DESC;
