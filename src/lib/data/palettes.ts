/**
 * Color Palette System for Dystopian Decay Visualizations
 * Palettes designed to evoke themes of rot, decay, pollution, and environmental collapse
 */

export interface ColorPalette {
  id: string;
  name: string;
  description: string;
  gradient: {
    [key: string]: string; // Stop position (0.0-1.0) to color
  };
}

/**
 * Collection of dystopian decay-themed color palettes
 */
export const COLOR_PALETTES: ColorPalette[] = [
  {
    id: 'toxic-wasteland',
    name: 'Toxic Wasteland',
    description: 'Earthy greens, muted grays, and neon green accents suggesting radioactive decay',
    gradient: {
      '0.0': '#2d3436',  // Deep charcoal
      '0.25': '#4a5759', // Muted gray
      '0.5': '#74b49b',  // Murky green
      '0.75': '#a7d129', // Sickly lime
      '1.0': '#39ff14',  // Neon green accent
    },
  },
  {
    id: 'rusted-future',
    name: 'Rusted Future',
    description: 'Deep rust-browns and warm oranges representing decaying machinery',
    gradient: {
      '0.0': '#3d2817',  // Deep brown
      '0.3': '#7e4b3a',  // Deep rust
      '0.6': '#b5651d',  // Burnt sienna
      '0.8': '#d4a373',  // Terracotta
      '1.0': '#f4a460',  // Sandy brown
    },
  },
  {
    id: 'industrial-decay',
    name: 'Industrial Decay',
    description: 'Deep charcoal, greenish-yellows, and muted browns of abandoned factories',
    gradient: {
      '0.0': '#1a1a1a',  // Deep charcoal
      '0.3': '#3e3e3e',  // Dark gray
      '0.5': '#6b6b47',  // Greenish-brown
      '0.7': '#8b8b3d',  // Dingy yellow-green
      '1.0': '#b5b56a',  // Sickly yellow
    },
  },
  {
    id: 'faded-illusion',
    name: 'Faded Illusion',
    description: 'Pale pinks and creams suggesting artificiality and hidden rot beneath',
    gradient: {
      '0.0': '#e8d5c4',  // Pale cream
      '0.3': '#f0d9ca',  // Peachy beige
      '0.6': '#f5c7c7',  // Faded pink
      '0.8': '#e8a5a5',  // Dusty rose
      '1.0': '#d88484',  // Muted coral
    },
  },
  {
    id: 'moldy-overgrowth',
    name: 'Moldy Overgrowth',
    description: 'Muted greens representing fungus, mold, and nature consuming ruins',
    gradient: {
      '0.0': '#2c3e2c',  // Dark forest
      '0.3': '#4a5f4a',  // Muted olive
      '0.6': '#6b8e6b',  // Mossy green
      '0.8': '#8fac8f',  // Pale sage
      '1.0': '#b8d4b8',  // Faded mint
    },
  },
  {
    id: 'ashen-ruins',
    name: 'Ashen Ruins',
    description: 'Muted grays and ashen tones representing absence of life',
    gradient: {
      '0.0': '#1c1c1c',  // Near black
      '0.25': '#3a3a3a', // Charcoal
      '0.5': '#5e5e5e',  // Medium gray
      '0.75': '#8a8a8a', // Light gray
      '1.0': '#b8b8b8',  // Ashen
    },
  },
  {
    id: 'polluted-atmosphere',
    name: 'Polluted Atmosphere',
    description: 'Dingy yellows and browns suggesting poisoned air and smog',
    gradient: {
      '0.0': '#3d3420',  // Dark brown
      '0.3': '#5e5438',  // Murky brown
      '0.5': '#807850',  // Olive brown
      '0.7': '#9d9560',  // Dingy yellow
      '1.0': '#b8ad6b',  // Sickly yellow
    },
  },
  {
    id: 'stagnant-water',
    name: 'Stagnant Water',
    description: 'Olive and teal tones evoking stagnant, polluted water',
    gradient: {
      '0.0': '#1f2e2e',  // Deep teal-black
      '0.3': '#3a4f4a',  // Dark olive-teal
      '0.6': '#5a7067',  // Murky teal
      '0.8': '#7a9084',  // Pale olive
      '1.0': '#9fb0a3',  // Faded sage-teal
    },
  },
  {
    id: 'chemical-burn',
    name: 'Chemical Burn',
    description: 'Harsh yellows and burnt oranges suggesting chemical pollution',
    gradient: {
      '0.0': '#4a3c28',  // Dark burnt umber
      '0.25': '#6b5433', // Medium brown
      '0.5': '#8b7040',  // Mustard brown
      '0.75': '#c9a847', // Sickly gold
      '1.0': '#e8c547',  // Chemical yellow
    },
  },
  {
    id: 'bio-decay',
    name: 'Bio-Decay',
    description: 'Sickly greens and yellows representing biological decomposition',
    gradient: {
      '0.0': '#2a3a2a',  // Deep olive
      '0.3': '#3d4f3a',  // Dark moss
      '0.5': '#5e6e4a',  // Olive green
      '0.7': '#7e8e5a',  // Sickly green
      '1.0': '#9eae6a',  // Pale decay
    },
  },
  {
    id: 'radiation-zone',
    name: 'Radiation Zone',
    description: 'Dark grays to neon greens suggesting radioactive contamination',
    gradient: {
      '0.0': '#0a0f0a',  // Near black
      '0.2': '#1a2a1a',  // Dark green-black
      '0.4': '#2a4a2a',  // Deep green
      '0.7': '#4a8a4a',  // Medium radioactive
      '1.0': '#6aff6a',  // Bright radioactive
    },
  },
  {
    id: 'corroded-metal',
    name: 'Corroded Metal',
    description: 'Teal-greens and rust representing oxidized copper and iron',
    gradient: {
      '0.0': '#2d3a3a',  // Dark teal-gray
      '0.25': '#4a5e5a', // Weathered teal
      '0.5': '#6a7e7a',  // Oxidized green
      '0.75': '#8a6e5a', // Rust transition
      '1.0': '#aa5a3a',  // Deep rust
    },
  },
  {
    id: 'dead-forest',
    name: 'Dead Forest',
    description: 'Earthy browns and dead leaf colors',
    gradient: {
      '0.0': '#2a2419',  // Dark soil
      '0.3': '#4a4129',  // Dead leaves
      '0.6': '#6a5e39',  // Dried bark
      '0.8': '#8a7a49',  // Dead grass
      '1.0': '#aa9a59',  // Faded straw
    },
  },
  {
    id: 'urban-smog',
    name: 'Urban Smog',
    description: 'Grays and dingy yellows representing city pollution',
    gradient: {
      '0.0': '#2d2d2d',  // Dark gray
      '0.25': '#4d4d45', // Gray-brown
      '0.5': '#6d6d5d',  // Medium smog
      '0.75': '#8d8d75', // Light smog
      '1.0': '#adad8d',  // Yellow haze
    },
  },
  {
    id: 'plague-rot',
    name: 'Plague Rot',
    description: 'Sickly purples and greens suggesting disease and pestilence',
    gradient: {
      '0.0': '#2a1f2a',  // Deep purple-black
      '0.3': '#3a2f3a',  // Dark purple-gray
      '0.5': '#4a4f4a',  // Gray-green
      '0.7': '#5a6a5a',  // Sickly green-gray
      '1.0': '#7a8a6a',  // Pale sick green
    },
  },
  {
    id: 'glitch-corruption',
    name: 'Glitch Corruption',
    description: 'Digital decay with jarring cyan to magenta shifts',
    gradient: {
      '0.0': '#0a0a0a',  // Near black
      '0.2': '#1a4a4a',  // Dark teal
      '0.4': '#ff00ff',  // Sudden magenta
      '0.6': '#2a2a6a',  // Dark blue
      '0.8': '#00ffff',  // Bright cyan
      '1.0': '#ff1493',  // Deep pink
    },
  },
  {
    id: 'toxic-sunset',
    name: 'Toxic Sunset',
    description: 'Beautiful but poisonous oranges clashing with sickly greens',
    gradient: {
      '0.0': '#3a2a1a',  // Dark brown
      '0.25': '#ff6b35', // Harsh orange
      '0.5': '#4a5a2a',  // Sudden olive
      '0.75': '#ff8c42', // Return to orange
      '1.0': '#9acd32',  // Jarring yellow-green
    },
  },
  {
    id: 'nuclear-twilight',
    name: 'Nuclear Twilight',
    description: 'Purple twilight interrupted by radioactive green spikes',
    gradient: {
      '0.0': '#2a1a3a',  // Deep purple
      '0.3': '#4a2a5a',  // Dark violet
      '0.5': '#39ff14',  // Sudden neon green
      '0.7': '#5a3a7a',  // Back to purple
      '1.0': '#7fff00',  // Bright chartreuse
    },
  },
  {
    id: 'synthetic-flesh',
    name: 'Synthetic Flesh',
    description: 'Unsettling pinks clashing with mechanical grays and neon blues',
    gradient: {
      '0.0': '#3a3a3a',  // Dark gray
      '0.25': '#ff69b4', // Sudden hot pink
      '0.5': '#4a4a5a',  // Return to gray-blue
      '0.75': '#00bfff', // Jarring deep sky blue
      '1.0': '#ff1493',  // Violent pink
    },
  },
  {
    id: 'corrupted-gold',
    name: 'Corrupted Gold',
    description: 'Regal golds tarnished by invasive purples and greens',
    gradient: {
      '0.0': '#2a2218',  // Dark brown
      '0.2': '#ffd700',  // Sudden gold
      '0.4': '#4a2a5a',  // Discordant purple
      '0.7': '#b8860b',  // Dark golden rod
      '1.0': '#32cd32',  // Jarring lime green
    },
  },
  {
    id: 'blood-rust',
    name: 'Blood Rust',
    description: 'Deep reds interrupted by oxidized greens and chemical yellows',
    gradient: {
      '0.0': '#2a0a0a',  // Near black-red
      '0.3': '#8b0000',  // Dark red
      '0.5': '#4a6a5a',  // Sudden teal-green
      '0.7': '#cd5c5c',  // Indian red
      '1.0': '#ffff00',  // Harsh yellow
    },
  },
  {
    id: 'neon-necropolis',
    name: 'Neon Necropolis',
    description: 'Dead grays exploding into violent neon pinks and greens',
    gradient: {
      '0.0': '#1a1a1a',  // Dark gray
      '0.25': '#3a3a3a', // Medium gray
      '0.5': '#ff00ff',  // Violent magenta
      '0.75': '#00ff00', // Harsh green
      '1.0': '#ff10f0',  // Bright pink
    },
  },
  {
    id: 'acid-rain',
    name: 'Acid Rain',
    description: 'Watery blues corrupted by chemical yellows and toxic oranges',
    gradient: {
      '0.0': '#1a2a3a',  // Dark blue
      '0.3': '#4a6a8a',  // Slate blue
      '0.5': '#ffff00',  // Sudden yellow
      '0.7': '#5a7a9a',  // Return to blue
      '1.0': '#ff4500',  // Harsh orange-red
    },
  },
];

/**
 * Get palette by ID
 */
export function getPaletteById(id: string): ColorPalette | undefined {
  return COLOR_PALETTES.find(p => p.id === id);
}

/**
 * Get default palette
 */
export function getDefaultPalette(): ColorPalette {
  return COLOR_PALETTES[0]; // Toxic Wasteland
}
