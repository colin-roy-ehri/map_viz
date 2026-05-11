# Stored Procedures for Automated Pipeline

This directory contains the core stored procedures for the automated multi-dataset processing pipeline.

## Procedures Overview

### 1. sp_classify_search_reasons_incremental
**File**: `10_sp_classify_search_reasons_incremental.sql`

Classifies search reasons using LLM with global cache optimization.

**Features**:
- Checks global reason cache before LLM calls
- Only classifies new unique reasons
- Updates global cache with new classifications
- Tracks cache hits and cost metrics

**Parameters**:
- `source_table` (STRING): Source table with raw search data
- `destination_table` (STRING): Output table with classifications
- `use_global_cache` (BOOLEAN, default: TRUE): Enable cache optimization

**Returns**:
- Status message with metrics (rows, cache hits, cost)

**Cost Optimization**:
- First dataset: LLM calls for all unique reasons (~$0.09)
- Second dataset: Only new reasons (~$0.006, 93% savings)
- Third+ datasets: Minimal new classifications (~$0.003)

**Output Columns** (in destination_table):
- All source columns
- `reason_category` (STRING): Classified category
- `reason_bucket` (STRING): 'Valid_Reason' or 'Invalid_Reason'
- `used_fallback_rules` (BOOLEAN): Whether fallback rules applied
- `classification_timestamp` (TIMESTAMP): When classified

**Usage**:
```sql
CALL FlockML.sp_classify_search_reasons_incremental(
  'durango-deflock.DurangoPD.October2025',
  'durango-deflock.DurangoPD.October2025_classified',
  TRUE
);
```

---

### 2. sp_match_agencies_incremental
**File**: `11_sp_match_agencies_incremental.sql`

Matches organization names to agencies using rule-based matching.

**Features**:
- Works on any classified table (parameterized)
- Identifies participating agencies in Colorado
- Stores results in global cache for reuse
- Handles location normalization

**Parameters**:
- `source_classified_table` (STRING): Classified table with org_name column

**Returns**:
- Status message with match counts and participation stats

**Output** (stored in `global_org_name_rule_based_matches`):
- `org_name` (STRING): Original organization name
- `matched_agency` (STRING): Normalized agency name
- `matched_state` (STRING): State code
- `matched_type` (STRING): Agency location
- `confidence` (FLOAT64): Confidence score (0-1)
- `match_type` (STRING): 'Rule-Based'
- `is_participating_agency` (BOOLEAN): Whether in participating agencies list

**Participating Agencies** (Colorado):
- Durango, Telluride, La Plata, Montezuma
- Pagosa, Archuleta, Montrose, Grand Junction
- Mesa County

**Usage**:
```sql
CALL FlockML.sp_match_agencies_incremental(
  'durango-deflock.DurangoPD.October2025_classified'
);
```

---

### 3. sp_generate_standard_analysis
**File**: `12_sp_generate_standard_analysis.sql`

Generates 6 standard analysis tables from enriched data.

**Features**:
- Parameterized for any dataset
- Consistent analysis across all datasets
- Eliminates code duplication
- Focuses on Colorado local agencies

**Parameters**:
- `enriched_table` (STRING): Enriched table with classifications + agency matches
- `output_dataset` (STRING): Dataset where analysis tables are created
- `dataset_label` (STRING): Label for reports (e.g., 'October 2025')

**Returns**:
- Status message with execution duration

**Generated Tables**:

#### 1. local_reason_breakdown
Reason categories by organization.

**Columns**:
- `dataset` (STRING): Dataset label
- `org_name` (STRING): Organization name
- `reason_category` (STRING): Classified category
- `search_count` (INT64): Count of searches
- `pct_of_org` (FLOAT64): Percentage of org's total
- `participating_count` (INT64): From participating agencies
- `no_case_num_count` (INT64): Records without case number

#### 2. local_org_summary
Overall statistics by organization.

**Columns**:
- `dataset` (STRING): Dataset label
- `org_name` (STRING): Organization name
- `total_searches` (INT64): Total searches
- `distinct_reasons_used` (INT64): Unique reason categories
- `participating_searches` (INT64): From participating agencies
- `pct_participating` (FLOAT64): Percentage from participating
- `days_with_searches` (INT64): Days with activity

#### 3. local_participation_status
Participation status breakdown.

**Columns**:
- `dataset` (STRING): Dataset label
- `is_participating_agency` (BOOLEAN): Participating status
- `total_searches` (INT64): Count
- `unique_orgs` (INT64): Number of organizations
- `distinct_reasons` (INT64): Unique categories
- `pct_of_all_searches` (FLOAT64): Percentage

#### 4. local_reason_bucket_distribution
Distribution across reason validity buckets.

