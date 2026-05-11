# Troubleshooting Guide

## Automated Multi-Dataset Processing Pipeline

Solutions to common issues and how to diagnose problems.

## Installation & Setup Issues

### Issue: "bq command not found"

**Problem**: BigQuery CLI is not installed or not in PATH.

**Solutions**:
1. Install Google Cloud SDK:
   ```bash
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init
   ```

2. Verify installation:
   ```bash
   bq version
   gcloud config list
   ```

### Issue: "Authentication failed"

**Problem**: Not authenticated with Google Cloud.

**Solutions**:
```bash
# Login interactively
gcloud auth login

# Or set credentials from service account
gcloud auth activate-service-account --key-file=path/to/key.json

# Set default project
gcloud config set project durango-deflock

# Verify authentication
gcloud auth list
```

### Issue: "Permission denied" when running bq queries

**Problem**: GCP account doesn't have BigQuery permissions.

**Solutions**:
1. Ask admin to grant these roles:
   - `roles/bigquery.dataEditor` (read/write data)
   - `roles/bigquery.jobUser` (run queries)

2. Verify permissions:
   ```bash
   gcloud projects get-iam-policy durango-deflock
   ```

### Issue: "Python module not found" (google.cloud)

**Problem**: Python dependencies not installed.

**Solutions**:
```bash
# Install from requirements
pip install -r python/orchestrator/requirements.txt

# Or install directly
pip install google-cloud-bigquery>=3.0.0

# Verify installation
python -c "from google.cloud import bigquery; print('OK')"
```

### Issue: Setup script fails

**Problem**: SQL files are not in expected locations.

**Solutions**:
```bash
# Verify SQL files exist
ls -la sql/setup/
ls -la sql/config/
ls -la sql/procedures/

# Run setup with dry-run first
bash SETUP_PIPELINE.sh --dry-run

# Check bq configuration
bq show durango-deflock.FlockML
```

## Dataset Registration Issues

### Issue: "Config ID not found" error

**Problem**: Dataset hasn't been registered in the configuration table.

**Solutions**:
```bash
# Register the dataset
python python/orchestrator/register_dataset.py \
  --dataset DurangoPD --table November2025

# Verify registration
python python/orchestrator/register_dataset.py --list
```

### Issue: Wrong dataset name in configuration

**Problem**: Source table name doesn't match actual BigQuery table.

**Solutions**:
```bash
# Check actual table in BigQuery
bq ls -t durango-deflock.DurangoPD

# Re-register with correct table name
python python/orchestrator/register_dataset.py \
  --dataset DurangoPD --table October2025

# Check configuration
python python/orchestrator/register_dataset.py --list
```

### Issue: Cannot list datasets

**Problem**: Python script fails to connect to BigQuery.

**Solutions**:
```bash
# Test connection
python -c """
from google.cloud import bigquery
client = bigquery.Client(project='durango-deflock')
datasets = list(client.list_datasets())
print(f'Found {len(datasets)} datasets')
"""

# Check permissions
gcloud projects get-iam-policy durango-deflock \
  --flatten="bindings[].members" \
  --filter="bindings.members:${USER}"
```

## Processing & Execution Issues

### Issue: "Procedure does not exist" error

**Problem**: Stored procedures haven't been created yet.

**Solutions**:
```bash
# Run setup script
bash SETUP_PIPELINE.sh

# Or manually create procedures
for file in sql/procedures/*.sql; do
  bq query --use_legacy_sql=false < "$file"
  echo "Created: $file"
done

# Verify procedures exist
bq ls -r durango-deflock.FlockML | grep PROCEDURE
```

### Issue: "Table not found" error

**Problem**: Source or destination table doesn't exist.

**Solutions**:
```bash
# Check source table exists
bq show durango-deflock.DurangoPD.October2025

# Check output dataset exists
bq ls -d durango-deflock.DurangoPD

# Create output dataset if needed
bq mk --dataset \
  --description "Output dataset" \
  durango-deflock:DurangoPD

# Fix configuration if table name is wrong
python python/orchestrator/register_dataset.py --list
```

