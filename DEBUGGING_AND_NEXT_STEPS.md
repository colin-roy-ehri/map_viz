# Agency Matching - Debugging Results & Next Steps

## Investigation Complete ✅

I've identified exactly why the rule-based matching was returning 0 results and created corrected implementations.

---

## Root Cause Analysis

### The Problem

The query in `sql/25_add_synonym_matching.sql` was failing silently because of **data structure mismatches**:

#### Mismatch #1: State Codes vs State Names
```
Parsed org_names:  "Seminole County FL SO"  →  state_code = "FL"
Participating Agencies table:  STATE = "FLORIDA"

Join condition tried: p.state_code = pa.STATE
Result: "FL" != "FLORIDA"  →  ❌ NO MATCH
```

#### Mismatch #2: TYPE Column Content
```
Query expected in TYPE column:
  "Police Department", "Sheriff's Office", "Highway Patrol", etc.

Actual TYPE column values:
  "County", "Municipality", "State", "State Agency"

Result: ❌ TYPE matching impossible
```

#### Mismatch #3: Law Enforcement Type Location
```
Query was checking: pa.TYPE IN ('Police Department', ...)
Actual law enforcement type is IN THE AGENCY NAME:
  "Seminole County Sheriff's Office"     ← "Sheriff's Office" is here
  "Houston Police Department"             ← "Police Department" is here
  "Miami-Dade Police Department"          ← "Police Department" is here

Result: ❌ Need to search agency names for keywords
```

---

## Data Confirmed

### participatingAgencies Table Stats
- **Total agencies**: 1,424
- **States represented**: 47 (includes DC)
- **State distribution**:
  - FLORIDA: 342 agencies (largest)
  - TEXAS: 296 agencies
  - TENNESSEE: 63 agencies
  - PENNSYLVANIA: 58 agencies
  - ALABAMA: 51 agencies
  - (27 other states with ≤47 agencies each)

### Sample Agency Names
```
Pinellas County Sheriff's Office
Brevard County Sheriff's Office
Seminole County Sheriff's Office      ← Should match "Seminole County FL SO"
Houston Police Department             ← Should match "Houston TX PD"
Charlotte County Sheriff's Office
Broward County Sheriff's Office
...
```

---

## Solutions Provided

### Solution #1: Fixed Synonym Matching (Recommended)
**File**: `/home/colin/map_viz/sql/25_add_synonym_matching.sql`

**What Changed**:
1. Added inline state_mapping CTE
   - Converts "FL" → "FLORIDA", "TX" → "TEXAS", etc.
2. Fixed join condition
   - Now uses mapped state name instead of raw code
3. Changed type matching
   - Searches agency NAME for keywords instead of TYPE column
   ```sql
   OLD: pa.TYPE IN ('Police Department', 'Police', 'PD')
   NEW: UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%'

   OLD: pa.TYPE IN ('Sheriff\'s Office', 'Sheriff Office', 'Sheriff', 'SO')
   NEW: UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%SHERIFF%'
   ```

**Advantages**:
- All logic in single query
- Simpler to understand
- Better performance than procedures

**Disadvantages**:
- Inline state mapping is verbose
- Large JOIN operations might timeout

### Solution #2: Step-by-Step Approach
**File**: `/home/colin/map_viz/sql/26_simplified_matching_approach.sql`

**Phases**:
1. Create `parsed_org_names` table (498 records)
2. Add state mapping to create `parsed_org_names_with_state`
3. Find matches with scoring to `org_name_matches_temp`
4. Select best match per org_name to final table

**Advantages**:
- Materializes intermediate tables for debugging
- Scoring system gives transparency to matches
- Potentially more efficient (splits large JOINs)

**Disadvantages**:
- Creates temporary tables (uses storage)
- More steps to troubleshoot

---

## How to Execute

### Option A: Use BigQuery Web Console (RECOMMENDED)

Due to CLI timeout issues, use the web UI:

1. Go to: https://console.cloud.google.com/bigquery
2. Select project: `durango-deflock`
3. Create new query
4. **For Solution #1**: Copy entire content of `sql/25_add_synonym_matching.sql` and paste
5. **For Solution #2**: Copy each CREATE TABLE query from `sql/26_simplified_matching_approach.sql` one by one
6. Click "RUN" and wait for completion

### Option B: Use Manual Test Guide

**File**: `/home/colin/map_viz/SQL_MATCHING_TEST_MANUAL.md`

Provides 7 progressive tests:
- Test #1-5: Validate the data and mapping works
- Test #6: Run full matching
- Test #7: Verify results

Start with tests #1-5 before running full matching.

### Option C: Try CLI After Cleanup

If you want to try the bq CLI again:

```bash
# Kill stuck processes
pkill -f bq

# Wait a moment
sleep 2

# Try simple query first
bq query --nouse_legacy_sql "SELECT COUNT(*) FROM \`durango-deflock.FlockML.participatingAgencies\`;"

# If that works, try creating parsed table
bq query --nouse_legacy_sql < sql/26_simplified_matching_approach.sql
```

---

## Expected Results After Running

### Match Counts (Estimate)
```
match_type  | Expected Count
─────────────────────────────
exact       | 0 (abbreviations won't match full names)
synonym     | 100-400+ (depending on coverage)
none        | 100-400 (orgs without matching participating agencies)
```

