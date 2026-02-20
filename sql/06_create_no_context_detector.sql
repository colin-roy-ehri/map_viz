-- Phase 3.2: Create "No Context" Detection Function
-- This UDF identifies searches with neither case_num nor adequate reason
-- Used to flag records that lack sufficient context for investigation

CREATE OR REPLACE FUNCTION `durango-deflock.FlockML.is_no_context`(
  reason STRING,
  case_num STRING
)
RETURNS BOOL AS (
  CASE
    -- No reason provided
    WHEN reason IS NULL OR LENGTH(TRIM(reason)) < 2 THEN TRUE

    -- Case number is missing
    WHEN case_num IS NULL THEN (
      -- AND reason is inadequate
      CASE
        WHEN TRIM(reason) IN ('.', '..', '...', 'n/a', 'N/A', 'na', 'NA', '-', '--') THEN TRUE
        WHEN LENGTH(TRIM(reason)) = 1 THEN TRUE  -- Single character
        WHEN REGEXP_CONTAINS(reason, r'^[^a-zA-Z0-9]+$') THEN TRUE  -- Only special chars
        WHEN LOWER(TRIM(reason)) IN ('tbd', 'unknown', 'unk', 'none', 'null', 'test') THEN TRUE
        ELSE FALSE
      END
    )

    ELSE FALSE
  END
);

