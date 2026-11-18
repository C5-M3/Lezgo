# 0033. One set of surface colours, text greys and corner radii

- Status: Proposed
- Date: 2026-11-17
- Deciders: The team (to be confirmed in review)

## Context

Cards, panels, sheets and page backgrounds are drawn with about 14 different near-black values, some written in the screens (`Color.black`, `#1C1C1E`, `#202022`, `#18181A`, `#2C2C2E`, `Color(white: 0.16)` to `0.35`) and some from the asset catalog (`TripCard`, `RouteCard`, `InviteSurface`). Secondary text uses four different greys. Thirteen corner radii are in use.
[0032](0032-TintedGlassButtons.md) decides that buttons are glass and cards stay solid, so the solid surfaces need a decision of their own.
Glass takes its look from what is behind it, so the surface colour also decides how a tinted button looks.

## Decision

We will draw every solid surface with one of three asset-catalog levels: Page (`TripCard`, pure black `#000000`, chosen by the team over the Hi-Fi's `#121212`), Level 1 (`TripCardButton`, `#1E1E1E`) and Level 2 (a new asset, `SurfaceField`, `#2A2A2A`), the values the Hi-Fi uses. Sheets share one look: Page background, radius 30. Separators use a new asset, `SurfaceSeparator`. Secondary text uses `TripCardSubtext`. Corner radii come from one short list: 30 for cards and panels, 20 for inner cards and fields, 12 for small elements, capsule for pills and buttons. Cards, panels and dialogs of 30 points or more carry a thin white shadow (7% white, radius 1.5), so they stay visible on the black page. Screens do not write grey, black or white values for a surface.
A surface that someone on the team marks as intentionally different gets its own named asset instead of a literal.

## Alternatives considered

- **Keep each screen's own greys:** nothing to do, but buttons and cards keep disagreeing, which is the problem.
- **Two levels only (page and card):** simpler, but fields and chips on a card would have no contrast.
- **Make cards glass too:** not what the team decided; cards hold content and long text.

## Consequences

The look of every screen changes slightly (the greys move by a few levels, some radii move by a few points). Every screen owner is affected and must hear about it before merge.
`RouteCard` and `InviteSurface` are retired. The Set Route card changes from its own grey to the Page colour, like every other card over a map.
Applies the rules in [UI consistency](../../AGENTS.md#ui-consistency): colours from the asset catalog, same element and same look everywhere.
