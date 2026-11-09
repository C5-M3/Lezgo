# 0025. One custom alert for the whole app

- Status: Accepted
- Date: 2026-11-09
- Deciders: N

## Context

The hi-fi design draws every alert as a dark card with a centred title, a grey "Cancel" and a yellow main button ("H2 Has Arrived · Confirm").
The app had three kinds of alert: the system `.alert` on Home, Draft Trip and Set Route, `ConfirmDialog` in the Trip Room and `TripMapDialog` on the trip map.
They looked different from each other, and a system alert cannot take our colours or show the LEZGO logo on its button.
[0022](0022-CustomTripMapControls.md) kept system alerts on the trip map; the trip map already moved away from them.

## Decision

We will show every question and message in the app with the shared `ConfirmDialog` (`Views/Components/ConfirmDialog.swift`), through `.confirmDialog(isPresented:...)` or as a view when a view model decides which dialog shows.
CarPlay keeps `CPAlertTemplate`, which CarPlay requires.

## Alternatives considered

- **System alerts everywhere:** consistent and free, but not the hi-fi design, and no image on a button.
- **Keep one custom dialog per screen:** each screen drifts in look, motion and accessibility.

## Consequences

Alerts look and move the same everywhere, and a fix to one fixes all.
We own what the system alert gave us: the modal trait, the escape gesture, large text and the dimmed backdrop are in `ConfirmDialog`.
A dialog inside a sheet is drawn inside that sheet, so the screen opens the sheet fully before showing it.
UI tests cannot find these dialogs with `app.alerts`; they use `app.Dialog(title)` from `LezgoUITests/XCUIApplication+ConfirmDialog.swift`.
The rules in [UI consistency](../../AGENTS.md#ui-consistency) apply: never add a system `.alert` or `.confirmationDialog`.
