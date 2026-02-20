# Map Visualization - Svelte 5 + D3 + Leaflet

A high-performance, interactive map visualization with a flexible "skin" system enabling vivid animations and dynamic visual effects. Built with Svelte 5, D3, and Leaflet.

## Features

- **6 Vivid Pre-built Skins**:
  1. **Pulsing Orbs** - Breathing circles with synchronized pulses and color cycling
  2. **Neon Glow** - Intense bloom effects with flickering neon colors
  3. **Chromatic Ripple** - Expanding ripples with RGB color separation
  4. **Time Distortion** - Proximity-based time dilation (slow-mo near mouse)
  5. **Particle Trails** - Comet-like particle systems with curved trajectories
  6. **Turbulent Morph** - Organic morphing shapes with SVG turbulence

- **Flexible Skin System**: Create custom skins with TypeScript or JSON
- **Real-time Animations**: 60fps smooth animations using RequestAnimationFrame
- **Viewport Culling**: Only renders visible points for performance
- **Leaflet Integration**: Full map interaction (zoom, pan, etc.)
- **D3 Math Engine**: Scales, interpolators, and projections
- **SVG Rendering**: Supports complex filters and effects

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Run Development Server

```bash
npm run dev
```

The app will open at `http://localhost:5173`

### 3. Build for Production

```bash
npm run build
npm run preview
```

## Project Structure

```
src/
├── lib/
│   ├── components/
│   │   ├── MapContainer.svelte         # Main orchestrator
│   │   ├── LeafletBase.svelte          # Leaflet map wrapper
│   │   ├── SvgOverlay.svelte           # SVG layer management
│   │   ├── PointRenderer.svelte        # Point rendering with skins
│   │   ├── PolygonRenderer.svelte      # Polygon rendering
│   │   └── SkinSelector.svelte         # Skin switcher UI
│   ├── skins/
│   │   ├── types.ts                    # Skin interface definitions
│   │   ├── registry.ts                 # Skin manager
│   │   ├── base-skin.ts                # Default skin
│   │   ├── pulsing-orbs.ts             # Skin 1
│   │   ├── neon-glow.ts                # Skin 2
│   │   ├── chromatic-ripple.ts         # Skin 3
│   │   ├── time-distortion.ts          # Skin 4
│   │   ├── particle-trails.ts          # Skin 5
│   │   ├── turbulent-morph.ts          # Skin 6
│   │   └── index.ts                    # Skin initialization
│   ├── data/
│   │   ├── cities.ts                   # Sample point data (30 cities)
│   │   └── regions.ts                  # Sample polygon data (12 regions)
│   ├── stores/
│   │   └── map-state.svelte.ts         # Global state with Svelte 5 runes
│   └── utils/
├── App.svelte
└── main.ts
```

## Using the App

### Switching Skins

Use the **Skin Selector** panel in the top-left corner to switch between skins. Each skin has:
- Unique visual effects
- Configurable animation parameters
- SVG filter chains
- Custom rendering logic

### Interacting with the Map

- **Zoom**: Scroll wheel or pinch
- **Pan**: Click and drag
- **Time Distortion**: Move your mouse over the map to see proximity-based time dilation

## Creating Custom Skins

### TypeScript Skin (Full Power)

Create a new file in `src/lib/skins/my-skin.ts`:

```typescript
import { createSkin } from './base-skin';
import type { PointData, RenderContext, PointStyle } from './types';

export const mySkin = createSkin({
  id: 'my-skin',
  name: 'My Custom Skin',
  description: 'My awesome visualization',

  colors: {
    primary: '#ff0000',
    secondary: '#00ff00',
    accent: '#0000ff',
  },

  animation: {
    enabled: true,
    duration: 2000,
    easing: 'ease-in-out',
    loop: true,
  },

  filters: {
    glow: {
      enabled: true,
      color: '#ffffff',
      intensity: 2,
    },
  },

  renderPoint(point: PointData, context: RenderContext): PointStyle {
    const [x, y] = context.projection([point.lng, point.lat]);
    const phase = (context.timestamp / this.animation.duration!) % 1;

    return {
      cx: x,
      cy: y,
      r: 8,
      fill: this.colors.primary as string,
      opacity: Math.sin(phase * Math.PI * 2) * 0.5 + 0.5,
      filter: 'url(#glow-filter)',
    };
  },

  renderPolygon(polygon, context) {
    return {
      fill: this.colors.secondary as string,
      stroke: this.colors.primary as string,
      strokeWidth: 1,
      opacity: 1,
      fillOpacity: 0.3,
      strokeOpacity: 0.8,
    };
  },
});
```

