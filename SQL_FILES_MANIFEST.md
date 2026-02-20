# SQL Files Manifest

Complete list of SQL files for the BigQuery ML classification solution, organized by phase and execution order.

## Phase 1: Environment Setup

### 01_setup_vertex_ai_connection.sql
**Purpose:** Create Vertex AI connection for Gemini API access
**Location:** `sql/01_setup_vertex_ai_connection.sql`
**Execution Time:** ~2 minutes + manual IAM setup (5 minutes)
**Key Steps:**
1. Creates `durango-deflock.us-central1.vertex-ai-connection`
2. Displays service account email
3. Requires manual Vertex AI User role grant in GCP IAM

**Dependencies:** None
**Downstream:** Required for all Gemini model operations

**Manual Verification:**
```sql
-- After running, verify connection exists
SELECT connection_name, location FROM `durango-deflock.region-us`.INFORMATION_SCHEMA.CONNECTIONS
WHERE connection_name = 'vertex-ai-connection';
```

---

### 02_create_datasets.sql
**Purpose:** Create logical grouping of models, outputs, and audit logs
**Location:** `sql/02_create_datasets.sql`
**Execution Time:** ~1 minute
**Creates:**
- `FlockML` - UDFs and remote models
- `DurangoPD`, `TelluridePD_Classified`, `ICE_Classified` - Classified outputs
- `FlockML` - Audit logs and monitoring

**Dependencies:** None (but Vertex AI connection should exist)
**Downstream:** All subsequent SQL files depend on these datasets

---

## Phase 2: Category Analysis & Prompt Design

### 03_category_analysis.sql
**Purpose:** Understand current category distribution before implementing merges
**Location:** `sql/03_category_analysis.sql`
**Execution Time:** ~2 minutes
**Output:**
- `current_category` distribution (40+ original categories)
- Record counts per category
- Unique reasons per category
- Sample reasons for each category

**Dependencies:** Access to `durango-deflock.TelluridePD.2025_Aggregate` (source table with Durango data)
**Key Metrics:**
- Most common categories and their sizes
- Data quality patterns
- Merge candidates based on distribution

**Note:** This is analysis-only, doesn't create tables or modify data

---

### 04_create_prompt_function.sql
**Purpose:** Build reusable prompt UDF for Gemini classification
**Location:** `sql/04_create_prompt_function.sql`
**Execution Time:** ~1 minute
**Creates:** `durango-deflock.FlockML.build_classification_prompt(reason STRING)`

**Functionality:**
- Takes raw reason string
- Returns formatted prompt with:
  - 25 merged category definitions
  - Clear examples
  - Instructions for deterministic output

**Dependencies:** `FlockML` dataset
**Used By:** `sp_classify_search_reasons` procedure

**Example Usage:**
```sql
SELECT `durango-deflock.FlockML.build_classification_prompt`('stolen vehicle') AS prompt;
```

---

## Phase 3: Build Classification System

### 05_create_gemini_model.sql
**Purpose:** Create remote model connection to Gemini 2.5 Flash
**Location:** `sql/05_create_gemini_model.sql`
**Execution Time:** ~1 minute
**Creates:** `durango-deflock.FlockML.gemini_reason_classifier`

**Configuration:**
- `endpoint = 'gemini-2.5-flash'` - Cost-optimized for batch processing
- `temperature = 0.0` - Deterministic/reproducible results
- `max_output_tokens = 50` - Category names are short

**Dependencies:**
- `FlockML` dataset
- Vertex AI connection (from 01_setup_vertex_ai_connection.sql)

**Key Testing:**
```sql
-- Test the model (uncommented in file)
SELECT ml_generate_text_result
FROM ML.GENERATE_TEXT(
  MODEL `durango-deflock.FlockML.gemini_reason_classifier`,
  (SELECT 'Classify this: stolen vehicle' AS prompt),
  STRUCT(0.0 AS temperature, 50 AS max_output_tokens)
);
```

---

