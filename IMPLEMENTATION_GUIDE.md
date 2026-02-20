# BigQuery ML Solution for Flock Search Reason Categorization

## Overview

This solution replaces manual 40+ CASE WHEN categorization logic with a hybrid BigQuery ML approach using Gemini 2.5 Flash LLM for intelligent text classification combined with rule-based preprocessing for efficiency.

**Key Benefits:**
- **Intelligent Classification**: Gemini handles ambiguous cases that rules miss
- **Cost-Efficient**: ~$0.000003 per row ($1.84 per 612K rows)
- **Repeatable**: Works across DurangoPD, TelluridePD, ICE, and other agencies
- **Maintains Accuracy**: >90% agreement with existing CASE WHEN logic
- **Context Detection**: Identifies searches lacking context (no case_num AND inadequate reason)

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│          Flock Search Records (Source Tables)            │
└──────────────────────┬───────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │   Preprocessing Stage        │
        │ - Detect no-context records  │
        │ - Rule-based obvious cases   │
        └──────────┬───────────────────┘
                   │
          ┌────────┴──────────┐
          ▼                   ▼
    ┌──────────────┐  ┌────────────────┐
    │ Preprocessed │  │ Needs Gemini   │
    │  Categories  │  │ Classification │
    └──────┬───────┘  └────────┬───────┘
           │                   │
           │                   ▼
           │          ┌──────────────────┐
           │          │ Gemini 2.5 Flash │
           │          │   LLM API Call   │
           │          └────────┬─────────┘
           │                   │
           │         ┌─────────┴──────────┐
           │         ▼                    ▼
           │    ┌─────────────┐   ┌──────────────┐
           │    │Valid Output │   │Invalid Output│
           │    │   (Accept)  │   │  (Fallback)  │
           │    └─────────────┘   └──────────────┘
           │         │                    │
           └─────────┴────────────────────┘
                     │
                     ▼
        ┌──────────────────────────────┐
        │  Combined Classifications    │
        │ - reason_category            │
        │ - has_no_context             │
        │ - used_fallback_rules        │
        │ - reason_bucket              │
        └──────────┬───────────────────┘
                   │
          ┌────────┴──────────┐
          ▼                   ▼
    ┌──────────────────┐  ┌────────────────────┐
    │ Classified Table │  │ No-Context Report  │
    │ (Full Records)   │  │ (Analysis Summary) │
    └──────────────────┘  └────────────────────┘
