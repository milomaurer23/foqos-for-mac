# Foqos for Mac: developer handoff

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
- The README was rewritten for the Mac app. The original iOS README moved to `docs/IOS_README.md`, and this handoff moved out of the README

## Next steps

1. **Small cleanup:**
   - Read the version from the bundle instead of the hardcoded `"1.0"` in `ContentView.swift`
   - Remove the no-op `flushDNSCache()` in `HostsManager.swift`
   - Derive `profile.isActive` from `activeProfileId` instead of storing both
2. **Distribution:** sign, notarize and publish a release `.app` so people don't have to build from source.
3. Make the month calendar interactive: click a day to see that day's sessions.
4. Keep the popular-domain catalog current (LinkedIn, Hulu, Spotify and so on).
5. Add macOS unit tests for domain validation, hosts-marker parsing, calendar aggregation and profile persistence.
6. Known limitation that Milo accepts for now: `/etc/hosts` can't wildcard (for example `*.googlevideo.com`) and doesn't affect tabs that were already open, so a cached YouTube tab can still play videos. A real fix needs an `NEFilterDataProvider` network extension.

**Don't** attempt the Screen Time / FamilyControls APIs on macOS. `FamilyActivityPicker` is iOS-only, `ManagedSettings` app shielding needs Mac Catalyst, and it requires Family Sharing guardian approval, which rules out self-blocking.