### Issue: Pipeline processing very slowly

**Problem**: Sequential processing on multiple large datasets.

**Solutions**:
```bash
# Use parallel processing
python python/orchestrator/pipeline_runner.py --parallel --max-workers 4

# Reduce max_workers if hitting resource limits
python python/orchestrator/pipeline_runner.py --parallel --max-workers 2

# Check BigQuery query performance
bq show -j <job_id>
```

### Issue: "Out of memory" or "Resource exhausted"

**Problem**: Processing table is too large for available memory.

**Solutions**:
1. Reduce dataset size (filter by date range)
2. Process one dataset at a time (sequential)
3. Increase BigQuery slot reservations
4. Check for runaway queries:
   ```bash
   bq ls -j --all_users | head -20
   ```

### Issue: Setup script hangs or times out

**Problem**: Setup script stalls for 5+ minutes when running SQL files

**Cause**: IPv6 connectivity issues with Google Cloud APIs (common on some networks)

**Solution**: The updated scripts now include the fix automatically

```bash
# This is included automatically
export GRPC_DNS_RESOLVER=native
bash SETUP_PIPELINE.sh
```

**If still having issues**:
1. Set the variable manually before running:
   ```bash
   export GRPC_DNS_RESOLVER=native
   bash SETUP_PIPELINE.sh
   ```

2. Or add to your shell profile permanently:
   ```bash
   echo 'export GRPC_DNS_RESOLVER=native' >> ~/.bashrc
   source ~/.bashrc
   ```

**For detailed information**: See `IPv6_CONNECTIVITY_FIX.md`

## Cost & Performance Issues

### Issue: LLM cost unexpectedly high

**Problem**: Many new reasons being classified (cache not helping).

**Solutions**:
```bash
# Check cache hit ratio
bq query --use_legacy_sql=false <<'EOF'
SELECT
  config_id,
  unique_reasons,
  new_reasons_classified,
  ROUND(100.0 * (unique_reasons - new_reasons_classified) / unique_reasons, 1) AS cache_hit_pct,
  classification_cost_usd
FROM `durango-deflock.FlockML.dataset_processing_log`
WHERE processing_status = 'SUCCESS'
ORDER BY execution_timestamp DESC
LIMIT 10;
EOF

# Investigate new reasons
bq query --use_legacy_sql=false <<'EOF'
SELECT reason_category, COUNT(*) as count
FROM `durango-deflock.FlockML.global_reason_classifications`
WHERE DATE(first_classified_timestamp) = CURRENT_DATE()
GROUP BY reason_category
ORDER BY count DESC;
EOF
```

If cache hit ratio is low:
- This is expected for the second dataset if reasons differ significantly
- Check if new dataset has different search patterns
- Monitor costs over time (should stabilize)

### Issue: Processing taking longer than expected

**Problem**: Operations slower than typical execution times.

**Solutions**:
```bash
# Check BigQuery job status
bq ls -j --max_results=20 | head -10

# Monitor BigQuery slots
gcloud compute instances list --filter="name:slot*"

# Check BigQuery quotas
bq show -j <job_id>

# Run smaller test dataset first
python python/orchestrator/pipeline_runner.py --dry-run
```

## Data Quality Issues

### Issue: Reason categories don't look right

**Problem**: Classification seems incorrect or inconsistent.

**Solutions**:
```bash
# Compare classification results
bq query --use_legacy_sql=false <<'EOF'
SELECT
  reason_category,
  COUNT(*) as count,
  ARRAY_AGG(DISTINCT reason LIMIT 5) as sample_reasons
FROM `durango-deflock.DurangoPD.October2025_classified`
WHERE reason_category IS NOT NULL
GROUP BY reason_category
ORDER BY count DESC;
EOF

# Check against old system
SELECT reason_category, COUNT(*) FROM old_table
GROUP BY reason_category
ORDER BY COUNT(*) DESC;

# Identify mismatches
SELECT *
FROM new_classified
WHERE reason_category NOT IN (SELECT reason_category FROM old_classified)
LIMIT 100;
```

