/**
 * Event data structure and loading
 */

export interface Event {
  id: string;
  lat: number;
  lng: number;
  name: string;
  city: string;
  region: string;
  startTime: Date;
  endTime: Date;
  type: string;
  ssid?: string;
  value?: number;
}

/**
 * Parse CSV line handling quoted fields
 */
function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    const nextChar = line[i + 1];

    if (char === '"') {
      if (inQuotes && nextChar === '"') {
        current += '"';
        i++; // Skip next quote
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }

  result.push(current.trim());
  return result;
}

/**
 * Parse CSV event data
 * Expects format with columns: trilat, trilong, ssid, firsttime, lasttime, city, region, etc.
 */
export function parseEventCSV(csv: string): Event[] {
  const lines = csv.trim().split('\n');
  if (lines.length < 2) return [];

  const headers = parseCSVLine(lines[0]).map(h => h.replace(/"/g, '').trim());
  const events: Event[] = [];

  // Find column indices
  const latIdx = headers.indexOf('trilat');
  const lngIdx = headers.indexOf('trilong');
  const ssidIdx = headers.indexOf('ssid');
  const startIdx = headers.indexOf('firsttime');
  const endIdx = headers.indexOf('lasttime');
  const cityIdx = headers.indexOf('city');
  const regionIdx = headers.indexOf('region');
  const nameIdx = headers.indexOf('name');

  console.log('CSV Headers:', headers);
  console.log('Column indices:', { latIdx, lngIdx, ssidIdx, startIdx, endIdx, cityIdx, regionIdx });

  // Parse data rows
  for (let i = 1; i < Math.min(lines.length, 100); i++) {
    if (!lines[i].trim()) continue;

    try {
      const parts = parseCSVLine(lines[i]).map(p => p.replace(/"/g, ''));

      if (parts.length < Math.max(latIdx, lngIdx, startIdx, endIdx) + 1) continue;

      const lat = parseFloat(parts[latIdx]);
      const lng = parseFloat(parts[lngIdx]);

      if (isNaN(lat) || isNaN(lng)) {
        if (i < 5) console.warn(`Row ${i}: Invalid lat/lng - lat=${parts[latIdx]}, lng=${parts[lngIdx]}`);
        continue;
      }

      const startTime = new Date(parts[startIdx]?.trim() || '');
      const endTime = new Date(parts[endIdx]?.trim() || '');

      if (isNaN(startTime.getTime()) || isNaN(endTime.getTime())) {
        if (i < 5) console.warn(`Row ${i}: Invalid dates - start=${parts[startIdx]}, end=${parts[endIdx]}`);
        continue;
      }

      const event: Event = {
        id: `event-${i}-${parts[ssidIdx]}`,
        lat,
        lng,
        name: parts[nameIdx]?.trim() || 'WiFi Network',
        city: parts[cityIdx]?.trim() || '',
        region: parts[regionIdx]?.trim() || '',
        startTime,
        endTime,
        type: 'hotspot',
        ssid: parts[ssidIdx]?.trim(),
        value: 1,
      };

      events.push(event);

      if (events.length === 1) {
        console.log('First event parsed:', event);
      }
    } catch (error) {
      if (i < 5) console.error(`Error parsing event at row ${i}:`, error);
    }
  }

  console.log(`Parsed ${events.length} events from CSV`);
  return events;
}

/**
 * Filter events that are active or recently ended at a given timestamp
 * @param events All events
 * @param timestamp Current playback timestamp
 * @param persistenceMs How long to show events after they end (default 30 minutes)
 */
export function getActiveEvents(events: Event[], timestamp: Date, persistenceMs = 30 * 60 * 1000): Event[] {
  const cutoffTime = new Date(timestamp.getTime() - persistenceMs);

  return events.filter(event => {
    // Event is active if: startTime <= timestamp AND endTime >= cutoffTime
    return event.startTime <= timestamp && event.endTime >= cutoffTime;
  });
}

/**
 * Get events currently in progress
 */
export function getOngoingEvents(events: Event[], timestamp: Date): Event[] {
  return events.filter(event => {
    return event.startTime <= timestamp && event.endTime >= timestamp;
  });
}

/**
 * Get events that ended recently (still in persistence window)
 */
export function getRecentlyEndedEvents(events: Event[], timestamp: Date, persistenceMs = 30 * 60 * 1000): Event[] {
  const cutoffTime = new Date(timestamp.getTime() - persistenceMs);

  return events.filter(event => {
    return event.endTime < timestamp && event.endTime >= cutoffTime;
  });
}

/**
 * Calculate opacity for a recently-ended event based on how long ago it ended
 */
export function getEventOpacity(event: Event, timestamp: Date, persistenceMs = 30 * 60 * 1000): number {
  if (event.endTime > timestamp) {
    return 1; // Still ongoing
  }

  const timeSinceEnd = timestamp.getTime() - event.endTime.getTime();
  const fadeOutFraction = 1 - (timeSinceEnd / persistenceMs);

  return Math.max(0, Math.min(1, fadeOutFraction));
}
