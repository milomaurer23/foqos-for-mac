# Foqos Mac (Milo's personal build): developer handoff

> **Instructions for the next agent:**
> Read this whole file before you touch any macOS code. When you finish a session, update it with what you changed, any bugs you fixed, and the revised next steps. Leave it so the agent after you can start without asking Milo to re-explain the project.

The macOS app lives in `Foqos - macOS/`. It's a separate native SwiftUI app inspired by the iOS Foqos app. It isn't part of the iOS target, and it doesn't use the Screen Time APIs.

## Location and build

- Project: `Foqos - macOS/Foqos - macOS.xcodeproj` (scheme `Foqos - macOS`, bundle ID `Milo.Foqos---macOS`)
- Sources: `Foqos - macOS/Foqos - macOS/`
- Desktop test copy: `~/Desktop/Foqos.app`
- Build:

```bash
cd "Foqos - macOS"
xcodebuild -project "Foqos - macOS.xcodeproj" \
  -scheme "Foqos - macOS" \
  -configuration Debug \
  -sdk macosx \
  -derivedDataPath /tmp/FoqosMacBuild \
  CODE_SIGNING_ALLOWED=NO build
```

### Source map

| File | What it owns |
|---|---|
| `Foqos___macOSApp.swift` | App entry, menu bar extra, quit interception (`AppDelegate`) |
| `ContentView.swift` | Sidebar, Home, Profiles, History and Settings tabs, focus tracker |
| `ProfileDetailView.swift` | One profile's blocked sites and apps, add-domain sheet |
| `DomainPickerView.swift` | Popular-sites checklist |
| `ProfileStore.swift` | Profiles, sessions, the active session, persistence, launch reconciliation |
| `HostsManager.swift` | The marked `/etc/hosts` block (write, remove, parse, validate) |
| `AppBlocker.swift` | Quits blocked apps while a session runs |
| `Models.swift` | Codable data models, categories and presets, templates |

## How blocking works

**Sites.** `HostsManager.swift` writes only a clearly marked section between `# >>> FOQOS BLOCK START <<<` and `# >>> FOQOS BLOCK END <<<` in `/etc/hosts`. Starting a session replaces any previous Foqos section, and stopping removes only that section. Other hosts entries are preserved, and a one-time backup goes to `/etc/hosts.foqos.bak`. macOS asks for an administrator password through `osascript` whenever the file changes. The target has App Sandbox **off** because of this.

**Apps.** `AppBlocker.swift` watches app launches and asks blocked apps to quit (`NSRunningApplication.terminate`). It needs no special permissions, works only while Foqos is open, and never blocks Finder, the Dock, the login window, SystemUIServer or Foqos itself.

**Data.** Profiles, completed sessions and the active session are stored as JSON in `~/Library/Application Support/Foqos-macOS/`: `profiles.json`, `sessions.json` and `active-session.json`. Window size is saved in `~/Library/Preferences/Milo.Foqos---macOS.plist` under `NSWindow Frame main-AppWindow-1`. There's also a stale sandboxed container at `~/Library/Containers/Milo.Foqos---macOS`, so `defaults read Milo.Foqos---macOS` reads the wrong domain. Use the plist path instead.

## Change log

**2026-08-03**
- One password dialog per start/stop instead of two (the DNS flush was merged into the same `osascript` call)
- Profiles no longer come back as "active" after a crash
- Starting a second session while one is running is now ignored
- The Settings tab is reachable from the sidebar
- Calendar day numbers are readable on filled days
- The first tracker metric follows the month being displayed

**2026-08-13**
- Quitting with a session running asks: Stop Blocking and Quit / Keep Blocking and Quit / Cancel
- The active session is persisted, and `ProfileStore.restoreActiveSession()` reconciles it with `/etc/hosts` on launch (resume, stale-block alert, or archive)
- `stopSession()` keeps the session running if the unblock fails, so the UI never claims a site is unblocked when it isn't
- Deleting the selected profile no longer shows the empty state
- Adding a domain uses a sheet that validates as you type (`AddDomainSheet`)
- Domains can be removed with a hover minus button or a right-click
- The timer is derived from `startTime`, so it survives sleep
- Rebuilt focus tracker: days shaded by minutes focused, a legend, Today / Month / Streak / All-time tiles, a ring on today, and the running session counted live

