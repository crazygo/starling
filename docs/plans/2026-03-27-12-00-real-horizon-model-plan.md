# Real Horizon Model for Voyage Dome View

## Summary

Upgrade Voyage dome mode from a visual-only horizon cue to an astronomy-correct
horizontal-coordinate view, with full upper and lower celestial-sphere
browsing.

The new dome renderer will:

- derive star positions from observer latitude/longitude, observation
  date/time, and star RA/Dec
- project the true `0°` altitude horizon into screen space
- keep stars and constellation lines visually continuous across the horizon
- differentiate the below-horizon region through darker blue background
  treatment only
- preserve orientation with horizon-anchored cardinal markers
- enforce a strict linear drag model with no nonlinear dome remapping
- allow browsing across the full altitude range from zenith `+90°` to nadir
  `-90°`

For v1, the non-gyro default view will use a deterministic seasonal heuristic
rather than a dynamic brightest-region search.

## Key Changes

### 1. Camera and Coordinate Model

Replace the dome mode's current RA/Dec rectangular viewport logic with a
horizontal-coordinate camera model.

- Dome mode camera state becomes:
  - `centerAzimuthDeg`
  - `centerAltitudeDeg`
  - `zoom`
- Classic mode remains unchanged and continues using the current RA/Dec
  viewport behavior.
- For dome mode, each star is converted from equatorial coordinates to
  horizontal coordinates using existing astronomy utilities and the current
  observation context.
- Screen projection for dome mode must be computed from relative
  azimuth/altitude against the camera center, not from the current fake Y
  remap.
- The horizon line must be mathematically projected from the `altitude = 0°`
  circle into the same screen space as stars and lines.
- The horizon must move with camera pitch because it is part of the same
  projected sky, not an independently animated overlay.

### 2. Observation Context and Inputs

Thread real observation inputs from Explore into the dome renderer.

- Use observer location from:
  - GPS when `LocationMode.gps` is active and a fix exists
  - Beijing fallback when GPS is unavailable or disabled
- Use observation time from the existing Explore date/time controls.
- Normalize to UTC before passing into astronomy conversion utilities.
- Add a dome-specific render context object or equivalent input bundle so the
  chart receives:
  - latitude
  - longitude
  - UTC observation datetime
  - camera azimuth/altitude
- Reuse `AstronomyUtils.equatorialToHorizontal(...)` as the conversion
  primitive; extend only if needed for projection helpers, not for alternative
  astronomy formulas.

### 3. Interaction Model

Keep dome interaction physically consistent and support full-sphere browsing.

- Vertical drag in dome mode controls camera altitude directly with a strict
  linear mapping.
- Horizontal drag in dome mode controls camera azimuth directly with the same
  kind of linear mapping.
- No nonlinear damping, soft clamp, safe-zone remap, or horizon-specific drift
  logic in dome mode.
- Swipe distance must be symmetric:
  - horizon to zenith uses the same physical drag distance as zenith back to
    horizon
- Dome pitch range:
  - min altitude: `-90°`
  - max altitude: `+90°`
- Users may browse the full celestial sphere, including below the true horizon
  and down toward the nadir.
- Gyro mode should continue to apply an additive orientation offset, but its
  dome result must still clamp to `[-90°, +90°]`.

### 4. Visual Rules

Render the horizon as physically meaningful, while keeping the celestial
content continuous.

- Stars:
  - do not dim stars below the horizon
  - do not change star size or contrast based on above/below-horizon
    classification
- Constellation lines:
  - remain continuous across the horizon
  - do not clip at the horizon
  - keep the same visual treatment above and below horizon for v1
- Below-horizon background:
  - use the same blue visual family as the sky
  - make the blue below the true horizon darker than the blue above it
  - do not add explicit terrain art, earth texture, or a strong "ground" read
  - keep the transition subtle enough that visual clarity of stars and labels
    is not harmed
- Horizon line:
  - single line only
  - drawn from the true projected `0°` altitude curve
  - shallow and visually restrained, but clearly legible
