# 0032. Apple's glass for every button, always tinted

- Status: Proposed
- Date: 2026-11-17
- Deciders: The team (to be confirmed in review)

## Context

Buttons look different from screen to screen: about 14 near-black greys, three Back buttons (a hard-coded grey circle, a shared `RoundBackButton`, a glass one in Trip History), yellow capsules of 52, 54 and 56 points, and four ways of showing a disabled button. Colours are written in the screens instead of coming from the asset catalog.
The team decided that buttons use Apple's Liquid Glass, customised as natively as possible: some buttons are yellow, some hold a picture.
A prototype (`-DebugScreen glassButtons`) showed that glass takes its look from what is behind it. On a map it reads well. On the flat dark backdrop of most screens, untinted glass almost disappears. On the yellow half of Home, yellow-tinted glass disappears and untinted glass turns pale yellow, so white text cannot be read.
[0022](0022-CustomTripMapControls.md) keeps the Trip Started cards as our own solid views; it also drew the map buttons as our own views.
The minimum iOS version is 26.0 today. Issue #327 asks to lower it to 18.0, which has no `.glass` button style.

## Decision

We will draw every button with Apple's glass (`.buttonStyle(.glass(...))`, and `glassEffect` for buttons that hold a picture), and use the system's own styles: `.glassProminent` tinted `BrandYellow` for the main action, plain `.glass` for every other button. Roles only choose the text colour (`TripCardText`, or `TripAlertRed` for a destructive one, as the Hi-Fi draws End Trip) and the size. The system draws the press effect, the disabled look and the Reduce Transparency fallback.
Cards, panels and sheets stay solid surfaces from the asset catalog; glass is for controls only.

## Alternatives considered

- **Untinted glass everywhere:** it disappears on flat dark screens and turns pale on yellow, and the yellow main action would not be yellow.
- **Glass only on the map and over pictures, solid elsewhere:** buttons would still differ between screens, which is the problem we want to remove.
- **Keep solid buttons and only unify their colours:** simplest, but it is not what the team decided.

## Consequences

One look for every button, colours from the asset catalog, and the system's own press and accessibility behaviour (Reduce Transparency, Increase Contrast) instead of our `pressFeedback`.
The app stays on iOS 26.0 or later, so issue #327 cannot be done as written; it must be closed or changed, or every button needs a material fallback.
A tinted glass button on a flat background looks close to the solid one it replaces; the difference shows over maps and pictures.
A disabled tinted button is not clearly disabled by itself; the shared style must show it (for example, a duller tint).
Applies the rules in [UI consistency](../../AGENTS.md#ui-consistency): same element, same look, colours from the asset catalog.