### Sample Successful Matches
```
Seminole County FL SO      → Seminole County Sheriff's Office (confidence: 0.95)
Houston TX PD              → Houston Police Department (confidence: 0.95)
Miami-Dade FL SO           → Miami-Dade Sheriff's Office (confidence: 0.95)
Broward County FL SO       → Broward County Sheriff's Office (confidence: 0.95)
Palm Beach County FL SO    → Palm Beach County Sheriff's Office (confidence: 0.95)
```

### Sample Unmatched
```
Rural County CO PD         → NULL (no match found)
Small Town ID PD           → NULL (no match found)
Some Agency GA             → NULL (no match found)
```

---

## Verification Queries

After running matching, use these to verify:

### Query 1: Match Summary
```sql
SELECT
  match_type,
  COUNT(*) as count,
  ROUND(COUNT(*)*100.0/SUM(COUNT(*)) OVER(), 1) as percentage
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
GROUP BY match_type
ORDER BY count DESC;
```

### Query 2: Sample Matches by Type
```sql
SELECT
  org_name,
  matched_agency,
  matched_state,
  confidence,
  match_type
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
WHERE match_type = 'synonym'
ORDER BY org_name
LIMIT 30;
```

### Query 3: Coverage by State
```sql
SELECT
  matched_state,
  COUNT(*) as matched_count,
  COUNT(DISTINCT org_name) as unique_agencies
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
WHERE match_type = 'synonym'
GROUP BY matched_state
ORDER BY matched_count DESC;
```

### Query 4: Join Back to Classified Data
```sql
SELECT
  c.org_name,
  m.matched_agency,
  m.confidence,
  COUNT(*) as search_count
FROM `durango-deflock.DurangoPD.October2025_classified` c
LEFT JOIN `durango-deflock.FlockML.org_name_rule_based_matches` m
  ON c.org_name = m.org_name
GROUP BY c.org_name, m.matched_agency, m.confidence
ORDER BY search_count DESC
LIMIT 50;
```

---

## Known Issues & Workarounds

### Issue #1: BigQuery CLI Timeouts
**Symptom**: `bq query` commands hang indefinitely
**Cause**: Unclear - possibly resource constraints or authentication issues
**Workaround**: Use BigQuery web console instead
**Fix**: Clear stuck processes with `pkill -f bq` and retry

### Issue #2: Large JOIN Performance
**Symptom**: Query times out with message about job runtime
**Cause**: 498 org_names × 1,424 agencies = 708,672 potential comparisons
**Workaround**: Use step-by-step approach (Solution #2) to materialize intermediate tables
**Fix**: Run shorter queries with WHERE clauses to test specific subsets

### Issue #3: State Mapping Verbosity
**Symptom**: Inline state mapping makes query very long
**Cause**: Using CASE statements for all 50 states inline
**Fix**: Create permanent `state_mapping` table (saves 50+ lines)

---

## Next Phase: Manual Review & Refinement

After matching completes, do manual review:

### Step 1: Check Top Matches
```sql
SELECT org_name, matched_agency, confidence
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
WHERE match_type = 'synonym'
ORDER BY org_name
LIMIT 50;
```
👉 Verify these look correct

### Step 2: Check Ambiguous Matches
```sql
SELECT org_name, matched_agency, confidence
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
WHERE match_type = 'synonym'
  AND confidence < 0.95
ORDER BY confidence;
```
👉 Review lower-confidence matches for false positives

### Step 3: Check Unmatched Orgs
```sql
SELECT org_name, COUNT(*) as search_count
FROM `durango-deflock.DurangoPD.October2025_classified` c
LEFT JOIN `durango-deflock.FlockML.org_name_rule_based_matches` m
  ON c.org_name = m.org_name
WHERE m.org_name IS NULL
GROUP BY org_name
ORDER BY search_count DESC;
```
👉 See which unmatched orgs have the most searches (worth investigating manually)

### Step 4: Populate Manual Overrides
```sql
INSERT INTO `durango-deflock.FlockML.manual_org_name_matches`
(org_name, matched_agency, matched_state, matched_type, manual_override_reason, override_timestamp)
VALUES
('Some Org PD', 'Some Police Department', 'STATE', 'Type', 'Verified manually', CURRENT_TIMESTAMP());
```

---

## Summary Checklist

- [x] Identified root causes (3 data structure mismatches)
- [x] Fixed `sql/25_add_synonym_matching.sql` with state mapping and name-based type matching
- [x] Created alternative `sql/26_simplified_matching_approach.sql` for potential performance improvements
- [x] Created `SQL_MATCHING_TEST_MANUAL.md` with 7 progressive tests
- [x] Documented all findings in `MATCHING_ISSUES_FOUND.md` and `IMPLEMENTATION_SUMMARY.md`
- [ ] **USER ACTION**: Execute one of the solutions (via web console recommended)
- [ ] **USER ACTION**: Verify results using verification queries
- [ ] **USER ACTION**: Perform manual review and refinement
- [ ] **USER ACTION**: Join matched results back to classified table for analysis

---

## Questions to Ask Yourself After Running

1. **Is the match percentage reasonable?** (Should be 15-40% of unique orgs matched)
2. **Do the matched agencies look correct?** (Manual spot check)
3. **Are any states over/under-represented?** (Florida should have many matches)
4. **Do confidence scores make sense?** (Higher for exact location matches)
5. **How many searches are from participating agencies?** (This is the business metric)

Once you have these answers, you'll understand the quality of the matching and whether manual refinement is needed.