### 06_create_no_context_detector.sql
**Purpose:** UDF to identify searches lacking documentation context
**Location:** `sql/06_create_no_context_detector.sql`
**Execution Time:** ~1 minute
**Creates:** `durango-deflock.FlockML.is_no_context(reason STRING, case_num STRING)`

**Logic:**
- Returns TRUE if:
  - `reason` is NULL or <2 characters, OR
  - `case_num` is NULL AND `reason` is inadequate (like '.', 'n/a', single char, etc.)

**Dependencies:** `FlockML` dataset
**Used By:** `sp_classify_search_reasons` procedure

**Example Usage:**
```sql
SELECT `durango-deflock.FlockML.is_no_context`(reason, case_num) AS has_no_context
FROM source_table;
```

---

### 07_create_classification_procedure.sql
**Purpose:** Main orchestration procedure for hybrid classification
**Location:** `sql/07_create_classification_procedure.sql`
**Execution Time:** ~2 minutes creation + variable execution time per table
**Creates:** `durango-deflock.FlockML.sp_classify_search_reasons(source_table, destination_table)`

**Workflow:**
1. **Preprocessing Stage** - Create temp table with:
   - `has_no_context` flag
   - `preprocessed_category` (rule-based obvious cases)
   - `normalized_reason` (lowercase, trimmed)

2. **LLM Classification** - Filter to records needing Gemini:
   - ~20% of data (rest are rule-based)
   - Call Gemini with built prompt

3. **Validation & Fallback** - Validate Gemini output:
   - If valid category → use it
   - If invalid → apply fallback rules

4. **Output Table** - Create final table with:
   - All source columns preserved
   - `reason_category` - Final classification
   - `has_no_context` - Boolean flag
   - `used_fallback_rules` - Whether fallback was needed
   - `reason_bucket` - Summary bucket
   - `classification_timestamp` - When classified

5. **Audit Logging** - Insert into audit table

**Dependencies:**
- `FlockML` dataset
- `is_no_context()` function (from 06_create_no_context_detector.sql)
- `build_classification_prompt()` function (from 04_create_prompt_function.sql)
- `gemini_reason_classifier` model (from 05_create_gemini_model.sql)

**Performance:**
- Rule-based preprocessing: ~1-2 minutes for 600K rows
- Gemini API calls: ~10-20 minutes for 120K rows
- Total: 15-30 minutes per table

**Error Handling:** Logs failures to audit table with error messages

---

### 08_create_audit_table.sql
**Purpose:** Create audit log and monitoring infrastructure
**Location:** `sql/08_create_audit_table.sql`
**Execution Time:** ~1 minute
**Creates:**
- `classification_runs` table (partitioned by date)
- `classification_summary` view

**Schema - classification_runs:**
```
source_table           STRING NOT NULL
destination_table      STRING NOT NULL
execution_timestamp    TIMESTAMP NOT NULL
completion_timestamp   TIMESTAMP
total_rows            INT64
preprocessed_rows     INT64
llm_classified_rows   INT64
fallback_rows         INT64
no_context_rows       INT64
cost_estimate_usd     FLOAT64
```

**Dependencies:** `FlockML` dataset
**Used By:** `sp_classify_search_reasons` procedure (inserts), monitoring queries

---

## Phase 4: Analysis & Reporting

### 09_create_no_context_analysis.sql
**Purpose:** Generate detailed analysis of searches lacking context
**Location:** `sql/09_create_no_context_analysis.sql`
**Execution Time:** ~1 minute creation + ~5 minutes per table execution
**Creates:** `durango-deflock.FlockML.sp_analyze_no_context(classified_table, output_table)`

**Analysis Output:**
- `total_no_context_searches` and percentage
- Breakdown by organization
- Reason patterns (NULL vs inadequate)
- Case number statistics
- Temporal distribution
- Search scope metrics

