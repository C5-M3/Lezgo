# 0022. Custom trip map cards instead of Apple's sheet and glass

- Status: Proposed
- Date: 2026-11-05
- Deciders: N

## Context

The hi-fi design of Trip Started has solid dark cards, a yellow route, robot cars and a yellow "Lez Go!" animation that opens the map.
Before this, the bottom of the map was a system sheet with detents, and the cards used Liquid Glass.
A system sheet is presented above everything else on screen, so the animation could not cover it, and its shape and position cannot follow the design.

## Decision

We will draw the Trip Started bottom card, turn card and map buttons as our own SwiftUI views, and keep Apple's `Map` and system alerts.

## Alternatives considered

- **Keep the system sheet and restyle it:** the sheet cannot float with margins as in the design, and it stays above the animation.
- **Hide the sheet during the animation:** presenting it afterwards makes it slide in late, apart from the other cards.

## Consequences

The design is matched exactly, and Edit Route opens without first waiting for a sheet to close.
We now own what the system gave us for free: dragging the card, its large text behaviour and its VoiceOver labels.
The rules in [Accessibility](../../AGENTS.md#accessibility-minimum-bar) apply to these views directly.
