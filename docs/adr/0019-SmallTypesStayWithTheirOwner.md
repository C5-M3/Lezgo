# 0019. Small helper types stay with the type that uses them

- Status: Proposed
- Date: 2026-10-27
- Deciders: Nathan

## Context

AGENTS.md says "One type per file. The file is named after the type." Taken literally, every helper becomes its own file, even an enum of a few lines that only one view model uses (for example the camera mode or the leave confirmation of the trip map). The `Models` and `ViewModels` folders filled up with tiny files, which made it harder to see the types that matter, and harder to tell which helper belongs to which screen.
Common Swift practice, including Apple's own code and sample projects, is one *main* type per file named after the file, with small types that serve only that type nested inside it.

## Decision

We will keep one main type per file, named after the file. A small type used only by that type (an enum, a small struct, an error) may live in the same file, preferably nested inside it, for example `TripMapViewModel.CameraMode`. A type used by more than one other type keeps its own file.

## Alternatives considered

- **Keep "one type per file" strictly:** simple to check, but it creates many tiny files and hides which helper belongs to which type.
- **Allow any number of types per file:** fewer files, but large files with unrelated types are hard to find and to review.

## Consequences

- Fewer, more meaningful files. A helper's name shows its owner (`TripMapViewModel.CloseReason`).
- When a nested type gets a second user, move it to its own file in the same PR.
- [Architecture: MVVM, layer first](../../AGENTS.md#architecture-mvvm-layer-first) states the rule.
