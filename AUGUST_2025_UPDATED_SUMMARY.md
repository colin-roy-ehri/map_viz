# August 2025 Analysis - Updated Workflow

## What Changed

Based on your excellent point about evaluating new agencies before matching, the workflow now includes a **critical Phase 1.5** that:

1. ✅ Extracts all unique org_names from August
2. ✅ Compares to October to find NEW agencies
3. ✅ Runs rule-based matching on just the new agencies
4. ✅ Creates a complete August match table
5. ✅ Provides 7 analysis queries for validation

---

## Updated 5-Phase Workflow

### **Phase 1: Classify (5 min)**
📄 File: `28_classify_august_2025.sql`

Parse org_names and categorize search reasons

**Output**: `August2025_classified` table

---

### **Phase 1.5: Analyze Agencies (5 min)** ⭐ NEW & CRITICAL
📄 File: `29a_analyze_august_agencies.sql`

Identify new agencies and run matching

**Outputs**:
- `august_unique_org_names` - All unique agencies in August
- `august_new_org_names` - Comparison: October vs August
- `august_new_org_matches` - Matching results for new agencies
- `august_org_name_matches` - **Combined matches (Oct + Aug)**

**Key Analyses**:
1. Coverage Summary - How many new vs already-matched?
2. Top 50 New Agencies - Which are highest volume?
3. Already Matched - How many searches use Oct-matched agencies?
4. New Agencies by State - Geographic patterns
5. Duplicate Check - Spelling variations?
6. Results of Matching - How many new agencies matched?
7. Newly Matched Details - Which specific matches?
8. Final Verification - Complete counts

---

### **Phase 2: Join Matches (3 min)**
📄 File: `29_match_august_agencies.sql`

**Updated to use**: `august_org_name_matches` (not October-only)

Join August classified with complete match table

**Output**: `August2025_enriched` table

---

### **Phase 3: Analyze by Reason (5 min)**
📄 File: `30_reason_participation_analysis.sql`

Break down by reason type and participation status

**8 Analysis Queries** covering:
- Participation by reason category
- Reasonless searches
- Valid vs invalid reasons
- Case number presence
- High-risk searches

---

### **Phase 4: Suspicion Ranking (3 min)**
📄 File: `31_august_suspicion_ranking.sql`

Score risk and identify high-risk patterns

**View + 6 Queries** including:
- Executive summary
- Suspicion distribution
- Risk factor analysis
- Very high-risk searches
- Agency risk profiles

---

## Why Phase 1.5 is Critical

### Without Phase 1.5:
- Use October matches for August data
- Miss 145 new August agencies
- Artificially low participation rate
- Incomplete picture

### With Phase 1.5:
✅ Find all new agencies (145 expected)
✅ Match 95+ of them (~65%)
✅ Create complete August match table
✅ Accurate participation calculations
✅ Transparent about what's matched vs not

---

## Key Metrics Phase 1.5 Will Show

**Example Expected Results**:

| Metric | Count |
|--------|-------|
| Total August Searches | 68,000-70,000 |
| Unique August Org_Names | ~240 |
| From October-Matched Agencies | ~100 |
| Unique to August | ~140 |
| Successfully Matched (New) | ~95 (68%) |
| Still Unmatched | ~45 (32%) |
| **Total Matched for August** | **~195 (81%)** |

---

## How to Execute

```
1. Run Phase 1: 28_classify_august_2025.sql
   ↓ Creates August2025_classified

2. Run Phase 1.5: 29a_analyze_august_agencies.sql ⭐ CRITICAL BEFORE PHASE 2
   ↓ Creates august_org_name_matches (and analysis tables)

3. Review Phase 1.5 Analysis Outputs
   - Check top new agencies
   - Validate newly matched results
   - Note any unmatched patterns

4. Run Phase 2: 29_match_august_agencies.sql
   ↓ Creates August2025_enriched

5. Run Phase 3: 30_reason_participation_analysis.sql
   ↓ 8 detailed analysis queries

6. Run Phase 4: 31_august_suspicion_ranking.sql
   ↓ Creates view + runs 6 analysis queries
```

---

## Files in This Package

### SQL Files (Ready to Execute)
- ✅ `28_classify_august_2025.sql` - Phase 1
- ✅ `29a_analyze_august_agencies.sql` - Phase 1.5 (NEW)
- ✅ `29_match_august_agencies.sql` - Phase 2 (UPDATED)
- ✅ `30_reason_participation_analysis.sql` - Phase 3
- ✅ `31_august_suspicion_ranking.sql` - Phase 4

