<script lang="ts">
  import { onMount } from 'svelte';
  import type { Event } from '../data/events';
  import { parseEventCSV } from '../data/events';
  import { playback } from '../stores/playback.svelte';
  import csvData from '../data/Flock-_______20240530_124303.csv?raw';

  let isLoading = $state(true);
  let error = $state<string | null>(null);

  onMount(() => {
    try {
      console.log('EventDataLoader: Starting to parse CSV data');
      const allEvents = parseEventCSV(csvData);

      console.log(`EventDataLoader: Parsed ${allEvents.length} events`);

      if (allEvents.length > 0) {
        // Initialize playback with all events
        playback.setEvents(allEvents);
        console.log(`EventDataLoader: Playback initialized with ${allEvents.length} events`);
      } else {
        console.warn('EventDataLoader: No events were parsed from CSV');
      }

      isLoading = false;
    } catch (err) {
      error = err instanceof Error ? err.message : 'Unknown error';
      console.error('Error loading events:', err);
      isLoading = false;
    }
  });
</script>

{#if isLoading}
  <div class="loader">Loading event data...</div>
{/if}

{#if error}
  <div class="error">Error: {error}</div>
{/if}

<style>
  .loader,
  .error {
    position: fixed;
    top: 20px;
    right: 20px;
    padding: 12px 16px;
    border-radius: 4px;
    font-size: 12px;
    z-index: 999;
  }

  .loader {
    background: rgba(59, 130, 246, 0.8);
    color: #fff;
  }

  .error {
    background: rgba(239, 68, 68, 0.8);
    color: #fff;
  }
</style>
