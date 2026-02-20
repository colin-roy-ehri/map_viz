import type { Event } from '../data/events';
import type L from 'leaflet';

/**
 * Global map state using Svelte 5 runes
 * Manages animation timing, map state, and events
 */
export const mapState = $state({
  mapBounds: null as L.LatLngBounds | null,
  zoom: 10,
  mousePosition: { x: 0, y: 0 },
  globalMouseX: 0,
  globalMouseY: 0,
  activeEvents: [] as Event[],

  /**
   * Update map bounds (called on map move/zoom)
   */
  updateMapBounds(bounds: L.LatLngBounds): void {
    this.mapBounds = bounds;
  },

  /**
   * Update zoom level
   */
  updateZoom(zoom: number): void {
    this.zoom = zoom;
  },

  /**
   * Update mouse position (legacy)
   */
  updateMousePosition(x: number, y: number): void {
    this.mousePosition = { x, y };
  },

  /**
   * Update global mouse position for proximity effects
   */
  setGlobalMousePosition(x: number, y: number): void {
    this.globalMouseX = x;
    this.globalMouseY = y;
  },

  /**
   * Set active events to render
   */
  setActiveEvents(events: Event[]): void {
    this.activeEvents = events;
  },
});