**2026-09-30**
- `HostsManager` hardening: a failed copy no longer reports success, a one-time hosts backup is written, block parsing is order-safe and handles half-written or duplicate blocks, and `isValidDomain` is ASCII-only with no empty labels
- The menu bar icon is an outline shield when idle and filled while blocking
- Settings shows the live hosts block status with a Clear button
- App blocking (`AppBlocker.swift`), with per-profile blocked apps

**2026-10-04**
- `WindowGroup` has `.defaultSize(width: 1100, height: 780)`, so a first launch shows the whole tracker
- Ali Waseem is credited in the app: a Credits section at the top of Settings (links to his repo and the App Store) and a footer line on Home (`FoqosCreditLine` in `ContentView.swift`)
- README screenshots live in `docs/screenshots/` and use sample data, not real history
- The README was rewritten for the Mac app. The original iOS README moved to `docs/IOS_README.md`, and this handoff moved out of the README
- First public release, **v0.1.0**, on GitHub Releases. The minimum macOS dropped from 26.3 to **14.0** (it compiles clean; it's only been run on macOS 26). `MARKETING_VERSION` is 0.1.0, and Settings reads the version from the bundle

**2026-10-04 (0.1.1)**
- Renamed to **Foqos Mac (Milo's personal build)**. Ali Waseem ships an official **Foqos for Mac** (since 2026-08-05, in his repo under `FoqosMac/`, released as `mac-v*` tags). It syncs with the iPhone app over iCloud and blocks websites with a system content filter. This build must never look like it competes with that one.
- The window title is the new name, and the zipped app is `Foqos Mac (personal build).app`, so it never collides with the official `Foqos for Mac.app`
- Settings → Credits links Ali's repo, his official Mac app and the iPhone app. The Home footer reads "A personal build based on Foqos by Ali Waseem"
- The README opens with a pointer to the official Mac app and has a comparison table

## Making a release

The app is ad-hoc signed, not notarized (Milo has no paid Apple Developer Program membership yet), so users go through "Open Anyway" once. Apple Silicon refuses to run a completely unsigned binary, so the ad-hoc signature is required.

```bash
cd "Foqos - macOS"
xcodebuild -project "Foqos - macOS.xcodeproj" -scheme "Foqos - macOS" -configuration Release \
  -sdk macosx -derivedDataPath /tmp/FoqosMacRelease ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build
ditto "/tmp/FoqosMacRelease/Build/Products/Release/Foqos - macOS.app" "/tmp/release/Foqos Mac (personal build).app"
codesign --force --deep --sign - "/tmp/release/Foqos Mac (personal build).app"
cd /tmp/release && ditto -c -k --sequesterRsrc --keepParent "Foqos Mac (personal build).app" Foqos-Mac-personal-build-X.Y.Z.zip
gh release create vX.Y.Z Foqos-Mac-personal-build-X.Y.Z.zip --repo milomaurer23/foqos-for-mac
```

Bump `MARKETING_VERSION` in the pbxproj (both configs) first.

## Next steps

1. **Notarized releases** once Milo joins the Apple Developer Program: create a Developer ID Application certificate, sign with hardened runtime, `xcrun notarytool submit`, staple, and ship a `.dmg`. This removes the "Open Anyway" step.
2. **Test on macOS 14 and 15.** The deployment target is 14.0, but the app has only been run on macOS 26.
3. **Small cleanup:**
   - Remove the no-op `flushDNSCache()` in `HostsManager.swift`
   - Derive `profile.isActive` from `activeProfileId` instead of storing both
4. Make the month calendar interactive: click a day to see that day's sessions.
5. Keep the popular-domain catalog current (LinkedIn, Hulu, Spotify and so on).
6. Add macOS unit tests for domain validation, hosts-marker parsing, calendar aggregation and profile persistence.
7. Known limitation that Milo accepts for now: `/etc/hosts` can't wildcard (for example `*.googlevideo.com`) and doesn't affect tabs that were already open, so a cached YouTube tab can still play videos. A real fix needs an `NEFilterDataProvider` network extension.

**Don't** attempt the Screen Time / FamilyControls APIs on macOS. `FamilyActivityPicker` is iOS-only, `ManagedSettings` app shielding needs Mac Catalyst, and it requires Family Sharing guardian approval, which rules out self-blocking.