### Issue: Agency matching results incorrect

**Problem**: Organizations not matched to correct agencies.

**Solutions**:
```bash
# Check org_name matching
bq query --use_legacy_sql=false <<'EOF'
SELECT
  org_name,
  matched_agency,
  matched_type,
  confidence,
  is_participating_agency
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
WHERE org_name LIKE '%durango%' OR org_name LIKE '%telluride%'
LIMIT 20;
EOF

# Review matching rules
cat sql/procedures/11_sp_match_agencies_incremental.sql | grep -A 20 "normalized_location"

# Test specific organization
bq query --use_legacy_sql=false <<'EOF'
SELECT *
FROM `durango-deflock.FlockML.org_name_rule_based_matches`
WHERE org_name = 'YourOrgName';
EOF
```

### Issue: Analysis tables are empty

**Problem**: Generated analysis tables have no data.

**Solutions**:
```bash
# Check enriched view has data
bq query --use_legacy_sql=false <<'EOF'
SELECT COUNT(*) as row_count
FROM `durango-deflock.DurangoPD.October2025_enriched`;
EOF

# Check local agency filter
bq query --use_legacy_sql=false <<'EOF'
SELECT COUNT(DISTINCT org_name) as orgs
FROM `durango-deflock.DurangoPD.October2025_enriched`
WHERE LOWER(org_name) REGEXP_CONTAINS '(durango|telluride|la plata|montezuma|pagosa|archuleta|montrose|grand junction|mesa)';
EOF

# If zero, adjust filter in sp_generate_standard_analysis
# Check actual org_names in source
bq query --use_legacy_sql=false <<'EOF'
SELECT DISTINCT org_name
FROM `durango-deflock.DurangoPD.October2025_enriched`
ORDER BY org_name;
EOF
```

## Monitoring & Debugging

### Check Pipeline Health

```bash
# Overview of all datasets
python python/orchestrator/register_dataset.py --list

# Recent processing history
bq query --use_legacy_sql=false <<'EOF'
SELECT
  config_id,
  execution_timestamp,
  processing_status,
  total_rows,
  new_reasons_classified,
  classification_cost_usd
FROM `durango-deflock.FlockML.dataset_processing_log`
ORDER BY execution_timestamp DESC
LIMIT 20;
EOF

# Cost summary by date
bq query --use_legacy_sql=false <<'EOF'
SELECT
  DATE(execution_timestamp) as date,
  COUNT(*) as runs,
  SUM(total_rows) as rows,
  SUM(new_reasons_classified) as new_classifications,
  ROUND(SUM(classification_cost_usd), 4) as cost
FROM `durango-deflock.FlockML.dataset_processing_log`
WHERE processing_status = 'SUCCESS'
GROUP BY date
ORDER BY date DESC;
EOF
```

### Check for Errors

```bash
# Find processing errors
bq query --use_legacy_sql=false <<'EOF'
SELECT
  config_id,
  execution_timestamp,
  error_message,
  error_stack_trace
FROM `durango-deflock.FlockML.dataset_processing_log`
WHERE processing_status = 'ERROR'
ORDER BY execution_timestamp DESC;
EOF

# Check logs file
tail -100 pipeline_execution.log
grep "ERROR" pipeline_execution.log
```

### Monitor Cache Status

