# 0020. Universal invite link on a free Netlify site

- Status: Proposed
- Date: 2026-10-30
- Deciders: Oky, Rizal

## Context

"Share Link" in the Trip Room sends the invite link `lezgo://join?code=897654` (US-04). Chat apps such as WhatsApp, Telegram and LINE only turn `https://` addresses into links, so members cannot tap it and have to type the code by hand (#210).
iOS opens an app from an `https://` link only through a universal link: the app declares the domain in its Associated Domains entitlement, and the domain serves an `apple-app-site-association` (AASA) file that lists the app. That needs a domain and a place to host one static file. The team has no shared server and does not want to run one, and the build has to stay free of third-party SDKs.
Each developer signs with their own team ID and bundle identifier (ADR 0015), and iOS only opens the app for the app IDs listed in the AASA file.

## Decision

We will share the invite link as `https://lezgo.netlify.app/join?code=897654`, a universal link served by a free static Netlify site.
The site's files live in the repository under `Web/InviteLink/` and are deployed by dragging that folder to Netlify Drop on the team account. The AASA file lists the release app ID (`K64G2J8QL7.com.nathansudiara.Lezgo`) and any developer app ID that needs to test the link. The app keeps accepting `lezgo://join?code=` so older invites still work.

## Alternatives considered

- **Keep `lezgo://`:** nothing to host, but the link cannot be tapped in chat apps, which is the problem.
- **GitHub Pages:** also free, but the team chose not to tie the invite link to a GitHub Pages repository, and GitHub Pages cannot set the AASA file's content type.
- **Our own server:** full control, but nobody wants to run or pay for one.
- **A redirect page to `lezgo://`:** tappable, but adds a Safari step and an "Open in Lezgo?" prompt before the app opens.
- **iCloud share links (`CKShare`):** tappable with no hosting, but trips would have to move from the public database to shared zones, which reverses ADR 0014.
- **A deep-link service SDK (for example Branch):** adds a third-party dependency and sends join data to another company.

## Consequences

- The invite link can be tapped in every chat app, and opens Lezgo when it is installed. Without the app, `/join` shows how to get it.
- The app gains the `applinks:lezgo.netlify.app` entitlement. Automatic signing adds the Associated Domains capability to each developer's app ID.
- A universal link only opens builds whose app ID is in the AASA file, so the link is tested on TestFlight, or on a developer build after adding its app ID and redeploying the site.
- Changing `Web/InviteLink/` does nothing until someone redeploys it to Netlify. The site name `lezgo` and the Netlify account belong to the team.
- `specs/UserStories.md` uses the new link in US-02, US-04 and Words.
