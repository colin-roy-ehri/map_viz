#!/usr/bin/env python3
"""
Police Agency Geocoding System

Extracts unique police agencies from police search data, parses city/state,
geocodes using OpenStreetMap Nominatim API, and stores results in BigQuery.

Usage:
    python geocode_agencies.py

Rate limiting: 1 request/second (Nominatim policy)
Estimated runtime: ~1 hour for 3,500 agencies
"""

import re
import time
import logging
import json
from typing import Optional, Tuple, Dict, List
from dataclasses import dataclass
from datetime import datetime

import requests
from google.cloud import bigquery
from google.api_core.exceptions import AlreadyExists, BadRequest

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# State/territory center coordinates (approximate geographic centers)
# Source: U.S. Census Bureau geographic centers
STATE_COORDINATES = {
    'AL': (32.806671, -86.791130), 'AK': (61.370716, -152.404419),
    'AZ': (33.729759, -111.431221), 'AR': (34.969704, -92.373123),
    'CA': (36.116203, -119.681564), 'CO': (39.059811, -105.311104),
    'CT': (41.597782, -72.755371), 'DE': (39.318523, -75.507141),
    'FL': (27.766279, -81.686783), 'GA': (33.040619, -83.643074),
    'HI': (21.094318, -157.498337), 'ID': (44.240459, -114.478828),
    'IL': (40.349457, -88.986137), 'IN': (39.849426, -86.258278),
    'IA': (42.011539, -93.210526), 'KS': (38.526600, -96.726486),
    'KY': (37.668140, -84.670067), 'LA': (31.169546, -91.867805),
    'ME': (44.693947, -69.381927), 'MD': (39.063946, -76.802101),
    'MA': (42.230171, -71.530106), 'MI': (43.326618, -84.536095),
    'MN': (45.694454, -93.900192), 'MS': (32.741646, -89.678696),
    'MO': (38.456085, -92.288368), 'MT': (46.921925, -110.454353),
    'NE': (41.125370, -98.268082), 'NV': (38.313515, -117.055374),
    'NH': (43.452492, -71.563896), 'NJ': (40.298904, -74.521011),
    'NM': (34.840515, -106.248482), 'NY': (42.165726, -74.948051),
    'NC': (35.630066, -79.806419), 'ND': (47.528912, -99.784012),
    'OH': (40.388783, -82.764915), 'OK': (35.565342, -96.928917),
    'OR': (44.572021, -122.070938), 'PA': (40.590752, -77.209755),
    'RI': (41.680893, -71.511780), 'SC': (33.856892, -80.945007),
    'SD': (44.299782, -99.438828), 'TN': (35.747845, -86.692345),
    'TX': (31.054487, -97.563461), 'UT': (40.150032, -111.862434),
    'VT': (44.045876, -72.710686), 'VA': (37.769337, -78.169968),
    'WA': (47.400902, -121.490494), 'WV': (38.491226, -80.954453),
    'WI': (44.268543, -89.616508), 'WY': (42.755966, -107.302490),
    'DC': (38.907192, -77.036871),
    # Territories (approximate centers)
    'AS': (-14.270972, -170.132217), 'GU': (13.444304, 144.793731),
    'MP': (15.097500, 145.673889), 'PR': (18.282833, -66.590149),
    'UM': (19.282778, 166.647222), 'VI': (18.335765, -64.896335)
}


@dataclass
class ParsedOrgName:
    """Parsed components of an organization name."""
    city: str
    state: str
    agency: str
    confidence: str  # 'high', 'medium', 'low'