**Schema - Output Table:**
```
total_no_context_searches      INT64
pct_of_all_searches            FLOAT64
org_name                       STRING
searches_by_org                INT64
pct_of_no_context              FLOAT64
completely_null_reason         INT64
inadequate_reason              INT64
sample_inadequate_reasons      ARRAY<STRING>
null_case_num                  INT64
has_case_num                   INT64
earliest_search                TIMESTAMP
latest_search                  TIMESTAMP
avg_networks                   INT64
avg_devices                    INT64
total_devices_across_all       INT64
```

**Dependencies:**
- `FlockML` dataset
- Classified table (output from `sp_classify_search_reasons`)

---

## Phase 5: Deployment

### 10_deploy_classification.sql
**Purpose:** Orchestrate classification of all DurangoPD tables
**Location:** `sql/10_deploy_classification.sql`
**Execution Time:** ~2-3 hours (all 4 tables)
**Process:**
1. Loops through configured tables
2. Calls `sp_classify_search_reasons()` for each
3. Calls `sp_analyze_no_context()` for each
4. Generates summary report

**Configured Tables:**
- `FlockSearches_Jan25`
- `FlockSearches_Feb25`
- `FlockSearches_Mar25`
- `October2025`

**Output Tables (per source table):**
- `DurangoPD.{table_name}_classified` (main output)
- `DurangoPD.{table_name}_no_context_analysis` (analysis)

**Final Report:** Summary of all runs from today

**Dependencies:**
- All procedures and functions from phases 1-4
- Source tables in `DurangoPD` dataset

---

### 11_deploy_template.sql
**Purpose:** Reusable template for classifying any table from any agency
**Location:** `sql/11_deploy_template.sql`
**Execution Time:** ~1 minute edit + 15-30 minutes execution
**Process:**
1. Configure variables:
   ```sql
   agency_dataset = 'TelluridePD'      -- Change to your agency
   source_table = '2025_Aggregate'     -- Your table name
   dest_dataset = 'TelluridePD_Classified'  -- Output dataset
   ```
2. Executes classification and analysis
3. Shows results summary

**Usage Examples:**
```sql
-- For TelluridePD
SET agency_dataset = 'TelluridePD';
SET source_table = '2025_Aggregate';

-- For ICE
SET agency_dataset = 'ICE';
SET source_table = 'searches_2025';
```

**Dependencies:**
- All procedures and functions from phases 1-4
- Destination dataset created in 02_create_datasets.sql

---

## Phase 6: Validation & Evaluation

### 12_evaluate_accuracy.sql
**Purpose:** Compare Gemini classifications against original CASE WHEN logic
**Location:** `sql/12_evaluate_accuracy.sql`
**Execution Time:** ~2-3 minutes
**Process:**
1. Creates accuracy evaluation table on 5% sample
2. Runs original CASE WHEN logic (mapped to merged categories)
3. Gets Gemini classifications from output table
4. Compares and calculates accuracy metrics
5. Shows confusion matrix for mismatches

**Output Tables:**
- `FlockML.accuracy_evaluation` - Full comparison

**Output Queries:**
```
Accuracy metrics:
  Total samples: 30,646
  Matching classifications: 29,515
  Accuracy: 96.32%

Confusion matrix:
  rule_based_category | gemini_category | mismatch_count | example_reasons
```

**Dependencies:**
- Source table (DurangoPD.October2025)
- Classified table (DurangoPD.October2025_classified)

**Success Criteria:**
- Accuracy >90% (target: >95%)
- Confusion matrix shows reasonable mismatches
- No major category disagreements

---

### 13_compare_distributions.sql
**Purpose:** Compare category distributions before and after classification
**Location:** `sql/13_compare_distributions.sql`
**Execution Time:** ~2 minutes
**Process:**
1. Calculates distribution from original CASE WHEN logic
2. Calculates distribution from Gemini classifications
3. Full outer join to show all categories
4. Calculates changes and change types

**Output Schema:**
```
category             STRING
old_count            INT64
new_count            INT64
difference           INT64
change_type          STRING (NEW, REMOVED, SIGNIFICANT_CHANGE, STABLE)
pct_change           FLOAT64
```

**Usage:**
- Identify which categories gained/lost records
- Flag significant changes (>10%)
- Verify merging strategy is sound

