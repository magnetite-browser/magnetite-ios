# App Store listing

What Magnetite's page on the App Store says, and the answers given in App
Store Connect. Change it here first, then there.

## Listing (English)

- **Name:** Magnetite
- **Subtitle:** Your spaces, on your phone
- **Category:** Utilities, then Productivity
- **Price:** free, no in-app purchases
- **Countries:** all but France, which asks for a declaration of the app's
  encryption first
- **Pictures:** `scripts/screenshots.sh` takes them from the demo chain:
  six for the 6.9" iPhone, four for the 13" iPad, in the order of their
  names
- **Preview videos:** `scripts/preview.sh` records them, one for each of
  those two sizes
- **Keywords:** `browser,spaces,sidebar,tabs,ad blocker,tracker,privacy,private,sync,encrypted,open source,bookmarks`
- **Support URL:** https://magnetitebrowser.org
- **Marketing URL:** https://magnetitebrowser.org
- **Privacy policy URL:** https://magnetitebrowser.org/privacy/
- **Copyright:** StackForge UG (haftungsbeschränkt)

### Promotional text

A browser with spaces, blocked ads and trackers, and private tabs. It joins
the sync chain of Magnetite on your computer. No account, no telemetry, open
source.

### Description

Magnetite is an open-source browser with a sidebar instead of a tab strip:
spaces for the different parts of your day, favorites, and pinned tabs in
folders. This is Magnetite for iPhone and iPad.

THE PAGE FIRST
The page fills the screen, with one floating bar at the bottom. It steps
aside while you read and comes back with a tap. Find on page, text size and
the desktop site are in the page's menu.

SPACES, SWIPED THROUGH
The start page is your sidebar: each space with its favorites, pinned tabs
and the tabs open in it. Swipe from space to space, or pick one from the row
of icons. On an iPad the sidebar stays beside the page, as on the desktop.

ADS AND TRACKERS BLOCKED
Magnetite blocks ads and trackers with the same filter lists as on the
desktop, before they load. A site's menu turns blocking off for that site.

HISTORY, BOOKMARKS, DOWNLOADS
The pages you visit are offered while you type, and kept on this device only,
for as long as you choose. The bookmarks of your spaces are a tap away, and
downloads land in the Files app.

PRIVATE TABS
The private space leaves nothing behind: no history, and its cookies and
logins are gone when Magnetite quits. Its tabs are never shown on your other
devices.

YOUR SIDEBAR, WITH YOU
Join the sync chain of Magnetite on your computer and its spaces, favorites
and pinned tabs are here too, each space in its colour. Pin a page, add a
favorite or start a space here, and your computer makes the change when it
syncs. Your computer lists the tabs open here and can take one over; "Send
to Desktop" asks for that.

SYNC THAT ONLY YOU CAN READ
A sync chain is encrypted on your devices with a code of 24 words. The
server stores what it cannot read. Use Magnetite's server, or one you host
yourself. Sync is optional: without it, Magnetite is a plain, quiet browser.

NOTHING BEHIND YOUR BACK
No account. No telemetry. No advertising. Besides the pages you open and the
sync server you pick, the app contacts only the publishers of the filter
lists it blocks with.

OPEN SOURCE
The code is public under the EUPL-1.2: https://github.com/magnetite-browser

### What's new

None for the first version: the store asks for it from the second on.

## Answers in App Store Connect

- **Age rating:** "Unrestricted Web Access": yes; everything else: none.
- **App privacy:** "Data Not Collected". The app sends nothing to us but a
  sync chain, and that only encrypted with a key that never leaves the
  user's devices; the server keeps no access logs. Pages the user opens go
  to their sites, not to us.
- **Sign-in:** none needed.
- **Notes for review:** the app is a browser built on WebKit and works
  without an account. Sync is optional; a chain is made by Magnetite on a
  computer, so the notes carry the 24 words of a demo chain on Magnetite's
  server, to join from the start page or Settings → Join a Sync Chain.
