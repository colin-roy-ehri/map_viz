# Colorado Attorney General Suspicion Ranking Report
## Guide to Analyzing Potential State Law Violations

**Purpose**: This analysis identifies Flock Safety searches that may violate Colorado state law prohibiting police assistance in federal immigration cases.

**Data Period**: October 2025
**Data Sources**:
- `durango-deflock.DurangoPD.October2025_classified` - Classified search data
- `durango-deflock.FlockML.org_name_rule_based_matches` - Participating agency matching

---

## Quick Start

### Option 1: Run SQL Queries Directly (Recommended for quick analysis)

1. Open BigQuery Console
2. Go to your project: `durango-deflock`
3. Copy and paste queries from `sql/27_suspicion_ranking_analysis.sql`
4. Run each query to get different analyses

**Key Queries to Run First**:
- **Query 1**: Executive Summary (overall statistics)
- **Query 4**: Top 50 Highest Risk Searches (for detailed review)
- **Query 2**: Distribution by suspicion level

### Option 2: Run Python Script (For complete report generation)

```bash
cd /home/colin/map_viz
python suspicion_ranking_report.py
```

This generates:
- `Colorado_AG_Suspicion_Report.md` - Full markdown report
- `Colorado_AG_Suspicion_Report_detailed_data.csv` - Data for further analysis

---

## Scoring Methodology

### Risk Factors and Points

Each search receives a **suspicion score from 0-100** based on these cumulative factors:

| Risk Factor | Points | Trigger Condition |
|------------|--------|------------------|
| **Participating Agency** | +40 | Agency participates in ICE collaboration via Flock Safety |
| **No Case Number** | +30 | `case_num` field is empty/null (redacted is OK) |
| **AOA/Interagency Reason** | +20 | `reason_category` = 'Interagency' or reason contains 'AOA' |
| **Invalid/Ambiguous Reason** | +10 | `reason_bucket` in {Invalid_Reason, Case_Number, OTHER} |

**Maximum Score**: 100 (capped)
**Score Formula**: `MIN(40 × participating + 30 × no_case_num + 20 × aoa + 10 × invalid, 100)`

### Suspicion Categories

| Suspicion Level | Score Range | Risk Assessment |
|-----------------|-------------|-----------------|
| **No Suspicion** | 0% | No risk factors present |
| **Low Suspicion** | 1-30% | One minor factor |
| **Moderate Suspicion** | 31-60% | Multiple factors or one major factor |
| **High Suspicion** | 61-99% | Multiple major factors |
| **Very High Suspicion** | 100% | Participating + No case number + AOA/Invalid reason |

### Why This Scoring?

The scoring reflects the legal concerns:

1. **Participating Agency (+40)** - HIGHEST WEIGHT
   - Agencies in Flock's participation database have formal agreements
   - Strongest indicator of potential ICE cooperation
   - Federal partners are known and documented

2. **No Case Number (+30)** - HIGH WEIGHT
   - Colorado law requires documented case numbers
   - Absence suggests undocumented activity
   - Harder to audit and trace
   - Redacted case numbers are acceptable (still documented)

3. **AOA/Interagency Reason (+20)** - MODERATE WEIGHT
   - "All Other Agencies" suggests coordination outside normal channels
   - May indicate federal agency involvement
   - AOA codes often hide the true nature of requests

4. **Invalid/Ambiguous Reason (+10)** - LOW WEIGHT
   - Lack of clear documented purpose
   - Makes it harder to verify legitimacy
   - Could indicate rushed or undocumented process

---

## Key Definitions

### Participating Agency
An agency that:
- Appears in `durango-deflock.FlockML.participatingAgencies` database
- Has been matched using rule-based criteria (state + location + type)
- Is known to participate in Flock Safety system
- May have formal ICE collaboration agreements

**Note**: Non-participating agencies may still conduct searches (private security, federal agencies, etc.)

### Case Number
- **Valid**: Any documented case, warrant, or report number
- **Redacted**: Acceptable; indicates documentation exists but is protected
- **Invalid**: Empty, null, or generic placeholders

### Reason Classifications
- **Valid Reason**: Crime investigation with clear documented purpose
- **Interagency (AOA)**: Undefined external agency request
- **Invalid_Reason**: Unclassified, test, or invalid entries
- **Case_Number**: Entry is a case number, not a valid reason

### Case Number Field States
The analysis treats these as "no case number":
- Empty string (`""`)
- NULL value
- Whitespace only

The analysis treats these as valid (OK):
- Any numeric or alphanumeric code
- "[REDACTED]", "REDACTED", "Redacted"
- "XXXX", "####"
- Any documented placeholder indicating case exists but is protected

---

## Understanding the Risk Factors

### Factor 1: Participating Agency (40 points)

**What it means**: The searching organization is a confirmed law enforcement agency participating in Flock Safety.

**Why it matters**:
- Flock Safety participates in federal programs
- Participating agencies have formal relationships with federal partners
- Known corruption vector for undocumented immigration inquiries

