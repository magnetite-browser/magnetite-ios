# Magnetite for iOS

The iPhone and iPad app of [Magnetite](https://github.com/magnetite-browser/magnetite).
It browses with the system's web engine (WKWebView) and shows the spaces,
favorites and pinned tabs of a sync chain. It never changes the chain's
sidebar. What it writes is its own entry among the chain's devices: the tabs
open on it, which another device can take over ("Send to Desktop" asks for
that).

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

To try it by hand, join `http://localhost:8787` ("Your own server") with the
words the demo server prints. `curl -X POST localhost:8787/demo/take` plays a
desktop that takes over the tabs the phone lists.

## Layout

- `App/Model`: the tabs of this device (`Browser`), the sync chain (`Sync`),
  what the address field's text means (`Address`).
- `App/Model/Favicons.swift`: site icons, kept when a page of the site was
  loaded here; a row never contacts a site.
- `App/Web`: one tab's web view and its state.
- `App/Views`: the page with its bar, the sidebar, joining, settings. On a
  wide screen (iPad) the sidebar is a column beside the page; on a narrow
  one it is the start page and a sheet.
- `Core/`: generated, not in the repository.

## Licence

[EUPL-1.2](LICENSE), as Magnetite itself.
