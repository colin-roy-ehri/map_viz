<script lang="ts">
  import MapContainer from './lib/components/MapContainer.svelte';
</script>

<main>
  <MapContainer />
</main>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
      'Helvetica Neue', Arial, sans-serif;
    background: #0f0f0f;
    color: #fff;
  }

  :global(*) {
    box-sizing: border-box;
  }

  main {
    width: 100%;
    height: 100vh;
  }

  /* Marker animations for HeatmapRenderer */
  :global(.custom-marker) {
    overflow: visible !important;
  }

  :global(.custom-marker svg) {
    overflow: visible;
  }

  :global(.outer-pulse) {
    animation: outer-pulse 1.2s ease-out infinite;
  }

  :global(.tingle) {
    animation: tingle 0.6s ease-in-out infinite;
  }

  :global(.spark) {
    animation: spark 1s ease-in-out infinite;
  }

  @keyframes outer-pulse {
    0%, 100% {
      r: 20px;
      stroke-width: 2px;
    }
    50% {
      r: 28px;
      stroke-width: 1px;
    }
  }

  @keyframes tingle {
    0%, 100% {
      r: 8px;
    }
    50% {
      r: 12px;
    }
  }

  @keyframes spark {
    0%, 100% {
      opacity: 0;
    }
    50% {
      opacity: 1;
    }
  }
</style>
