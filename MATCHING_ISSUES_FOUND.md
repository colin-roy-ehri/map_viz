# Critical Issues Found in Rule-Based Agency Matching

## Problem Summary

The synonym matching query (`sql/25_add_synonym_matching.sql`) was returning 0 results because of fundamental mismatches between the org_name parsing format and the participatingAgencies table structure.

## Root Causes Identified

### 1. STATE Column Mismatch ❌
- **Parsed org_names extract**: State codes like `FL`, `TX`, `CO`, `ID`, `GA`
- **participatingAgencies table contains**: Full state names like `FLORIDA`, `TEXAS`, `COLORADO`
- **Join condition**: `p.state_code = pa.STATE`
- **Result**: `'FL' != 'FLORIDA'` → NO MATCHES

### 2. TYPE Column Mismatch ❌
- **Matching query expected**: TYPE column to contain `'Police Department'`, `'Sheriff's Office'`, etc.
- **participatingAgencies table actually contains**: `'County'`, `'Municipality'`, `'State'`, `'State Agency'`
- **Result**: TYPE synonym matching impossible, 0 results

### 3. Law Enforcement Type Location ⚠️
- **The real law enforcement type** (Police, Sheriff, etc.) is **embedded in the agency NAME itself**
  - Example: `"Seminole County Sheriff's Office"` - contains "Sheriff's Office"
  - Example: `"Houston Police Department"` - contains "Police Department"
- **Solution**: Need to search for keywords in the LAW ENFORCEMENT AGENCY name, not TYPE column

## Data Structure Analysis

### Participating Agencies Table
```
Column: LAW ENFORCEMENT AGENCY  | Sample Values
─────────────────────────────────────────────────────────
"Pinellas County Sheriff's Office"
"Houston Police Department"
"Miami-Dade Police Department"
"Seminole County Sheriff's Office"
```

### Parsed org_names
```
org_name: "Seminole County FL SO"
→ state_code: "FL" (needs → "FLORIDA")
→ agency_type: "SO" (needs to match "Sheriff's Office" in name)
→ location_raw: "Seminole County"
```

### participatingAgencies STATE values
- FLORIDA (342 agencies)
- TEXAS (296 agencies)
- TENNESSEE (63 agencies)
- PENNSYLVANIA (58 agencies)
- ALABAMA (51 agencies)
- etc.

## Solution Implemented

### Updated `sql/25_add_synonym_matching.sql`

**Key Fixes:**

1. **Added state_mapping CTE** - Converts state codes to full names inline:
   ```sql
   'FL' → 'FLORIDA'
   'TX' → 'TEXAS'
   'CO' → 'COLORADO'
   ```

2. **Fixed state join condition**:
   ```sql
   OLD: ON p.state_code = pa.STATE
   NEW: ON sm.state_name = pa.STATE  (after joining with state_mapping)
   ```

3. **Changed type matching from TYPE column to agency NAME**:
   ```sql
   OLD: pa.TYPE IN ('Police Department', 'Police', 'PD')
   NEW: UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%POLICE%'

   OLD: pa.TYPE IN ('Sheriff\'s Office', 'Sheriff Office', 'Sheriff', 'SO')
   NEW: UPPER(pa.`LAW ENFORCEMENT AGENCY`) LIKE '%SHERIFF%'
   ```

## Expected Results After Fix

### Matching Example
- org_name: `"Seminole County FL SO"`
  - state_code: `"FL"` → state_name: `"FLORIDA"` ✓
  - agency_type: `"SO"`
  - location_raw: `"Seminole County"`
- Matching query will now:
  1. Look for agencies in FLORIDA state ✓
  2. With "Seminole County" in the name ✓
  3. With "Sheriff" in the name (matching "SO") ✓
  4. Result: **"Seminole County Sheriff's Office"** ← Should match!

## Outstanding Issues

### BigQuery Performance
The corrected query is timing out when executed. This could be due to:
1. Large JOIN operations (498 unique org_names × 1,424 agencies)
2. Multiple LIKE operations on large string fields
3. BigQuery resource constraints

### Next Steps

1. **Test simple match first** - Verify basic joining works with subset of data
2. **Optimize query** - Consider:
   - Materialized views for state_mapping
   - STRUCT-based matching instead of LIKE
   - Two-phase matching (state first, then location)
3. **If performance remains issue** - Consider breaking into batches or using different approach

## Files Modified
- `/home/colin/map_viz/sql/25_add_synonym_matching.sql` - Fixed state mapping and type matching logic
