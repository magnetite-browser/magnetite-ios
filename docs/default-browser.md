# Default browser

iOS lets the user pick another browser as the default only if Apple has
given the app the managed entitlement `com.apple.developer.web-browser`.
StackForge's team has to ask Apple for it; Apple checks that the app opens
any web address, has a field to type one, and leaves navigation to the user.

What the app does already:

- It names `http` and `https` among the links it opens (`CFBundleURLTypes`
  in `project.yml`). Without the entitlement iOS does not send it such links.
- A web link from another app opens as a new tab of the space in front
  (`SceneDelegate` in `App/MagnetiteApp.swift`); other links are left alone.

Once Apple has granted it:

1. Add `App/Magnetite.entitlements` with `com.apple.developer.web-browser`
   set to `true`, and point `CODE_SIGN_ENTITLEMENTS` at it in `project.yml`.
2. Make a provisioning profile with the entitlement by hand in the developer
   account (Xcode's automatic signing does not add a managed entitlement),
   and use it for the App Store build (`scripts/release.sh`).
3. Then the system's Settings show "Default Browser App" for Magnetite.
   A row in the app's Settings that leads there can follow.

Apple's page: <https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser>
