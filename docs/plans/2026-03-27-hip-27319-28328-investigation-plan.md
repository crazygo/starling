# Investigation Plan: Suspicious HIP 27319 / HIP 28328 Link

## Summary

Investigate why `HIP 27319` and `HIP 28328` are rendered as a connected pair in
Starling, even though the pairing looks implausible under the product rule that
only stars forming a coherent asterism or a major constellation outline should
be linked.

This investigation should establish:

- whether the link exists in the app's current binary assets
- whether it comes from upstream source data or from repo-side transformation
- whether the issue is caused by a bad edge definition, a bad HIP mapping, or a
  parser/build bug
- what the correct fix should be if the link is invalid

## Key Investigation Steps

### 1. Confirm the current app data path

- Verify the link in the runtime assets used by the app:
  - `catalog_base.bin`
  - `culture_western.bin`
  - `culture_chinese.bin`
- Record the direct western and Chinese edge memberships for:
  - `HIP 27319`
  - `HIP 28328`
- Confirm whether both cultures independently encode the same suspicious link.

### 2. Trace the repo transformation chain

- Identify how western and Chinese edge pairs are parsed, normalized, and
  serialized into binary assets.
- Determine whether the suspicious link is introduced:
  - before parsing
  - during parsing
  - during binary generation
  - or only at render time
- Verify whether the renderer is faithfully drawing the stored edge pairs or
  accidentally creating cross-links between unrelated stars.

### 3. Inspect upstream source truth

- Locate the corresponding upstream Stellarium or Stargazer source entries for
  the western and Chinese datasets that mention `HIP 27319` or `HIP 28328`.
- Check whether the suspicious edge exists in upstream raw source files.
- If it exists upstream, determine whether it appears intentional or obviously
  corrupted relative to the surrounding asterism / constellation structure.
- If it does not exist upstream, identify the exact repo-side bug that creates
  it.

### 4. Evaluate against the product rule

- Judge the edge against the Starling product rule:
  - links should represent stars that jointly form a coherent asterism or a
    recognizable major constellation outline
- Use:
  - star positions
  - brightness
  - neighboring edges
  - culture grouping context
- Produce a conclusion:
  - valid link
  - upstream-data issue
  - repo transformation issue
  - renderer issue

### 5. Prepare fix direction

- If the link is invalid, define the repair scope:
  - source patch
  - parser/build fix
  - binary regeneration
  - test coverage
- If the link is valid upstream but violates Starling's product rule, define
  the product-side override strategy and the exact layer where that override
  should live.

## Expected Outputs

- A written conclusion describing the true provenance of the link
- A recommendation for whether the edge should remain or be removed
- A concrete fix strategy ready for implementation on this branch
- If appropriate, a targeted regression test for the corrected behavior

## Assumptions

- The current rendered link is suspicious enough that it should not be accepted
  solely because binary data currently contains it.
- Product correctness is defined by coherent constellation / asterism structure,
  not by blindly trusting imported edge data.
- This branch will continue into the fix once the investigation result is clear.

## Findings

- The suspicious `HIP 27319 ↔ HIP 28328` link was real in the committed app
  binaries, not a renderer-side artifact.
- Current upstream western source truth does not contain that link:
  - `SGR` uses modern high-HIP edges such as `89931 ↔ 90496`
  - `COL` contains the valid `27628 ↔ 28328` edge
- The parser path was already correct. The actual bug was in binary
  serialization:
  - FlatBuffers `Edge.from_hip` / `to_hip` were defined as `uint16`
  - modern western source contains HIP values above `65535`
  - those values were truncated modulo `65536` during binary generation
  - truncated high-HIP western edges then appeared as fake low-HIP links such
    as `27319 ↔ 28328`
- Fix direction:
  - upgrade edge HIP storage from `uint16` to `uint32`
  - regenerate the checked-in FlatBuffers Dart bindings
  - force-refresh the western source before rebuilding assets
  - add a regression test that proves `SGR` no longer contains
    `27319 ↔ 28328` while `COL` still contains `27628 ↔ 28328`