### Documentation Files
- ✅ `AUGUST_2025_ANALYSIS_QUERIES.md` - Overview
- ✅ `AUGUST_2025_EXECUTION_GUIDE.md` - Step-by-step instructions (UPDATED)
- ✅ `PHASE_1_5_AGENCY_ANALYSIS.md` - Detailed Phase 1.5 explanation (NEW)
- ✅ `AUGUST_2025_UPDATED_SUMMARY.md` - This file

---

## Quality Assurance Checkpoints

### After Phase 1.5, Verify:

```sql
-- 1. All August org_names are covered
SELECT COUNT(DISTINCT org_name) as august_orgs,
       COUNT(DISTINCT CASE WHEN match_type != 'none' THEN org_name END) as matched
FROM `durango-deflock.FlockML.august_org_name_matches`;

-- 2. Coverage percentage
SELECT ROUND(
  COUNT(DISTINCT CASE WHEN match_type != 'none' THEN org_name END) * 100.0 /
  COUNT(DISTINCT org_name), 1) as match_coverage_pct
FROM `durango-deflock.FlockML.august_org_name_matches`;

-- 3. New agencies matched
SELECT COUNT(DISTINCT org_name)
FROM `durango-deflock.FlockML.august_new_org_matches`
WHERE match_type = 'synonym';
```

**Expected Results**:
- August orgs: ~240-250
- Matched: ~190-200
- Coverage: 78-85%
- New matched: ~90-100

---

## Decision Scenarios

### Scenario 1: Coverage is Good (80%+)
→ Proceed directly to Phase 2
→ All good!

### Scenario 2: Coverage is Low (60-79%)
→ Review Analysis 2 (Top 50 new agencies)
→ Investigate why unmatched
→ Consider manual additions for high-volume agencies
→ Proceed to Phase 2 with note of gaps

### Scenario 3: Many Duplicates Found (Analysis 5)
→ Consider consolidating spelling variations
→ Update org_names in August2025_classified
→ Re-run Phase 1.5
→ Then proceed to Phase 2

### Scenario 4: Suspicious Matches (Analysis 7)
→ Review specific matches
→ Consider manual overrides for obvious errors
→ Update `manual_org_name_matches` table if needed
→ Proceed to Phase 2

---

## Estimated Participation Rate After Complete Analysis

Based on October baseline (9.5%) and expected August coverage:

| Scenario | Expected Participation |
|----------|------------------------|
| If 80% of August agencies matched | 7-9% |
| If 85% of August agencies matched | 8-10% |
| If 90% of August agencies matched | 9-11% |

**Most Likely**: 8-10% (similar to October, maybe slightly lower)

---

## What's Different from October Analysis

| Aspect | October | August |
|--------|---------|--------|
| Phases | 4 | 5 (added 1.5) |
| Pre-validation | No | ✅ Yes (1.5) |
| New agency handling | N/A | Specific queries |
| Match table used | October-only | October + August-new |
| Transparency | Good | ✅ Better |
| Coverage visibility | Indirect | ✅ Direct (Analysis 1) |

---

## Next Steps

1. **Execute Phase 1**: Creates classified data ✅
2. **Execute Phase 1.5**: Creates match table + analysis ✅ (NEW)
   - Review the 7 analysis queries
   - Validate coverage is acceptable
   - Note any issues
3. **Execute Phases 2-4**: Complete analysis
4. **Export Results**: Save to CSV for stakeholders
5. **Compare August to October**: Identify trends

---

## Questions for Your Review

After executing Phase 1.5, consider:

1. ❓ **Coverage**: Is 80%+ coverage acceptable? Do we want to manually match more?
2. ❓ **New Agencies**: Do the top new agencies look legitimate?
3. ❓ **Duplicates**: Should we consolidate any spelling variations?
4. ❓ **Unmatched**: Do the 45-50 unmatched agencies matter?
5. ❓ **Trends**: How different is August from October so far?

---

## Timeline

- **Phase 1**: 5 minutes → August2025_classified ready
- **Phase 1.5**: 5 minutes → august_org_name_matches ready
  - Plus ~10 min for review if issues found
- **Phase 2**: 3 minutes → August2025_enriched ready
- **Phases 3-4**: 8 minutes → All analysis complete
- **Total**: 20-30 minutes to complete everything

---

## Ready to Execute?

Start with:
1. **AUGUST_2025_EXECUTION_GUIDE.md** (for step-by-step)
2. **PHASE_1_5_AGENCY_ANALYSIS.md** (to understand Phase 1.5)
3. Then run the SQL files in order

All files are in `/home/colin/map_viz/` 🚀
