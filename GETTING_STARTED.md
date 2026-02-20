# Getting Started with Map Visualization

Your Svelte 5 + D3 + Leaflet visualization app is ready to use!

## Installation & Running

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build
```

## What's Included

### 6 Vivid Skins
All 6 skins are pre-built and ready to use. Switch between them using the **Skin Selector** panel in the top-left:

1. **Pulsing Orbs** - Breathing circles with color cycling
2. **Neon Glow** - Intense glowing effects with neon colors
3. **Chromatic Ripple** - Expanding ripples with RGB separation
4. **Time Distortion** - Move your mouse to slow down nearby points
5. **Particle Trails** - Comet-like particle effects
6. **Turbulent Morph** - Organic morphing shapes

### Sample Data
- **30 World Cities** - Major cities with population data
- **12 Geographic Regions** - Simplified continental boundaries

### Interactive Features
- **Map Interaction**: Zoom and pan with your mouse
- **Proximity Effects**: Time Distortion skin slows animations near your cursor
- **Real-time Animations**: 60fps smooth animations
- **Viewport Culling**: Optimized rendering for performance

## Creating Custom Skins

### Quick: Use TypeScript Template

Copy this to create a new skin file (`src/lib/skins/custom-skin.ts`):

```typescript
import { createSkin } from './base-skin';
import type { PointData, RenderContext, PointStyle } from './types';

export const customSkin = createSkin({
  id: 'custom-skin',
  name: 'My Custom Skin',
  description: 'My awesome visualization',

  colors: {
    primary: '#ff0066',
    secondary: '#00ff99',
    accent: '#ffaa00',
  },

  animation: {
    enabled: true,
    duration: 2000,
    easing: 'ease-in-out',
    loop: true,
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
import { customSkin } from './custom-skin';

// In initializeSkins():
skinRegistry.register(customSkin);
```

### Better: Ask Claude/ChatGPT to Generate a Skin

Use this prompt:

```
I'm building a map visualization with Svelte 5 and D3. I need a new skin.

Concept: [describe your effect, e.g., "stars twinkling"]
Colors: [provide 3 hex colors for primary, secondary, accent]
Duration: [animation length in ms, e.g., 3000]

Generate complete TypeScript code for a skin using this structure:

import { createSkin } from './base-skin';
import type { PointData, RenderContext, PointStyle } from './types';

export const [skinName] = createSkin({
  id: '[skin-id]',
  name: '[Display Name]',
  description: '[Description]',
  colors: { primary: ..., secondary: ..., accent: ... },
  animation: { enabled: true, duration: ..., easing: ..., loop: true },
  renderPoint(point: PointData, context: RenderContext): PointStyle {
    // Implement point rendering
  },
  renderPolygon(polygon, context) {
    // Implement polygon rendering
  },
});

Make it vivid and eye-catching!
```

## Key Files to Know

- **Skin Registry**: `src/lib/skins/index.ts` - Register new skins here
- **Skin Types**: `src/lib/skins/types.ts` - Interface definitions
- **Sample Skins**: `src/lib/skins/*.ts` - Reference implementations
- **Global State**: `src/lib/stores/map-state.svelte.ts` - Animation timing, mouse position
- **Data**: `src/lib/data/cities.ts`, `src/lib/data/regions.ts`

## Animation Tips

### Phase-Based Animation (Standard Pattern)

```typescript
// Get normalized phase (0 to 1)
const phase = (context.timestamp / this.animation.duration!) % 1;

// Sine wave oscillation (0.5 to 1.0)
const opacity = Math.sin(phase * Math.PI * 2) * 0.5 + 0.5;

// Color rotation (0 to 360 degrees)
const hue = phase * 360;

// Scale pulsation
const scale = 1 + Math.sin(phase * Math.PI * 2) * 0.3;
```

### Using Stagger for Sequential Effects

```typescript
const staggeredPhase = (phase + context.index * 0.1) % 1;
// Each point animates with a delay based on its index
```

### Proximity Detection (Time Distortion Example)

```typescript
const mouseX = context.customAttrs?.mouseX ?? 0;
const mouseY = context.customAttrs?.mouseY ?? 0;
const distance = Math.sqrt((x - mouseX) ** 2 + (y - mouseY) ** 2);

if (distance < 200) {
  // Apply effect when within 200px of mouse
}
```

## Performance Optimization

The app automatically:
- ✅ Culls points outside viewport
- ✅ Uses single RAF loop for all animations
- ✅ Reuses SVG filters instead of recreating
- ✅ Applies GPU acceleration with CSS transforms

For large datasets (500+ points), consider:
- Increasing viewport culling threshold
- Using Canvas fallback (not yet implemented)
- Reducing filter complexity

## Debugging

### See Skin Data
```typescript
// In browser console:
import { skinRegistry } from './lib/skins';
console.log(skinRegistry.getAll());
```

### Watch State Changes
```typescript
// In component:
console.log('Active skin:', mapState.activeSkin);
console.log('Timestamp:', mapState.timestamp);
console.log('Mouse:', mapState.globalMouseX, mapState.globalMouseY);
```

## Next Steps

1. **Try each skin** - Use the skin selector to test all 6 effects
2. **Understand animations** - Read a skin implementation like `pulsing-orbs.ts`
3. **Create your first skin** - Start with a simple sine wave effect
4. **Use LLM** - Generate more complex skins with Claude/ChatGPT
5. **Explore data** - Modify `cities.ts` and `regions.ts` with your own data

## Common Questions

**Q: How do I add my own data?**
A: Edit `src/lib/data/cities.ts` and `src/lib/data/regions.ts` with your GeoJSON or CSV data.

**Q: Can I use this with a backend?**
A: Yes! The frontend is completely decoupled. You can fetch data from any API.

**Q: How do I optimize for large datasets?**
A: Use viewport culling (already implemented). For 500+ points, Canvas renderer would be better.

**Q: Can I generate skins programmatically?**
A: Yes, use the `SafeSkinConfig` interface in `registry.ts` to load JSON skins.

## Architecture Overview

```
SVG Overlay (SvgOverlay.svelte)
├── PointRenderer × 30 (renders each city with active skin)
└── PolygonRenderer × 12 (renders each region)

Animation Loop (MapContainer)
└── requestAnimationFrame → mapState.updateTimestamp()
    └── All renderers reactively update via Svelte $derived

Map State Store (Svelte 5 $state)
├── activeSkin: Current visualization
├── timestamp: Animation time
├── globalMouseX/Y: Proximity effects
└── mapBounds: Viewport culling
```

## Resources

- Svelte 5 Docs: https://svelte.dev
- Leaflet Docs: https://leafletjs.com
- D3 Docs: https://d3js.org
- Full README: See `README.md`

Happy visualizing! 🎨
