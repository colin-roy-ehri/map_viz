import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [svelte()],
  assetsInclude: ['**/*.csv'],
  optimizeDeps: {
    include: [
      'leaflet',
      'd3-scale',
      'd3-interpolate',
      'd3-color',
      'd3-ease',
      'd3-geo',
      'd3-array',
    ],
  },
  server: {
    port: 5173,
    open: true,
  },
  build: {
    target: 'ES2020',
    minify: 'terser',
  },
});
