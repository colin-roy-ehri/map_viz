# Agency Matching Redesign - Rule-Based Approach

**Problem with Current System:**
- Fuzzy semantic matching is too permissive
- 59 matches seems reasonable, BUT Houston dominates (67.76%)
- Many false positives where similar-sounding agencies are matched incorrectly
- No distinction between city-level vs county-level agencies

**New Approach:** Rule-based matching with controlled synonyms and strict validation

---

## Architecture Overview

### Phase 1: Parse Org Names
Extract structure from abbreviated org_names like: `"Houston TX PD"`, `"Seminole County FL SO"`

**Pattern:** `[Location Name] [State Code] [Agency Type Abbrev]`

Extract:
- Location: "Houston", "Seminole County"
- State: "TX", "FL"
- Type: "PD", "SO", "HSO", "SPD", etc.

### Phase 2: Create Synonym Mappings
Build controlled synonym sets for matching:

```
Type Synonyms:
  PD → ["Police Department", "Police", "PD"]
  SO → ["Sheriff's Office", "Sheriff Office", "SO"]
  HSO → ["Highway Patrol", "State Patrol", "HSO"]
  SPD → ["Police Department", "Police", "SPD"]

City/County Indicators:
  County: ["County", "County Sheriff", "County Police"]
  City: ["Police Department", "Police", "City Police", "City PD"]
```

### Phase 3: Distinguish City vs County
Parse location to determine level:
- If org_name contains "County" → County-level agency
- If org_name is city name alone → City-level agency
- Match participating agencies accordingly

### Phase 4: Match with Increasing Specificity

**Level 1: Exact Match (Highest Confidence)**
```
org_name:              "Houston TX PD"
participating_agency: "Houston Police Department"
                      (exact location + exact state + exact type match)
Confidence: 1.0 ✅
```

**Level 2: Synonym Match (High Confidence)**
```
org_name:              "Houston TX PD"
participating_agency: "Houston Police Department"
                      (exact location + exact state + synonym type match)
                      PD → Police Department
Confidence: 0.95 ✅✅
```

**Level 3: Fuzzy Synonym Match (Medium-High Confidence)**
```
org_name:              "Houston PD"  (missing state)
participating_agency: "Houston Police Department"
                      (exact location + synonym type + no state to verify)
Confidence: 0.85 ⚠️
Only match if unique within state? Or require state?
```

**Level 4: Permutation Match (Lower Confidence - Skip Initially)**
```
org_name:              "Hous TX PD"  (misspelled)
participating_agency: "Houston Police Department"
                      (fuzzy location + exact state + synonym type)
Confidence: 0.70 ✗
SKIP - Too risky
```

---

## Detailed Algorithm

### Step 1: Parse Org Name

Input: `"Seminole County FL SO"`

```
Parse Components:
1. Extract state code (last 2 chars or pattern): "FL"
2. Extract agency type (last token): "SO"
3. Extract location (everything else): "Seminole County"

Output:
{
  location: "Seminole County",
  state: "FL",
  type: "SO",
  location_type: "County"  // inferred from "County" in location
}
```

### Step 2: Normalize Location

Input: `"Seminole County"`

```
Normalization:
1. Remove stop words carefully: Keep "County"
2. Trim whitespace
3. Standardize case: Title Case
4. Remove special characters: -, ', etc.

Variations to Generate:
- "Seminole County"
- "Seminole"  (remove County)
- "Seminole Cty"  (abbreviate)
```

### Step 3: Create Type Variations

Input: `"SO"`

```
Type Synonyms:
  SO → [
    "Sheriff's Office",
    "Sheriff Office",
    "Sheriff",
    "SO"
  ]
```

### Step 4: Search Participating Agencies

For each org_name, search participating agencies with **Exact Then Fuzzy** strategy:

```sql
-- Exact Match (Level 1)
SELECT * FROM participating_agencies
WHERE
  LAW_ENFORCEMENT_AGENCY = "Seminole County Sheriff's Office"
  AND STATE = "FL"

-- Synonym Match (Level 2)
SELECT * FROM participating_agencies
WHERE
  LAW_ENFORCEMENT_AGENCY IN (
    "Seminole County Sheriff's Office",
    "Seminole County Sheriff Office",
    "Seminole County Sheriff"
  )
  AND STATE = "FL"

-- Location + Type Match (Level 3)
SELECT * FROM participating_agencies
WHERE
  (LAW_ENFORCEMENT_AGENCY LIKE "Seminole County%"
   OR LAW_ENFORCEMENT_AGENCY LIKE "Seminole%")
  AND STATE = "FL"
  AND (LAW_ENFORCEMENT_AGENCY LIKE "%Sheriff%")
```

