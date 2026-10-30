# Invite link site

The static site behind the invite link `https://lezgo-trip.netlify.app/join?code=897654` (ADR 0020).

| File | Purpose |
| --- | --- |
| `.well-known/apple-app-site-association` | Tells iOS which app IDs open `/join?code=` links |
| `_headers` | Serves the AASA file as JSON |
| `join/index.html` | Shown when Lezgo is not installed, or when the link is opened from Safari's address bar |

## Deploy

1. Open [app.netlify.com/drop](https://app.netlify.com/drop) and sign in with the team account.
2. Drag the `Web/InviteLink` folder onto the page. Finder hides `.well-known`, but it is uploaded with the folder. The "browse" button only takes a zip: run `zip -r ~/Downloads/lezgo-invite-link.zip . -x README.md` inside this folder and upload that file.
3. The site is named `lezgo-trip` (Site configuration > Change site name), so it is served at `lezgo-trip.netlify.app`. It must be public, or iOS cannot read the AASA file.
4. Check that `https://lezgo-trip.netlify.app/.well-known/apple-app-site-association` shows the JSON.

Changes in this folder do nothing until the site is deployed again (Deploys > drag the folder again).

## Test on your own build

iOS only opens the builds listed in `appIDs`. To test with your own signing (ADR 0015), add `<DEVELOPMENT_TEAM>.<BUNDLE_IDENTIFIER_PREFIX>.Lezgo` from your `Config/Local.xcconfig`, deploy, then delete and reinstall the app so iOS fetches the file again.
