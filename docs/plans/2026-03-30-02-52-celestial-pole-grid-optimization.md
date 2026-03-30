# Celestial pole grid optimization plan

## Background
- Current celestial (equatorial) grid draws both declination and right ascension lines across the full sky, which adds too much visual noise.
- Product intent is to keep the horizon grid as default, while the celestial grid should only act as a subtle cue near the celestial pole.

## Goals
1. Keep horizon grid behavior unchanged.
2. Redesign celestial grid so it only renders latitude-like declination arcs near the local celestial pole.
3. Remove all right ascension (vertical) lines for celestial grid.
4. Make declination arcs fade out with distance from the pole so most of the screen has no celestial grid.

## Implementation approach
- Update `lib/widgets/star_chart.dart`:
  - Replace full-range declination loop with a pole-focused set of declinations.
  - Determine target pole by observer latitude sign (`+90` north / `-90` south).
  - Draw only declination curves from the pole outward for a limited angular span.
  - Compute per-line alpha based on angular distance from the pole (closer to pole = stronger, farther = weaker) and skip very faint lines.
  - Stop drawing right ascension curves in celestial grid rendering.

## Validation
- Run focused tests related to rendering math/projection:
  - `flutter test test/star_chart_projection_test.dart`
- If environment is missing Flutter SDK/dependencies, record as warning and provide exact command output.

## PR message note
Use this plan content as the PR body after implementation.
