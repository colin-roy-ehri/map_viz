<script lang="ts">
  import { playback } from '../stores/playback.svelte';
  import { onMount } from 'svelte';

  let lastFrameTime = 0;

  onMount(() => {
    // Animation loop for playback
    const animate = (timestamp: number) => {
      if (playback.isPlaying) {
        if (lastFrameTime > 0) {
          const deltaMs = Math.min(timestamp - lastFrameTime, 100); // Cap at 100ms
          playback.advance(deltaMs);
        }
      }
      lastFrameTime = timestamp;
      requestAnimationFrame(animate);
    };

    requestAnimationFrame(animate);
  });

  function handlePlayPause() {
    playback.togglePlayback();
  }

  function handleReset() {
    playback.reset();
  }

  function handleSpeedChange(newSpeed: number) {
    playback.setSpeed(newSpeed);
  }

  function handleSeek(e: Event) {
    const input = e.target as HTMLInputElement;
    const progress = parseFloat(input.value);
    const totalMs = playback.endDate.getTime() - playback.startDate.getTime();
    const newTime = new Date(playback.startDate.getTime() + totalMs * progress);
    playback.seek(newTime);
  }

  function handleDateInput(e: Event) {
    const input = e.target as HTMLInputElement;
    const date = new Date(input.value + 'T00:00:00Z');
    if (!isNaN(date.getTime())) {
      playback.seek(date);
    }
  }
</script>

<div class="playback-controls">
  <div class="controls-row">
    <button
      class="control-btn play-btn {playback.isPlaying ? 'playing' : ''}"
      onclick={handlePlayPause}
      title={playback.isPlaying ? 'Pause' : 'Play'}
    >
      {#if playback.isPlaying}
        ⏸ Pause
      {:else}
        ▶ Play
      {/if}
    </button>

    <button class="control-btn" onclick={handleReset} title="Reset to start">
      ⏮ Reset
    </button>

    <div class="speed-controls">
      <label>Speed:</label>
      <select value={playback.playbackSpeed} onchange={(e) => handleSpeedChange(parseFloat(e.target.value*1000))}>
        <option value={0.25}>0.25x</option>
        <option value={0.5}>0.5x</option>
        <option value={1}>1x</option>
        <option value={8}>8x</option>
        <option value={40}>40x</option>
        <option value={200}>200x</option>
        <option value={800}>800x</option>
        <option value={5000}>5000x</option>
        
      </select>
    </div>
  </div>

  <div class="controls-row">
    <div class="time-display">
      <span class="time-label">Time:</span>
      <span class="time-value">{playback.formatTime()}</span>
    </div>
  </div>

  <div class="controls-row">
    <label for="date-input" class="date-label">Jump to date:</label>
    <input
      id="date-input"
      type="date"
      value={playback.formatDate()}
      onchange={handleDateInput}
      min={playback.startDate.toISOString().split('T')[0]}
      max={playback.endDate.toISOString().split('T')[0]}
    />
  </div>

  <div class="timeline-container">
    <input
      type="range"
      class="timeline"
      min="0"
      max="1"
      step="0.001"
      value={playback.getProgress()}
      oninput={handleSeek}
    />
    <div class="timeline-labels">
      <span class="timeline-start">{playback.startDate.toISOString().split('T')[0]}</span>
      <span class="timeline-end">{playback.endDate.toISOString().split('T')[0]}</span>
    </div>
  </div>
</div>

<style>
  .playback-controls {
    position: absolute;
    bottom: 20px;
    left: 20px;
    right: 20px;
    background: rgba(0, 0, 0, 0.85);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 8px;
    padding: 16px;
    z-index: 1001;
    color: #fff;
    font-size: 12px;
    max-width: 500px;
    backdrop-filter: blur(10px);
  }

  .controls-row {
    display: flex;
    gap: 12px;
    align-items: center;
    margin-bottom: 12px;
  }

  .controls-row:last-child {
    margin-bottom: 0;
  }

  .control-btn {
    padding: 8px 12px;
    background: rgba(59, 130, 246, 0.6);
    border: 1px solid rgba(59, 130, 246, 0.8);
    color: #fff;
    border-radius: 4px;
    cursor: pointer;
    font-size: 11px;
    font-weight: 500;
    transition: all 200ms ease;
    white-space: nowrap;
  }

  .control-btn:hover {
    background: rgba(59, 130, 246, 0.8);
    border-color: rgba(59, 130, 246, 1);
  }

  .control-btn.play-btn.playing {
    background: rgba(34, 197, 94, 0.7);
    border-color: rgba(34, 197, 94, 1);
  }

  .speed-controls {
    display: flex;
    gap: 6px;
    align-items: center;
  }

  .speed-controls label {
    font-weight: 500;
    color: #aaa;
  }

  .speed-controls select {
    padding: 4px 6px;
    background: rgba(59, 130, 246, 0.3);
    border: 1px solid rgba(59, 130, 246, 0.5);
    color: #fff;
    border-radius: 3px;
    font-size: 11px;
    cursor: pointer;
  }

  .time-display {
    display: flex;
    gap: 8px;
    align-items: center;
    margin-left: auto;
  }

  .time-label {
    color: #aaa;
    font-weight: 500;
  }

  .time-value {
    color: #fff;
    font-family: monospace;
    font-weight: 600;
  }

  .date-label {
    color: #aaa;
    font-weight: 500;
    white-space: nowrap;
  }

  #date-input {
    padding: 4px 6px;
    background: rgba(59, 130, 246, 0.2);
    border: 1px solid rgba(59, 130, 246, 0.4);
    color: #fff;
    border-radius: 3px;
    font-size: 11px;
    cursor: pointer;
  }

  .timeline-container {
    display: flex;
    flex-direction: column;
    gap: 6px;
    margin-top: 8px;
  }

  .timeline {
    width: 100%;
    height: 6px;
    border-radius: 3px;
    background: rgba(255, 255, 255, 0.1);
    outline: none;
    -webkit-appearance: none;
    appearance: none;
  }

  .timeline::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: rgba(59, 130, 246, 1);
    cursor: pointer;
    box-shadow: 0 0 8px rgba(59, 130, 246, 0.6);
  }

  .timeline::-moz-range-thumb {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: rgba(59, 130, 246, 1);
    cursor: pointer;
    border: none;
    box-shadow: 0 0 8px rgba(59, 130, 246, 0.6);
  }

  .timeline-labels {
    display: flex;
    justify-content: space-between;
    font-size: 10px;
    color: #888;
  }
</style>