class OrgNameParser:
    """Parse police agency names like 'Houston TX PD' -> city='Houston', state='TX'."""

    # Mapping of full state names to abbreviations
    STATE_NAMES = {
        'alabama': 'AL', 'alaska': 'AK', 'arizona': 'AZ', 'arkansas': 'AR',
        'california': 'CA', 'colorado': 'CO', 'connecticut': 'CT', 'delaware': 'DE',
        'florida': 'FL', 'georgia': 'GA', 'hawaii': 'HI', 'idaho': 'ID',
        'illinois': 'IL', 'indiana': 'IN', 'iowa': 'IA', 'kansas': 'KS',
        'kentucky': 'KY', 'louisiana': 'LA', 'maine': 'ME', 'maryland': 'MD',
        'massachusetts': 'MA', 'michigan': 'MI', 'minnesota': 'MN', 'mississippi': 'MS',
        'missouri': 'MO', 'montana': 'MT', 'nebraska': 'NE', 'nevada': 'NV',
        'new hampshire': 'NH', 'new jersey': 'NJ', 'new mexico': 'NM', 'new york': 'NY',
        'north carolina': 'NC', 'north dakota': 'ND', 'ohio': 'OH', 'oklahoma': 'OK',
        'oregon': 'OR', 'pennsylvania': 'PA', 'rhode island': 'RI', 'south carolina': 'SC',
        'south dakota': 'SD', 'tennessee': 'TN', 'texas': 'TX', 'utah': 'UT',
        'vermont': 'VT', 'virginia': 'VA', 'washington': 'WA', 'west virginia': 'WV',
        'wisconsin': 'WI', 'wyoming': 'WY', 'district of columbia': 'DC'
    }

    # Regex patterns for different agency name formats
    PATTERNS = [
        # Pattern 1: "City ST Agency" - most common
        # e.g., "Houston TX PD", "Denver CO Police Department"
        (
            r'^([A-Z][a-z\s\-]+?)\s+([A-Z]{2})\s+(?:P(?:olice)?D?|Sheriff|SO|Police Dept|Department|Division|Bureau)$',
            'high'
        ),
        # Pattern 2: "County County ST Agency"
        # e.g., "Harris County TX SO", "Kings County NY Sheriff"
        (
            r'^([A-Z][a-z\s\-]+?)\s+County\s+([A-Z]{2})\s+(?:SO|Sheriff|Police)$',
            'high'
        ),
        # Pattern 3: "City ST Division of Agency"
        # e.g., "Cleveland OH Division of Police"
        (
            r'^([A-Z][a-z\s\-]+?)\s+([A-Z]{2})\s+Division\s+of\s+(?:Police|Sheriff)$',
            'high'
        ),
        # Pattern 5: "City Agency - ST" format
        # e.g., "Aztec PD - NM", "Bay St. Louis MS PD"
        (
            r'^([A-Z][a-z\s\-\.]+?)\s+(?:P(?:olice)?D?|Sheriff|SO|PD)\s*-\s*([A-Z]{2})$',
            'high'
        ),
        # Pattern 6: "City Agency (ST)" format with state in parentheses
        # e.g., "Arlington PD (WA)", "Salem Police (OR)"
        (
            r'^([A-Z][a-z\s\-\.]+?)\s+(?:P(?:olice)?D?|Sheriff|SO)\s*\(([A-Z]{2})\)$',
            'high'
        ),
        # Pattern 7: "ST - City Agency" format (state first with dash)
        # e.g., "AR - Alma PD", "TX - Houston Police"
        (
            r'^([A-Z]{2})\s*-\s*([A-Z][a-z\s\-\.]+?)\s+(?:P(?:olice)?D?|Sheriff|SO|Department|Dept)$',
            'medium'
        ),
        # Pattern 8: "Parish/County Name ST Agency" (for parishes)
        # e.g., "Bienville Parish LA SO", "Washington Parish LA Sheriff"
        (
            r'^([A-Z][a-z\s\-]+?)\s+(?:Parish|County)\s+([A-Z]{2})\s+(?:SO|Sheriff|Police|PD)$',
            'high'
        ),
        # Pattern 9: "Word Word ST Agency" - multi-word cities
        # e.g., "Amberley Village OH PD", "New York NY Police"
        (
            r'^([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\s+([A-Z]{2})\s+(?:P(?:olice)?D?|Sheriff|SO|Department|Dept)$',
            'high'
        ),
        # Pattern 10: City with dots/periods and state
        # e.g., "Bay St. Louis MS PD", "Port St. Lucie FL Police"
        (
            r'^([A-Z][a-z]+(?:\s+[A-Z]?[a-z]+\.?)+)\s+([A-Z]{2})\s+(?:P(?:olice)?D?|Sheriff|SO|Department|Dept)$',
            'high'
        ),
        # Pattern 11: "Word CO Word ST Agency" where CO means County, not Colorado
        # e.g., "Blaine CO OK SO" (Blaine County, OK)
        (
            r'^([A-Z][a-z\s\-]+?)\s+CO\s+([A-Z]{2})\s+(?:SO|Sheriff|Police)$',
            'high'
        ),
        # Pattern 4: Just "City ST" with low confidence
        (
            r'^([A-Z][a-z\s\-]+?)\s+([A-Z]{2})$',
            'medium'
        ),
    ]

    @staticmethod
    def parse(org_name: str) -> Optional[ParsedOrgName]:
        """
        Parse organization name into city, state, agency components.

        Attempts city+state extraction, with fallback to state-only extraction.

        Args:
            org_name: Organization name string (e.g., "Houston TX PD")

        Returns:
            ParsedOrgName with extracted components, or None if parsing fails
        """
        if not org_name or not isinstance(org_name, str):
            return None

        org_name = org_name.strip()

        # Try standard city+state patterns first
        for pattern, confidence in OrgNameParser.PATTERNS:
            match = re.match(pattern, org_name)
            if match:
                group1 = match.group(1).strip()
                group2 = match.group(2).strip().upper()

                # Determine which is city and which is state
                # Pattern 7 ("ST - City Agency") has state in group1, city in group2
                if len(group1) == 2 and OrgNameParser._is_valid_us_state(group1):
                    # State is first
                    state = group1
                    city = group2
                else:
                    # City is first (normal case)
                    city = group1
                    state = group2

                # Validate state code
                if not OrgNameParser._is_valid_us_state(state):
                    continue

                agency = 'Police Department'  # Default
                if 'Sheriff' in org_name or 'SO' in org_name:
                    agency = 'Sheriff Office'

                return ParsedOrgName(
                    city=city,
                    state=state,
                    agency=agency,
                    confidence=confidence
                )

        # Fallback: Try to extract state name even if city extraction fails
        # For state-level agencies like "California Department of Corrections"
        extracted_state = OrgNameParser._extract_state_from_name(org_name)
        if extracted_state:
            # Use state name as city (generic for state-level agencies)
            state_name = None
            for name, abbrev in OrgNameParser.STATE_NAMES.items():
                if abbrev == extracted_state:
                    state_name = name.title()
                    break

            agency = 'Police Department'  # Default
            if 'Sheriff' in org_name or 'SO' in org_name:
                agency = 'Sheriff Office'

            return ParsedOrgName(
                city=state_name or extracted_state,  # Use state name as city placeholder
                state=extracted_state,
                agency=agency,
                confidence='low'  # Lower confidence since we're using state-level
            )

        return None

    @staticmethod
    def _extract_state_from_name(org_name: str) -> Optional[str]:
        """
        Try to extract state abbreviation from organization name by looking for state names.

        Args:
            org_name: Organization name (e.g., "Alabama Department of Corrections")

        Returns:
            State abbreviation if found, None otherwise
        """
        org_lower = org_name.lower()

        # Try multi-word state names first (e.g., "New York", "North Carolina")
        for state_name in sorted(OrgNameParser.STATE_NAMES.keys(), key=len, reverse=True):
            if state_name in org_lower:
                return OrgNameParser.STATE_NAMES[state_name]

        return None

    @staticmethod
    def _is_valid_us_state(state_code: str) -> bool:
        """Check if state code is valid US state/territory abbreviation."""
        valid_states = {
            'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
            'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
            'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
            'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
            'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
            'DC', 'AS', 'GU', 'MP', 'PR', 'UM', 'VI'
        }
        return state_code in valid_states


