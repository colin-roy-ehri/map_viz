/**
 * Event storage for simultaneous display
 * All events are rendered at the same time
 */
import type { Event } from '../data/events';

let state = $state({
  allEvents: [] as Event[],
});

export const playback = {
  get allEvents() {
    return state.allEvents;
  },

  /**
   * Initialize with events - store them for display
   */
  setEvents(events: Event[]): void {
    state.allEvents = events;
  },
};
