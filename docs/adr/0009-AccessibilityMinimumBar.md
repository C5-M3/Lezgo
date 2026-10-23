# 0009. Accessibility minimum bar

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

Accessibility is cheap when built in and expensive to add later. The team set a minimum that every feature must meet before review.

## Decision

We will support Dynamic Type (system text styles, layouts that adapt at the largest sizes) and meet color contrast of at least 4.5:1 for body text and 3:1 for large text and icons, in light and dark mode. Controls also need clear VoiceOver labels, 44x44 point touch targets, and respect for Reduce Motion.

## Alternatives considered

- **Fixing accessibility before release:** later fixes often mean redesigning screens.
- **Fixed font sizes for pixel-perfect designs:** looks closer to the mockups, but excludes users who need larger text.

## Consequences

- Designs must work at the largest text size, which may mean stacking content vertically.
- SwiftLint's `accessibility_label_for_image` and `accessibility_trait_for_button` rules catch common misses.
- The `ios-accessibility` agent skill guides agents.
- See AGENTS.md "Accessibility (minimum bar)" and "UI checks after coding".