class LLMStateClassifier:
    """Use Claude LLM via Anthropic API to classify state from organization names."""

    API_URL = 'https://api.anthropic.com/v1/messages'

    def __init__(self):
        """Initialize with API key from environment."""
        import os
        self.api_key = os.environ.get('ANTHROPIC_API_KEY')
        if not self.api_key:
            logger.warning('ANTHROPIC_API_KEY not set - LLM state classification will be skipped')
        self.cache = {}  # Simple cache to avoid redundant API calls

    def classify_state(self, org_name: str) -> Optional[str]:
        """
        Use Claude to classify the state from an organization name via Anthropic API.

        Args:
            org_name: Organization name (e.g., "Blount County Commission (AL)")

        Returns:
            State abbreviation (e.g., "AL") or None if unable to classify
        """
        if not self.api_key:
            return None

        if org_name in self.cache:
            return self.cache[org_name]

        # Check for federal agencies - default to DC
        if any(keyword in org_name.lower() for keyword in ['federal', 'national', 'us ', 'usa', 'united states', 'postal', 'fbi', 'atf', 'ncmec']):
            logger.debug(f'Classified as federal agency: {org_name} → DC')
            self.cache[org_name] = 'DC'
            return 'DC'

        try:
            response = requests.post(
                self.API_URL,
                headers={
                    'x-api-key': self.api_key,
                    'anthropic-version': '2023-06-01',
                    'content-type': 'application/json'
                },
                json={
                    'model': 'claude-opus-4-6',
                    'max_tokens': 50,
                    'system': '''You are a US state classifier. Given a police or law enforcement agency name,
extract the US state abbreviation (2 letters like AL, TX, CA, etc).

If the name clearly references a specific state/city, return that state abbreviation.
If it's a federal agency or national organization, return "DC".
If you cannot determine the state with reasonable confidence, return "UNKNOWN".

Respond with ONLY the state abbreviation, nothing else.''',
                    'messages': [
                        {
                            'role': 'user',
                            'content': f'Organization name: {org_name}'
                        }
                    ]
                },
                timeout=10
            )

            if response.status_code != 200:
                logger.debug(f'API error classifying {org_name}: {response.status_code}')
                self.cache[org_name] = None
                return None

            data = response.json()
            response_text = data['content'][0]['text'].strip().upper()

            # Validate the response is a valid state code
            valid_states = {
                'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
                'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
                'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
                'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
                'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC', 'UNKNOWN'
            }

            if response_text in valid_states:
                if response_text == 'UNKNOWN':
                    logger.debug(f'LLM could not determine state for {org_name}')
                    self.cache[org_name] = None
                    return None
                else:
                    logger.debug(f'LLM classified: {org_name} → {response_text}')
                    self.cache[org_name] = response_text
                    return response_text
            else:
                logger.debug(f'LLM returned invalid state for {org_name}: {response_text}')
                self.cache[org_name] = None
                return None

        except requests.exceptions.RequestException as e:
            logger.error(f'Error classifying state for {org_name}: {e}')
            self.cache[org_name] = None
            return None
        except (KeyError, IndexError, json.JSONDecodeError) as e:
            logger.error(f'Parse error classifying state for {org_name}: {e}')
            self.cache[org_name] = None
            return None


