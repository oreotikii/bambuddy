# Weigh Screen Glass Finish Plan

## Goal
Finish the partially implemented Bambuddy Assign Flutter weigh-screen redesign without changing the verified API contract. The remaining work is limited to UI cleanup in `weigh_screen.dart`, preserving the already-added data-layer support for spool detail, locations, and the dedicated weigh endpoint.

## Current State
- `apps/filament-assignment-flutter/lib/src/ui/design_effects.dart` already contains `FrostedPanel` backed by `GlassContainer.frostedGlass`.
- `apps/filament-assignment-flutter/lib/src/ui/weigh_screen.dart` already imports `design_effects.dart`, has the compact search field, app-bar scan action, rich spool card widgets, update fields, and save flow.
- `apps/filament-assignment-flutter/lib/src/data/assignment_repository.dart` already has `fetchSpoolDetail`, `fetchSpoolLocations`, and `updateSpoolWeigh` wired to the verified endpoints.
- Tests and API docs were already updated before the interruption and passed once before the final UI edits.

## Decisions
- Use `PATCH /api/v1/spoolman/inventory/spools/{id}/weigh` only through `AssignmentRepository.updateSpoolWeigh`; do not issue live PATCH requests during verification.
- Use `MobileSpoolDetail.subtype` as the preferred displayed manufacturer color name, falling back to `MobileSpool.colorName` when subtype is null or blank.
- Treat the remaining UI work as a visual refactor only; do not change save semantics, endpoint shapes, or secure configuration behavior.
- Keep secrets in `apps/filament-assignment-flutter/baked-config.json` private; do not print, copy, or commit them.

## Implementation Tasks
1. Update `apps/filament-assignment-flutter/lib/src/ui/weigh_screen.dart` `_SpoolCard`:
   - Replace the outer `DecoratedBox` plus `Padding` wrapper with `FrostedPanel(radius: 14, padding: const EdgeInsets.all(16), child: Row(...))`.
   - Keep the existing inner `Row`, percent badge, material headline, swatches, effect chip, and spool side view structure.
   - Compute a non-empty display color name from `detail?.subtype` first, then `spool.colorName`; pass that value to `_ColorRow`.
   - Pass a glass-compatible surface color such as `cs.surfaceContainerHigh` into `_SpoolSideView.surface` so the core hole visually matches the panel.

2. Update the resolved-spool update area in `weigh_screen.dart`:
   - Replace `_Section(title: 'Update spool', child: Column(...))` with a `FrostedPanel(radius: 14, padding: const EdgeInsets.all(16), child: Column(...))`.
   - Preserve the current field keys: `weight-grams-field`, `empty-spool-field`, and `location-field-$spoolId`.
   - Preserve the current labels and helper text: `Measured weight (g)`, `Scale reading: filament + spool`, `Empty spool weight (g)`, `Location`, and button label `Update spool`.
   - Keep fields and the `ElevatedButton.icon` full-width via `crossAxisAlignment: CrossAxisAlignment.stretch`.
   - Keep the button disabled unless `_hasChanges && !_busy`.

3. Remove obsolete UI scaffolding:
   - Delete `_Section` if no longer referenced.
   - Keep `_MessageBanner` as-is unless analyzer reports an issue.

4. Preserve data and failure behavior:
   - Do not alter `_resolveSpool` fallback behavior when detail fetch fails.
   - Do not alter `_loadLocations` fallback behavior when location fetching fails.
   - Do not alter `_save` no-op behavior when measured weight, empty spool weight, and location are unchanged.
   - Do not send empty strings or unchanged values to the weigh PATCH endpoint.

5. Format and validate from `apps/filament-assignment-flutter/`:
   - Run `dart format lib/src/ui/weigh_screen.dart lib/src/ui/design_effects.dart`.
   - Run `flutter analyze`.
   - Run `flutter test --reporter compact`.
   - If analyzer or tests fail due to the UI refactor, make the smallest targeted fix and rerun the failing command.

## Risks
- `GlassContainer.frostedGlass` must remain usable without fixed width/height; this was already checked against `glass_kit` 4.0.2, but analyzer is the source of truth.
- Removing `_Section` may slightly change layout spacing; preserve the current `SizedBox` spacing around the spool card and update panel.
- The visual spool core color is only an approximation of the glass panel background; prefer a theme surface color over hard-coded colors.

## Validation Criteria
- `flutter analyze` passes cleanly.
- `flutter test --reporter compact` passes.
- The weigh screen shows a left-aligned `Weigh spool` title with a scan action.
- Spool lookup uses one compact input with search action inside the field.
- Resolved spool summary uses glass background, brand on top, material prominent, subtype/color fallback, swatches/effect where available, side-view spool visualization, and top-right remaining percent.
- Update panel uses glass background and allows measured gross weight, empty spool weight, and existing-location dropdown updates through the dedicated weigh endpoint.

## Open Questions
None. The plan is ready for an implementation-capable agent.