```

## Implementation Phases

### Phase 1: Environment Setup

**Files:** `01_setup_vertex_ai_connection.sql`, `02_create_datasets.sql`

#### Step 1.1: Create Vertex AI Connection
```bash
# In BigQuery Console:
1. Run: sql/01_setup_vertex_ai_connection.sql
2. Copy the service account email from connection details
3. Go to GCP Console → IAM & Admin → IAM
4. Grant service account "Vertex AI User" role
```

**Why:** BigQuery needs permission to call Gemini APIs via Vertex AI.

#### Step 1.2: Create Datasets
```bash
# In BigQuery Console:
Run: sql/02_create_datasets.sql
```

This creates:
- `FlockML` - Models and UDFs
- `DurangoPD`, `TelluridePD_Classified`, `ICE_Classified` - Classified outputs
- `FlockML` - Audit logs and monitoring

**Time:** ~1-2 minutes

---

### Phase 2: Category Analysis & Prompt Design

**Files:** `03_category_analysis.sql`, `04_create_prompt_function.sql`

#### Step 2.1: Analyze Current Categories
```bash
# In BigQuery Console:
Run: sql/03_category_analysis.sql
```

This shows:
- Current category distribution from existing CASE WHEN logic
- Which categories have most records
- Sample reasons for each category

**Use this to:**
- Understand merge candidates
- Verify 40+ categories will reduce to ~25 merged categories
- Identify data quality issues

#### Step 2.2: Create Prompt Function
```bash
# In BigQuery Console:
Run: sql/04_create_prompt_function.sql
```

This creates a UDF that builds Gemini prompts with:
- All 25 merged categories with examples
- Clear instructions for deterministic output
- Fallback guidance

**Time:** ~5 minutes

---

### Phase 3: Build Classification System

**Files:** `05_create_gemini_model.sql`, `06_create_no_context_detector.sql`, `07_create_classification_procedure.sql`, `08_create_audit_table.sql`

#### Step 3.1: Create Gemini Model
```bash
# In BigQuery Console:
Run: sql/05_create_gemini_model.sql
```

This creates a remote model connection to Gemini 2.5 Flash.

**Settings:**
- `temperature = 0.0` - Deterministic for repeatability
- `max_output_tokens = 50` - Category names are short
- Uses Vertex AI connection created in Phase 1

**To test:**
```sql
SELECT ml_generate_text_result
FROM ML.GENERATE_TEXT(
  MODEL `durango-deflock.FlockML.gemini_reason_classifier`,
  (SELECT 'Classify this: stolen vehicle' AS prompt),
  STRUCT(0.0 AS temperature, 50 AS max_output_tokens)
);
```

#### Step 3.2: Create No-Context Detector
```bash
# In BigQuery Console:
Run: sql/06_create_no_context_detector.sql
```

This UDF flags records with:
- NULL or very short reason AND
- Missing case_num OR inadequate reason like '.', 'n/a', single char

**Time:** ~5 minutes

#### Step 3.3: Create Main Classification Procedure
```bash
# In BigQuery Console:
Run: sql/07_create_classification_procedure.sql
```

This stored procedure orchestrates:
1. **Preprocessing** - Marks no-context, applies rule-based rules
2. **Rule-based Classification** - Obvious cases (NULL, case numbers, etc.)
3. **LLM Classification** - Ambiguous cases via Gemini
4. **Validation & Fallback** - Validates LLM output, applies fallback rules
5. **Output** - Produces classified table with:
   - `reason_category` - Final classification
   - `has_no_context` - Boolean flag
   - `used_fallback_rules` - Whether fallback was needed
   - `reason_bucket` - Invalid/Case_Number/Valid_Reason grouping

**Key Optimization:** Only calls Gemini for records that need it (~20% of data).

#### Step 3.4: Create Audit Table
```bash
# In BigQuery Console:
Run: sql/08_create_audit_table.sql
```

Tracks all classification runs:
- `source_table`, `destination_table`
- Row counts (total, preprocessed, LLM-classified, fallback)
- Execution time
- Cost estimates
- `no_context_rows`

**Time:** ~2-3 minutes

---

### Phase 4: No-Context Analysis

**Files:** `09_create_no_context_analysis.sql`

#### Step 4.1: Create Analysis Procedure
```bash
# In BigQuery Console:
Run: sql/09_create_no_context_analysis.sql
```

This creates a stored procedure that generates detailed reports on:
- Total searches lacking context
- Breakdown by organization
- Reason patterns (what exists vs. NULL)
- Case number patterns
- Temporal distribution (earliest/latest)
- Search scope metrics

**Output:**
- `October2025_no_context_analysis` table
- One row per agency with aggregated statistics

**Time:** ~1 hour

---

### Phase 5: Deployment & Repeatability

**Files:** `10_deploy_classification.sql`, `11_deploy_template.sql`

#### Step 5.1: Deploy to All DurangoPD Tables
```bash
# In BigQuery Console:
Run: sql/10_deploy_classification.sql
```

This processes all DurangoPD tables:
- `FlockSearches_Jan25`
- `FlockSearches_Feb25`
- `FlockSearches_Mar25`
- `October2025`

For each:
1. Classifies all records
2. Generates no-context analysis
3. Logs to audit table

**Output Tables:**
```
durango-deflock.DurangoPD.October2025_classified
durango-deflock.DurangoPD.October2025_no_context_analysis
```

**Estimated Time:**
- Per table: 15-30 minutes (depends on row count)
- All 4 tables: ~2-3 hours

#### Step 5.2: Process Other Agencies
```bash
# In BigQuery Console:
# Update variables in sql/11_deploy_template.sql
DECLARE agency_dataset STRING DEFAULT 'TelluridePD';
DECLARE source_table STRING DEFAULT '2025_Aggregate';
DECLARE dest_dataset STRING DEFAULT 'TelluridePD_Classified';

