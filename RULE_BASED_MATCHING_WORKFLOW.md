# Rule-Based Org Name Matching - User Workflow

**Objective:** Conservative, explainable matching with manual review capability

---

## Quick Start (5 Steps)

### Step 1: Create Tables & Synonyms
```sql
-- Create all reference tables and populate synonyms
bq query --use_legacy_sql=false --project_id=durango-deflock \
  < sql/23_create_disambiguation_tables.sql
```

### Step 2: Identify Org Name Clusters
```sql
-- Find all clusters of similar org_names (e.g., "Houston PD", "Houston SO")
bq query --use_legacy_sql=false --project_id=durango-deflock \
  "CALL \`durango-deflock.FlockML.sp_identify_org_name_clusters\`();"

-- Review the clusters
bq query --use_legacy_sql=false --project_id=durango-deflock \
  "SELECT * FROM \`durango-deflock.FlockML.org_name_disambiguation\`
   WHERE status = 'pending'
   ORDER BY org_types DESC
   LIMIT 20;"
```

### Step 3: Run Rule-Based Matching (Exact + Synonyms Only)
```sql
-- Execute matching with exact + synonym rules
bq query --use_legacy_sql=false --project_id=durango-deflock \
  "CALL \`durango-deflock.FlockML.sp_rule_based_org_name_matching\`();"
```

### Step 4: Review Results
```sql
-- See summary of matches
bq query --use_legacy_sql=false --project_id=durango-deflock \
  "SELECT
     match_type,
     COUNT(*) as count,
     ROUND(AVG(confidence), 3) as avg_confidence
   FROM \`durango-deflock.FlockML.org_name_rule_based_matches\`
   GROUP BY match_type
   ORDER BY avg_confidence DESC;"
```

### Step 5: Create Enriched View
```sql
-- Join matches with original classified data
bq query --use_legacy_sql=false --project_id=durango-deflock \
  < sql/26_create_rule_based_enriched_view.sql
```

---

## Detailed Workflow

### Phase 1: Identify Ambiguous Org Names

**Disambiguation Table:** `org_name_disambiguation`

```sql
SELECT
  disambiguation_id,
  location_cluster,
  org_names,
  org_types,
  state_code,
  potential_matches,
  status
FROM `durango-deflock.FlockML.org_name_disambiguation`
WHERE status = 'pending'
LIMIT 10;
```

**Example Output:**

| location_cluster | org_names | org_types | potential_matches |
|---|---|---|---|
| Houston | ["Houston TX PD", "Houston TX SO"] | ["PD", "SO"] | [{name: "Houston Police Department", state: "TX"}, {name: "Houston Sheriff's Office", state: "TX"}] |
| Seminole County | ["Seminole County FL SO", "Seminole County FL PD"] | ["SO", "PD"] | [{name: "Seminole County Sheriff's Office", state: "FL"}] |

### Phase 2: Manual Review & Assignment

For each cluster, you can:

**Option A: Accept Suggestion**
```sql
UPDATE `durango-deflock.FlockML.org_name_disambiguation`
SET
  manual_selection = STRUCT(
    'Houston Police Department' AS selected_agency,
    'Houston TX PD' AS selected_org_name,
    CURRENT_TIMESTAMP() AS assignment_date,
    'john.doe@example.com' AS assigned_by
  ),
  status = 'assigned'
WHERE disambiguation_id = 'cluster_123';
```

**Option B: Add Manual Match**
```sql
INSERT INTO `durango-deflock.FlockML.manual_org_name_matches`
VALUES (
  'Houston TX PD',
  'Houston Police Department',
  'TX',
  'PD',
  'disambiguation',
  0.95,
  CURRENT_TIMESTAMP(),
  'john.doe@example.com',
  'Manually verified - confirmed match'
);
```

**Option C: Reject (No Participating Agency)**
```sql
INSERT INTO `durango-deflock.FlockML.manual_org_name_matches`
VALUES (
  'Some Unknown PD',
  NULL,
  NULL,
  NULL,
  'rejected',
  0.0,
  CURRENT_TIMESTAMP(),
  'john.doe@example.com',
  'No matching participating agency found'
);

UPDATE `durango-deflock.FlockML.org_name_disambiguation`
SET status = 'rejected'
WHERE disambiguation_id = 'cluster_456';
```

### Phase 3: Automatic Matching (Exact + Synonyms)

**Exact Matches (Confidence 1.0)**
```
org_name: "Houston TX PD"
participating: "Houston Police Department"
Result: MATCH (1.0)
Reason: Exact location + state + type match
```

**Synonym Matches (Confidence 0.95)**
```
org_name: "Seminole County FL SO"
participating: "Seminole County Sheriff's Office"
Synonym mapping: SO → ["Sheriff's Office", "Sheriff", "SO"]
Result: MATCH (0.95)
Reason: Location + state + type synonym match
```

**No Match (Confidence 0.0)**
```
org_name: "Unknown Agency TX"
Result: NO MATCH (0.0)
Reason: No participating agency found
```

---

## Reference Tables

### Agency Type Synonyms

| Type | Synonyms |
|------|----------|
| PD | Police Department, Police, PD |
| SO | Sheriff's Office, Sheriff Office, Sheriff, SO |
| HSP | Highway Patrol, State Patrol, Patrol, HSP |
| SPD | Police Department, Police, SPD |
| DA | Department, Division, DA |
| SD | Sheriff Division, Sheriff Department, SD |
| MPD | Police Department, Police, MPD |