### Step 5: City vs County Validation

**Critical:** Prevent false matches between city and county agencies

```
org_name: "Seminole FL SO"
     → location_type: "County"

participating_agency_1: "Seminole County Sheriff's Office"
     → TYPE: "County"
     MATCH: ✅

participating_agency_2: "Seminole Police Department"  (city-level)
     → TYPE: "City"
     MATCH: ✗ (City/County mismatch)
```

---

## Implementation Structure

### New SQL Files Needed

**`sql/23_parse_org_names.sql`**
- Parse org_names into components
- Create lookup table: `org_name_parsed`
  - Columns: org_name, location, state, type, location_type

**`sql/24_create_agency_synonym_mappings.sql`**
- Create synonym tables
- `agency_type_synonyms`: PD → ["Police", "Police Department"]
- `location_variations`: "Seminole County" → ["Seminole", "Seminole Cty"]

**`sql/25_rule_based_matching.sql`**
- Implement multi-level matching algorithm
- Return: org_name, matched_agency, match_level, confidence

**`sql/26_validate_city_county_matches.sql`**
- Filter out city/county mismatches
- Apply location_type validation

**`sql/27_create_rule_based_enriched_view.sql`**
- Create new enriched view with rule-based matches

---

## Matching Levels & Confidence Scores

| Level | Match Type | Confidence | Criteria |
|-------|-----------|-----------|----------|
| 1 | Exact | 1.0 | Location exact + State exact + Type exact |
| 2 | Synonym | 0.95 | Location exact + State exact + Type synonym |
| 3 | Fuzzy | 0.85 | Location fuzzy + State exact + Type synonym |
| 4 | Partial | 0.70 | Location partial + State present + Type synonym |
| 5 | None | 0.0 | No match |

**Initial Strategy:** Only accept Levels 1 and 2 (confidence ≥ 0.95)

---

## Synonym Mappings

### Agency Type Synonyms

```
PD (Police Department):
  → "Police Department"
  → "Police"
  → "PD"

SO (Sheriff's Office):
  → "Sheriff's Office"
  → "Sheriff Office"
  → "Sheriff"
  → "SO"

HSP (Highway Patrol/State Patrol):
  → "Highway Patrol"
  → "State Patrol"
  → "Patrol"

DA (District Attorney / Division):
  → "Division"
  → "Department"

SPD (Special Police Department):
  → "Police Department"
  → "Police"
```

### Location Stop Words to Remove

```
Removable:
  - "County"
  - "City"
  - "Department"
  - "Division"
  - "Bureau"

Replaceable Abbreviations:
  - "Cty" ↔ "County"
  - "Dept" ↔ "Department"
  - "Div" ↔ "Division"
```

---

## Algorithm Pseudocode

```python
def match_org_names_rule_based(org_names, participating_agencies):
    matches = []

    for org_name in org_names:
        # Step 1: Parse org_name
        parsed = parse_org_name(org_name)
        location = parsed['location']
        state = parsed['state']
        org_type = parsed['type']
        location_type = parsed['location_type']

        # Step 2: Create variations
        location_variations = create_location_variations(location)
        type_synonyms = get_type_synonyms(org_type)

        # Step 3: Search for matches (Level 1 & 2)
        best_match = None
        best_confidence = 0

        for agency in participating_agencies:
            # Exact Match (Level 1)
            if (location == extract_location(agency['name'])
                and state == agency['state']
                and agency['name'].endswith(agency_type_match(org_type))):
                match = {
                    'org_name': org_name,
                    'matched_agency': agency['name'],
                    'state': agency['state'],
                    'confidence': 1.0,
                    'level': 1
                }
                best_match = match
                best_confidence = 1.0
                break

            # Synonym Match (Level 2)
            if (location == extract_location(agency['name'])
                and state == agency['state']
                and any(syn in agency['name'] for syn in type_synonyms)):
                if 0.95 > best_confidence:
                    best_match = {
                        'org_name': org_name,
                        'matched_agency': agency['name'],
                        'state': agency['state'],
                        'confidence': 0.95,
                        'level': 2
                    }
                    best_confidence = 0.95

        # Step 4: City/County Validation
        if best_match:
            agency_location_type = infer_location_type(best_match['matched_agency'])
            if location_type == agency_location_type:
                matches.append(best_match)
            else:
                # Mismatch: Skip or flag
                matches.append({
                    'org_name': org_name,
                    'matched_agency': None,
                    'reason': f'City/County mismatch: {location_type} vs {agency_location_type}',
                    'confidence': 0.0
                })

    return matches
```

