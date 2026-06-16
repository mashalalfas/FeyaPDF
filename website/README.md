# FeyaPDF — Animated SVG Logo

**Encrypted PDF Reader** brand mark.

Built with **Three.js SVGRenderer** + **GSAP** in a single self-contained HTML file. No build step, no npm — open `logo.html` directly in any modern browser.

## Animation Phases

| Phase | Time | Description |
|-------|------|-------------|
| **1 — Particle Assembly** | 0–1.5s | Teal glowing particles swirl from all directions and spiral into the shape of a PDF document icon (rectangle with folded corner). 3D depth via Three.js PerspectiveCamera. |
| **2 — Shield Reveal** | 1.5–2.7s | A shield draws itself around the PDF icon with a glowing teal stroke. A lock icon scales up inside, centered on the shield. |
| **3 — Text Entrance** | 2.5–3.7s | "FEYA" slides in from the left, "PDF" from the right, meeting below the icon. Tagline "ENCRYPTED PDF READER" fades up. |
| **4 — Idle Loop** | 3.5s+ | Continuous subtle motion — shield opacity pulses, lock icon breathes, keyhole amber glow oscillates, particles drift gently with parallax. |

## Brand Palette

- **Teal** `#00897B` — primary brand color
- **Amber** `#FFB300` — accent (keyhole)
- **Dark** `#1A1C1E` — background
- **Warm Beige** `#FBF8F1` — reserved for light-mode usage

## Technical Stack

- **Three.js r128** — SVGRenderer for perspective-projected particles rendered as SVG `<circle>` elements
- **GSAP 3.12** — master timeline, easing, staggered entrances, infinite yoyo loops
- **SVG filters** — `feGaussianBlur` + `feMerge` for teal glow, amber keyhole pulse
- **Responsive** — scales to any viewport via `max-width`/`max-height` and SVG `viewBox`

## Usage

```bash
# Open directly
open logo.html

# Or serve locally
python3 -m http.server 8000
# → http://localhost:8000/logo.html
```

All dependencies loaded from CDN — no installation required.

## File Structure

```
logo.html          Single file (~480 lines)
├── <style>        CSS — dark background, centering, glow
├── <svg>          Overlay — shield, lock, text + SVG filters
├── <script> CDN   three.js r128 + SVGRenderer + GSAP 3
└── <script> App   Three.js scene → particle system → GSAP timeline → render loop
```
