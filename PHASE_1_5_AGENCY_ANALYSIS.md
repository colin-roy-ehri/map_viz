# Phase 1.5: August Agency Analysis & New Matching

## Overview

Before we can accurately match August 2025 searches to participating agencies, we need to:

1. **Identify what agencies are in August** but NOT in October
2. **Run matching on these NEW agencies**
3. **Combine results** into a complete August match table
4. **Report coverage** to understand gaps

This is a critical intermediary step that ensures we don't lose searches from agencies unique to August.

---

## Why Phase 1.5 is Necessary

### The Problem

When we run Phase 1 (classification), we get all org_names from August. But:
- October had certain agencies
- August has those PLUS new agencies not in October
- If we only use October's matches, August searches from new agencies will show as "Non-Participating"
- This would artificially inflate the non-participating percentage

### The Solution

Phase 1.5 applies the rule-based matching algorithm to **only the new August agencies**, then combines:
- October matches (for agencies that appear in both)
- August-only matches (for new agencies unique to August)
= Complete August matching table

---

## What Phase 1.5 Creates

### 4 Output Tables

1. **`august_unique_org_names`** (Read-only Reference)
   - All distinct org_names from August 2025
   - Search count per agency
   - Ranked by frequency

2. **`august_new_org_names`** (Analysis Table)
   - Compares August to October matches
   - Labels each org_name as "NEW" or "Already Matched"
   - Shows October match results (if any)

3. **`august_new_org_matches`** (Matching Results)
   - Rule-based matching applied to new agencies only
   - Same structure as October matches
   - Contains both matched and unmatched new agencies

4. **`august_org_name_matches`** (Final - Used by Phase 2)
   - Combined table: October matches + New August matches
   - Used to join with August2025_classified in Phase 2
   - Contains all possible org_name matches for August

### 7 Analysis Queries

| # | Name | Purpose |
|---|------|---------|
| 1 | Coverage Summary | How many new vs already-matched agencies? |
| 2 | Top 50 New Agencies | Which new agencies have most searches? |
| 3 | Already Matched | How many August searches use Oct-matched agencies? |
| 4 | New Agencies by State | Geographic pattern of new agencies |
| 5 | Duplicate Check | Are there spelling variations? |
| 6 | Results of Matching | How many new agencies got matched? |
| 7 | Newly Matched Details | Which specific new agencies matched? |
| Final | Verification | Overall summary counts |

---

## Expected Findings

### Example Scenario

Suppose:
- October had 180 unique org_names (98 matched, 82 unmatched)
- August has 243 unique org_names

**Phase 1.5 Results**:
```
August Unique Org_Names:        243
Already in October:             98 (40%)
NEW to August:                 145 (60%)
  - Matched by rule-based:     95  (65.5%)
  - Still unmatched:           50  (34.5%)

Final Coverage:
Total Matched for August:       193 (79.4%)
Total Unmatched for August:      50 (20.6%)
```

### What This Tells Us

- 98 agencies appear in both October and August
- 145 new agencies are unique to August
- Of those 145 new agencies, we successfully matched 95 (good coverage)
- Only 50 August agencies couldn't be matched (likely very small volume or non-standard names)

---

## Key Analyses in Phase 1.5

### Analysis 1: Coverage Summary

```
status                | org_names | searches | participation
─────────────────────┼───────────┼──────────┼────────────────
Already Matched       |    98     |  43,900  |    64.8%
NEW - Needs Matching  |   145     |  24,300  |    35.2%
```

**What This Shows**:
- Searches from October-matched agencies: ~65%
- Searches from new August agencies: ~35%
- This means new agencies matter! We can't ignore them.

### Analysis 2: Top 50 New Agencies

This helps identify:
- Which new agencies have highest search volume
- Whether they follow expected patterns
- If any look like misspellings or duplicates

**Example**:
```
Houston TX PD          |  2,500 searches  (likely should match Houston PD)
Seminole County FL SO  |  1,800 searches  (likely should match Seminole Co SO)
Small Town KS PD       |    120 searches  (may not match any participating agency)
```

### Analysis 4: New Agencies by State

Shows where new agencies are coming from:

```
state | org_names | searches | %
──────┼───────────┼──────────┼──────
FL    |    45     |   12,300 | 50.6%
TX    |    32     |    8,900 | 36.6%
CO    |    15     |    1,850 | 7.6%
Other |    53     |    1,250 | 5.1%
```

**Insight**: If August heavily skews toward certain states, that affects participation rates.

