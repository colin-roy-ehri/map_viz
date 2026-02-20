#!/usr/bin/env python3
"""
Test script for geocoding fallback strategy.

Tests the three-tier fallback system:
1. Original city name query
2. City name with suffixes stripped
3. State-level fallback coordinates
"""

import sys
sys.path.insert(0, '/home/colin/map_viz/python')

from geocode_agencies import NominatimGeocoder

def test_geocoding():
    """Run tests for the geocoding fallback strategy."""
    geocoder = NominatimGeocoder()

    print("=" * 70)
    print("GEOCODING FALLBACK STRATEGY TEST")
    print("=" * 70)

    # Test 1: Original city (should succeed with Tier 1)
    print("\n[Test 1] Original city name - Houston, TX")
    print("-" * 70)
    result = geocoder.geocode('Houston', 'TX')
    if result:
        print(f"✓ Geocoding succeeded")
        print(f"  Method:     {result.get('geocode_method', 'unknown')}")
        print(f"  Coords:     {result['latitude']:.4f}, {result['longitude']:.4f}")
        print(f"  Confidence: {result.get('geocode_confidence', 'unknown')}")
        print(f"  Display:    {result.get('display_name', '')[:80]}...")
    else:
        print(f"✗ Geocoding failed")

    # Test 2: City with suffix (should try stripped variant)
    print("\n[Test 2] City with suffix - Cleveland Division, OH")
    print("-" * 70)
    result = geocoder.geocode('Cleveland Division', 'OH')
    if result:
        print(f"✓ Geocoding succeeded")
        print(f"  Method:     {result.get('geocode_method', 'unknown')}")
        if result.get('geocode_method') == 'suffix_stripped':
            print(f"  Original:   {result.get('original_city', 'N/A')}")
            print(f"  Stripped:   {result.get('stripped_city', 'N/A')}")
        print(f"  Coords:     {result['latitude']:.4f}, {result['longitude']:.4f}")
        print(f"  Confidence: {result.get('geocode_confidence', 'unknown')}")
        print(f"  Display:    {result.get('display_name', '')[:80]}...")
    else:
        print(f"✗ Geocoding failed")

    # Test 3: Nonexistent city (should fallback to state-level)
    print("\n[Test 3] Nonexistent city - ZZZFakeCity123, WY")
    print("-" * 70)
    result = geocoder.geocode('ZZZFakeCity123', 'WY')
    if result:
        print(f"✓ Geocoding succeeded (fallback)")
        print(f"  Method:     {result.get('geocode_method', 'unknown')}")
        print(f"  Coords:     {result['latitude']:.4f}, {result['longitude']:.4f}")
        print(f"  Confidence: {result.get('geocode_confidence', 'unknown')}")
        print(f"  Source:     {result.get('geocode_source', 'unknown')}")
        print(f"  Display:    {result.get('display_name', '')}")
    else:
        print(f"✗ All geocoding tiers failed")

    # Test 4: Test suffix stripping logic
    print("\n[Test 4] Suffix stripping logic")
    print("-" * 70)
    test_cases = [
        'Cleveland Division',
        'Houston Police Department',
        'Los Angeles Sheriff Services',
        'Denver Bureau of Police',
        'New York City Office',
        'Austin Police',
        'Chicago Police Department',
    ]
    for city in test_cases:
        variants = geocoder._strip_city_suffixes(city)
        print(f"  '{city}'")
        for i, variant in enumerate(variants):
            prefix = "  → " if i > 0 else "    "
            print(f"{prefix}{variant}")

    # Test 5: State fallback coordinates
    print("\n[Test 5] State-level fallback coordinates")
    print("-" * 70)
    test_states = ['TX', 'CA', 'NY', 'WY', 'PR', 'DC']
    for state in test_states:
        result = geocoder._get_state_fallback(state)
        if result:
            print(f"  {state}: ({result['latitude']:.4f}, {result['longitude']:.4f})")
        else:
            print(f"  {state}: No coordinates available")

    print("\n" + "=" * 70)
    print("TEST COMPLETE")
    print("=" * 70)

if __name__ == '__main__':
    test_geocoding()
