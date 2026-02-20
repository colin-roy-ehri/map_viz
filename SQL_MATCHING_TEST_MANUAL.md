# Manual Testing Instructions for Agency Matching

## Overview

The bq CLI is experiencing performance issues. Use these instructions to test the matching logic directly in the BigQuery Console (web UI).

## URL to BigQuery Console

https://console.cloud.google.com/bigquery

Make sure to:
1. Select project: `durango-deflock`
2. Create a new query tab

## Test #1: Verify State Name Mapping Works

Copy and paste into BigQuery Console:

```sql
-- Test: Verify state mapping works for a few state codes
WITH state_mapping AS (
  SELECT 'AL' AS code, 'ALABAMA' AS name UNION ALL
  SELECT 'FL', 'FLORIDA' UNION ALL
  SELECT 'TX', 'TEXAS' UNION ALL
  SELECT 'CO', 'COLORADO' UNION ALL
  SELECT 'ID', 'IDAHO' UNION ALL
  SELECT 'GA', 'GEORGIA'
)
SELECT *
FROM state_mapping
ORDER BY code;
```

**Expected result**: 6 rows showing state codes mapping to full state names

---

## Test #2: Check parsed org_names

```sql
-- Sample some parsed org_names
SELECT
  org_name,
  REGEXP_EXTRACT(org_name, r'([A-Z]{2})') AS state_code,
  TRIM(REGEXP_EXTRACT(org_name, r'\s([A-Z]+)$')) AS agency_type,
  TRIM(REGEXP_EXTRACT(org_name, r'^(.*?)\s[A-Z]{2}\s')) AS location_raw
FROM (
  SELECT DISTINCT org_name
  FROM `durango-deflock.DurangoPD.October2025_classified`
  WHERE org_name IS NOT NULL
)
ORDER BY org_name
LIMIT 20;
```

**Expected result**: Shows org_names with parsed state_code, agency_type, and location_raw

---

## Test #3: Verify Seminole County exists in participating agencies

```sql
-- Check if Seminole County agencies exist in participating agencies
SELECT
  `LAW ENFORCEMENT AGENCY`,
  STATE,
  TYPE
FROM `durango-deflock.FlockML.participatingAgencies`
WHERE STATE = 'FLORIDA'
  AND `LAW ENFORCEMENT AGENCY` LIKE '%Seminole%'
LIMIT 10;
```

**Expected result**: Should show "Seminole County Sheriff's Office" or similar

---

## Test #4: Simple matching test for FL only

```sql
-- Test matching logic for Florida agencies
WITH parsed AS (
  SELECT
    org_name,
    REGEXP_EXTRACT(org_name, r'([A-Z]{2})') AS state_code,
    TRIM(REGEXP_EXTRACT(org_name, r'\s([A-Z]+)$')) AS agency_type,
    TRIM(REGEXP_EXTRACT(org_name, r'^(.*?)\s[A-Z]{2}\s')) AS location_raw
  FROM (
    SELECT DISTINCT org_name
    FROM `durango-deflock.DurangoPD.October2025_classified`
    WHERE org_name IS NOT NULL
      AND org_name LIKE '%FL%'  -- Only FL for testing
  )
),
matches AS (
  SELECT
    p.org_name,
    p.state_code,
    p.agency_type,
    p.location_raw,
    pa.`LAW ENFORCEMENT AGENCY`,
    pa.STATE,
    CASE
      WHEN p.agency_type = 'SO' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%SHERIFF%' THEN 'SHERIFF_MATCH'
      WHEN p.agency_type = 'PD' AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%' THEN 'POLICE_MATCH'
      ELSE 'TYPE_MISMATCH'
    END AS type_match
  FROM parsed p
  JOIN `durango-deflock.FlockML.participatingAgencies` pa
    ON 'FLORIDA' = pa.STATE  -- Manual state mapping for test
    AND LOWER(TRIM(pa.`LAW ENFORCEMENT AGENCY`)) LIKE CONCAT('%', LOWER(p.location_raw), '%')
)
SELECT * FROM matches
LIMIT 50;
```

**Expected result**: Should show matches between FL org_names and Florida agencies if location and type match

---

## Test #5: Count matches in each state

```sql
-- Count how many org_names we have in each state code
WITH parsed AS (
  SELECT
    REGEXP_EXTRACT(org_name, r'([A-Z]{2})') AS state_code,
    COUNT(*) as count
  FROM (
    SELECT DISTINCT org_name
    FROM `durango-deflock.DurangoPD.October2025_classified`
    WHERE org_name IS NOT NULL
  )
  GROUP BY state_code
)
SELECT state_code, count
FROM parsed
ORDER BY count DESC;
```

**Expected result**: Shows distribution of org_names by state code (FL should have many)

---

## Test #6: Run Full Matching (Once Performance is Acceptable)

When Test #1-5 all pass, execute the full matching query:

**Option A: Using sql/25_add_synonym_matching.sql** (with state mapping)

1. Go to `/home/colin/map_viz/sql/25_add_synonym_matching.sql`
2. Copy entire content
3. Paste into BigQuery Console
4. Click "RUN"

**Option B: Using sql/26_simplified_matching_approach.sql** (step-by-step)

1. Execute each query from `/home/colin/map_viz/sql/26_simplified_matching_approach.sql` in order
2. This creates intermediate tables you can inspect

---

## Test #7: Verify Match Results

After running the full matching query, check results:

```sql
-- Count results by match type
SELECT
  match_type,
  COUNT(*) as count
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
GROUP BY match_type;
```

**Expected result** (example):
```
match_type  | count
─────────────────────
synonym     | 250
none        | 248
exact       | 0
```

```sql
-- Sample matches
SELECT
  org_name,
  matched_agency,
  matched_state,
  confidence
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
WHERE match_type = 'synonym'
ORDER BY confidence DESC
LIMIT 20;
```

**Expected result**: Shows actual matched agency names with confidence scores

---

## Troubleshooting

### No matches found
- Check: Are state names correct in participatingAgencies? (Should be full names like "FLORIDA", not "FL")
- Check: Does location_raw match part of agency names? (Use LIKE '%{location}%')
- Check: Are type keywords matching? (PD should find '%POLICE%', SO should find '%SHERIFF%')

### Too many matches
- Add more specific filtering (e.g., first word must match)
- Increase similarity threshold
- Add manual disambiguation for ambiguous matches

### Query timeout
- Reduce dataset size (add WHERE conditions)
- Split into smaller queries
- Consider materialized views for intermediate results

---

## Next Steps After Verification

1. **Validate accuracy** - Manually check 20-30 top matches
2. **Add to classified table** - Join matches back to October2025_classified
3. **Manual review** - Populate manual_org_name_matches table for edge cases
4. **Analyze results** - See distribution of participating vs non-participating agency searches

---

## Key SQL Patterns for Reference

### State Code to Full Name Mapping
```sql
CASE
  WHEN state_code = 'AL' THEN 'ALABAMA'
  WHEN state_code = 'FL' THEN 'FLORIDA'
  WHEN state_code = 'TX' THEN 'TEXAS'
  -- ... etc
END AS state_name
```

### Type Keyword Matching
```sql
CASE
  WHEN agency_type = 'PD' AND name LIKE '%POLICE%' THEN TRUE
  WHEN agency_type = 'SO' AND name LIKE '%SHERIFF%' THEN TRUE
  WHEN agency_type = 'HSP' AND name LIKE '%PATROL%' THEN TRUE
  ELSE FALSE
END AS type_matches
```

### Location Contains Check
```sql
LOWER(agency_name) LIKE CONCAT('%', LOWER(location_raw), '%')
```
