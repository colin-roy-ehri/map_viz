# August 2025 Analysis - Execution Guide

## Quick Reference

5 SQL files, 5 phases, ~20-25 minutes to complete analysis

| Phase | File | Purpose | Output |
|-------|------|---------|--------|
| 1 | `28_classify_august_2025.sql` | Parse & categorize reasons | `August2025_classified` |
| **1.5** | **`29a_analyze_august_agencies.sql`** | **Identify new agencies & match** | **`august_org_name_matches`** |
| 2 | `29_match_august_agencies.sql` | Join with complete matches | `August2025_enriched` |
| 3 | `30_reason_participation_analysis.sql` | Analyze by reason category | 8 detailed analysis queries |
| 4 | `31_august_suspicion_ranking.sql` | Score risk & identify high-risk | `August2025_suspicion_ranking_analysis` view |

**⚠️ IMPORTANT**: Run Phase 1.5 BEFORE Phase 2. It creates the `august_org_name_matches` table needed for joining.

---

## Phase 1: Classification (5 min)

**File**: `/home/colin/map_viz/sql/28_classify_august_2025.sql`

**What it does**:
1. Reads raw August 2025 data
2. Parses reason field into:
   - `reason_bucket` (detailed): Homicide, Warrant, Theft, Invalid_Reason, Case_Number, no_reason, etc.
   - `reason_category` (grouped): Violent_Crime, Property_Crime, Drug_Crime, etc.
3. Creates `August2025_classified` table

**Expected Output**:
```
reason_bucket     | record_count | percentage | sample_reasons
──────────────────┼──────────────┼────────────┼────────────
Warrant           |   12,500     |   18.2%    | ['warrant', 'wanted', 'a&d']
Stolen_Vehicle    |   9,800      |   14.2%    | ['stolen', 'mv', 'auto']
no_reason         |   8,200      |   11.9%    | [NULL]
... (more rows)
```

**Run in BigQuery Console**:
```
Copy entire content of 28_classify_august_2025.sql → Paste → RUN
```

---

## Phase 1.5: Analyze August Agencies (5 min) ⚠️ RUN BEFORE PHASE 2

**File**: `/home/colin/map_viz/sql/29a_analyze_august_agencies.sql`

**What it does**:
1. Extracts all unique org_names from August data
2. Compares to October matches to identify NEW agencies
3. Runs rule-based matching on new agencies only
4. Combines October + new August matches into single table
5. Provides 7 analysis queries to show coverage

**Why This Matters**:
- August will have agencies not in October
- We need to match these NEW agencies before joining with classified data
- Creates `august_org_name_matches` table needed by Phase 2

**Expected Output**:

**Analysis 1: Coverage Summary**
```
status                   | org_names | total_searches | pct_of_august
─────────────────────────┼───────────┼────────────────┼──────────────
NEW - Needs Matching     |    145    |    24,300      |   35.2%
Already Matched          |     98    |    43,900      |   64.8%
```

**Analysis 2: Top 50 New Agencies**
```
org_name              | search_count
──────────────────────┼──────────────
New Agency 1          |   2,100
New Agency 2          |   1,850
New Agency 3          |   1,650
... (47 more)
```

**Analysis 6: Results of Matching**
```
match_type | org_name_count | unique_agencies_matched | pct_of_new
───────────┼────────────────┼────────────────────────┼───────────
synonym    |      95        |        92               |   65.5%
none       |      50        |        0                |   34.5%
```

**Analysis 7: Newly Matched Agencies**
Shows which specific new August agencies found participating agency matches

**Final Verification**:
```
Total August Searches:           68,400
Unique August Org_Names:           243
Org_Names Already Matched (Oct):    98
Org_Names Newly Matched (Aug):      95
Total Matched Org_Names:           193
Unmatched Org_Names:                50
```

**Run in BigQuery Console**:
```
Copy entire content of 29a_analyze_august_agencies.sql → Paste → RUN
This creates: august_unique_org_names, august_new_org_names, august_new_org_matches, august_org_name_matches
```

---

## Phase 2: Matching (3 min)

**File**: `/home/colin/map_viz/sql/29_match_august_agencies.sql`

**What it does**:
1. Joins August data with Oct 2025 rule-based matches
2. Adds `is_participating_agency` flag for each search
3. Creates `August2025_enriched` table with participation status
4. Includes 3 verification queries

**Expected Output Tables**:

**Verification Query 1: Overall Summary**
```
agency_status        | search_count | pct_of_searches | pct_without_case_num
─────────────────────┼──────────────┼─────────────────┼──────────────
Participating        |     5,400    |      7.8%       |      22.1%
Non-Participating    |    63,000    |     92.2%       |      18.5%
```

