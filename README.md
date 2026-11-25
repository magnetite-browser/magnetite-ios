# Magnetite for iOS

The iPhone and iPad app of [Magnetite](https://github.com/magnetite-browser/magnetite).
It browses with the system's web engine (WKWebView) and shows the spaces,
favorites and pinned tabs of a sync chain. It never writes the chain's
sidebar. What it writes is its own entry among the chain's devices: the tabs
open on it, which another device can take over ("Send to Desktop" asks for
that), and its changes to the sidebar (pin, favorite, new space, rename,
remove), which a desktop of the chain makes.

## Build

Needs Xcode, Rust (with the targets in the core's `rust-toolchain.toml`) and
`xcodegen`. The shared Rust core is its own repository,
[magnetite-mobile-core](https://github.com/magnetite-browser/magnetite-mobile-core),
expected beside this one as `../magnetite-mobile-core`.

```sh
scripts/core.sh      # builds the core into Core/ (again after the core changed)
scripts/project.sh   # generates Magnetite.xcodeproj from project.yml
open Magnetite.xcodeproj
```

## Test

The UI tests join a demo chain and open a page from it; one runs on an
iPhone, the other on an iPad. Start the demo
server first, and run the test on a simulator without the app installed:

```sh
(cd ../magnetite-mobile-core && cargo run --example demo_server) &
xcodebuild -project Magnetite.xcodeproj -scheme Magnetite \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`TEST_RUNNER_DEMO_SERVER=http://localhost:8788` points `BrowsingTests` and
`EditingTests` at a demo server on another port
(`DEMO_PORT=8788 cargo run --example demo_server`). `EditingTests` changes
the demo chain; start the server again before the other tests.
`BrowsingTests.testAnAdIsBlockedUnlessTheSiteIsAllowed` downloads the filter
lists from their publishers, so it needs the internet, as the tests that
open Wikipedia do.

To try it by hand, join `http://localhost:8787` ("Your own server") with the
words the demo server prints. `curl -X POST localhost:8787/demo/take` plays a
desktop that takes over the tabs the phone lists, `…/demo/apply` one that
makes the changes to the sidebar the phone asked for (pin, favorite, new
space, rename, remove).

## Release

Raise `MARKETING_VERSION` in `project.yml` with a pull request, then tag the
merged commit `v<version>`. The release workflow waits for a maintainer's
approval, then archives the app and uploads it to App Store Connect, where
it shows up under TestFlight. `scripts/release.sh` is what it runs, and does
the same from a Mac; it says at its top what it needs.

What the App Store page says is in [docs/app-store.md](docs/app-store.md);
`scripts/screenshots.sh` takes its pictures.

## Layout

- `App/Model`: the tabs of this device (`Browser`), the sync chain (`Sync`),
  the pages visited here (`BrowsingHistory`, kept by the core, never
  synced, nothing from private spaces), content blocking
  (`ContentBlocker`: the desktop's filter lists, compiled by WebKit into
  one rule list), downloads (`Downloads`: into Downloads in the app's
  documents, which the Files app shows), what the address field's text
  means (`Address`) and offers while typing (`Suggestions`).
- `App/Model/Favicons.swift`: site icons, kept when a page of the site was
  loaded here; a row never contacts a site.
- `App/Web`: one tab's web view and its state.
- `App/Views`: the page with its bar, the sidebar (a page per space, swiped
  through as on the desktop), the library (bookmarks of all spaces,
  history, downloads), joining (by typing the 24 words or by
  scanning the QR code a computer shows beside them), settings. On a wide
  screen (iPad) the sidebar is a column beside the page; on a narrow one it
  is the start page and a sheet.
- `Core/`: generated, not in the repository.

## Licence

[EUPL-1.2](LICENSE), as Magnetite itself.