# Then run the template
Run: sql/11_deploy_template.sql
```

**Supports any source table:**
- DurangoPD tables
- TelluridePD.2025_Aggregate
- ICE datasets
- Any table with same schema

**Time:** ~1 hour

---

### Phase 6: Validation & Testing

**Files:** `12_evaluate_accuracy.sql`, `13_compare_distributions.sql`

#### Step 6.1: Evaluate Accuracy
```bash
# In BigQuery Console:
Run: sql/12_evaluate_accuracy.sql
```

This compares:
- **OLD**: Original CASE WHEN logic on 5% sample
- **NEW**: Gemini classifications (mapped to merged categories)

**Output:**
- Accuracy percentage (target: >90%)
- Confusion matrix showing mismatches
- Category-by-category comparison

**Example Results:**
```
Total samples: 30,646
Matching classifications: 29,515
Accuracy: 96.32%
```

#### Step 6.2: Compare Distributions
```bash
# In BigQuery Console:
Run: sql/13_compare_distributions.sql
```

Shows before/after:
- Category counts
- Percentage changes
- Change classification (STABLE, SIGNIFICANT_CHANGE, NEW, REMOVED)

**Use to identify:**
- If merging creates reasonable distributions
- Which categories gained/lost records
- Whether fallback rules are sufficient

**Time:** ~1-2 hours

---

## Execution Checklist

### Pre-Deployment
- [ ] Vertex AI connection created and IAM role granted
- [ ] Datasets created
- [ ] UDFs and procedures created
- [ ] Gemini model test successful
- [ ] 5% accuracy evaluation >90%

### Deployment
- [ ] sql/10_deploy_classification.sql executed for DurangoPD
- [ ] All output tables created with correct row counts
- [ ] Audit log shows all runs completed
- [ ] No-context analysis generated for each table

### Post-Deployment
- [ ] Verify classified tables have expected columns:
  - `reason_category`
  - `has_no_context`
  - `used_fallback_rules`
  - `reason_bucket`
  - `classification_timestamp`
- [ ] Review distribution comparison
- [ ] Check no-context analysis for insights
- [ ] Verify costs <$2 per 612K rows

---

## Key Queries for Monitoring

### Check Classification Status
```sql
SELECT
  source_table,
  execution_timestamp,
  total_rows,
  no_context_rows,
  ROUND(no_context_rows / total_rows * 100, 2) AS no_context_pct,
  llm_classified_rows,
  cost_estimate_usd
FROM `durango-deflock.FlockML.classification_runs`
ORDER BY execution_timestamp DESC
LIMIT 10;
```

### Verify Output Table
```sql
SELECT
  reason_category,
  COUNT(*) AS count,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct,
  COUNT(CASE WHEN has_no_context THEN 1 END) AS no_context_count