Then register it in `src/lib/skins/index.ts`:

```typescript
import { mySkin } from './my-skin';

export function initializeSkins() {
  // ... existing registrations
  skinRegistry.register(mySkin);
}
```

### Using LLM to Generate Skins

Use this prompt template with Claude or another LLM:

```markdown
Generate a new Svelte 5 + D3 + Leaflet skin for map visualization.

**Skin Concept**: [Describe your desired effect, e.g., "underwater bubbles floating upward with wobble"]

**Color Palette**:
- Primary: [color]
- Secondary: [color]
- Accent: [color]

**Animation Parameters**:
- Duration: [milliseconds]
- Loop: true/false
- Easing: ease-in-out, linear, etc.

**Required Filters**: [blur, glow, turbulence, etc.]

**Output Format**:
Provide complete TypeScript code using this structure:
\`\`\`typescript
import { createSkin } from './base-skin';
import type { PointData, RenderContext, PointStyle } from './types';

export const myCustomSkin = createSkin({
  id: 'my-custom-id',
  name: 'My Custom Skin',
  // ... implementation
});
\`\`\`

**Requirements**:
1. Implement renderPoint() method (40-60 lines)
2. Implement renderPolygon() method (10-20 lines)
3. Use Math functions and D3 utilities only
4. Ensure smooth 60fps animations
5. Use phase-based animations: `const phase = (context.timestamp / this.animation.duration!) % 1;`
6. Return valid PointStyle objects with cx, cy, r, fill, opacity
7. Make it vivid and eye-catching
```

### Example LLM Prompt

```
Generate a skin where points are underwater bubbles that float upward and wobble.

Color Palette:
- Primary: #0077be (ocean blue)
- Secondary: #00d4ff (light cyan)
- Accent: #ffffff (white)

Animation: 8000ms duration, ease-in-out, loops

Filters: blur and glow for soft bubble appearance

Create the complete TypeScript code.
```

## Skin Interface Reference

### PointStyle (What Each Point Renders As)

```typescript
interface PointStyle {
  cx: number;              // X coordinate
  cy: number;              // Y coordinate
  r: number;               // Radius
  fill: string;            // Fill color
  stroke?: string;         // Stroke color
  strokeWidth?: number;    // Stroke width
  opacity: number;         // Opacity (0-1)
  filter?: string;         // SVG filter URL
  shape?: 'circle' | 'path'; // Shape type
  pathData?: string;       // SVG path data if shape='path'
  transform?: string;      // CSS transforms
  customAttrs?: Record<string, any>; // Special rendering
}
```

### RenderContext (What You Get)

```typescript
interface RenderContext {
  timestamp: number;       // Current animation time (ms)
  mapBounds: L.LatLngBounds | null; // Current map viewport
  zoom: number;            // Zoom level
  projection: (latlng: [number, number]) => [number, number]; // Lat/lng → pixel
  totalPoints: number;     // Total point count
  index: number;           // Current point index
  customAttrs?: {
    mouseX: number;        // Global mouse X (for proximity effects)
    mouseY: number;        // Global mouse Y
  };
}
```

### Animation Phase Calculation

All animations use normalized phase (0-1):

```typescript
const phase = (context.timestamp / this.animation.duration!) % 1;

// Use phase for sine waves, color cycling, etc.
const opacity = Math.sin(phase * Math.PI * 2) * 0.5 + 0.5; // 0.5-1.0
const scale = phase; // 0-1
const hue = phase * 360; // 0-360
```

## Performance Tips

1. **Viewport Culling**: Only visible points are rendered (automatically handled)
2. **Filter Optimization**: Reuse filters instead of creating per-frame
3. **Transform over Position**: Use CSS transforms for animations (GPU accelerated)
4. **Phase-based Animation**: Use single RAF loop (already implemented)
5. **Conditional Rendering**: Only animate visible elements

## Debugging

- Open browser DevTools (F12)
- Check console for errors
- Use Svelte DevTools extension for reactive state inspection
- Profile with Chrome DevTools Performance tab

## Browser Support

- Chrome/Edge 120+
- Firefox 115+
- Safari 17+
- Requires ES2020 support

## License

MIT

## Future Enhancements

- Canvas fallback for >500 points
- 3D globe mode (Three.js integration)
- Audio-reactive skins
- Multi-layer skin compositing
- Skin marketplace/gallery
- Real-time data import (GeoJSON, CSV)
- Web Worker support for large datasets
- Custom shader-based skins (WebGL)