**Dependencies:**
- Source table (DurangoPD.October2025)
- Classified table (DurangoPD.October2025_classified)

---

## Execution Order

### Initial Setup (Phase 1-3)
```
01_setup_vertex_ai_connection.sql
    ↓
02_create_datasets.sql
    ↓
03_category_analysis.sql (analysis only)
    ↓
04_create_prompt_function.sql
    ↓
05_create_gemini_model.sql
    ↓
06_create_no_context_detector.sql
    ↓
07_create_classification_procedure.sql
    ↓
08_create_audit_table.sql
```

### Production Deployment (Phase 4-5)
```
09_create_no_context_analysis.sql
    ↓
10_deploy_classification.sql (DurangoPD)
OR
11_deploy_template.sql (Any agency/table)
```

### Validation (Phase 6)
```
12_evaluate_accuracy.sql (After classification complete)
    ↓
13_compare_distributions.sql (Review results)
```

---

## File Dependencies Graph

```
01_setup_vertex_ai_connection.sql
    ↓
    └──→ 05_create_gemini_model.sql
            ↓
            └──→ 07_create_classification_procedure.sql

02_create_datasets.sql
    ├──→ 04_create_prompt_function.sql
    ├──→ 06_create_no_context_detector.sql
    ├──→ 08_create_audit_table.sql
    ├──→ 09_create_no_context_analysis.sql
    └──→ 07_create_classification_procedure.sql

03_category_analysis.sql (no dependencies)

04_create_prompt_function.sql (→ 07)
06_create_no_context_detector.sql (→ 07)

07_create_classification_procedure.sql
    ├──→ 10_deploy_classification.sql
    └──→ 11_deploy_template.sql

09_create_no_context_analysis.sql (→ 10, 11)

12_evaluate_accuracy.sql (requires classified table)
13_compare_distributions.sql (requires classified table)
```

---

## Quick Reference: What Each File Creates

| File | Type | Creates | Dataset |
|------|------|---------|---------|
| 01 | Setup | External Connection | us-central1 |
| 02 | Setup | 5 Datasets | FlockML, etc. |
| 03 | Query | N/A (analysis) | - |
| 04 | UDF | build_classification_prompt() | FlockML |
| 05 | Model | gemini_reason_classifier | FlockML |
| 06 | UDF | is_no_context() | FlockML |
| 07 | Procedure | sp_classify_search_reasons() | FlockML |
| 08 | Table | classification_runs + view | FlockML |
| 09 | Procedure | sp_analyze_no_context() | FlockML |
| 10 | Script | Orchestrates Phase 5 | DurangoPD |
| 11 | Template | Reusable deployment | Any_Classified |
| 12 | Evaluation | accuracy_evaluation table | FlockML |
| 13 | Analysis | N/A (query only) | - |

---

## Error Recovery

If a file fails:

1. **Phase 1-3 Failures:**
   - Re-run the failed file
   - Check error message
   - Verify prerequisites exist

2. **Phase 5 Deployment Failures:**
   - Check audit table: `SELECT * FROM classification_runs WHERE execution_timestamp = CURRENT_DATE()`
   - Re-run just the failed table with template
   - Verify LLM quota not exceeded

3. **Phase 6 Failures:**
   - Verify classified table exists and has data
   - Check audit table for row counts
   - Run queries directly to debug

---

## Maintenance & Updates

### Update Merged Categories
Edit `build_classification_prompt()` in file 04 and re-run.

### Adjust Fallback Rules
Edit `sp_classify_search_reasons()` in file 07 and re-run.

### Monitor Costs
Query audit table:
```sql
SELECT
  SUM(cost_estimate_usd) AS total_cost,
  COUNT(*) AS runs,
  ROUND(AVG(cost_estimate_usd), 4) AS avg_cost_per_run
FROM `durango-deflock.FlockML.classification_runs`;
```

### Tune Performance
Adjust Gemini calls by modifying which records need LLM classification in step 2 of file 07.