class NominatimGeocoder:
    """Rate-limited OpenStreetMap Nominatim API geocoder with fallback strategy."""

    BASE_URL = 'https://nominatim.openstreetmap.org/search'
    USER_AGENT = 'FlockAgencyGeocoder/1.0'
    RATE_LIMIT_DELAY = 1.0  # 1 second between requests (Nominatim policy)

    # Common words that appear in city names but aren't part of the actual city
    CITY_SUFFIXES = [
        'Division', 'Department', 'Dept', 'Bureau', 'Office',
        'Police', 'Sheriff', 'Services', 'Administration'
    ]

    def __init__(self):
        """Initialize geocoder with rate limiting."""
        self.last_request_time = 0
        self.session = requests.Session()
        self.session.headers.update({'User-Agent': self.USER_AGENT})

    def _strip_city_suffixes(self, city: str) -> List[str]:
        """
        Generate variants of city name with common suffixes removed.

        Args:
            city: Original city name (e.g., "Cleveland Division")

        Returns:
            List of city name variants to try, in order of preference
            Example: ["Cleveland Division", "Cleveland"]
        """
        variants = [city]  # Always try original first

        # Try removing each suffix
        for suffix in self.CITY_SUFFIXES:
            # Match suffix at end of string (with optional 's')
            pattern = r'\s+' + suffix + r's?\s*$'
            stripped = re.sub(pattern, '', city, flags=re.IGNORECASE)
            if stripped != city and stripped not in variants:
                variants.append(stripped.strip())

        return variants

    def _get_state_fallback(self, state: str) -> Optional[Dict]:
        """
        Get state-level coordinates as last-resort fallback.

        Args:
            state: State code (e.g., 'TX')

        Returns:
            Dict with state-level coordinates and low confidence
        """
        if state not in STATE_COORDINATES:
            return None

        lat, lon = STATE_COORDINATES[state]
        return {
            'latitude': lat,
            'longitude': lon,
            'display_name': f'{state}, USA (state-level fallback)',
            'geocode_confidence': 'low',
            'geocode_source': 'state_fallback',
            'geocode_method': 'state_level'
        }

    def geocode(self, city: str, state: str) -> Optional[Dict]:
        """
        Geocode a city, state location with multi-tier fallback strategy.

        Attempts (in order):
        1. Original city name: "{city}, {state}, USA"
        2. Stripped variants: Remove suffixes like "Division", "Department"
        3. State-level fallback: Use approximate state center coordinates

        Args:
            city: City name (e.g., "Houston" or "Cleveland Division")
            state: State abbreviation (e.g., "TX")

        Returns:
            Dict with keys: {latitude, longitude, display_name, confidence,
                            source, geocode_method}
            or None if all fallbacks fail
        """
        # TIER 1: Try original city name
        result = self._geocode_single(city, state)
        if result:
            result['geocode_method'] = 'original'
            logger.debug(f'  ✓ Geocoded via original query: {city}, {state}')
            return result

        # TIER 2: Try stripped city name variants
        city_variants = self._strip_city_suffixes(city)
        if len(city_variants) > 1:  # Only try if we have variants
            logger.debug(f'  → Trying {len(city_variants)-1} stripped variants...')
            for variant in city_variants[1:]:  # Skip first (original)
                result = self._geocode_single(variant, state)
                if result:
                    result['geocode_method'] = 'suffix_stripped'
                    result['original_city'] = city
                    result['stripped_city'] = variant
                    logger.info(
                        f'  ✓ Geocoded via suffix stripping: '
                        f'"{city}" → "{variant}", {state}'
                    )
                    return result

        # TIER 3: State-level fallback
        logger.debug(f'  → Using state-level fallback for {state}')
        result = self._get_state_fallback(state)
        if result:
            logger.info(
                f'  ⚠ Using state-level coordinates for {city}, {state} '
                f'(imprecise fallback)'
            )
            return result

        # All tiers failed
        logger.warning(f'  ✗ All geocoding tiers failed for {city}, {state}')
        return None

    def _geocode_single(self, city: str, state: str) -> Optional[Dict]:
        """
        Single geocoding attempt via Nominatim API.

        This is the original geocode() logic extracted into a helper
        to enable retry logic in the main geocode() method.
        """
        # Rate limiting
        time_since_last = time.time() - self.last_request_time
        if time_since_last < self.RATE_LIMIT_DELAY:
            time.sleep(self.RATE_LIMIT_DELAY - time_since_last)

        try:
            # Query Nominatim API
            query = f'{city}, {state}, USA'
            params = {
                'q': query,
                'format': 'json',
                'limit': 1,
                'addressdetails': 1
            }

            response = self.session.get(self.BASE_URL, params=params, timeout=10)
            self.last_request_time = time.time()

            if response.status_code != 200:
                logger.debug(f'Nominatim API error for {query}: {response.status_code}')
                return None

            results = response.json()
            if not results:
                return None

            result = results[0]

            # Assess confidence based on importance score
            importance = float(result.get('importance', 0))
            if importance > 0.5:
                confidence = 'high'
            elif importance > 0.1:
                confidence = 'medium'
            else:
                confidence = 'low'

            return {
                'latitude': float(result['lat']),
                'longitude': float(result['lon']),
                'display_name': result.get('display_name', ''),
                'geocode_confidence': confidence,
                'geocode_source': 'nominatim'
            }

        except requests.exceptions.RequestException as e:
            logger.debug(f'Request error geocoding {city}, {state}: {e}')
            return None
        except (ValueError, KeyError) as e:
            logger.debug(f'Parse error in geocoding {city}, {state}: {e}')
            return None