### Location Stop Words

| Word | Keep in Match | Notes |
|------|---|---|
| County | YES | Essential for county-level agencies |
| City | NO | Can be omitted |
| Department | NO | Implied by type |
| Division | NO | Implied by type |
| Bureau | NO | Implied by type |

---

## Query Examples

### View All Matches by Type

```sql
SELECT
  match_type,
  COUNT(*) as count,
  COUNT(DISTINCT org_name) as unique_orgs,
  ROUND(AVG(confidence), 3) as avg_confidence
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
GROUP BY match_type
ORDER BY count DESC;
```

### Find Unmatched Org Names

```sql
SELECT
  org_name,
  COUNT(*) as search_count
FROM `durango-deflock.DurangoPD.October2025_enriched_rule_based`
WHERE is_participating_agency = FALSE
GROUP BY org_name
ORDER BY search_count DESC
LIMIT 20;
```

### View Searches by Participating Agency (Rule-Based)

```sql
SELECT
  matched_agency,
  matched_state,
  COUNT(*) as search_count,
  ROUND(AVG(match_confidence), 3) as avg_confidence
FROM `durango-deflock.DurangoPD.October2025_enriched_rule_based`
WHERE is_participating_agency = TRUE
GROUP BY matched_agency, matched_state
ORDER BY search_count DESC;
```

### Compare Matching Results

```sql
-- Compare semantic vs rule-based matching
SELECT
  'Semantic' as method,
  COUNT(DISTINCT org_name) as matched_org_names,
  COUNT(*) as matched_searches,
  ROUND(AVG(match_confidence), 3) as avg_confidence
FROM `durango-deflock.DurangoPD.October2025_enriched`
WHERE is_participating_agency = TRUE

UNION ALL

SELECT
  'Rule-Based' as method,
  COUNT(DISTINCT org_name),
  COUNT(*),
  ROUND(AVG(match_confidence), 3)
FROM `durango-deflock.DurangoPD.October2025_enriched_rule_based`
WHERE is_participating_agency = TRUE;
```

---

## Data Structures

### org_name_disambiguation (For Manual Review)

| Column | Type | Purpose |
|--------|------|---------|
| disambiguation_id | STRING | Unique cluster ID |
| location_cluster | STRING | Normalized location (e.g., "Houston") |
| org_names | ARRAY<STRING> | All similar org_names in cluster |
| org_types | ARRAY<STRING> | Agency types in cluster |
| state_code | STRING | State code |
| potential_matches | ARRAY<STRUCT> | Suggested participating agencies |
| manual_selection | STRUCT | User's manual assignment |
| notes | STRING | User notes |
| status | STRING | pending, reviewed, assigned, rejected |

### manual_org_name_matches (Final Assignments)

| Column | Type | Purpose |
|--------|------|---------|
| org_name | STRING | Original org_name |
| matched_agency | STRING | Final matching agency |
| matched_state | STRING | Agency state |
| matched_type | STRING | Agency type |
| match_type | STRING | exact, synonym, disambiguation, rejected |
| confidence | FLOAT64 | 1.0, 0.95, 0.85, or 0.0 |
| match_timestamp | TIMESTAMP | When assigned |
| assigned_by | STRING | Who made the assignment |
| notes | STRING | Assignment reason |

---

## Matching Levels Explained

| Level | Type | Confidence | Criteria | Example |
|-------|------|-----------|----------|---------|
| 1 | Exact | 1.0 | Location exact + State exact + Type exact | Houston TX PD → Houston Police Department |
| 2 | Synonym | 0.95 | Location exact + State exact + Type synonym | Seminole County FL SO → Seminole County Sheriff's Office (SO ∈ synonyms) |
| 3 | Manual | 0.85+ | User-verified after disambiguation review | User manually confirmed match |
| None | None | 0.0 | No participating agency found | Unknown Agency TX → (no match) |

---

## Tips & Best Practices

1. **Start with pending clusters:** Use `status = 'pending'` to find clusters needing review
2. **Batch updates:** Update multiple clusters at once with similar characteristics
3. **Document your decisions:** Add notes to explain why you accepted/rejected matches
4. **Cross-check states:** Always verify state codes match - this prevents city/county confusion
5. **Use arrays for suggestions:** The potential_matches array gives you options to choose from
6. **Validate synonyms:** Check that type synonyms are correct for your domain before running

---

## Troubleshooting

**Issue: Too many unmatched org_names**
- Add more synonyms to `agency_type_synonyms` table
- Review disambiguation clusters for common patterns
- Check if participating agencies table is complete

**Issue: False matches appearing**
- The synonym list may be too broad
- Add rejected matches to `manual_org_name_matches` with match_type='rejected'
- Stricter validation can be added to rule_based matching procedure

**Issue: City/County confusion**
- Ensure participating agencies table has correct TYPE values
- Add manual matches with correct city/county distinction
- Review inferred_location_type logic in parsing

---

## Next Steps

1. ✅ Run steps 1-5 above
2. ✅ Review preliminary matches
3. ✅ Manually review and assign disambiguation clusters
4. ✅ Add any special cases to manual_org_name_matches
5. ✅ Re-run matching procedure after manual assignments
6. ✅ Compare rule-based results vs semantic approach

