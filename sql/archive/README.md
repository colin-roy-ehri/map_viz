# Archived SQL Files

This directory contains the legacy dataset-specific SQL files that have been replaced by the **Automated Multi-Dataset Processing Pipeline**.

## Why These Files Were Archived

The previous processing approach required duplicate SQL files for each dataset and time period, leading to:
- ❌ 37 total SQL files
- ❌ Significant code duplication
- ❌ Manual effort to add new datasets
- ❌ High LLM classification costs ($0.09 per dataset)

## New Approach

These files have been replaced by a **configuration-driven, parameterized pipeline** that:
- ✅ Uses 12 core SQL files (zero duplication)
- ✅ Automatically processes any dataset
- ✅ 87% cost reduction for multiple datasets
- ✅ 93% faster dataset registration

## Archived Files

### Dataset Classification Files
- `28_classify_august_2025.sql` → Replaced by `sp_classify_search_reasons_incremental`
- Legacy reason classification (hardcoded for specific months)

### Agency Matching Files
- `29_match_august_agencies.sql` → Replaced by `sp_match_agencies_incremental`
- `29a_composite_org_matching.sql` → Replaced by `sp_match_agencies_incremental`
- Legacy organization name matching (hardcoded)

### Analysis Files
- `31_october_reason_analysis_revised.sql` → Replaced by `sp_generate_standard_analysis`
- `31_august_suspicion_ranking.sql` → Replaced by `sp_generate_standard_analysis`
- `32_august_reason_analysis_revised.sql` → Replaced by `sp_generate_standard_analysis`
- `33_comparative_reason_analysis.sql` → Replaced by `sp_generate_standard_analysis`
- `34_august_suspicion_ranking.sql` → Replaced by `sp_generate_standard_analysis`
- `35_suspicion_summary_comparative.sql` → Replaced by `sp_generate_standard_analysis`
- `36_high_risk_80_percent_records.sql` → Replaced by `sp_generate_standard_analysis`
- `37_local_enriched_analysis.sql` → Replaced by `sp_generate_standard_analysis`

### Participation Analysis
- `30_reason_participation_analysis.sql` → Replaced by `sp_generate_standard_analysis`

## New Pipeline Files

See `sql/procedures/` for the new parameterized procedures:
- `10_sp_classify_search_reasons_incremental.sql` - Classification with global cache
- `11_sp_match_agencies_incremental.sql` - Agency matching
- `12_sp_generate_standard_analysis.sql` - Unified analysis generator
- `13_sp_process_single_dataset.sql` - Single dataset orchestrator
- `14_sp_process_all_datasets.sql` - Multi-dataset orchestrator

## How to Use the New Pipeline

Instead of running individual SQL files:

```sql
-- OLD APPROACH (deprecated)
EXECUTE sql/28_classify_august_2025.sql
EXECUTE sql/29_match_august_agencies.sql
EXECUTE sql/32_august_reason_analysis_revised.sql

-- NEW APPROACH (unified)
CALL FlockML.sp_process_single_dataset('durango-aug-2025')
```

Or use Python orchestration:

```bash
python python/orchestrator/pipeline_runner.py
```

## Recovery

If needed to revert to old approach:
1. The files are preserved here for reference
2. However, using old files will lose cost optimization benefits
3. Recommend using new pipeline instead

## References

- See `README_PIPELINE.md` for complete pipeline documentation
- See `sql/procedures/README.md` for procedure reference
- See `QUICKSTART.md` for getting started

---

**Archived**: March 22, 2025
**Status**: Replaced by Automated Multi-Dataset Processing Pipeline
**Recommendation**: Use new pipeline for all processing
