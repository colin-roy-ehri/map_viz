<script lang="ts">
  import { onMount } from 'svelte';
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';

  interface Props {
    map?: L.Map;
  }

  let { map = $bindable() }: Props = $props();
  let mapContainer = $state<HTMLDivElement | null>(null);

  onMount(() => {
    if (!mapContainer) return;

    // Initialize Leaflet map with Canvas renderer for better performance
    map = L.map(mapContainer, {
      preferCanvas: true
    }).setView([20, 0], 2);

    // Add OpenStreetMap tile layer
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
      tileSize: 256,
    }).addTo(map);

    return () => {
      if (map) {
        map.remove();
      }
    };
  });
</script>

<div class="map-container" bind:this={mapContainer}></div>

<style>
  .map-container {
    width: 100%;
    height: 100%;
  }

  :global(.leaflet-container) {
    font-family: inherit;
    background: #1a1a1a;
  }

  :global(.leaflet-control-attribution) {
    background: rgba(255, 255, 255, 0.7);
    color: #000;
  }
</style>