class BigQueryManager:
    """Manages BigQuery operations for agency locations."""

    PROJECT_ID = 'durango-deflock'
    DATASET_ID = 'FlockML'
    TABLE_ID = 'agency_locations'

    def __init__(self):
        """Initialize BigQuery client."""
        self.client = bigquery.Client(project=self.PROJECT_ID)
        self.table_ref = f'{self.PROJECT_ID}.{self.DATASET_ID}.{self.TABLE_ID}'

    def get_unique_agencies(self, source_tables: List[str]) -> List[str]:
        """
        Get unique agencies from source tables that haven't been successfully geocoded yet.

        Includes:
        - Agencies not in the table at all
        - Agencies with NULL coordinates (failed attempts)

        Args:
            source_tables: List of source table IDs (e.g., ['durango-deflock.DurangoPD.October2025'])

        Returns:
            List of unique org_names not yet successfully geocoded
        """
        # Get agencies from source tables
        union_queries = [
            f'SELECT DISTINCT org_name FROM `{table}`'
            for table in source_tables
        ]
        source_query = ' UNION ALL '.join(union_queries)

        # Find agencies that either:
        # 1. Don't exist in agency_locations yet, OR
        # 2. Exist but have NULL coordinates (failed geocoding)
        query = f"""
        WITH source_agencies AS (
            {source_query}
        )
        SELECT DISTINCT org_name
        FROM source_agencies
        WHERE org_name NOT IN (
            SELECT DISTINCT org_name
            FROM `{self.table_ref}`
            WHERE (latitude IS NOT NULL AND longitude IS NOT NULL)
            AND geocode_source IN ('nominatim', 'manual')
        )
        ORDER BY org_name
        """

        try:
            results = self.client.query(query).result()
            return [row['org_name'] for row in results]
        except Exception as e:
            logger.error(f'Error fetching unique agencies: {e}')
            return []

    def get_failed_geocode_count(self) -> int:
        """Get count of agencies with NULL coordinates."""
        query = f"""
        SELECT COUNT(*) as count
        FROM `{self.table_ref}`
        WHERE latitude IS NULL OR longitude IS NULL
        """
        try:
            result = self.client.query(query).result()
            row = next(result)
            return row['count']
        except Exception as e:
            logger.error(f'Error counting failed geocodes: {e}')
            return 0

    def delete_failed_geocodes(self) -> bool:
        """
        Delete records with NULL coordinates to allow retry with new fallback strategy.

        Returns:
            True if successful, False otherwise
        """
        query = f"""
        DELETE FROM `{self.table_ref}`
        WHERE latitude IS NULL OR longitude IS NULL
        """
        try:
            self.client.query(query).result()
            logger.info('Deleted all failed geocode records')
            return True
        except Exception as e:
            logger.error(f'Error deleting failed geocodes: {e}')
            return False

    def insert_agency_location(
        self,
        org_name: str,
        city: str,
        state: str,
        latitude: Optional[float],
        longitude: Optional[float],
        geocode_confidence: Optional[str],
        geocode_source: str,
        display_name: Optional[str],
        notes: Optional[str] = None,
        geocode_method: Optional[str] = None
    ) -> bool:
        """
        Insert or update agency location in BigQuery.

        Args:
            org_name: Organization name (primary key)
            city: City name
            state: State code
            latitude: Latitude coordinate
            longitude: Longitude coordinate
            geocode_confidence: 'high', 'medium', 'low', or None
            geocode_source: 'nominatim' or 'manual'
            display_name: Full address from geocoder
            notes: Optional notes for manual corrections
            geocode_method: 'original', 'suffix_stripped', 'state_level', etc.

        Returns:
            True if successful, False otherwise
        """
        # Append geocode_method to notes if provided
        if geocode_method:
            method_note = f'[Method: {geocode_method}]'
            notes = f'{method_note} {notes}' if notes else method_note

        rows_to_insert = [
            {
                'org_name': org_name,
                'city': city,
                'state': state,
                'latitude': latitude,
                'longitude': longitude,
                'geocode_confidence': geocode_confidence,
                'geocode_source': geocode_source,
                'display_name': display_name,
                'geocode_timestamp': datetime.utcnow().isoformat(),
                'notes': notes
            }
        ]

        try:
            errors = self.client.insert_rows_json(self.table_ref, rows_to_insert)
            if errors:
                logger.error(f'Insert errors for {org_name}: {errors}')
                return False
            return True
        except Exception as e:
            logger.error(f'Error inserting {org_name}: {e}')
            return False

    def get_geocoding_stats(self) -> Dict:
        """Get geocoding coverage statistics including method breakdown."""
        query = f"""
        SELECT
          COUNT(*) as total,
          COUNT(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 END) as geocoded,
          COUNT(CASE WHEN geocode_confidence = 'high' THEN 1 END) as high_confidence,
          COUNT(CASE WHEN geocode_confidence = 'medium' THEN 1 END) as medium_confidence,
          COUNT(CASE WHEN geocode_confidence = 'low' THEN 1 END) as low_confidence,
          -- Method breakdown (extract from notes field)
          COUNT(CASE WHEN notes LIKE '%[Method: original]%' THEN 1 END) as method_original,
          COUNT(CASE WHEN notes LIKE '%[Method: suffix_stripped]%' THEN 1 END) as method_suffix_stripped,
          COUNT(CASE WHEN notes LIKE '%[Method: state_level]%' THEN 1 END) as method_state_level
        FROM `{self.table_ref}`
        """

        try:
            result = self.client.query(query).result()
            row = next(result)
            return {
                'total': row['total'],
                'geocoded': row['geocoded'],
                'high_confidence': row['high_confidence'],
                'medium_confidence': row['medium_confidence'],
                'low_confidence': row['low_confidence'],
                'method_original': row['method_original'],
                'method_suffix_stripped': row['method_suffix_stripped'],
                'method_state_level': row['method_state_level']
            }
        except Exception as e:
            logger.error(f'Error fetching geocoding stats: {e}')
            return {}


