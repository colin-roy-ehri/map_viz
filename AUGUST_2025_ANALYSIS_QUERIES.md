# August 2025 Analysis Query Suite

## Overview

This document outlines the queries and analysis for the August 2025 police search dataset, including:
- Organization name parsing and matching to participating agencies
- Reason categorization (crime types, status codes, invalid/missing)
- Participation rate analysis by reason category
- Suspicion ranking and risk assessment

## Datasets Used

- **Source**: `durango-deflock.DurangoPD.August2025`
- **Reference**: `durango-deflock.FlockML.org_name_rule_based_matches` (populated from October analysis)
- **Participating Agencies**: `durango-deflock.FlockML.participatingAgencies`

## Query Execution Order

### Phase 1: Data Classification & Categorization

**File**: `28_classify_august_2025.sql`
- Parse org_names from August dataset
- Categorize reasons into buckets (Crime, Status, Invalid, Interagency, Training, etc.)
- Create classified view for analysis

**Output Table**: `August2025_classified`

### Phase 2: Participation Matching

**File**: `29_match_august_agencies.sql`
- Join August classified data with rule-based matches
- Flag participating vs non-participating agencies
- Create enriched view with participation status

**Output Table**: `August2025_enriched`

### Phase 3: Analysis by Reason

**File**: `30_reason_participation_analysis.sql`
- Break down searches by reason category
- Calculate participation rates within each category
- Show percent of searches with valid reasons
- Identify reasonless searches

**Output**: Multiple analysis views and result sets

### Phase 4: Suspicion Ranking

**File**: `31_august_suspicion_ranking.sql`
- Apply suspicion scoring (same algorithm as October)
- Identify high-risk search patterns
- Create risk factor breakdowns

**Output View**: `August2025_suspicion_ranking_analysis`

---

## Key Metrics to Generate

### 1. Overall Participation Summary
```
Total Searches: [count]
Participating Agency Searches: [count] ([pct]%)
Non-Participating/Other: [count] ([pct]%)
Unique Agencies: [count]
```

### 2. Participation by Reason Category

| Reason Category | Total Searches | Participating | Non-Participating | Participation % |
|---|---|---|---|---|
| Homicide | X | Y | Z | Y% |
| Warrant | X | Y | Z | Y% |
| Stolen Vehicle | X | Y | Z | Y% |
| ... | X | Y | Z | Y% |
| **No Reason/Invalid** | X | Y | Z | Y% |
| **TOTAL** | X | Y | Z | Y% |

### 3. Reasonless Searches Breakdown

```
Valid Reason Provided: [count] ([pct]%)
No Reason (NULL): [count] ([pct]%)
Invalid Reason: [count] ([pct]%)
Unknown/OTHER: [count] ([pct]%)
```

### 4. Participation Rate by Reason Quality

```
Legitimate Reason + Valid Case #: [pct]%
Legitimate Reason + No Case #: [pct]%
Questionable Reason + Valid Case #: [pct]%
Questionable Reason + No Case #: [pct]%
No Reason + No Case #: [pct]% ← High Risk
```

---

## Reason Categories Used

### Valid Crime Categories
- **Violent Crimes**: Homicide, Murder, Shooting, Assault, Rape, Robbery
- **Property Crimes**: Theft, Burglary, Auto Theft, Hit_And_Run, Arson
- **Crimes Against Persons**: Assault, Domestic_Violence, Stalking, Kidnapping
- **Drug/Weapon Crimes**: Drugs, Weapons_Offense, Smuggling
- **Investigation/Enforcement**: Warrant, Fugitive, Missing_Person, Evasion_Pursuit
- **Special Categories**: Amber_Alert, Sex_Crime, Human_Trafficking, Interdiction

### Ambiguous/Invalid Categories
- **No Reason**: NULL or empty reason field
- **Case Number Only**: Reason is just a number (e.g., "25", "24-12345")
- **Invalid Reason**: Keyboard smash, single letters, generic/meaningless text
- **OTHER**: Anything not fitting established patterns

### Status/Operational Categories
- **Interagency**: AOA (Assist Other Agencies) - cross-agency coordination
- **Training/Test**: Training exercises, testing system
- **Tip**: Anonymous or informant tips
- **Welfare Check**: Welfare checks, missing person inquiries
- **Attempt To Locate**: ATL/BOLO (Be On Lookout)

---

## Analysis Outputs (Saved as Files)

### Summary Reports
1. **august_2025_overall_summary.csv**
   - High-level statistics
   - Participation rates
   - Reason distribution

2. **august_2025_reason_breakdown.csv**
   - Detailed breakdown by reason category
   - Participation percentages
   - Search counts

3. **august_2025_reasonless_analysis.csv**
   - Searches with no valid reason
   - Those without case numbers
   - Geographic/agency patterns

4. **august_2025_suspicion_ranking.csv**
   - Scores and risk factors
   - High-risk searches
   - Agency-level risk profiles

### Accessory Analyses
5. **august_2025_top_agencies.csv**
   - Agency search volumes
   - Participation status
   - Reason pattern by agency

6. **august_2025_participation_by_state.csv**
   - Geographic distribution
   - Which states have participating agencies
   - Where access is non-participating

---

## Comparison to October 2025

Once all analyses are complete, comparative report will show:
- Difference in participation rates (October 9.5% vs August X%)
- Changes in reason categories
- Trends in reasonless searches
- Risk factor evolution

---

## Recommended Next Steps

1. **Execute Phase 1-4 queries in sequence** (see execution order above)
2. **Export analysis results to CSVs** for stakeholder review
3. **Compare August vs October metrics** for trend analysis
4. **Investigate outliers** - if participation rate differs significantly
5. **Manual validation** - spot-check high-risk searches
6. **Policy implications** - use data to inform access control decisions

---

## Query Templates Provided

All queries include:
- ✅ Comprehensive comments explaining logic
- ✅ Error handling for missing/NULL values
- ✅ Percentage calculations (both total and within categories)
- ✅ Aggregations by multiple dimensions
- ✅ Export-ready formatting (can save to CSV)

---

## Expected Dimensions

| Metric | October (Known) | August (Expected) |
|---|---|---|
| Total Searches | 70,842 | ~ 60,000-80,000 |
| Participating % | 9.5% | ~ 8-12% |
| With Valid Reason | ~85% | ~ 85% |
| Reasonless | ~15% | ~ 15% |
| High Risk (Suspicion ≥60) | ? | ? |

---

## Notes

- All queries reference the **rule-based matching results** from October (the corrected 0.95 confidence matches)
- If August agency names differ significantly from October, re-run matching on August-only org_names
- Reason categorization logic is identical to October for consistency
- All views are READ-ONLY (no data modification)
