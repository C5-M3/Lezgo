# 0018. Debug tools in their own folder

- Status: Proposed
- Date: 2026-10-27
- Deciders: Nathan

## Context

ADR 0003 groups the app's code by layer: `Models`, `ViewModels`, `Views`, `Services`. Besides the app itself, the team now has developer tools that never ship: `DebugScreen` (opens a screen from a launch argument), sample and simulated trip data for previews, and the Sync Check screen used to test iCloud sync on real phones (#111).
These tools were placed by layer too, so `Services`, `ViewModels` and `Views/Screens` mixed shipping code with debug-only code. Reviewers could not tell at a glance what reaches the App Store, and the folders looked full of unused files.

## Decision

We will keep every debug-only tool in one folder, `Lezgo/Debug/`, with its tests in `LezgoTests/Debug/`. Every file there is wrapped in `#if DEBUG`, so Release builds (Xcode Cloud, TestFlight, App Store) contain none of it. Inside the folder there are no layer subfolders: the tools are few and belong together.

App code never depends on `Lezgo/Debug/`. The only links are the `#if DEBUG` hook in `LezgoApp` that opens `DebugScreen`, and previews inside `#if DEBUG`.

## Alternatives considered

- **Keep them in the layer folders:** follows ADR 0003 to the letter, but shipping and debug-only code stay mixed, which is the problem this solves.
- **A separate target or Swift package:** the strictest separation, but it needs project and scheme changes, and the tools need the app's internal types, so most of the app would have to become public. Too heavy for a handful of files.
- **Delete the tools:** previews and phone checks need sample data and Sync Check. The Load Check, whose job was done, was deleted (#186).

## Consequences

- `Models`, `ViewModels`, `Views` and `Services` hold only code that ships.
- New debug-only code (sample data for a screen, a check screen) goes in `Lezgo/Debug/` and is wrapped in `#if DEBUG`. A Release build fails if app code uses it, which catches mistakes early.
- ADR 0003 still holds for the app's own code. [Architecture: MVVM, layer first](../../AGENTS.md#architecture-mvvm-layer-first) lists the new folder.
