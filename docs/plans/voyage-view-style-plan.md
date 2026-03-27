# Voyage View Style Plan

## Summary

This change introduces a user-selectable sky view style for the Voyage screen.
The new dome-style view becomes the default, while the current flat rectangular
chart remains available as a Classic fallback.

The dome view must avoid the disorienting "crossing over the head" interaction
seen in some other sky apps. Users should be able to raise the view toward the
zenith, but the zenith must never move into the main observation region of the
screen. The goal is to preserve immersion without sacrificing orientation.

This document is intended to be reused as the PR body so reviewers can read the
design intent and behavior constraints directly from one source.

## Key Changes

### 1. Add a persisted view-style setting

- Extend `SettingsService` with a new `ViewStyle` enum.
- Persist the selected style in `SharedPreferences`.
- Default to the new dome view for users with no stored preference.
- Expose the selected style through a getter and setter so the Explore/Voyage
  screen can rebuild immediately when the preference changes.

Initial options:

- `dome`: new immersive sky view, default
- `classic`: current rectangular chart

### 2. Add a View Style section in Settings

- Add a new section to the Settings page using the existing option-tile pattern.
- Add English and Chinese localization strings for:
  - section title
  - dome option title/subtitle
  - classic option title/subtitle
- Keep the setting lightweight and consistent with the existing Culture,
  Location, and Language sections.

### 3. Make the chart render by selected style

- Update the Voyage/Explore page to read `viewStyle` from `SettingsService`.
- Pass the selected style into `StarChart`.
- Keep the current rendering path as the `classic` implementation.
- Add a separate `dome` rendering path that changes presentation without
  changing the underlying star data or label model.

### 4. Define dome-mode presentation

The dome view should feel like looking upward from a horizon-based viewpoint,
not like freely rotating a full sphere.

Rendering rules:

- Present the sky inside a dome-shaped or dome-framed composition rather than a
  flat edge-to-edge rectangle.
- Use atmospheric background treatment instead of a single flat fill.
- Add persistent orientation anchors, at minimum:
  - horizon cue
  - subtle directional framing
  - a zenith cue
- Keep stars, constellation lines, labels, tap handling, zoom, and gyro support
  working in both styles.

### 5. Define zenith-safe interaction constraints

This is the key behavioral requirement for dome mode.

Desired composition:

- In the resting/default state, roughly 90% of the screen represents sky above
  the horizon and roughly 10% acts as below-horizon framing.
- As the user drags upward, the horizon moves downward and the zenith moves
  into view.
- The zenith may approach the upper part of the screen, but it must not be
  allowed to enter the main observation zone.

Hard constraint:

- The zenith must never move lower than about the top 20% of the screen in dome
  mode.
- Once the zenith reaches that threshold, further upward dragging should no
  longer advance the view.

Interaction behavior at the limit:

- Apply resistance as the user approaches the zenith cap.
- Clamp at the cap rather than allowing a flip or reference-frame inversion.
- Avoid any interaction model where the zenith can reach the screen center.
- Keep left/right dragging semantically stable so users retain orientation near
  the cap.

This means the constraint is defined in screen-composition terms, not only as a
raw astronomical altitude limit.

## Public Interfaces / Types

- Add `ViewStyle` enum to `lib/services/settings_service.dart`
- Add `viewStyle` getter to `SettingsService`
- Add `setViewStyle(ViewStyle style)` to `SettingsService`
- Add a `viewStyle` input to `StarChart`

No star-data, constellation-data, or search interfaces should change.

## Test Plan

Manual verification:

- Fresh app state defaults to dome mode.
- Changing the setting to Classic immediately restores the current flat chart.
- Relaunch preserves the selected style.
- Dome mode visually reads as a horizon-based sky view, not a rectangular box.
- In dome mode, upward dragging can bring the zenith into view but cannot move
  it below the top safety region.
- The zenith never reaches screen center.
- Near the zenith limit, drag resistance feels intentional rather than broken.
- Left/right panning remains directionally understandable near the cap.
- Gyro mode, star taps, zoom, labels, and search continue to work in both
  styles.
- Chinese and Western culture modes both render correctly in both styles.

Regression checks:

- Classic mode remains visually close to the current behavior.
- Labels and constellation lines are not clipped in a distracting way by the
  dome framing.
- Settings strings fit in both English and Chinese.

## Assumptions

- "Voyage" is the target screen for this setting and view-style change.
- Dome mode is optimized for user orientation and perceived realism, not for
  full unrestricted spherical camera motion.
- Advanced free-rotation mode is out of scope for this change.
- This plan file should be included in the code commit and reused as the PR
  body when opening the PR.