def main():
    """Main geocoding orchestrator."""
    logger.info('Starting agency geocoding process...')

    # Initialize components
    parser = OrgNameParser()
    geocoder = NominatimGeocoder()
    llm_classifier = LLMStateClassifier()
    bq = BigQueryManager()

    # Configure source tables
    source_tables = [
        'durango-deflock.DurangoPD.October2025',
        # Add more tables as needed
    ]

    # Get unique agencies not yet geocoded
    agencies = bq.get_unique_agencies(source_tables)
    logger.info(f'Found {len(agencies)} unique agencies to geocode')

    if not agencies:
        logger.info('All agencies already geocoded!')
        return

    # Process each agency
    success_count = 0
    fail_count = 0
    skip_count = 0

    for i, org_name in enumerate(agencies, 1):
        logger.info(f'[{i}/{len(agencies)}] Processing: {org_name}')

        # Parse agency name
        parsed = parser.parse(org_name)
        if not parsed:
            # Try LLM classifier as fallback
            logger.debug(f'  → Attempting LLM state classification...')
            llm_state = llm_classifier.classify_state(org_name)
            if llm_state:
                # Use LLM-classified state with generic city placeholder
                parsed_city = f'{llm_state} Agency'
                parsed_state = llm_state
                logger.info(f'  ✓ LLM classified state: {parsed_state}')
            else:
                logger.warning(f'  ✗ Failed to parse org_name (LLM also failed)')
                skip_count += 1
                bq.insert_agency_location(
                    org_name=org_name,
                    city=None,
                    state=None,
                    latitude=None,
                    longitude=None,
                    geocode_confidence=None,
                    geocode_source='nominatim',
                    display_name=None,
                    notes='Parse and LLM classification failed'
                )
                continue
        else:
            parsed_city = parsed.city
            parsed_state = parsed.state

        # Geocode location
        geocoded = geocoder.geocode(parsed_city, parsed_state)

        if geocoded:
            # Extract geocode_method (with backwards compatibility)
            geocode_method = geocoded.get('geocode_method', 'original')

            # Log with method indicator
            method_indicator = {
                'original': '✓',
                'suffix_stripped': '↻',
                'state_level': '⚠'
            }.get(geocode_method, '✓')

            logger.info(
                f'  {method_indicator} Geocoded: {geocoded["latitude"]:.4f}, '
                f'{geocoded["longitude"]:.4f} '
                f'({geocoded["geocode_confidence"]}, {geocode_method})'
            )
            success_count += 1

            # Build notes with additional context
            notes = None
            if geocode_method == 'suffix_stripped':
                notes = f'Stripped "{geocoded.get("original_city")}" → "{geocoded.get("stripped_city")}"'
            elif geocode_method == 'state_level':
                notes = 'Using state-level coordinates (imprecise)'

            bq.insert_agency_location(
                org_name=org_name,
                city=parsed_city,
                state=parsed_state,
                latitude=geocoded['latitude'],
                longitude=geocoded['longitude'],
                geocode_confidence=geocoded['geocode_confidence'],
                geocode_source=geocoded['geocode_source'],
                display_name=geocoded['display_name'],
                geocode_method=geocode_method,
                notes=notes
            )
        else:
            # This branch should now be very rare (only if state code is invalid)
            logger.warning(f'  ✗ All geocoding tiers failed for {parsed_city}, {parsed_state}')
            fail_count += 1
            bq.insert_agency_location(
                org_name=org_name,
                city=parsed_city,
                state=parsed_state,
                latitude=None,
                longitude=None,
                geocode_confidence=None,
                geocode_source='nominatim',
                display_name=None,
                notes='All geocoding tiers failed'
            )

    # Print summary
    logger.info('\n' + '='*60)
    logger.info('GEOCODING SUMMARY')
    logger.info('='*60)
    logger.info(f'Total agencies processed: {len(agencies)}')
    logger.info(f'Successfully geocoded:   {success_count}')
    logger.info(f'Geocoding failed:        {fail_count}')
    logger.info(f'Parsing skipped:         {skip_count}')

    # Fetch and display coverage statistics
    stats = bq.get_geocoding_stats()
    if stats:
        coverage_pct = (stats['geocoded'] / stats['total'] * 100) if stats['total'] > 0 else 0
        logger.info(f'\nTotal agencies in BigQuery: {stats["total"]}')
        logger.info(f'With coordinates:          {stats["geocoded"]} ({coverage_pct:.1f}%)')
        logger.info(f'  - High confidence:       {stats["high_confidence"]}')
        logger.info(f'  - Medium confidence:     {stats["medium_confidence"]}')
        logger.info(f'  - Low confidence:        {stats["low_confidence"]}')
        logger.info(f'\nGeocoding method breakdown:')
        logger.info(f'  - Original query:        {stats.get("method_original", 0)}')
        logger.info(f'  - Suffix stripped:       {stats.get("method_suffix_stripped", 0)}')
        logger.info(f'  - State-level fallback:  {stats.get("method_state_level", 0)}')

    logger.info('='*60)
    logger.info('✓ Geocoding complete!')


if __name__ == '__main__':
    main()