**Columns**:
- `dataset` (STRING): Dataset label
- `reason_bucket` (STRING): 'Valid_Reason' or 'Invalid_Reason'
- `reason_category` (STRING): Category
- `count` (INT64): Count
- `pct_of_bucket` (FLOAT64): Percentage within bucket
- `pct_of_all` (FLOAT64): Percentage of total

#### 5. local_invalid_case_analysis
Invalid and case number analysis.

**Columns**:
- `dataset` (STRING): Dataset label
- `reason_category` (STRING): Category (Invalid/Case/OTHER)
- `record_count` (INT64): Count
- `unique_orgs` (INT64): Organizations with these
- `avg_reason_length` (FLOAT64): Average string length

#### 6. local_high_risk_categories
High-risk crime categories analysis.

**Columns**:
- `dataset` (STRING): Dataset label
- `reason_category` (STRING): Category
- `search_count` (INT64): Count
- `unique_agencies` (INT64): Number of agencies
- `participating_agencies` (INT64): From participating
- `pct_of_all_searches` (FLOAT64): Percentage
- `agencies_involved` (STRING): Comma-separated agency list

**High-Risk Categories**:
- Violent_Crime
- Sex_Crime
- Human_Trafficking
- Weapons_Offense
- Kidnapping
- Domestic_Violence

**Usage**:
```sql
CALL FlockML.sp_generate_standard_analysis(
  'durango-deflock.DurangoPD.October2025_enriched',
  'durango-deflock.DurangoPD_analysis',
  'October 2025'
);
```

---

### 4. sp_process_single_dataset
**File**: `13_sp_process_single_dataset.sql`

Master orchestrator for processing a single dataset.

**Features**:
- Reads configuration from dataset_pipeline_config
- Executes all processing steps in order:
  1. Classify reasons
  2. Match agencies
  3. Create enriched view
  4. Generate analysis
- Handles errors and logs completion
- Updates last_processed_timestamp

**Parameters**:
- `config_id` (STRING): Configuration ID from dataset_pipeline_config

**Returns**:
- Status messages for each step
- Completion summary with duration

**Steps**:
1. **Verify Configuration**: Check if config_id exists and is enabled
2. **Classify Reasons**: Call sp_classify_search_reasons_incremental
3. **Match Agencies**: Call sp_match_agencies_incremental
4. **Create Enriched View**: LEFT JOIN classifications with agency matches
5. **Generate Analysis**: Call sp_generate_standard_analysis
6. **Log Results**: Insert success record to dataset_processing_log

**Usage**:
```sql
CALL FlockML.sp_process_single_dataset('durango-oct-2025');
```

**Error Handling**:
- Logs errors to dataset_processing_log
- Re-raises exception for caller to handle
- Allows partial success (e.g., classification succeeds, analysis fails)

---

### 5. sp_process_all_datasets
**File**: `14_sp_process_all_datasets.sql`

Orchestrate processing of all enabled datasets.

