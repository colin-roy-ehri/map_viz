# Agency Matching Implementation - Status Summary

## Current Status: ❌ Matching Logic Fixed, ⚠️ BigQuery Performance Issues

### What Was Discovered

The rule-based matching was failing due to **fundamental data structure mismatches** between:
1. **Parsed org_names** (abbreviated format from police records)
2. **Participating agencies table** (official full agency names)

### Critical Findings

#### Problem #1: State Code vs State Name Mismatch
- **org_names format**: `"Seminole County FL SO"` → extracts state code `"FL"`
- **participatingAgencies table**: STATE column contains `"FLORIDA"` not `"FL"`
- **Result**: `'FL' != 'FLORIDA'` → **0 MATCHES**
- **Fix**: Create state code to full name mapping

#### Problem #2: TYPE Column Contains Wrong Data
- **Expected**: TYPE column to have `"Police Department"`, `"Sheriff's Office"`, etc.
- **Actual**: TYPE column contains `"County"`, `"Municipality"`, `"State"`, `"State Agency"`
- **Result**: Type synonym matching impossible → **0 MATCHES**
- **Fix**: Extract law enforcement type from agency NAME instead, search for keywords

#### Problem #3: Law Enforcement Type is in Agency NAME
- **Example**: `"Seminole County Sheriff's Office"` - the "Sheriff's Office" part is what tells us the type
- **Matching logic needed**:
  - If org_name ends in "SO" → look for agencies containing "Sheriff" or "Sheriff's Office"
  - If org_name ends in "PD" → look for agencies containing "Police" or "Police Department"

### Data Structure Breakdown

**participatingAgencies Table** (1,424 agencies):
```
FLORIDA        342 agencies
TEXAS          296 agencies
TENNESSEE       63 agencies
PENNSYLVANIA    58 agencies
ALABAMA         51 agencies
... (47 states total)
```

**Sample Agency Names**:
```
"Pinellas County Sheriff's Office"
"Brevard County Sheriff's Office"
"Seminole County Sheriff's Office"
"Charlotte County Sheriff's Office"
"Calhoun County Sheriff's Office"
...
```

**Current org_names Parsing** (498 unique):
```
"Lakewood CO PD"       → state_code: CO, type: PD, location: Lakewood
"Seminole County FL SO" → state_code: FL, type: SO, location: Seminole County
"Houston TX PD"        → state_code: TX, type: PD, location: Houston
"Miami-Dade FL SO"     → state_code: FL, type: SO, location: Miami-Dade
```

### Solution Implemented

**File**: `/home/colin/map_viz/sql/25_add_synonym_matching.sql` (Updated)

**Fixes Applied**:

1. **Added inline state mapping** (FL↔FLORIDA, TX↔TEXAS, etc.):
```sql
WITH state_mapping AS (
  SELECT 'FL' AS state_code, 'FLORIDA' AS state_name
  UNION ALL SELECT 'TX', 'TEXAS'
  ...
)
```

2. **Updated join condition**:
```sql
ON p.state_name = pa.STATE  -- Now FL maps to FLORIDA
```

3. **Changed type matching to search in agency name**:
```sql
-- OLD (won't work):
AND pa.TYPE IN ('Police Department', 'Police', 'PD')

-- NEW (searches agency name for keywords):
AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%'

-- FOR SHERIFF:
AND UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%SHERIFF%'
```

### Alternative Implementation: Step-by-Step Approach

**File**: `/home/colin/map_viz/sql/26_simplified_matching_approach.sql` (Created)

Four-phase approach to potentially improve performance:
1. **Phase 1**: Parse and create `parsed_org_names` table (498 unique records)
2. **Phase 2**: Add state mapping to create `parsed_org_names_with_state`
3. **Phase 3**: Find matches, store in `org_name_matches_temp` with scoring
4. **Phase 4**: Select best match, handle unmatched orgs

