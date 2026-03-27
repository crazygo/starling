# Plan: Fixed Angular Density for Star Chart Projection

## Summary

Fix the star chart projection so it uses a fixed angular density instead of a
fixed field of view.

At `zoom = 1`, both classic and dome mode should project the sky at
`0.15° / px` on both axes. This means:

- wider screens show more of the sky horizontally
- taller screens show more of the sky vertically
- stars keep consistent geometry instead of being stretched by the viewport
- zoom still works by reducing degrees per pixel as zoom increases

## Scope

- Update classic-mode projection in `lib/widgets/star_chart.dart`
- Update dome-mode projection in `lib/widgets/star_chart.dart`
- Update gesture and trackpad pan math so both modes use the same
  density-driven interpretation of screen motion
- Add focused regression coverage for both classic and dome projection math

## Implementation

- Introduce shared per-mode helpers:
  - `classicDegreesPerPixelForZoom(zoom)`
  - `domeDegreesPerPixelForZoom(zoom)`
- Derive classic half-span from the actual render size:
  - `halfWidth = size.width / 2 * degPerPixel`
  - `halfHeight = size.height / 2 * degPerPixel`
- Derive dome perspective focal length from density instead of fixed width FOV:
  - `focalLength = 1 / radians(degPerPixel)`
- Use the same helper for:
  - star projection
  - drag panning
  - trackpad scrolling

## Acceptance

- Classic mode uses `0.15° / px` at `zoom = 1`
- Dome mode uses `0.15° / px` at `zoom = 1`
- Wider screens show a larger horizontal sky span in both modes
- Horizontal and vertical density stay matched
- Existing zoom and pan behavior remains functional

## Validation

- `flutter test`
- `flutter analyze lib test`
- Added regression coverage:
  - `test/star_chart_projection_test.dart`