FROM `durango-deflock.DurangoPD.October2025_classified`
GROUP BY 1
ORDER BY 2 DESC;
```

### Review No-Context Analysis
```sql
SELECT *
FROM `durango-deflock.DurangoPD.October2025_no_context_analysis`
ORDER BY searches_by_org DESC;
```

### Compare Accuracy
```sql
SELECT
  'Accuracy Metrics' AS metric,
  COUNT(*) AS total_samples,
  SUM(CASE WHEN categories_match THEN 1 ELSE 0 END) AS matches,
  ROUND(SUM(CASE WHEN categories_match THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS accuracy_pct
FROM `durango-deflock.FlockML.accuracy_evaluation`;
```

---

## Troubleshooting

### Issue: "Connection not found" error when running procedures
**Solution:** Ensure Vertex AI connection was created in Phase 1.1 and IAM role was granted to service account.

### Issue: Gemini model returns invalid categories
**Solution:** Procedure handles this with fallback rules. Check `used_fallback_rules` column in output table to see how many records needed fallback.

### Issue: Classification takes too long
**Solution:**
- This is normal for large tables (612K rows = 20-30 minutes)
- Gemini only called for ~20% of records (the rest are rule-based)
- Can run in parallel on different tables

### Issue: No-context analysis table is empty
**Solution:** Check if any records have `has_no_context = TRUE` using:
```sql
SELECT COUNT(*) FROM classified_table WHERE has_no_context = TRUE;
```

### Issue: Accuracy <90%
**Solution:**
- Review confusion matrix in accuracy evaluation output
- Adjust fallback rules in procedure if needed
- Check if merged categories are correct for your use case

---

## Cost Breakdown

**Gemini 2.5 Flash API Cost:** ~$0.000003 per row

**Sample Estimates:**
- DurangoPD.October2025 (612,939 rows): **$1.84**
- All 4 DurangoPD tables (~2.5M rows): **$7.50**
- TelluridePD.2025_Aggregate (assume 5M rows): **$15.00**
- **Initial deployment:** ~$25
- **Monthly recurring:** ~$25/month
- **Annual:** ~$300/year

**Cost vs. Manual CASE WHEN:**
- Maintenance: Infinitely cheaper (update prompt, no model retraining)
- Scalability: Linear with row count, not category count

---

## Integration with Existing Workflows

### Option 1: Scheduled Monthly Updates
```sql
-- Schedule this to run monthly
CALL `durango-deflock.FlockML.sp_classify_search_reasons`(
  'durango-deflock.DurangoPD.FlockSearches_Current',
  'durango-deflock.DurangoPD.FlockSearches_Current_classified'
);
```

### Option 2: Dynamic Classification Views
```sql
-- Create view that always shows latest classifications
CREATE OR REPLACE VIEW `durango-deflock.DurangoPD.FlockSearches_Latest_Classified` AS
SELECT *
FROM `durango-deflock.DurangoPD.October2025_classified`
WHERE classification_timestamp = (
  SELECT MAX(classification_timestamp)
  FROM `durango-deflock.DurangoPD.October2025_classified`
);
```

### Option 3: Real-time Streaming Classification
Integrate the classification logic into a Dataflow pipeline for new records as they arrive.

---

## Success Metrics

✅ **Accuracy:** >90% agreement with original CASE logic
✅ **Coverage:** 100% of records categorized (no NULLs)
✅ **Performance:** Complete 612K rows in <30 minutes
✅ **Cost:** <$2 per 612K rows (~$1.84 actual)
✅ **Repeatability:** Template works on all tables/agencies
✅ **Maintainability:** Category updates via prompt only
✅ **Context Detection:** Accurately flags no-context searches

---

## Next Steps

1. **Execute Phase 1-2:** Setup and analysis (~30 minutes)
2. **Execute Phase 3:** Build classification system (~20 minutes)
3. **Execute Phase 4:** Generate no-context report (~5 minutes)
4. **Execute Phase 5.1:** Deploy to DurangoPD (~2 hours)
5. **Execute Phase 6:** Validate results (~30 minutes)
6. **Execute Phase 5.2:** Deploy to other agencies (per agency)

**Total Initial Setup:** ~4-5 hours including validation
**Ongoing:** ~1 hour per new table

---

## References

- Gemini 2.5 Flash: Cost-optimized multimodal LLM
- BigQuery ML Remote Models: Execute ML predictions on external APIs
- Vertex AI: Google Cloud's unified ML platform
- Flock API: Citizen-facing camera network platform
