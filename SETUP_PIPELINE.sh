#!/bin/bash
# ============================================================================
# Pipeline Setup Script
# ============================================================================
# This script sets up the entire automated multi-dataset processing pipeline.
# It runs all necessary SQL files in the correct order and creates tables/procedures.
#
# Usage:
#   bash SETUP_PIPELINE.sh
#   bash SETUP_PIPELINE.sh --dry-run
#   bash SETUP_PIPELINE.sh --skip-auth-check
# ============================================================================

DRY_RUN=false
SKIP_AUTH=false
PROJECT_ID="durango-deflock"
FAILED_FILES=0
SUCCESSFUL_FILES=0

# Fix IPv6 timeout issues with Google Cloud APIs
# Set native DNS resolver to avoid IPv6 timeout on some networks
export GRPC_DNS_RESOLVER=native

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            ;;
        --skip-auth-check)
            SKIP_AUTH=true
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

if [[ "$DRY_RUN" == true ]]; then
    echo "⚠️  DRY RUN MODE - No changes will be made"
fi

echo "========================================================================="
echo "Automated Multi-Dataset Processing Pipeline - Setup Script"
echo "========================================================================="
echo "Project: $PROJECT_ID"
echo "Timestamp: $(date)"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check BigQuery authentication
check_auth() {
    if [[ "$SKIP_AUTH" == true ]]; then
        echo -e "${BLUE}ℹ️ Skipping authentication check${NC}"
        return 0
    fi

    echo -e "${BLUE}Checking BigQuery authentication (timeout: 15s)...${NC}"
    
    # Check gcloud auth with timeout
    if ! timeout 15 gcloud auth list --filter=status:ACTIVE --format="value(account)" > /dev/null 2>&1; then
        echo -e "${RED}✗ No active gcloud authentication found or timeout${NC}"
        echo "Run: gcloud auth login"
        return 1
    fi

    echo -e "${BLUE}Checking BigQuery project access (timeout: 15s)...${NC}"
    
    # Check BigQuery access with timeout
    if ! timeout 15 bq ls --project_id="$PROJECT_ID" > /dev/null 2>&1; then
        echo -e "${RED}✗ Cannot access BigQuery project: $PROJECT_ID${NC}"
        echo "Check project ID and permissions"
        return 1
    fi

    echo -e "${GREEN}✓ Authentication successful${NC}"
    return 0
}

# Function to run SQL file with timeout
run_sql_file() {
    local sql_file=$1
    local description=$2
    local timeout=300  # 5 minutes

    if [[ ! -f "$sql_file" ]]; then
        echo -e "${RED}✗ File not found: $sql_file${NC}"
        ((FAILED_FILES++))
        return 1
    fi

    echo -e "${YELLOW}Running: $description${NC}"
    echo "  File: $sql_file"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${GREEN}  [DRY RUN] Would execute${NC}"
        ((SUCCESSFUL_FILES++))
        return 0
    fi

    # Run with timeout to prevent hanging
    if timeout $timeout bq query --use_legacy_sql=false < "$sql_file" > /tmp/bq_output.log 2>&1; then
        echo -e "${GREEN}✓ Success${NC}"
        ((SUCCESSFUL_FILES++))
        return 0
    else
        local exit_code=$?
        echo -e "${RED}✗ Failed (exit code: $exit_code)${NC}"

        # Show last few lines of error
        if [[ -f /tmp/bq_output.log ]]; then
            echo -e "${RED}Error details:${NC}"
            tail -5 /tmp/bq_output.log | sed 's/^/  /'
        fi

        ((FAILED_FILES++))
        return 1
    fi
}

# =========================================================================
# Check Authentication
# =========================================================================
if ! check_auth; then
    echo ""
    echo -e "${RED}Setup cannot proceed without BigQuery authentication${NC}"
    echo "Run: gcloud auth login"
    exit 1
fi

# =========================================================================
# Phase 1: Create Central Reference Tables
# =========================================================================
echo ""
echo "Phase 1: Creating Central Reference Tables"
echo "==========================================================================="

run_sql_file "sql/setup/05_create_global_reason_cache.sql" \
    "Global reason classification cache"

run_sql_file "sql/setup/06_create_processing_audit.sql" \
    "Processing audit table"

run_sql_file "sql/config/20_create_dataset_config.sql" \
    "Dataset configuration table"

run_sql_file "sql/config/21_register_2025_datasets.sql" \
    "Register all 2025 monthly datasets"

# =========================================================================
# Phase 2: Create Procedures
# =========================================================================
echo ""
echo "Phase 2: Creating Processing Procedures"
echo "==========================================================================="

run_sql_file "sql/procedures/10_sp_classify_search_reasons_incremental.sql" \
    "Incremental classification procedure (with global cache)"

run_sql_file "sql/procedures/11_sp_match_agencies_incremental.sql" \
    "Parameterized agency matching procedure"

run_sql_file "sql/procedures/12_sp_generate_standard_analysis.sql" \
    "Parameterized analysis generation procedure"

run_sql_file "sql/procedures/13_sp_process_single_dataset.sql" \
    "Single dataset processor"

run_sql_file "sql/procedures/14_sp_process_all_datasets.sql" \
    "Multi-dataset orchestrator"

# =========================================================================
# Setup Complete
# =========================================================================
echo ""
echo "========================================================================="
echo "SETUP SUMMARY"
echo "========================================================================="
echo "Successful: $SUCCESSFUL_FILES"
echo "Failed: $FAILED_FILES"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${BLUE}DRY RUN COMPLETE - No changes were made${NC}"
elif [[ $FAILED_FILES -eq 0 ]]; then
    echo -e "${GREEN}✓ SETUP COMPLETE${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Register datasets:"
    echo "     python python/orchestrator/register_dataset.py --list"
    echo ""
    echo "  2. Run the pipeline:"
    echo "     python python/orchestrator/pipeline_runner.py --dry-run"
    echo "     python python/orchestrator/pipeline_runner.py"
    echo ""
    echo "  3. Check results:"
    echo "     bq query 'SELECT * FROM durango-deflock.FlockML.dataset_processing_log LIMIT 5'"
else
    echo -e "${RED}✗ SETUP FAILED${NC}"
    echo "Some files failed to execute. Check errors above."
    echo ""
    echo "Troubleshooting:"
    echo "  • Check BigQuery permissions: gcloud projects get-iam-policy $PROJECT_ID"
    echo "  • Verify dataset exists: bq ls $PROJECT_ID:FlockML"
    echo "  • Check connection: bq ls --project_id=$PROJECT_ID"
    echo ""
    echo "To retry with more verbose output:"
    echo "  bash SETUP_PIPELINE.sh 2>&1 | tee setup.log"
fi

echo "========================================================================="
echo ""
echo "See README_PIPELINE.md for detailed documentation."
echo "========================================================================="

# Exit with error code if any files failed
if [[ $FAILED_FILES -gt 0 ]]; then
    exit 1
fi
