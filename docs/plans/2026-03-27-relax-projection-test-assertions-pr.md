## Summary

Adjust floating-point expectations in `test/star_chart_projection_test.dart`
to use `closeTo(...)` instead of exact equality.

## Why

This follows the review feedback on PR #48 and makes the projection tests more
robust and consistent with the repo's other numeric assertions.

## Validation

- `flutter test test/star_chart_projection_test.dart`
- `flutter analyze lib test`