**Features**:
- Reads enabled datasets from configuration
- Processes in priority order
- Supports dry-run mode
- Error isolation (one failure doesn't block others)
- Generates summary report

**Parameters**:
- `dry_run` (BOOLEAN, default: FALSE): If TRUE, show what would process

**Returns**:
- List of datasets that would be processed (dry-run mode)
- Execution status for each dataset
- Summary report with success/failure counts

**Dry-Run Mode**:
```sql
CALL FlockML.sp_process_all_datasets(TRUE);
```
Shows which datasets will be processed without executing.

**Normal Mode**:
```sql
CALL FlockML.sp_process_all_datasets(FALSE);
```
Processes all enabled datasets in order.

**Error Handling**:
- Catches errors per dataset
- Logs error details
- Continues with next dataset
- Final report shows success count

**Output Columns** (summary):
- `execution_date` (DATE): Execution date
- `total_runs` (INT64): Total datasets processed
- `successful` (INT64): Successful runs
- `failed` (INT64): Failed runs
- `total_rows_processed` (INT64): Total rows processed
- `new_reasons_added_to_cache` (INT64): New classifications
- `cache_hits` (INT64): Cached classifications used
- `total_cost_usd` (FLOAT64): Total LLM cost

---

## Configuration Table

### dataset_pipeline_config

Stores configuration for all datasets. Used by all procedures.

**Columns**:
- `config_id` (STRING): Unique identifier
- `dataset_project` (STRING): GCP project ID
- `dataset_name` (STRING): BigQuery dataset
- `source_table_name` (STRING): Raw source table
- `enabled` (BOOLEAN): Whether to process
- `priority` (INT64): Processing order
- `output_dataset_name` (STRING): Override output dataset
- `output_suffix` (STRING): Suffix for output tables
- `description` (STRING): Dataset description
- `owner` (STRING): Responsible person
- `created_timestamp` (TIMESTAMP): When registered
- `last_processed_timestamp` (TIMESTAMP): Last processing time

**Example**:
```sql
INSERT INTO FlockML.dataset_pipeline_config VALUES
  ('durango-oct-2025', 'durango-deflock', 'DurangoPD', 'October2025',
   TRUE, 1, NULL, '_classified', 'Durango PD October 2025', 'colin',
   CURRENT_TIMESTAMP(), NULL);
```

---

## Audit Tables

### dataset_processing_log

Records all processing runs for monitoring and cost tracking.

**Columns**:
- `run_id` (STRING): Unique run identifier
- `config_id` (STRING): Configuration ID
- `execution_timestamp` (TIMESTAMP): When started
- `completion_timestamp` (TIMESTAMP): When completed
- `total_rows` (INT64): Rows processed
- `unique_reasons` (INT64): Unique reasons found
- `cache_hits` (INT64): Cached classifications used
- `new_reasons_classified` (INT64): New classifications
- `classification_cost_usd` (FLOAT64): LLM cost
- `processing_status` (STRING): 'SUCCESS', 'ERROR', 'RUNNING'
- `error_message` (STRING): Error details if failed

---

### global_reason_classifications

Global cache of all unique reasons and their classifications.

**Columns**:
- `normalized_reason` (STRING): Normalized reason text
- `reason_category` (STRING): Classified category
- `first_seen_dataset` (STRING): Which dataset first classified it
- `first_classified_timestamp` (TIMESTAMP): When first classified
- `classification_count` (INT64): How many times used
- `last_updated` (TIMESTAMP): Last update time
- `classification_version` (STRING): Schema version

**Benefit**: Eliminates redundant LLM calls across datasets

---

### org_name_rule_based_matches

Global cache of organization name matches.

**Columns**:
- `org_name` (STRING): Original organization name
- `matched_agency` (STRING): Normalized name
- `matched_state` (STRING): State code
- `matched_type` (STRING): Agency type/location
- `confidence` (FLOAT64): Confidence score
- `match_type` (STRING): Matching method
- `is_participating_agency` (BOOLEAN): In participating list
- `created_timestamp` (TIMESTAMP): When created
- `last_updated` (TIMESTAMP): Last update

---

## Calling Procedures Directly

### From SQL

```sql
-- Process a specific dataset
CALL `durango-deflock.FlockML.sp_process_single_dataset`('durango-oct-2025');

-- Process all datasets
CALL `durango-deflock.FlockML.sp_process_all_datasets`(FALSE);

-- Dry run
CALL `durango-deflock.FlockML.sp_process_all_datasets`(TRUE);
```

### From Python

```python
from google.cloud import bigquery

client = bigquery.Client(project='durango-deflock')
job = client.query(
    "CALL `durango-deflock.FlockML.sp_process_single_dataset`('durango-oct-2025')"
)
job.result()
```

---

## Error Handling

### Common Errors

**"Procedure does not exist"**
- Solution: Run sql/procedures/*.sql files to create procedures

**"Table not found"**
- Solution: Check source table name in dataset_pipeline_config

**"Config ID not found"**
- Solution: Register dataset using register_dataset.py

**"Access denied"**
- Solution: Verify BigQuery permissions for your GCP account

### Debug Queries

```sql
-- Check recent errors
SELECT * FROM FlockML.dataset_processing_log
WHERE processing_status = 'ERROR'
ORDER BY execution_timestamp DESC;

-- Check cache status
SELECT
  COUNT(*) AS cached_reasons,
  COUNT(DISTINCT first_seen_dataset) AS contributing_datasets
FROM FlockML.global_reason_classifications;

-- Check configuration
SELECT * FROM FlockML.dataset_pipeline_config
WHERE enabled = TRUE;
```

---

## Performance Notes

### Typical Execution Times (600K row dataset)

- Classification: 2-3 min (first time), 30-60 sec (cached)
- Agency Matching: 30-60 sec
- Analysis Generation: 1-2 min
- **Total**: 5-8 min (first), 2-3 min (cached)

### Cost per Dataset

- First dataset: $0.09 (30K unique reasons × $0.000003)
- Second dataset: $0.006 (200 new reasons, rest cached)
- Third+ datasets: $0.003-$0.006 (minimal new reasons)

### Optimization Tips

1. Use `--parallel` for multiple datasets
2. Monitor cache hit ratio via dataset_processing_log
3. Review high-cost runs for unusual reason patterns
4. Archive old audit logs to save on storage

---

## See Also

- `README_PIPELINE.md` - Comprehensive documentation
- `QUICKSTART.md` - Quick start guide
- `IMPLEMENTATION_CHECKLIST.md` - Implementation status
- `python/orchestrator/register_dataset.py` - Dataset registration
- `python/orchestrator/pipeline_runner.py` - Pipeline orchestration