### Analysis 5: Duplicate Check

Identifies spelling variations that should be consolidated:

```
normalized_name         | variations | searches
────────────────────────┼────────────┼──────────
houston texas pd        |     2      |  2,100
  - "Houston TX PD"     |            |  1,500
  - "Houston Texas PD"  |            |    600
```

**Action**: Manually review and consider consolidating before Phase 2.

### Analysis 6: Results of Matching New Agencies

```
match_type | new_orgs | matched_agencies | %
───────────┼──────────┼──────────────────┼──────
synonym    |    95    |       92         | 65.5%
none       |    50    |        0         | 34.5%
```

**What This Means**:
- 95 new agencies successfully matched (good!)
- 50 new agencies couldn't match (investigate why)
- 95% success rate on new agencies is excellent

### Analysis 7: Newly Matched Details

Shows exact matches for new agencies:

```
org_name              | matched_agency                | state
──────────────────────┼───────────────────────────────┼──────
Houston TX PD         | Houston Police Department     | TEXAS
Seminole County FL SO | Seminole County Sheriff's Off | FLORIDA
...
```

**Use For**: Validation that matches look correct.

---

## Decision Points in Phase 1.5

### 1. Review Top New Agencies (Analysis 2)
- Do they look like legitimate agencies?
- Any obvious misspellings?
- Any that should be consolidated?

### 2. Check Duplicate Spellings (Analysis 5)
- Are there multiple spellings of same agency?
- Should they be consolidated before matching?

### 3. Validate Newly Matched (Analysis 7)
- Do the matched agencies look correct?
- Any suspicious matches?
- Any that look wrong?

### 4. Investigate Unmatched (Analysis 1 + 7)
- Which 50 agencies couldn't be matched?
- Are they small volume (not critical)?
- Are they obvious matches we missed?
- Should they be manually added?

---

## Execution Flow

```
START
  ↓
Run Phase 1: Classify August
  ↓
August2025_classified ← Ready
  ↓
Run Phase 1.5: Analyze Agencies
  ↓
Extract unique org_names
  ↓
Compare to October matches
  ↓
Identify NEW agencies (145)
  ↓
Run matching on NEW agencies only
  ↓
[REVIEW ANALYSIS RESULTS]
  ↓
Create combined match table
  ↓
august_org_name_matches ← Ready for Phase 2
  ↓
Run Phase 2: Join with matches
  ↓
August2025_enriched ← Ready for analysis
```

---

## Quality Checks

After Phase 1.5, validate:

✅ **`august_org_name_matches` table exists**
```sql
SELECT COUNT(*) FROM `durango-deflock.FlockML.august_org_name_matches`;
-- Should be: 243 (one row per unique org_name)
```

✅ **All August org_names are represented**
```sql
SELECT COUNT(DISTINCT org_name)
FROM `durango-deflock.DurangoPD.August2025_classified`
WHERE org_name NOT IN (SELECT org_name FROM `durango-deflock.FlockML.august_org_name_matches`);
-- Should be: 0 (no unaccounted org_names)
```

✅ **Matching is complete**
```sql
SELECT match_type, COUNT(*) FROM `durango-deflock.FlockML.august_org_name_matches`
GROUP BY match_type;
-- Should show: some 'synonym', some 'none', no gaps
```

---

## If Problems Arise

**No new agencies matched at all**:
- Check that `august_new_org_names` has NEW status
- Verify state mapping is correct
- Run Analysis 7 to see exact new matches

**Too many unmatched**:
- Check Analysis 4 (by state) for geographic patterns
- Review Analysis 2 (top new) for spelling issues
- Consider if agencies are actually non-participating

**Duplicates found**:
- Use Analysis 5 output
- Decide: consolidate before Phase 2 or keep separate
- Update org_names in August2025_classified if consolidating

---

## Next Step

Once Phase 1.5 is complete and validated:
→ Run Phase 2 which joins August2025_classified with august_org_name_matches
→ Creates August2025_enriched with participation flags
→ Continues to Phase 3 (reason analysis)

---

## Summary

**Phase 1.5 is critical because**:
1. August agencies ≠ October agencies
2. We must match new agencies or lose data
3. Affects all downstream participation calculations
4. Provides transparency on what we matched vs didn't

**After Phase 1.5**, we have:
- Complete inventory of August agencies
- Matching results (94%+ coverage expected)
- Insights into new agency patterns
- Confidence in Phase 2 results
