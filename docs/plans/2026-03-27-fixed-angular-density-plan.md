# Plan: Fixed Angular Density for Classic Star Chart

## Summary

Fix the classic star chart projection so it uses a fixed angular density
instead of a fixed field of view.

At `zoom = 1`, classic mode should project the sky at `0.15° / px` on both
axes. This means:

- wider screens show more of the sky horizontally
- taller screens show more of the sky vertically
- stars keep consistent geometry instead of being stretched by the viewport
- zoom still works by reducing degrees per pixel as zoom increases

## Scope

- Update classic-mode projection in `lib/widgets/star_chart.dart`
- Update classic-mode gesture and trackpad pan math to use the same angular
  density model
- Leave dome-mode projection unchanged
- Add a focused regression test for the classic projection math

## Implementation

- Introduce a shared classic-mode helper:
  - `classicDegreesPerPixelForZoom(zoom)`
- Derive classic half-span from the actual render size:
  - `halfWidth = size.width / 2 * degPerPixel`
  - `halfHeight = size.height / 2 * degPerPixel`
- Use the same helper for:
  - star projection
  - drag panning
  - trackpad scrolling

## Acceptance

- Classic mode uses `0.15° / px` at `zoom = 1`
- Wider screens show a larger horizontal sky span
- Horizontal and vertical density stay matched
- Existing zoom and pan behavior remains functional

## Validation

- `flutter test`
- `flutter analyze lib test`
- Added regression test:
  - `test/star_chart_projection_test.dart`