---

## Expected Results with Conservative Approach

| Metric | Current (Semantic) | Expected (Rule-Based) | Improvement |
|--------|---|---|---|
| Total Matches | 59 | ~40-50 | Fewer, higher-quality |
| Avg Confidence | 0.973 | 0.98+ | More confident |
| False Positives | ~5-10% | <1% | Much fewer |
| Houston Dominance | 67.76% | ? | Needs validation |
| Matched Searches | 16,597 | ? | Fewer but more accurate |

---

## Validation Plan

### Test Cases

**Test 1: Exact Match**
```
org_name: "Houston TX PD"
participating: "Houston Police Department"
state_match: TX = TX ✅
location_match: Houston = Houston ✅
type_match: PD = Police Department ✅
RESULT: Match (confidence 1.0)
```

**Test 2: Synonym Match**
```
org_name: "Seminole County FL SO"
participating: "Seminole County Sheriff's Office"
state_match: FL = FL ✅
location_match: Seminole County = Seminole County ✅
type_match: SO ∈ [Sheriff's Office, Sheriff Office, Sheriff, SO] ✅
RESULT: Match (confidence 0.95)
```

**Test 3: City/County Mismatch (Reject)**
```
org_name: "Seminole FL SO"  (inferred as County)
participating: "Seminole Police Department"  (City-level)
location_type_match: County ≠ City ✗
RESULT: No Match
```

**Test 4: Different State (Reject)**
```
org_name: "Houston TX PD"
participating: "Houston Police Department"  (state: CA)
state_match: TX ≠ CA ✗
RESULT: No Match
```

**Test 5: Different Agency Type (Reject)**
```
org_name: "Miami FL PD"  (Police)
participating: "Miami-Dade Sheriff's Office"  (Sheriff)
type_match: PD ≠ SO ✗
RESULT: No Match
```

---

## Implementation Roadmap

### Phase 1: Data Preparation
- [ ] Parse all org_names (sql/23)
- [ ] Create synonym mappings (sql/24)
- [ ] Generate location variations

### Phase 2: Matching Algorithm
- [ ] Implement rule-based matching (sql/25)
- [ ] Add city/county validation (sql/26)
- [ ] Generate match confidence scores

### Phase 3: Validation
- [ ] Manual review of top 50 matches
- [ ] Verify zero city/county mismatches
- [ ] Compare against participating agencies list

### Phase 4: Integration
- [ ] Create enriched view (sql/27)
- [ ] Update documentation
- [ ] Deploy and test

---

## Key Differences from Semantic Approach

| Aspect | Semantic (Current) | Rule-Based (Proposed) |
|--------|---|---|
| **Method** | ML embeddings + cosine similarity | Deterministic rules + synonyms |
| **Confidence** | Probabilistic 0-1 | Discrete levels 1-5 |
| **Transparency** | Black box | Fully explainable |
| **False Positives** | Higher (~5-10%) | Lower (<1%) |
| **False Negatives** | Lower | Higher (by design) |
| **State Validation** | Not enforced | Required match |
| **City/County** | Not distinguished | Strictly validated |
| **Maintainability** | Complex, needs retraining | Simple, easy to adjust |

---

## Next Steps

1. **Approve approach** - Does this rule-based strategy align with your requirements?
2. **Refine synonyms** - Are the type synonyms correct for your domain?
3. **Define levels** - Should we start with just Levels 1-2, or include Level 3?
4. **Review edge cases** - Special handling needed for state agencies, federal agencies, etc.?
5. **Implementation** - Ready to code the SQL procedures?

---

## Questions for Clarification

1. **Abbreviations:** Are there other common agency type abbreviations beyond PD, SO, HSP?
2. **State Code:** Can we assume all org_names follow `[Location] [STATE_CODE] [TYPE]`?
3. **Confidence Level:** Should we start with only 1.0 confidence (exact only) or include 0.95 (synonyms)?
4. **City/County:** How to handle agencies that serve both city and county (e.g., "Metro PD")?
5. **Special Cases:** Any known problematic org_names or agencies to exclude?

