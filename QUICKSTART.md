# Quick Start Guide

## Automated Multi-Dataset Processing Pipeline

Get the pipeline up and running in 5 minutes.

## Prerequisites

- Google Cloud project with BigQuery access
- `bq` command-line tool installed
- Python 3.7+
- Google Cloud authentication configured

## Installation (5 minutes)

### Step 1: Make setup script executable

```bash
chmod +x SETUP_PIPELINE.sh
chmod +x python/orchestrator/*.py
```

### Step 2: Install Python dependencies

```bash
pip install -r python/orchestrator/requirements.txt
```

### Step 3: Run setup script to create all tables and procedures

```bash
bash SETUP_PIPELINE.sh
```

This creates:
- Global reason classification cache
- Dataset configuration table
- Processing audit log
- 5 stored procedures for orchestration

## Quick Usage

### 1. Register datasets (30 seconds)

```bash
# List current datasets
python python/orchestrator/register_dataset.py --list

# Add a new dataset
python python/orchestrator/register_dataset.py \
  --dataset DurangoPD --table November2025 --priority 3
```

### 2. Preview what will be processed (10 seconds)

```bash
python python/orchestrator/pipeline_runner.py --dry-run
```

### 3. Run the pipeline

**Sequential (default):**
```bash
python python/orchestrator/pipeline_runner.py
```

**Parallel (faster for multiple datasets):**
```bash
python python/orchestrator/pipeline_runner.py --parallel --max-workers 3
```

### 4. Check results

```bash
# View processing history
python python/orchestrator/register_dataset.py --list

# Check cost savings
bq query --use_legacy_sql=false <<'EOF'
SELECT
  DATE(execution_timestamp) AS date,
  COUNT(*) AS runs,
  SUM(new_reasons_classified) AS new_classifications,
  ROUND(SUM(classification_cost_usd), 4) AS cost
FROM `durango-deflock.FlockML.dataset_processing_log`
GROUP BY date
ORDER BY date DESC
LIMIT 10;
EOF
```

## Common Tasks

### Add a new dataset from a new agency

```bash
# 1. Register
python python/orchestrator/register_dataset.py \
  --dataset TelluridePD --table October2025 --priority 10

# 2. Process
python python/orchestrator/pipeline_runner.py --dry-run
python python/orchestrator/pipeline_runner.py

# 3. Verify
python python/orchestrator/register_dataset.py --list
```

### Process multiple datasets in parallel

```bash
# Register several datasets first
for dataset in November2025 December2025; do
  python python/orchestrator/register_dataset.py \
    --dataset DurangoPD --table $dataset
done

# Process in parallel
python python/orchestrator/pipeline_runner.py --parallel --max-workers 3
```

### Disable a dataset

```bash
python python/orchestrator/register_dataset.py --unregister durango-november-2025
```

### Monitor performance

```bash
# Check pipeline health
bq query --use_legacy_sql=false <<'EOF'
SELECT
  c.config_id,
  c.source_table_name,
  c.last_processed_timestamp,
  l.processing_status,
  l.total_rows,
  ROUND(l.classification_cost_usd, 4) AS cost
FROM `durango-deflock.FlockML.dataset_pipeline_config` c
LEFT JOIN `durango-deflock.FlockML.dataset_processing_log` l
  ON c.config_id = l.config_id
  AND l.execution_timestamp = c.last_processed_timestamp
WHERE c.enabled = TRUE
ORDER BY c.priority;
EOF
```

## Output Locations

Each dataset produces tables in its dataset:

```
durango-deflock.DurangoPD.October2025_classified          # Classified reasons
durango-deflock.DurangoPD.October2025_classified_enriched # With agency matches
durango-deflock.DurangoPD_analysis.local_reason_breakdown # Analysis tables
durango-deflock.DurangoPD_analysis.local_org_summary
durango-deflock.DurangoPD_analysis.local_participation_status
durango-deflock.DurangoPD_analysis.local_reason_bucket_distribution
durango-deflock.DurangoPD_analysis.local_invalid_case_analysis
durango-deflock.DurangoPD_analysis.local_high_risk_categories
```

## Cost Savings

| Scenario | Cost | Savings |
|----------|------|---------|
| Dataset 1 only | $0.09 | — |
| Dataset 2 (reusing cache) | $0.006 | 93% |
| 10 datasets | $0.12 | 87% |

The global reason cache eliminates redundant LLM calls for reasons already classified.

## Troubleshooting

### Error: "Config ID not found"
→ Register the dataset first using `register_dataset.py`

### Error: "Procedure not found"
→ Run setup script: `bash SETUP_PIPELINE.sh`

### High LLM cost on second dataset
→ Check if reasons are significantly different from first dataset
→ Run: `bq query "SELECT COUNT(DISTINCT reason_category) FROM ..."`

### Pipeline taking too long
→ Use parallel processing: `--parallel --max-workers 4`

## Next Steps

1. **Read full documentation**: `README_PIPELINE.md`
2. **Check implementation**: `IMPLEMENTATION_CHECKLIST.md`
3. **Monitor costs**: Use queries in README_PIPELINE.md section "Monitoring & Debugging"
4. **Add more datasets**: Use `register_dataset.py` for new agencies/dates

## Help

For detailed information, see:
- **Usage guide**: `README_PIPELINE.md`
- **Implementation details**: `IMPLEMENTATION_CHECKLIST.md`
- **SQL reference**: `sql/procedures/README.md` (coming soon)

For issues:
- Check `pipeline_execution.log` for error details
- Review BigQuery console for query errors
- Run `--dry-run` to preview without executing

---

**Current Status**: Ready for production use ✓