- Cardinal markers:
  - `N`, `S`, `E`, `W` belong to the true horizon projection
  - marker positions are determined from azimuths on the `0°` altitude line
  - if a marker would fall off-screen because the horizon is out of view, pin
    it to the nearest screen edge while preserving left/right ordering and
    label identity

### 5. Default Initial Camera State

Replace the current arbitrary seasonal RA/Dec center for dome mode with a
seasonal horizontal heuristic.

- This rule applies only when not using gyroscope input.
- Initial dome pitch defaults to `+18°`.
- Initial dome azimuth uses a deterministic seasonal heuristic rather than a
  score-based search.
- For v1, define the heuristic as:
  - Northern hemisphere:
    - winter: face south
    - spring: face south
    - summer: face south
    - autumn: face south
  - Southern hemisphere:
    - winter: face north
    - spring: face north
    - summer: face north
    - autumn: face north
- Then apply a seasonal azimuth bias so the framing reflects the current
  prominent sky region without changing the base facing direction too
  aggressively:
  - winter: `0°` bias
  - spring: `+30°`
  - summer: `-30°`
  - autumn: `0°`
- If implementation simplicity is preferred, the v1 fallback is:
  - face south in northern hemisphere
  - face north in southern hemisphere
  - pitch `+18°`
- Keep this heuristic isolated in one helper so a later issue can replace it
  with a smarter visibility-based target selection.

## Public Interfaces / Types

- `StarChart` will need dome-specific observation inputs in addition to its
  current viewport:
  - observer latitude
  - observer longitude
  - observation datetime
- Dome view should use a dedicated camera representation, either:
  - a new dome camera type, or
  - an expanded viewport model with clear mode-specific semantics
- `ExplorePage` must pass the selected observation date/time and resolved
  observer location into the chart.
- `AstronomyUtils` remains the main astronomy conversion surface; add small
  projection helpers only if needed.

## Test Plan

### Unit Tests

- `AstronomyUtils.equatorialToHorizontal(...)` continues to pass existing
  tests.
- Add tests for dome camera clamp behavior:
  - altitude clamps to `+90°`
  - altitude clamps to `-90°`
  - azimuth wraps correctly across `0°/360°`
- Add tests for horizon classification:
  - stars with altitude `> 0` are above horizon
  - stars with altitude `< 0` are below horizon
  - stars near `0°` are handled stably with a small epsilon policy
- Add tests for seasonal default camera helper:
  - correct hemisphere-facing direction
  - correct default pitch
  - deterministic result for given date/location

### Widget / Rendering Tests

- Dome mode with a fixed location/time shows:
  - a projected horizon in the expected screen position
  - visible stars both above and below the horizon
  - no brightness difference between above- and below-horizon stars
  - cardinal markers on or edge-pinned from the true horizon line
- Looking upward moves the horizon downward without changing star/horizon
  relative geometry.
- Looking downward moves the horizon upward and still preserves star/horizon
  relative geometry.
- Nadir-facing states still render a stable full-sphere view without nonlinear
  dead zones.

### Manual / Screenshot Scenarios

- Default Explore dome screenshot for:
  - northern hemisphere winter evening
  - northern hemisphere summer evening
- Drag upward to zenith:
  - horizon moves down consistently
  - no nonlinear dead zone
- Drag downward toward nadir:
  - horizon moves up consistently
  - no independent horizon stop while stars continue moving
- GPS off / Beijing fallback
- GPS on with live location fix

## Assumptions and Defaults

- This issue changes dome mode only; classic mode remains on the current
  RA/Dec renderer.
- Real horizon correctness is defined by existing equatorial-to-horizontal
  conversion utilities plus observation context from Explore.
- Below-horizon differentiation is done only through a darker blue background
  treatment, not by dimming stars or lines.
- Dome mode is now a full-sphere browsing mode, not a limited pitch safety
  view.
- The initial non-gyro dome view uses a seasonal heuristic, not a dynamic
  "brightest visible region" search.
