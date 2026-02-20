<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import L from 'leaflet';
  import 'leaflet.heat';
  import type { Event } from '../data/events';
  import { playback } from '../stores/playback.svelte';
  import { COLOR_PALETTES, getDefaultPalette, type ColorPalette } from '../data/palettes';

  interface Props {
    map: L.Map;
  }

  let { map }: Props = $props();

  type VisualizationMode = 'heatmap' | 'markers' | 'both';
  type MarkerStyle = 'pulsing' | 'glowing' | 'neon' | 'ripple' | 'simple';

  let mode = $state<VisualizationMode>('both');
  let markerStyle = $state<MarkerStyle>('pulsing');
  let selectedPalette = $state<ColorPalette>(getDefaultPalette());

  let heatLayer: L.HeatLayer | null = null;
  let markerLayer: L.LayerGroup | null = null;
  let mapBounds = $state<L.LatLngBounds | null>(null);

  // Filter events within current map bounds
  function getVisibleEvents(): Event[] {
    if (!mapBounds) return playback.allEvents;
    return playback.allEvents.filter(event =>
      mapBounds!.contains([event.lat, event.lng])
    );
  }

  // Get colors from palette for markers
  function getPaletteColors() {
    const gradientValues = Object.values(selectedPalette.gradient);
    return {
      primary: gradientValues[Math.floor(gradientValues.length * 0.8)] || gradientValues[gradientValues.length - 1],
      secondary: gradientValues[Math.floor(gradientValues.length * 0.5)] || gradientValues[Math.floor(gradientValues.length / 2)],
      accent: gradientValues[gradientValues.length - 1],
      dark: gradientValues[0],
      mid: gradientValues[Math.floor(gradientValues.length * 0.3)] || gradientValues[1],
    };
  }

  // Generate unique CSS keyframe animation for color cycling
  function generateColorCycleAnimation(colors: ReturnType<typeof getPaletteColors>, animId: string): string {
    return `
      @keyframes color-cycle-${animId} {
        0% { fill: ${colors.primary}; }
        25% { fill: ${colors.accent}; }
        50% { fill: ${colors.secondary}; }
        75% { fill: ${colors.accent}; }
        100% { fill: ${colors.primary}; }
      }
      @keyframes stroke-cycle-${animId} {
        0% { stroke: ${colors.primary}; }
        33% { stroke: ${colors.accent}; }
        66% { stroke: ${colors.mid}; }
        100% { stroke: ${colors.primary}; }
      }
    `;
  }

  // Create styled marker based on current style
  function createStyledMarker(event: Event, style: MarkerStyle): L.DivIcon {
    let html = '';
    let size = 60;
    const colors = getPaletteColors();
    const animId = selectedPalette.id;

    // Helper to convert hex to rgba
    const hexToRgba = (hex: string, alpha: number) => {
      const r = parseInt(hex.slice(1, 3), 16);
      const g = parseInt(hex.slice(3, 5), 16);
      const b = parseInt(hex.slice(5, 7), 16);
      return `rgba(${r}, ${g}, ${b}, ${alpha})`;
    };

    switch (style) {
      case 'simple':
        html = `
          <svg width="20" height="20">
            <circle cx="10" cy="10" r="6" fill="${colors.primary}" class="simple-${animId}"/>
          </svg>
        `;
        size = 20;
        break;

      case 'glowing':
        html = `
          <svg width="60" height="60">
            <circle cx="30" cy="30" r="30" fill="${hexToRgba(colors.primary, 0.1)}" class="glow-outer-${animId}"/>
            <circle cx="30" cy="30" r="15" fill="${hexToRgba(colors.primary, 0.3)}" class="glow-mid-${animId}"/>
            <circle cx="30" cy="30" r="5" fill="${colors.primary}" class="glow-core-${animId}"/>
          </svg>
        `;
        break;

      case 'neon':
        html = `
          <svg width="30" height="30">
            <circle cx="15" cy="15" r="12" fill="none"
                    stroke="${colors.accent}" stroke-width="2" class="neon-ring-${animId}"/>
            <circle cx="15" cy="15" r="5" fill="${colors.primary}" class="neon-core-${animId}"/>
          </svg>
        `;
        size = 30;
        break;

      case 'ripple':
        html = `
          <svg width="60" height="60">
            <circle cx="30" cy="30" r="10" fill="none"
                    stroke="${hexToRgba(colors.primary, 0.8)}" stroke-width="1" class="ripple-${animId}"/>
            <circle cx="30" cy="30" r="20" fill="none"
                    stroke="${hexToRgba(colors.primary, 0.55)}" stroke-width="1" class="ripple-${animId}"/>
            <circle cx="30" cy="30" r="30" fill="none"
                    stroke="${hexToRgba(colors.primary, 0.3)}" stroke-width="1" class="ripple-${animId}"/>
            <circle cx="30" cy="30" r="6" fill="${colors.primary}" class="ripple-core-${animId}"/>
          </svg>
        `;
        break;

      case 'pulsing':
        const sparkles = Array.from({ length: 8 }, (_, i) => {
          const angle = (i / 8) * Math.PI * 2;
          const x = 30 + Math.cos(angle) * 18;
          const y = 30 + Math.sin(angle) * 18;
          return `<circle cx="${x}" cy="${y}" r="1.5"
                  fill="${colors.accent}" class="spark spark-${animId}"
                  style="animation-delay: ${i * 50}ms"/>`;
        }).join('');

        const animStyle = generateColorCycleAnimation(colors, animId);

        html = `
          <style>${animStyle}</style>
          <svg width="60" height="60">
            <circle cx="30" cy="30" r="20" fill="none"
                    stroke="${hexToRgba(colors.primary, 0.8)}" stroke-width="2"
                    class="outer-pulse outer-pulse-${animId}"/>
            <circle cx="30" cy="30" r="8" fill="${colors.primary}"
                    class="tingle tingle-${animId}"/>
            ${sparkles}
          </svg>
        `;
        break;
    }

    return L.divIcon({
      html,
      className: `custom-marker marker-${style}`,
      iconSize: [size, size],
      iconAnchor: [size / 2, size / 2]
    });
  }

  // Initialize heatmap layer
  function initHeatmap() {
    const heatData = playback.allEvents.map(e => [e.lat, e.lng, e.value || 1] as [number, number, number]);

    heatLayer = L.heatLayer(heatData, {
      radius: 25,
      blur: 15,
      maxZoom: 17,
      max: 1.0,
      minOpacity: 0.5,
      gradient: selectedPalette.gradient,
      pane: 'overlayPane'
    });

    if (mode === 'heatmap' || mode === 'both') {
      heatLayer.addTo(map);
    }
  }

  // Update heatmap gradient when palette changes
  function updateHeatmapGradient() {
    if (!heatLayer) return;

    // Remove old layer
    map.removeLayer(heatLayer);

    // Recreate with new gradient
    initHeatmap();
  }

  // Initialize marker layer
  function initMarkers() {
    // Create custom pane above heatmap
    if (!map.getPane('markersPane')) {
      const pane = map.createPane('markersPane');
      pane.style.zIndex = '650';
      pane.style.pointerEvents = 'none';
    }

    markerLayer = L.layerGroup({ pane: 'markersPane' });
    updateMarkers();

    if (mode === 'markers' || mode === 'both') {
      markerLayer.addTo(map);
    }
  }

  // Update markers based on style and visible events
  function updateMarkers() {
    if (!markerLayer) return;

    markerLayer.clearLayers();
    const visibleEvents = getVisibleEvents();

    visibleEvents.forEach(event => {
      const icon = createStyledMarker(event, markerStyle);
      const marker = L.marker([event.lat, event.lng], {
        icon,
        pane: 'markersPane'
      });

      marker.addTo(markerLayer!);
    });
  }

  // Update layers when mode changes
  $effect(() => {
    mode; // Dependency

    if (heatLayer) {
      if (mode === 'markers') {
        map.removeLayer(heatLayer);
      } else {
        heatLayer.addTo(map);
      }
    }

    if (markerLayer) {
      if (mode === 'heatmap') {
        map.removeLayer(markerLayer);
      } else {
        markerLayer.addTo(map);
      }
    }
  });

  // Update markers when style changes
  $effect(() => {
    markerStyle; // Dependency
    if (markerLayer && (mode === 'markers' || mode === 'both')) {
      updateMarkers();
    }
  });

  // Update markers when bounds change
  $effect(() => {
    mapBounds; // Dependency
    if (markerLayer && (mode === 'markers' || mode === 'both')) {
      updateMarkers();
    }
  });

  // Update heatmap when palette changes
  $effect(() => {
    selectedPalette; // Dependency
    if (heatLayer) {
      updateHeatmapGradient();
    }
    // Also update markers to match new palette
    if (markerLayer && (mode === 'markers' || mode === 'both')) {
      updateMarkers();
    }
  });

  onMount(() => {
    console.log('HeatmapRenderer: Mounting...');

    // Initialize layers
    initHeatmap();
    initMarkers();

    // Set initial bounds
    mapBounds = map.getBounds();

    // Update bounds on map move/zoom
    const updateBounds = () => {
      mapBounds = map.getBounds();
    };

    map.on('moveend', updateBounds);
    map.on('zoomend', updateBounds);

    console.log('HeatmapRenderer: Initialized with heatmap and markers');

    return () => {
      map.off('moveend', updateBounds);
      map.off('zoomend', updateBounds);
    };
  });

  onDestroy(() => {
    if (heatLayer) map.removeLayer(heatLayer);
    if (markerLayer) map.removeLayer(markerLayer);
  });

  // Generate dynamic color animation styles for current palette
  $effect(() => {
    const colors = getPaletteColors();
    const animId = selectedPalette.id;

    // Remove old style tag if exists
    const oldStyle = document.getElementById('palette-animations');
    if (oldStyle) oldStyle.remove();

    // Create new style tag with palette-specific animations
    const styleTag = document.createElement('style');
    styleTag.id = 'palette-animations';
    styleTag.textContent = `
      /* Pulsing marker color cycles */
      .tingle-${animId} {
        animation: tingle-pulse 2s ease-in-out infinite, color-cycle-tingle-${animId} 4s ease-in-out infinite !important;
      }
      .outer-pulse-${animId} {
        animation: outer-ring-pulse 2s ease-in-out infinite, stroke-cycle-pulse-${animId} 4s ease-in-out infinite !important;
      }
      .spark-${animId} {
        animation: spark-twinkle 1.5s ease-in-out infinite, color-cycle-spark-${animId} 3s ease-in-out infinite !important;
      }

      @keyframes color-cycle-tingle-${animId} {
        0% { fill: ${colors.primary}; }
        33% { fill: ${colors.accent}; }
        66% { fill: ${colors.secondary}; }
        100% { fill: ${colors.primary}; }
      }
      @keyframes stroke-cycle-pulse-${animId} {
        0% { stroke: ${colors.primary}; }
        33% { stroke: ${colors.accent}; }
        66% { stroke: ${colors.mid}; }
        100% { stroke: ${colors.primary}; }
      }
      @keyframes color-cycle-spark-${animId} {
        0% { fill: ${colors.accent}; }
        50% { fill: ${colors.secondary}; }
        100% { fill: ${colors.accent}; }
      }

      /* Simple marker subtle pulse */
      .simple-${animId} {
        animation: color-cycle-simple-${animId} 5s ease-in-out infinite;
      }
      @keyframes color-cycle-simple-${animId} {
        0%, 100% { fill: ${colors.primary}; }
        50% { fill: ${colors.accent}; }
      }

      /* Glowing marker color shift */
      .glow-core-${animId} {
        animation: color-cycle-glow-${animId} 6s ease-in-out infinite;
      }
      @keyframes color-cycle-glow-${animId} {
        0% { fill: ${colors.primary}; }
        25% { fill: ${colors.accent}; }
        50% { fill: ${colors.secondary}; }
        75% { fill: ${colors.accent}; }
        100% { fill: ${colors.primary}; }
      }

      /* Neon marker color cycling */
      .neon-ring-${animId} {
        animation: stroke-cycle-neon-${animId} 4s ease-in-out infinite;
      }
      .neon-core-${animId} {
        animation: color-cycle-neon-${animId} 4s ease-in-out infinite;
      }
      @keyframes stroke-cycle-neon-${animId} {
        0% { stroke: ${colors.accent}; }
        50% { stroke: ${colors.primary}; }
        100% { stroke: ${colors.accent}; }
      }
      @keyframes color-cycle-neon-${animId} {
        0% { fill: ${colors.primary}; }
        50% { fill: ${colors.secondary}; }
        100% { fill: ${colors.primary}; }
      }

      /* Ripple marker color cycling */
      .ripple-${animId} {
        animation: stroke-cycle-ripple-${animId} 3s ease-in-out infinite;
      }
      .ripple-core-${animId} {
        animation: color-cycle-ripple-${animId} 5s ease-in-out infinite;
      }
      @keyframes stroke-cycle-ripple-${animId} {
        0% { stroke: ${colors.primary}; }
        33% { stroke: ${colors.mid}; }
        66% { stroke: ${colors.accent}; }
        100% { stroke: ${colors.primary}; }
      }
      @keyframes color-cycle-ripple-${animId} {
        0% { fill: ${colors.primary}; }
        50% { fill: ${colors.accent}; }
        100% { fill: ${colors.primary}; }
      }
    `;
    document.head.appendChild(styleTag);
  });
