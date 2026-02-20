<script lang="ts">
  import { onMount } from 'svelte';
  import type L from 'leaflet';
  import LeafletBase from './LeafletBase.svelte';
  import EventDataLoader from './EventDataLoader.svelte';
  import HeatmapRenderer from './HeatmapRenderer.svelte';

  // State
  let leafletMap = $state<L.Map | null>(null);
</script>

<div class="map-container">
  <EventDataLoader />

  <div class="map-wrapper">
    <LeafletBase bind:map={leafletMap} />

    {#if leafletMap}
      <HeatmapRenderer map={leafletMap} />
    {/if}
  </div>
</div>

<style>
  .map-container {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
  }

  .map-wrapper {
    width: 100%;
    height: 100%;
  }
</style>