This approach:
- Breaks complex query into manageable steps
- Creates scoring system (location_score + type_score)
- Uses ROW_NUMBER to select best match per org_name
- Materializes intermediate tables for debugging

### Expected Matching Results

**Example successful matches** (after fix):
```
"Seminole County FL SO" → "Seminole County Sheriff's Office" ✓
  - state: FL → FLORIDA ✓
  - location: "Seminole County" found in name ✓
  - type: SO → LIKE '%SHERIFF%' ✓

"Houston TX PD" → "Houston Police Department" ✓
  - state: TX → TEXAS ✓
  - location: "Houston" found in name ✓
  - type: PD → LIKE '%POLICE%' ✓

"Miami-Dade FL SO" → "Miami-Dade Police Department" ✗
  - state: FL → FLORIDA ✓
  - location: "Miami-Dade" found in name ✓
  - type: SO → but name has POLICE not SHERIFF ✗
```

### Outstanding Issues

#### BigQuery Performance
- Queries timing out when executed
- Multiple hung bq processes from earlier execution attempts
- Possible resource constraints or authentication issues

**Next steps if performance issues persist**:
1. Try executing from BigQuery console directly
2. Use `bq job list` to check for stuck jobs
3. Consider using smaller batches if data size is issue
4. Check BigQuery project quotas and limits

### Files Modified/Created

1. **`sql/25_add_synonym_matching.sql`** - FIXED with state mapping and name-based type matching
2. **`sql/26_simplified_matching_approach.sql`** - Alternative step-by-step approach
3. **`MATCHING_ISSUES_FOUND.md`** - Detailed problem analysis
4. **`IMPLEMENTATION_SUMMARY.md`** - This file

### How to Verify Fix Works

Once BigQuery performance is resolved, run:

```sql
-- Test 1: Check parsed org_names
SELECT * FROM `durango-deflock.FlockML.parsed_org_names_with_state` LIMIT 5;

-- Test 2: Verify state mapping
SELECT DISTINCT state_code, state_name FROM `durango-deflock.FlockML.parsed_org_names_with_state`;

-- Test 3: Check for Seminole matches
SELECT
  org_name,
  state_code,
  state_name,
  location_raw
FROM `durango-deflock.FlockML.parsed_org_names_with_state`
WHERE location_raw LIKE '%Seminole%';

-- Test 4: Check participating agencies with Seminole
SELECT * FROM `durango-deflock.FlockML.participatingAgencies`
WHERE STATE = 'FLORIDA'
  AND `LAW ENFORCEMENT AGENCY` LIKE '%Seminole%'
LIMIT 5;

-- Test 5: Run final matching (once performance is resolved)
-- See sql/25_add_synonym_matching.sql or sql/26_simplified_matching_approach.sql
```

### Expected Outcome After Fix

Assuming matching works correctly:
- **Exact matches** (confidence 1.0): 0 (expected - abbreviated vs full names)
- **Synonym matches** (confidence 0.95): 100-400+ (depending on how many orgs have equivalents)
- **Unmatched** (confidence 0.0): Remaining org_names

Key metrics:
- Match percentage for searches by participating agencies
- Distribution of matches by state
- Confidence score breakdown

### User Action Items

1. **Verify the fix works** - Execute one of the SQL files once BigQuery is responsive
2. **Check results** - Query the resulting matches table
3. **Adjust thresholds** - If needed, modify confidence scores or match criteria
4. **Manual review** - Check ambiguous matches (confidence 0.85-0.95)
5. **Add to classified table** - Join match results back to October2025_classified

### Next Phase: Manual Refinement

Once matching runs, the `manual_org_name_matches` table can be populated:

```sql
-- Example: Manually override a match
INSERT INTO `durango-deflock.FlockML.manual_org_name_matches`
(org_name, matched_agency, matched_state, matched_type, manual_override_reason)
VALUES
('Some PD', 'Some Police Department', 'FLORIDA', 'County', 'Verified via phone');
```

This allows human-in-the-loop refinement of the matching results.
