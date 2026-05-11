#!/bin/bash
# ============================================================================
# Diagnostic Script for Pipeline Setup
# ============================================================================
# This script checks your environment and provides diagnostics if setup fails.
#
# Usage:
#   bash DIAGNOSE.sh
# ============================================================================

echo "========================================================================="
echo "PIPELINE DIAGNOSTIC TOOL"
echo "========================================================================="
echo ""

# Fix IPv6 timeout issues with Google Cloud APIs
# Set native DNS resolver to avoid IPv6 timeout on some networks
export GRPC_DNS_RESOLVER=native

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ISSUES=0

# 1. Check gcloud
echo -e "${BLUE}1. Checking gcloud CLI...${NC}"
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}✗ gcloud CLI not found${NC}"
    echo "  Install: https://cloud.google.com/sdk/docs/install"
    ((ISSUES++))
else
    echo -e "${GREEN}✓ gcloud CLI installed${NC}"
fi

# 2. Check bq
echo ""
echo -e "${BLUE}2. Checking BigQuery CLI...${NC}"
if ! command -v bq &> /dev/null; then
    echo -e "${RED}✗ bq CLI not found${NC}"
    echo "  Install: gcloud components install bq"
    ((ISSUES++))
else
    echo -e "${GREEN}✓ BigQuery CLI installed${NC}"
fi

# 3. Check Python
echo ""
echo -e "${BLUE}3. Checking Python...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python 3 not found${NC}"
    ((ISSUES++))
else
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ $PYTHON_VERSION${NC}"
fi

# 4. Check gcloud authentication
echo ""
echo -e "${BLUE}4. Checking gcloud authentication...${NC}"
if gcloud auth list --filter=status:ACTIVE --format="value(account)" > /dev/null 2>&1; then
    ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo -e "${GREEN}✓ Authenticated as: $ACCOUNT${NC}"
else
    echo -e "${RED}✗ No active gcloud authentication${NC}"
    echo "  Fix: gcloud auth login"
    ((ISSUES++))
fi

# 5. Check project
echo ""
echo -e "${BLUE}5. Checking BigQuery project...${NC}"
PROJECT_ID="durango-deflock"
if gcloud config get-value project > /dev/null 2>&1; then
    CURRENT_PROJECT=$(gcloud config get-value project)
    echo "  Default project: $CURRENT_PROJECT"

    if [[ "$CURRENT_PROJECT" != "$PROJECT_ID" ]]; then
        echo -e "${YELLOW}⚠️  Default project is not $PROJECT_ID${NC}"
        echo "  Set: gcloud config set project $PROJECT_ID"
    fi
fi

if bq ls --project_id="$PROJECT_ID" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Can access project: $PROJECT_ID${NC}"
else
    echo -e "${RED}✗ Cannot access project: $PROJECT_ID${NC}"
    echo "  Check permissions and project ID"
    ((ISSUES++))
fi

# 6. Check BigQuery dataset
echo ""
echo -e "${BLUE}6. Checking BigQuery dataset...${NC}"
if bq ls --project_id="$PROJECT_ID" --format=json 2>/dev/null | grep -q "FlockML"; then
    echo -e "${GREEN}✓ FlockML dataset exists${NC}"
else
    echo -e "${YELLOW}⚠️  FlockML dataset not found${NC}"
    echo "  It will be created by setup script or manually with:"
    echo "  bq mk --dataset --description 'Flock ML Pipeline' durango-deflock:FlockML"
fi

# 7. Check SQL files
echo ""
echo -e "${BLUE}7. Checking SQL files...${NC}"
SQL_COUNT=$(find sql/setup sql/config sql/procedures -name "*.sql" 2>/dev/null | wc -l)
echo "  Found $SQL_COUNT SQL files"

REQUIRED_FILES=(
    "sql/setup/05_create_global_reason_cache.sql"
    "sql/setup/06_create_processing_audit.sql"
    "sql/config/20_create_dataset_config.sql"
    "sql/procedures/10_sp_classify_search_reasons_incremental.sql"
    "sql/procedures/11_sp_match_agencies_incremental.sql"
    "sql/procedures/12_sp_generate_standard_analysis.sql"
    "sql/procedures/13_sp_process_single_dataset.sql"
    "sql/procedures/14_sp_process_all_datasets.sql"
)

MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}✗ Missing: $file${NC}"
        ((MISSING++))
    fi
done

if [[ $MISSING -eq 0 ]]; then
    echo -e "${GREEN}✓ All required SQL files present${NC}"
else
    echo -e "${RED}✗ Missing $MISSING required SQL files${NC}"
    ((ISSUES++))
fi

# 8. Check Python files
echo ""
echo -e "${BLUE}8. Checking Python files...${NC}"
if [[ -d "python/orchestrator" ]]; then
    PY_COUNT=$(find python/orchestrator -name "*.py" 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ Found $PY_COUNT Python files${NC}"
else
    echo -e "${RED}✗ python/orchestrator directory not found${NC}"
    ((ISSUES++))
fi

# 9. Check Python dependencies
echo ""
echo -e "${BLUE}9. Checking Python dependencies...${NC}"
if python3 -c "from google.cloud import bigquery" 2>/dev/null; then
    echo -e "${GREEN}✓ google-cloud-bigquery is installed${NC}"
else
    echo -e "${YELLOW}⚠️  google-cloud-bigquery not installed${NC}"
    echo "  Install: pip install -r python/orchestrator/requirements.txt"
fi

# 10. Check documentation
echo ""
echo -e "${BLUE}10. Checking documentation...${NC}"
DOCS=(
    "QUICKSTART.md"
    "README_PIPELINE.md"
    "TROUBLESHOOTING.md"
    "SETUP_PIPELINE.sh"
)

MISSING_DOCS=0
for doc in "${DOCS[@]}"; do
    if [[ ! -f "$doc" ]]; then
        echo -e "${RED}✗ Missing: $doc${NC}"
        ((MISSING_DOCS++))
    fi
done

if [[ $MISSING_DOCS -eq 0 ]]; then
    echo -e "${GREEN}✓ All documentation files present${NC}"
else
    echo -e "${YELLOW}⚠️  Missing $MISSING_DOCS documentation files${NC}"
fi

# Summary
echo ""
echo "========================================================================="
echo "DIAGNOSTIC SUMMARY"
echo "========================================================================="

if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed! You can run setup:${NC}"
    echo "  bash SETUP_PIPELINE.sh"
else
    echo -e "${RED}✗ Found $ISSUES issue(s)${NC}"
    echo ""
    echo "Common fixes:"
    echo "  1. Authenticate: gcloud auth login"
    echo "  2. Set project: gcloud config set project durango-deflock"
    echo "  3. Install deps: pip install -r python/orchestrator/requirements.txt"
    echo "  4. Check permissions: gcloud projects get-iam-policy durango-deflock"
fi

echo ""
echo "For more help, see: TROUBLESHOOTING.md"
echo "========================================================================="

exit $ISSUES