**Example searches**:
- "Seminole County FL SO" → Matches "Seminole County Sheriff's Office" ✓
- "Houston TX PD" → Matches "Houston Police Department" ✓
- "Unknown Security Inc" → No match (0 points for this factor)

### Factor 2: No Case Number (30 points)

**What it means**: The search lacks a documented case number or reference.

**Why it matters**:
- Colorado law requires case-based documentation
- Without case numbers, searches are harder to audit
- Suggests potentially undocumented activity
- Creates plausible deniability

**How to interpret**:
- Missing case number = 30 points
- Redacted but documented case number = 0 points (still auditable)
- Generic entry = 0 points (if it's any kind of case identifier)

**Examples**:
- NULL → 30 points (no documentation)
- "" (empty) → 30 points (no documentation)
- "[REDACTED]" → 0 points (documented, protected)
- "2025-001234" → 0 points (documented)

### Factor 3: AOA/Interagency Reason (20 points)

**What it means**: The search reason is classified as interagency or marked as "AOA" (All Other Agencies).

**Why it matters**:
- AOA codes are generic catch-all categories
- Often used to hide true purpose of searches
- Common in coordinated federal operations
- Suggests request may not be for local investigation

**Examples**:
- Reason = "AOA" → 20 points
- Reason_category = "Interagency" → 20 points
- Reason = "Tip from federal agent" → 20 points
- Reason = "Stolen vehicle" → 0 points

### Factor 4: Invalid/Ambiguous Reason (10 points)

**What it means**: The reason field is classified as Invalid, unparseable, or OTHER.

**Why it matters**:
- Incomplete documentation
- Unclear purpose of search
- Hard to justify or audit
- May indicate quick/unauthorized request

**Examples**:
- Reason_bucket = "Invalid_Reason" → 10 points
- Reason_bucket = "Case_Number" → 10 points (wrong field)
- Reason_category = "OTHER" → 10 points
- Reason = "violent crime" → 0 points (Valid_Reason)

---

## Understanding the Data

### October2025_classified Table

Key columns:
- `org_name` - Searching organization (typically abbreviated)
- `case_num` - Case or incident number
- `reason` - Free-text reason for search
- `reason_category` - LLM-classified category (e.g., "Violent_Crime", "Interagency")
- `reason_bucket` - Simplified classification ("Valid_Reason" or "Invalid_Reason")
- `has_no_context` - Boolean: reason lacks sufficient context

### org_name_rule_based_matches Table

Key columns:
- `org_name` - Searching organization from searches
- `is_participating_agency` - Boolean: in Flock participating agencies database
- `matched_agency` - Full agency name if matched
- `matched_state` - State code/name of matched agency
- `matched_type` - Agency type (PD, SO, HSP, etc.)
- `confidence` - Match confidence (0.0 to 1.0)
- `match_type` - Type of match ("exact", "synonym", or unmatched)

---

## Interpreting Results

### High-Risk Searches (60%+ suspicion)

A score of 60%+ indicates **strong suspicion** of potential law violation.

**Example search with 100% suspicion**:
```
Org: "Houston TX PD"
Matched Agency: "Houston Police Department"
Is Participating: TRUE  (+40 points)
Case Number: [empty]  (+30 points)
Reason: "AOA - Interdiction"  (+20 points)
Risk Factors: All four
Suspicion Score: 100%
```

**What it means**:
- A known participating agency
- Conducted search without case number
- For an interagency reason
- Likely violation of Colorado state law

### Medium-Risk Searches (30-60% suspicion)

Mixed indicators that warrant investigation.

**Example search with 60% suspicion**:
```
Org: "Denver PD"
Matched Agency: "Denver Police Department"
Is Participating: TRUE  (+40 points)
Case Number: "[REDACTED]"  (+0 points - documented)
Reason: "Person Search"  (+0 points - valid)
Reason Bucket: Invalid_Reason  (+10 points)
Suspicion Score: 50%
```

**What it means**:
- Participating agency (high risk)
- Has case number documentation (mitigates)
- Valid reason category (mitigates)
- But classified as invalid reason (concerns)
- **Action**: Review case file to understand classification issue

### Low-Risk Searches (0-30% suspicion)

Minimal concern, likely legitimate law enforcement activity.

**Example search with 0% suspicion**:
```
Org: "Unknown Security Inc"
Matched Agency: [null] (not participating)  (+0 points)
Case Number: "INC-2025-456"  (+0 points - documented)
Reason: "Stolen Vehicle"  (+0 points - valid)
Reason Bucket: Valid_Reason  (+0 points)
Suspicion Score: 0%
```

**What it means**:
- Non-participating organization
- Documented with case number
- Clear legitimate purpose
- **Action**: No concern

---

## Action Items for Colorado Attorney General

### Tier 1: Immediate Investigation (100% suspicion)
- **Count**: ~[X] searches
- **Action**: Request all records from these searches
- **Timeline**: 30 days
- **Scope**: Full investigation of case numbers, communications, outcomes

### Tier 2: Extended Review (60-99% suspicion)
- **Count**: ~[X] searches
- **Action**: Audit sample (every 5th search) for compliance
- **Timeline**: 60 days
- **Scope**: Verify case documentation and purpose

### Tier 3: Monitoring (30-60% suspicion)
- **Count**: ~[X] searches
- **Action**: Flag for ongoing monitoring
- **Timeline**: Quarterly review
- **Scope**: Track patterns and trends

### Tier 4: Baseline (0-30% suspicion)
- **Count**: ~[X] searches
- **Action**: Standard audit procedures
- **Timeline**: Annual
- **Scope**: Representative sample

---

## Running the Analysis

### Method 1: SQL Queries

Best for: Quick lookups, specific searches, exploration

```bash
# In BigQuery Console:
# 1. Copy queries from sql/27_suspicion_ranking_analysis.sql
# 2. Run "Query 1: Executive Summary" first
# 3. Use other queries to drill down
```

**Useful queries**:
- Query 1: Overall statistics
- Query 2: Distribution by suspicion level
- Query 3: Risk factor breakdown
- Query 4: Top 50 highest risk (for manual review)
- Query 5: By participating agency (for oversight)
- Query 6: 100% suspicion searches (priority review)

### Method 2: Python Script

Best for: Complete report, data export, automation

```bash
cd /home/colin/map_viz
python suspicion_ranking_report.py
```

Generates:
- Full markdown report with summary and recommendations
- CSV export of all searches with scores
- Logging output showing progress

**Customization**:
Edit `suspicion_ranking_report.py` to:
- Change point values (modify `calculate_suspicion_score()`)
- Adjust CSV export columns
- Modify report format or thresholds

### Method 3: BigQuery Table Creation

Best for: Ongoing monitoring, integration with dashboards

```sql
-- Create persistent table (from sql/27_suspicion_ranking_analysis.sql)
CREATE OR REPLACE TABLE `durango-deflock.FlockML.suspicion_ranking_detailed` AS
SELECT * FROM `durango-deflock.FlockML.suspicion_ranking_analysis`;

-- Then create dashboards, export regularly, etc.
```

---

## Customizing the Analysis

### Adjusting Point Values

To change scoring weights, modify the formula in:
- **SQL**: Update the `LEAST(...)` calculation in `sql/27_suspicion_ranking_analysis.sql`
- **Python**: Update `calculate_suspicion_score()` in `suspicion_ranking_report.py`

Example: Make "No Case Number" worth 50 points instead of 30:
```python
# In calculate_suspicion_score():
if not case_num:
    score += 50  # Changed from 30
    factors.append('No case number provided')
```

### Adjusting Suspicion Categories

Change the thresholds (currently 0, 30, 60, 100):
```python
# For example, make "High Suspicion" start at 50% instead of 60%
if score >= 50:  # Changed from 60
    suspicious_searches.append(row)
```

### Filtering by Specific Criteria

Add WHERE clauses to SQL queries:
```sql
-- Only participating agencies
WHERE is_participating_agency = TRUE

-- Only without case numbers
WHERE TRIM(COALESCE(case_num, '')) = ''

-- Only specific states
WHERE matched_state = 'CO' OR matched_state = 'COLORADO'

-- Only specific agencies
WHERE matched_agency LIKE '%Denver%'
```

---

## Limitations and Considerations

1. **Data Quality**
   - Analysis depends on accuracy of case numbers and reason classifications
   - Free-text reasons may be incomplete or miscoded
   - Matching to participating agencies may miss some agencies

2. **Context**
   - Suspicion score ≠ proof of violation
   - Some high-suspicion searches may be legitimate
   - Full case file review needed for definitive conclusions

3. **Scope**
   - October 2025 data only
   - Flock searches only (other systems not analyzed)
   - Colorado law interpretation may vary by jurisdiction

4. **Privacy**
   - This analysis focuses on metadata, not search results
   - Does not examine what information was retrieved
   - Does not track outcomes or actions based on searches

---

## Recommendations

### Short-term (30 days)
1. Run executive summary statistics
2. Identify all 100% suspicion searches
3. Manually review top 50 for case files
4. Contact agencies for missing case numbers

### Medium-term (60 days)
1. Complete audit of all 60%+ searches
2. Compare with state law interpretation
3. Develop compliance framework
4. Issue guidance to agencies

### Long-term (quarterly+)
1. Establish ongoing monitoring
2. Implement automated alerts for high-suspicion searches
3. Regular training for participating agencies
4. Update participating agencies database
5. Expand analysis to other time periods and systems

---

## Contact and Questions

For questions about:
- **Methodology**: Review this document and the code comments
- **Data Access**: Contact your BigQuery administrator
- **Results**: Review the generated reports and query outputs
- **Colorado Law**: Consult with Colorado Attorney General's legal team

---

## Appendix: Related Files

- `sql/27_suspicion_ranking_analysis.sql` - All SQL queries
- `suspicion_ranking_report.py` - Python analysis script
- `PARTICIPATING_AGENCY_ANALYSIS.md` - Background on agency matching
- `October2025_classified` table - Core data
- `org_name_rule_based_matches` table - Agency matching reference

---

**Document Version**: 1.0
**Last Updated**: February 2026
**Classification**: For Official Use by Colorado Attorney General
