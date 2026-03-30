# Feature Plan: Celestial Grid + Horizon Grid Toggles

## Background
- Need two independent sky grid overlays:
  - **Celestial grid (equatorial)**: Earth-centered reference grid, same definition for all observers.
  - **Horizon grid (horizontal/alt-az)**: local observer grid, dependent on geographic location and time.
- Defaults:
  - Horizon grid **ON** by default.
  - Celestial grid **OFF** by default.
  - Both can be ON simultaneously and must be visually distinguishable.
- Validation expectation:
  - In celestial-grid mode, **Polaris** should appear near the north celestial pole (high declination region).

## Implementation Plan
1. **Settings model**
   - Add persistent flags in `SettingsService`:
     - `showHorizonGrid` (default true)
     - `showCelestialGrid` (default false)
   - Add setters + SharedPreferences persistence.

2. **Settings UI**
   - Add two toggles under visual settings:
     - Draw horizon grid (default ON)
     - Draw celestial grid (default OFF)
   - Keep labels clear about coordinate frames.

3. **Wire settings into Explore page**
   - Read the two flags from provider selectors.
   - Pass down to `StarChart`.

4. **StarChart + painter support**
   - Extend `StarChart` and `_StarPainter` props for both toggles.
   - Implement overlay drawing:
     - **Horizon grid** from horizontal coordinates (azimuth/altitude).
     - **Celestial grid** from equatorial coordinates (RA/Dec).
   - Ensure style distinction (different color/line dash/opacity).
   - Draw order: backdrop -> grids -> stars/constellations/labels -> dome foreground.

5. **Coordinate conversion support**
   - Add horizontal→equatorial conversion utility for classic/equatorial projection case.
   - Reuse existing equatorial→horizontal where appropriate.

6. **Verification / sanity check**
   - Static analysis/formatting.
   - Quick run checks.
   - Confirm logic that celestial declination circles include near +90° region where Polaris should map near celestial pole.

## Risks / Notes
- Rendering many polylines can affect performance; sample step sizes should be moderate.
- In dome mode, clipping near horizon/edge may create broken segments; line-building should skip discontinuities.
- Distinguish azimuth/altitude and RA/Dec carefully to avoid frame confusion.
