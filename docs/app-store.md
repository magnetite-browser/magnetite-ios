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
- **Pictures:** `scripts/screenshots.sh` takes them from the demo chain
- **Keywords:** `browser,web,tabs,spaces,sync,privacy,open source,sidebar,favorites,pinned,private,encrypted`
- **Support URL:** https://magnetitebrowser.org
- **Marketing URL:** https://magnetitebrowser.org
- **Privacy policy URL:** https://magnetitebrowser.org/privacy/
- **Copyright:** StackForge UG (haftungsbeschränkt)

### Promotional text

The spaces, favorites and pinned tabs of Magnetite on your computer, on your
iPhone and iPad. No account, no telemetry, open source.

### Description

Magnetite is an open-source browser with a sidebar instead of a tab strip:
spaces for the different parts of your day, favorites, and pinned tabs in
folders. This is its app for iPhone and iPad.

YOUR SIDEBAR, WITH YOU
Join the sync chain of Magnetite on your computer and its spaces, favorites
and pinned tabs are here too, each space in its colour. On an iPad the
sidebar stays beside the page, as on the desktop.

HAND A TAB OVER
Your computer lists the tabs open on this device and can take one over.
"Send to Desktop" asks for that from here.

SYNC THAT ONLY YOU CAN READ
A sync chain is encrypted on your devices with a code of 24 words. The
server stores what it cannot read. Use Magnetite's server, or one you host
yourself. Joining is optional: without a chain, Magnetite is a plain, quiet
browser.

NOTHING BEHIND YOUR BACK
No account. No telemetry. No advertising. The app contacts a site only when
you open one of its pages. Tabs of private spaces are never listed for other
devices.

OPEN SOURCE
The code is public under the EUPL-1.2: https://github.com/magnetite-browser

### What's new (first version)

The first version of Magnetite for iPhone and iPad.

## Answers in App Store Connect

- **Age rating:** "Unrestricted Web Access": yes; everything else: none.
- **App privacy:** "Data Not Collected". The app sends nothing to us but a
  sync chain, and that only encrypted with a key that never leaves the
  user's devices; the server keeps no access logs. Pages the user opens go
  to their sites, not to us.
- **Sign-in:** none needed.
- **Notes for review:** the app is a browser built on WebKit and works
  without an account. Sync is optional; a chain is made by Magnetite on a
  computer, so the notes carry the address and the 24 words of a demo chain
  to join under Settings → Join a Sync Chain.
