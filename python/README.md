# Agency Geocoding System

Geocodes police agency locations using OpenStreetMap Nominatim API and stores results in BigQuery.

## Overview

This system extracts unique police agencies from Flock search data, parses their names to extract city/state, and geocodes them to get latitude/longitude coordinates for map visualization.

**Key Features:**
- Automatic org_name parsing: "Houston TX PD" → city="Houston", state="TX"
- OpenStreetMap Nominatim API integration (free, no key required)
- Rate limiting: 1 request/second (complies with Nominatim usage policy)
- Incremental processing: Only geocodes new agencies
- Confidence scores: Assesses geocoding accuracy (high/medium/low)
- Comprehensive error handling and logging

**Performance:**
- ~3,500 unique agencies
- ~1 hour for complete geocoding run at 1 req/sec
- Free (Nominatim is free tier, no API key needed)

## Setup

### Prerequisites
- Python 3.8+
- Google Cloud SDK with authenticated credentials (`gcloud auth application-default login`)
- Internet access to Nominatim API

### Installation

1. Create and activate virtual environment:
```bash
cd /home/colin/map_viz/python
python3 -m venv venv
source venv/bin/activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Authenticate with Google Cloud:
```bash
gcloud auth application-default login
```

## Usage

### Basic Execution

```bash
cd /home/colin/map_viz/python
source venv/bin/activate
python geocode_agencies.py
```

### Modify Source Tables

Edit `geocode_agencies.py` and update the `source_tables` list in `main()`:

```python
source_tables = [
    'durango-deflock.DurangoPD.October2025',
    'durango-deflock.DurangoPD.November2025',
    # Add more tables as needed
]
```

### Monitor Progress

The script logs progress in real-time:
```
[1/3500] Processing: Houston TX PD
  ✓ Geocoded: 29.7604, -95.3698 (high)
[2/3500] Processing: Dallas TX PD
  ✓ Geocoded: 32.7767, -96.7970 (high)
```

## Architecture

### OrgNameParser

Parses police agency names into city, state, agency type components.

**Supported Formats:**
- `"Houston TX PD"` → city="Houston", state="TX"
- `"Harris County TX SO"` → city="Harris County", state="TX"
- `"Cleveland OH Division of Police"` → city="Cleveland", state="OH"
- `"City ST"` → city="City", state="ST" (medium confidence)

**Parsing Confidence Levels:**
- `high`: Matches full pattern with agency type
- `medium`: Matches partial pattern without agency type
- `low`: Failed to parse cleanly

### NominatimGeocoder

Rate-limited wrapper around OpenStreetMap Nominatim API.

**Query Format:**
```
https://nominatim.openstreetmap.org/search?q=Houston,TX,USA&format=json
```

**Confidence Scoring:**
- `high`: importance > 0.5 (likely city/town center)
- `medium`: importance 0.1-0.5
- `low`: importance < 0.1

**Rate Limiting:**
- 1 request/second enforced
- Complies with Nominatim usage policy
- See: https://operations.osmfoundation.org/policies/nominatim/

### BigQueryManager

Handles BigQuery operations:
- Extracts unique agencies from source tables
- Inserts geocoding results into `agency_locations` table
- Fetches coverage statistics

## Data Schema

**BigQuery Table:** `durango-deflock.FlockML.agency_locations`

| Column | Type | Purpose |
|--------|------|---------|
| org_name | STRING | Original agency name (primary key) |
| city | STRING | Parsed city name |
| state | STRING | Parsed state code (e.g., "TX") |
| latitude | FLOAT64 | Geocoded latitude |
| longitude | FLOAT64 | Geocoded longitude |
| geocode_confidence | STRING | 'high', 'medium', 'low' |
| geocode_source | STRING | 'nominatim' or 'manual' |
| display_name | STRING | Full address from Nominatim |
| geocode_timestamp | TIMESTAMP | When geocoded |
| notes | STRING | Manual corrections or error notes |

## Verification

### Check Geocoding Coverage

```sql
SELECT
  geocode_confidence,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct
FROM `durango-deflock.FlockML.agency_locations`
GROUP BY geocode_confidence
ORDER BY count DESC;
```

### Validate Coordinates

```sql
SELECT
  COUNT(*) as total,
  COUNT(CASE WHEN latitude BETWEEN 24 AND 50 AND longitude BETWEEN -125 AND -65 THEN 1 END) as valid_us_coords
FROM `durango-deflock.FlockML.agency_locations`
WHERE geocode_source = 'nominatim';
```

### List Missing Agencies

```sql
SELECT org_name
FROM `durango-deflock.FlockML.agency_locations`
WHERE latitude IS NULL AND geocode_source = 'nominatim'
LIMIT 20;
```

## Troubleshooting

### "ModuleNotFoundError: No module named 'google.cloud'"

```bash
pip install -r requirements.txt
```

### "AuthenticationError: Could not automatically determine credentials"

```bash
gcloud auth application-default login
```

### Script is very slow

The script intentionally rate limits at 1 request/second. This is correct behavior per Nominatim usage policy. For 3,500 agencies, expect ~1 hour.

### Some agencies geocoding as "low confidence"

This is expected for smaller towns. Review the `display_name` field to verify accuracy. For incorrect results, manually insert with `geocode_source='manual'` and add notes.

### Parse failures for unusual org_name formats

Edit `OrgNameParser.PATTERNS` to add new regex patterns for additional formats. Test patterns at https://regex101.com before adding.

## Manual Geocoding

For agencies that fail automatic geocoding:

```sql
INSERT INTO `durango-deflock.FlockML.agency_locations`
(org_name, city, state, latitude, longitude, geocode_confidence, geocode_source, display_name, geocode_timestamp, notes)
VALUES
  ('Some PD', 'City', 'ST', 40.7128, -74.0060, 'high', 'manual', 'City, ST, USA', CURRENT_TIMESTAMP(), 'Manually geocoded - [reason]');
```

## Integration with Classification

Use geocoded data with classified search reasons:

```sql
SELECT
  c.reason_category,
  COUNT(*) AS search_count,
  COUNT(DISTINCT l.org_name) AS unique_agencies,
  COUNT(CASE WHEN l.latitude IS NOT NULL THEN 1 END) AS geocoded_count,
  ROUND(COUNT(CASE WHEN l.latitude IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) AS geocode_coverage_pct
FROM `durango-deflock.DurangoPD.October2025_classified` c
LEFT JOIN `durango-deflock.FlockML.agency_locations` l ON c.org_name = l.org_name
GROUP BY c.reason_category
ORDER BY search_count DESC;
```

## Future Enhancements

- [ ] Cache Nominatim results locally for faster re-runs
- [ ] Add geocoding quality monitoring dashboard
- [ ] Support alternative geocoders (Google Maps, MapBox) for failed results
- [ ] Batch geocoding with multiple API services
- [ ] Export to GeoJSON for mapping libraries

## Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review logs for error messages
3. Verify BigQuery table schema matches expected structure
4. Ensure source tables have `org_name` column

## Usage Policy

This geocoding system uses OpenStreetMap Nominatim API. Please comply with:
- **Usage Policy:** https://operations.osmfoundation.org/policies/nominatim/
- **Rate Limit:** Maximum 1 request/second per user/IP
- **Attribution:** Include attribution to OpenStreetMap when displaying data

The script automatically includes proper User-Agent headers and enforces rate limiting.