</script>

<!-- Visualization controls -->
<div class="viz-controls">
  <div class="control-section">
    <label>Mode:</label>
    <div class="button-group">
      <button
        class="mode-btn {mode === 'heatmap' ? 'active' : ''}"
        onclick={() => {
          mode = 'heatmap';
        }}
      >
        Heatmap
      </button>
      <button
        class="mode-btn {mode === 'markers' ? 'active' : ''}"
        onclick={() => {
          mode = 'markers';
        }}
      >
        Markers
      </button>
      <button
        class="mode-btn {mode === 'both' ? 'active' : ''}"
        onclick={() => {
          mode = 'both';
        }}
      >
        Both
      </button>
    </div>
  </div>

  {#if mode === 'heatmap' || mode === 'both'}
    <div class="control-section">
      <label>Color Palette:</label>
      <select
        class="palette-select"
        value={selectedPalette.id}
        onchange={(e) => {
          const palette = COLOR_PALETTES.find(p => p.id === e.currentTarget.value);
          if (palette) selectedPalette = palette;
        }}
      >
        {#each COLOR_PALETTES as palette}
          <option value={palette.id}>{palette.name}</option>
        {/each}
      </select>
      <div class="palette-description">
        {selectedPalette.description}
      </div>
      <div class="palette-preview">
        {#each Object.values(selectedPalette.gradient) as color}
          <div class="color-swatch" style="background-color: {color}"></div>
        {/each}
      </div>
    </div>
  {/if}

  {#if mode === 'markers' || mode === 'both'}
    <div class="control-section">
      <label>Style:</label>
      <div class="button-group">
        <button
          class="style-btn {markerStyle === 'simple' ? 'active' : ''}"
          onclick={() => {
            markerStyle = 'simple';
          }}
        >
          Simple
        </button>
        <button
          class="style-btn {markerStyle === 'glowing' ? 'active' : ''}"
          onclick={() => {
            markerStyle = 'glowing';
          }}
        >
          Glow
        </button>
        <button
          class="style-btn {markerStyle === 'neon' ? 'active' : ''}"
          onclick={() => {
            markerStyle = 'neon';
          }}
        >
          Neon
        </button>
        <button
          class="style-btn {markerStyle === 'ripple' ? 'active' : ''}"
          onclick={() => {
            markerStyle = 'ripple';
          }}
        >
          Ripple
        </button>
        <button
          class="style-btn {markerStyle === 'pulsing' ? 'active' : ''}"
          onclick={() => {
            markerStyle = 'pulsing';
          }}
        >
          Pulsing
        </button>
      </div>
    </div>
  {/if}
</div>

<style>
  .viz-controls {
    position: absolute;
    bottom: 20px;
    right: 20px;
    background: rgba(0, 0, 0, 0.85);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 8px;
    padding: 12px;
    z-index: 1000;
    color: #fff;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto;
  }

  .control-section {
    margin-bottom: 8px;
  }

  .control-section label {
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    color: #aaa;
    margin-bottom: 6px;
    display: block;
    letter-spacing: 0.5px;
  }

  .button-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  button {
    padding: 6px 10px;
    background: rgba(139, 92, 246, 0.3);
    border: 1px solid rgba(139, 92, 246, 0.5);
    color: #fff;
    border-radius: 3px;
    cursor: pointer;
    font-size: 10px;
    font-weight: 500;
    transition: all 150ms ease;
    white-space: nowrap;
  }

  button:hover {
    background: rgba(139, 92, 246, 0.5);
    border-color: rgba(139, 92, 246, 0.8);
  }

  button.active {
    background: rgba(139, 92, 246, 0.8);
    border-color: rgba(139, 92, 246, 1);
    box-shadow: 0 0 8px rgba(139, 92, 246, 0.6);
  }

  .palette-select {
    width: 100%;
    padding: 6px 8px;
    background: rgba(30, 30, 30, 0.9);
    border: 1px solid rgba(139, 92, 246, 0.5);
    color: #fff;
    border-radius: 3px;
    font-size: 11px;
    cursor: pointer;
    transition: all 150ms ease;
  }

  .palette-select:hover {
    border-color: rgba(139, 92, 246, 0.8);
    background: rgba(40, 40, 40, 0.9);
  }

  .palette-select:focus {
    outline: none;
    border-color: rgba(139, 92, 246, 1);
    box-shadow: 0 0 4px rgba(139, 92, 246, 0.4);
  }

  .palette-description {
    font-size: 9px;
    color: #999;
    margin-top: 6px;
    line-height: 1.3;
    font-style: italic;
  }

  .palette-preview {
    display: flex;
    gap: 2px;
    margin-top: 6px;
    height: 12px;
    border-radius: 2px;
    overflow: hidden;
  }

  .color-swatch {
    flex: 1;
    min-width: 0;
  }

  /* Global marker animations - applied to all palettes */
  :global(.custom-marker .tingle) {
    animation: tingle-pulse 2s ease-in-out infinite;
  }

  :global(.custom-marker .outer-pulse) {
    animation: outer-ring-pulse 2s ease-in-out infinite;
  }

  :global(.custom-marker .spark) {
    animation: spark-twinkle 1.5s ease-in-out infinite;
  }

  @keyframes tingle-pulse {
    0%, 100% {
      r: 8;
      opacity: 1;
    }
    50% {
      r: 10;
      opacity: 0.8;
    }
  }

  @keyframes outer-ring-pulse {
    0%, 100% {
      r: 20;
      opacity: 0.8;
    }
    50% {
      r: 23;
      opacity: 0.5;
    }
  }

  @keyframes spark-twinkle {
    0%, 100% {
      opacity: 1;
      r: 1.5;
    }
    50% {
      opacity: 0.3;
      r: 2;
    }
  }
</style>