**Verification Query 2: Top Agencies**
```
org_name           | matched_agency              | agency_status     | searches
───────────────────┼─────────────────────────────┼───────────────────┼──────────
Seminole County FL SO | Seminole County SO      | Participating     |  1,250
Miami-Dade FL SO   | Miami-Dade Sheriff's Office | Participating     |  980
Houston TX PD      | (unmatched)                 | Non-Participating |  850
```

**Run in BigQuery Console**:
```
Copy entire content of 29_match_august_agencies.sql → Paste → RUN
Note: This will execute the table creation + 3 verification queries
```

---

## Phase 3: Reason Analysis (5 min)

**File**: `/home/colin/map_viz/sql/30_reason_participation_analysis.sql`

**What it does**:
Creates 8 different analysis queries showing:
1. **Participation by reason category** (high-level)
2. **Participation by reason bucket** (detailed)
3. **Reasonless searches** (no reason, invalid reason, case # only)
4. **Valid vs invalid breakdown**
5. **Cross-tabulation** (reason × participation)
6. **Case number presence** (data quality)
7. **High-risk searches** (participating + no reason + no case)
8. **Summary table for export** (CSV-ready)

**Key Metrics Generated**:

**Query 1: Participation by Reason**
```
reason_category      | total | participating | pct
─────────────────────┼───────┼───────────────┼──────
Warrant              | 12500 | 2,100         | 16.8%
Property_Crime       | 9,800 | 450           | 4.6%
Interagency          | 8,200 | 1,500         | 18.3%
Violent_Crime        | 8,100 | 850           | 10.5%
```

**Query 3: Reasonless Searches (HIGH RISK)**
```
reason_quality              | search_count | participating | pct_no_case
────────────────────────────┼──────────────┼───────────────┼──────────
No Reason Provided (NULL)   |   5,200      |     890       | 78.2%
Invalid Reason              |   2,800      |     420       | 65.1%
Case Number Only            |   1,100      |     280       | 91.8%
Unknown/OTHER               |   900        |     150       | 55.3%
```

**Query 4: Valid vs Invalid**
```
reason_validity      | count  | participating | pct
─────────────────────┼────────┼───────────────┼─────
Valid Reason         | 55,000 | 3,100         | 5.6%
No/Invalid Reason    | 13,100 | 2,300         | 17.6%  ← HIGH RISK
```

**Run Each Query**:
```
-- Copy one query at a time from 30_reason_participation_analysis.sql
-- Each query is labeled ANALYSIS 1, ANALYSIS 2, etc.
-- Run in sequence to build up understanding
```

---

## Phase 4: Suspicion Ranking (3 min)

**File**: `/home/colin/map_viz/sql/31_august_suspicion_ranking.sql`

**What it does**:
1. Creates view with suspicion scores (0-100)
2. Scores based on:
   - Participating agency: +40
   - No case number: +30
   - Interagency reason: +20
   - Invalid reason: +10
3. Categorizes: No/Low/Moderate/High/Very High Suspicion
4. Provides 6 detailed analysis queries

**Suspicion Categories**:
- **No Suspicion** (0 points): Legitimate searches by non-participating agencies
- **Low Suspicion** (1-30 points): Minor risk factors
- **Moderate Suspicion** (31-60 points): Multiple risk factors or major single factor
- **High Suspicion** (61-99 points): Combined high-risk factors
- **Very High Suspicion** (100 points): Maximum risk - participating + no case + invalid reason + interagency

**Expected Output**:

**Query 1: Executive Summary**
```
Total Searches:                    68,400
Participating Agency Searches:     5,400 (7.9%)
Zero Suspicion Searches:          45,200 (66.1%)
Low Suspicion:                     8,900 (13.0%)
Moderate Suspicion:                7,200 (10.5%)
High Suspicion:                    4,800 (7.0%)
Very High Suspicion:               1,300 (1.9%)
Total High Risk (>=60):            6,100 (8.9%)
```

**Query 2: Suspicion Distribution**
```
risk_level           | search_count | avg_score | pct
─────────────────────┼──────────────┼───────────┼──────
No Suspicion         |   45,200     |   0.0     | 66.1%
Low Suspicion        |    8,900     |  18.5     | 13.0%
Moderate Suspicion   |    7,200     |  47.3     | 10.5%
High Suspicion       |    4,800     |  78.2     | 7.0%
Very High Suspicion  |    1,300     |  100.0    | 1.9%
```

**Query 5: Worst Case (Participating + No Case + Invalid Reason)**
```
org_name         | matched_agency           | reason_bucket | case_num | suspicion_score
─────────────────┼──────────────────────────┼───────────────┼──────────┼─────────────────
Seminole County  | Seminole County SO       | no_reason     | [null]   | 100
Miami-Dade FL    | Miami-Dade SO            | Invalid_Reas  | [null]   | 100
Jacksonville     | Jacksonville SO          | Case_Number   | [null]   | 100
```

**Run the View + All Queries**:
```
Copy entire content of 31_august_suspicion_ranking.sql → Paste → RUN
This creates the view + executes all 6 queries at once
```

---

## Complete Data Export Script

After running all phases, export all results:

```sql
-- Export each analysis as CSV

-- 1. Overall Summary
SELECT * FROM `durango-deflock.DurangoPD.August2025_suspicion_ranking_analysis`
LIMIT 1  -- Will show summary stats

-- 2. Reason Participation (from Phase 3, Query 1)
-- (Copy and run Analysis 1 query from 30_reason_participation_analysis.sql)

-- 3. High Risk Searches (from Phase 4, Query 5)
-- (Copy and run Query 5 from 31_august_suspicion_ranking.sql)

-- 4. Agency Risk Profile (from Phase 4, Query 6)
-- (Copy and run Query 6 from 31_august_suspicion_ranking.sql)
```

**To Export to CSV**:
1. Run query in BigQuery
2. Click "Save Results" → "CSV" (or use EXPORT DATA statement)
3. Save to: `/home/colin/map_viz/data/august2025_[name].csv`

---

## Expected Findings Summary

Based on October analysis pattern, expect:

| Metric | October | August (Estimate) |
|--------|---------|-------------------|
| Total Searches | 70,842 | 65,000-75,000 |
| Participating % | 9.5% | 8-12% |
| With Valid Reason | ~85% | ~85% |
| Reasonless | ~15% | ~15% |
| High Risk (Score ≥60) | Unknown* | 8-12% |
| Highest Risk: Participating + No Case + No Reason | ? | 1-2% |

*Haven't run suspicion scoring on October yet

---

## Step-by-Step Execution Checklist

- [ ] Phase 1: Run 28_classify_august_2025.sql
  - [ ] Verify table created: `August2025_classified`
  - [ ] Check verification query output (reason distribution)

- [ ] **Phase 1.5: Run 29a_analyze_august_agencies.sql** ⚠️ MUST RUN FIRST
  - [ ] Verify table created: `august_unique_org_names`
  - [ ] Verify table created: `august_new_org_names`
  - [ ] Verify table created: `august_new_org_matches`
  - [ ] Verify table created: `august_org_name_matches` (this is critical for Phase 2)
  - [ ] Check Analysis 1: Coverage summary
  - [ ] Check Analysis 6: Results of matching new agencies
  - [ ] Check Final Verification counts

- [ ] Phase 2: Run 29_match_august_agencies.sql
  - [ ] Verify table created: `August2025_enriched`
  - [ ] Check participation rate (~9.5% expected)
  - [ ] Identify top agencies

- [ ] Phase 3: Run each query from 30_reason_participation_analysis.sql
  - [ ] ANALYSIS 1: Participation by reason category
  - [ ] ANALYSIS 2: Participation by reason bucket
  - [ ] ANALYSIS 3: Reasonless searches
  - [ ] ANALYSIS 4: Valid vs Invalid
  - [ ] ANALYSIS 5: Cross-tabulation
  - [ ] ANALYSIS 6: Case numbers by agency type
  - [ ] ANALYSIS 7: High-risk (participating + no reason)
  - [ ] ANALYSIS 8: Export-ready summary

- [ ] Phase 4: Run 31_august_suspicion_ranking.sql
  - [ ] View created: `August2025_suspicion_ranking_analysis`
  - [ ] Query 1: Executive summary
  - [ ] Query 2: Suspicion distribution
  - [ ] Query 3: Risk factors
  - [ ] Query 4: High-risk searches
  - [ ] Query 5: Very high risk (participating + no case + invalid)
  - [ ] Query 6: Agency risk profiles

- [ ] Export Results
  - [ ] Save all analysis outputs to CSV
  - [ ] Compare August vs October metrics
  - [ ] Identify trends or differences

---

## Troubleshooting

**Table not found error**:
- Make sure Phase 1 completed successfully
- Check table name is exactly: `August2025_classified`

**Join returning no results**:
- Some August org_names may not match October data
- This is expected - different months have different agencies
- Consider running matching on August-only org_names if needed

**Query timeout**:
- Break into smaller queries (filter by reason_category)
- Add WHERE clauses to limit scope
- Run verification queries instead of full analysis

**Suspicion scores all zero**:
- This means all searches are non-participating with valid reasons
- This is actually a GOOD sign (low risk)
- High numbers would indicate risk

---

## Next Steps After Analysis

1. **Document Findings**: Create summary report comparing August to October
2. **Identify Trends**: Are participation rates changing? Reason categories?
3. **Flag High-Risk**: Save list of searches with suspicion score ≥80
4. **Policy Review**: Use data to inform access control decisions
5. **Comparative Analysis**: Are certain agencies or reasons more suspicious?

---

## Questions?

Refer back to:
- **AUGUST_2025_ANALYSIS_QUERIES.md** - Overview of all analyses
- **PARTICIPATING_AGENCY_ANALYSIS.md** - October baseline for comparison
- **Individual SQL files** - Detailed comments explain each query
