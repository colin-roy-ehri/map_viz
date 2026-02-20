# Quick Start: Run Agency Matching Now

## TL;DR

The matching was failing because:
- ❌ State codes (FL) don't match state names (FLORIDA)
- ❌ TYPE column has wrong data (County/Municipality, not Police/Sheriff)
- ❌ Law enforcement type is IN the agency names, not a separate column

**Status**: Fixed! Ready to execute.

---

## Run Matching in 2 Minutes

### Step 1: Open BigQuery Console
https://console.cloud.google.com/bigquery?project=durango-deflock

### Step 2: Create New Query
Click "+" → "SQL query"

### Step 3A: Copy & Run Solution #1 (Recommended)
Copy entire content from:
```
/home/colin/map_viz/sql/25_add_synonym_matching.sql
```
Paste into console → Click **RUN**

*OR*

### Step 3B: Run Solution #2 (Step-by-Step)
Copy each query from:
```
/home/colin/map_viz/sql/26_simplified_matching_approach.sql
```
Run them one at a time

### Step 4: Check Results
```sql
SELECT match_type, COUNT(*) FROM `durango-deflock.FlockML.org_name_rule_based_matches` GROUP BY match_type;
```

---

## Quick Test Before Running Full Query

Paste this into BigQuery console first:

```sql
-- Verify state mapping works
SELECT 'FL' AS code, 'FLORIDA' AS name
UNION ALL SELECT 'TX', 'TEXAS'
UNION ALL SELECT 'FL', 'FLORIDA'
```

Should return 3 rows.

---

## After Matching Completes

### Verify Results
```sql
SELECT
  match_type,
  COUNT(*) as count
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
GROUP BY match_type;
```

### See Sample Matches
```sql
SELECT org_name, matched_agency, confidence
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
WHERE match_type = 'synonym'
LIMIT 20;
```

### Count Participating Agency Searches
```sql
SELECT
  COALESCE(m.matched_agency, 'Unmatched') AS agency,
  COUNT(*) as searches
FROM `durango-deflock.DurangoPD.October2025_classified` c
LEFT JOIN `durango-deflock.FlockML.org_name_rule_based_matches` m
  ON c.org_name = m.org_name
GROUP BY agency
ORDER BY searches DESC
LIMIT 20;
```

---

## What to Expect

**Exact matches**: 0 (abbreviations vs full names)
**Synonym matches**: 100-400+ agencies
**Unmatched**: Remaining agencies

**Top matches should look like**:
```
"Seminole County FL SO" → "Seminole County Sheriff's Office"
"Houston TX PD" → "Houston Police Department"
"Miami-Dade FL SO" → "Miami-Dade Sheriff's Office"
```

---

## Troubleshooting

**No matches?**
- Check that state names in participatingAgencies are "FLORIDA" not "FL"
- Verify location_raw contains words found in agency names
- Make sure type keywords (POLICE, SHERIFF, etc.) are uppercase

**Too many matches?**
- Add more specific location filtering
- Increase confidence threshold
- Review manually for false positives

**Query timeout?**
- Use step-by-step approach (Solution #2)
- Add WHERE clause to test subset first
- Run in BigQuery console, not CLI

---

## Documentation Files

- **DEBUGGING_AND_NEXT_STEPS.md** - Complete guide with all verification queries
- **SQL_MATCHING_TEST_MANUAL.md** - 7 progressive tests
- **MATCHING_ISSUES_FOUND.md** - Detailed root cause analysis
- **IMPLEMENTATION_SUMMARY.md** - Data structure overview

---

## That's It!

You're ready to go. Open BigQuery console and paste the SQL. Report back with:
1. How many matches found?
2. Do they look correct?
3. Any issues encountered?
