# 0036. The invite link and the website live on joinlezgo.app

- Status: Accepted
- Date: 2026-11-19
- Deciders: Nathan Sudiara

## Context

The invite link is `https://lezgo-trip.netlify.app/join?code=897654`, a universal link on a free Netlify site ([0020](0020-UniversalInviteLinkOnNetlify.md)). The website that App Store Connect links to (landing page, privacy policy, support) is a separate Vercel site, `C5-M3/lezgo-website`, served at `lezgo.nathansudiara.com`. So people see two unrelated addresses, and neither says "Lezgo" on its own. The Netlify site is also deployed by hand, by dragging a folder to Netlify Drop.

The team has bought `joinlezgo.app`, registered in Cloudflare. Lezgo 1.0 is on the App Store and its builds only open `lezgo-trip.netlify.app` links, so invites shared from 1.0 keep using that address until people update.

## Decision

We will serve the website and the invite link from `joinlezgo.app`, from the `C5-M3/lezgo-website` repository on Vercel. The app shares `https://joinlezgo.app/join?code=897654`, and `/.well-known/apple-app-site-association` on that site lists the app IDs. The app keeps opening `lezgo-trip.netlify.app` links and `lezgo://join?code=` links, so invites sent from older builds still work. `lezgo.nathansudiara.com` and `www.joinlezgo.app` redirect to `joinlezgo.app`, and the contact address is `contact@joinlezgo.app` (Cloudflare Email Routing).

## Alternatives considered

- **Keep Netlify for the invite link:** works, but keeps two addresses and the manual Netlify Drop deploy.
- **Only redirect the Netlify site to the new domain:** iOS does not follow redirects when it reads the association file, and a redirect page adds a Safari step before the app opens.
- **Drop the Netlify host from the app at once:** invites shared from 1.0 would stop opening the app on updated phones.

## Consequences

- One address for everything people see: the App Store page, the invite link and the contact email.
- A push to `main` in `C5-M3/lezgo-website` deploys the invite page and the association file. `Web/InviteLink/` in this repository is only kept for the old Netlify site and should not change.
- The app gains `applinks:joinlezgo.app` in both entitlements files and keeps `applinks:lezgo-trip.netlify.app`. When no supported build shares Netlify links any more, a later record can remove the old host and the Netlify site.
- To test the link on a developer build, add its app ID to the association file in `C5-M3/lezgo-website`, not in this repository.
- The Marketing and Support URLs in App Store Connect move to `joinlezgo.app` with the next version. The old address redirects until then.
- `specs/UserStories.md` uses the new link in US-02, US-04 and Words.