```bash
# Cache utilization
bq query --use_legacy_sql=false <<'EOF'
SELECT
  COUNT(*) as total_cached,
  COUNT(DISTINCT first_seen_dataset) as datasets_contributed,
  MAX(last_updated) as last_update,
  MIN(first_classified_timestamp) as cache_start
FROM `durango-deflock.FlockML.global_reason_classifications`;
EOF

# Cache efficiency over time
bq query --use_legacy_sql=false <<'EOF'
SELECT
  DATE(execution_timestamp) as date,
  COUNT(*) as runs,
  AVG(new_reasons_classified) as avg_new_per_run,
  SUM(cache_hits) as total_cache_hits
FROM `durango-deflock.FlockML.dataset_processing_log`
WHERE processing_status = 'SUCCESS'
GROUP BY date
ORDER BY date DESC;
EOF
```

## Log Analysis

### Check Python execution logs

```bash
# View execution logs
cat pipeline_execution.log

# Find errors
grep -i error pipeline_execution.log

# Find specific dataset
grep "durango-oct-2025" pipeline_execution.log

# Follow live logs during execution
tail -f pipeline_execution.log
```

### Check BigQuery job logs

```bash
# Get job details
bq show -j <job_id>

# Show job status
bq ls -j --all_users | grep FAILED

# Get failed job details
bq show -j <failed_job_id>
```

## Recovery & Reset

### Clear cache (restart learning)

**Warning**: This will cause next dataset to re-classify all reasons (high cost).

```bash
# Delete cached classifications
bq delete --force durango-deflock.FlockML.global_reason_classifications

# Delete cached matches
bq delete --force durango-deflock.FlockML.org_name_rule_based_matches

# Recreate tables
bash SETUP_PIPELINE.sh
```

### Restart a failed dataset

```bash
# Option 1: Re-run through orchestrator
python python/orchestrator/pipeline_runner.py

# Option 2: Re-run specific dataset
python python/orchestrator/register_dataset.py --list
# Find config_id, then:
bq query "CALL FlockML.sp_process_single_dataset('durango-oct-2025')"

# Option 3: Manually process steps
bq query --use_legacy_sql=false <<'EOF'
CALL FlockML.sp_classify_search_reasons_incremental(
  'durango-deflock.DurangoPD.October2025',
  'durango-deflock.DurangoPD.October2025_classified',
  TRUE
);
EOF
```

### Disable problematic dataset

```bash
# Disable temporarily while investigating
python python/orchestrator/register_dataset.py \
  --unregister durango-problematic-dataset

# Re-enable when fixed
bq query <<'EOF'
UPDATE `durango-deflock.FlockML.dataset_pipeline_config`
SET enabled = TRUE
WHERE config_id = 'durango-problematic-dataset';
EOF
```

## Getting Help

### Collect diagnostic information

When reporting issues, include:

```bash
# Python version
python --version

# gcloud version
gcloud --version

# bq version
bq version

# Check BigQuery access
bq ls -p

# Check dataset exists
bq ls durango-deflock.FlockML

# Check procedures
bq ls -r durango-deflock.FlockML | grep PROCEDURE

# Execution log
tail -50 pipeline_execution.log
```

### Debug Script

Save as `diagnose.sh`:

```bash
#!/bin/bash
echo "=== Diagnostic Information ==="
echo "Python: $(python --version)"
echo "bq: $(bq version | head -1)"
echo "gcloud: $(gcloud --version | head -1)"
echo ""
echo "BigQuery Access:"
bq ls -p | head -5
echo ""
echo "Dataset Tables:"
bq ls -t durango-deflock.FlockML | head -10
echo ""
echo "Procedures:"
bq ls -r durango-deflock.FlockML | grep PROCEDURE | head -5
echo ""
echo "Recent Errors:"
grep -i error pipeline_execution.log | tail -5
```

Run it:
```bash
bash diagnose.sh
```

---

**Last Updated**: 2025-03-17
**Status**: Complete ✓

For additional help, see:
- `README_PIPELINE.md` - Full documentation
- `QUICKSTART.md` - Getting started
- `sql/procedures/README.md` - Procedure reference
