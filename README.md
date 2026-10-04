<p align="center">
  <img src="./images/foqos-logo.png" width="140" alt="Foqos app icon">
</p>

<h1 align="center">Foqos for Mac</h1>

<p align="center">
  <strong>A native macOS focus blocker. Pick a profile, press start, and the sites and apps that eat your afternoon are gone until you stop.</strong>
</p>

<p align="center">
  SwiftUI · macOS 26.3+ · free and open source · no account, no tracking
</p>

<p align="center">
  <img src="./docs/screenshots/home.png" width="860" alt="Foqos for Mac home screen with the focus tracker">
</p>

---

## Why I built it

I use [Foqos](https://github.com/awaseem/foqos) on my iPhone and wanted the same thing on the computer I actually work on. The iOS app relies on Apple's Screen Time APIs, which can't do self-blocking on a Mac, so this is a separate native app built a different way: a marked block in `/etc/hosts` for sites, and an app watcher that quits blocked apps.

## What it does

- **Profiles for different modes.** Deep Work, Study Mode, Bedtime, or your own, each with its own sites, apps, icon and color. Start from a preset or from scratch.
- **Blocks websites.** Choose from a checklist of popular sites, or add any domain. Typing `https://` or a path gets caught before it's saved.
- **Quits distracting apps.** Add apps to a profile, and they're asked to quit as soon as they open during a session. Finder, the Dock and Foqos itself can never be blocked.
- **One click from the menu bar.** The shield is an outline when you're free and filled while you're blocking.
- **A focus tracker you can read at a glance.** Each day is shaded by how long you focused, not how many times you pressed start. Tiles show today, the month, your streak and all-time, and the running session counts live.
- **Hard to lose track of.** Quitting mid-session asks whether to stop or keep blocking. If the app quits unexpectedly, the session picks back up on relaunch, and Settings always shows whether a block is active, with a button to clear it.

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="./docs/screenshots/profile.png" alt="A profile with its blocked sites and apps"><br><sub><b>A profile:</b> blocked sites and apps, each with its own toggle</sub></td>
    <td width="50%"><img src="./docs/screenshots/history.png" alt="Session history"><br><sub><b>History:</b> every session, newest first, with how long it lasted</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="./docs/screenshots/new-profile.png" alt="Creating a new profile"><br><sub><b>New profile:</b> a name, an icon and a color, then add what to block</sub></td>
    <td width="50%"><img src="./docs/screenshots/settings.png" alt="Settings showing the live hosts block status"><br><sub><b>Settings:</b> live block status and your hosts backup, at a glance</sub></td>
  </tr>
</table>

## How it works

| | How | What you'll notice |
|---|---|---|
| **Sites** | Adds a clearly marked section of `0.0.0.0` entries to `/etc/hosts`, and removes only that section when you stop. A one-time backup is saved to `/etc/hosts.foqos.bak`. | macOS asks for your password when you start and stop a session. |
| **Apps** | Watches app launches and politely asks blocked apps to quit. | Works only while Foqos is open. No special permissions needed. |
| **Your data** | Profiles and history are stored as JSON in `~/Library/Application Support/Foqos-macOS/`. | Nothing leaves your Mac. |

### Honest limits

- **Tabs that are already open can keep working.** `/etc/hosts` only affects new connections, and it can't block wildcards. A YouTube tab that was open before you started can still play cached videos. Close the tab and it's blocked.
- **This is a roadblock, not a jail.** Someone with your admin password can edit `/etc/hosts`. The point is friction, not lockdown.
- **No signed download yet.** For now you build it from source.

## Build it

You need Xcode 26.5 or later, and macOS 26.3 or later to run it.

```bash
git clone https://github.com/milomaurer23/foqos-for-mac.git
cd "foqos-for-mac/Foqos - macOS"
open "Foqos - macOS.xcodeproj"
```

Press **Run** in Xcode, or build from the command line:

```bash
xcodebuild -project "Foqos - macOS.xcodeproj" -scheme "Foqos - macOS" \
  -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

The app ends up in `build/Build/Products/Release/`.

## Credits

Foqos was created by [Ali Waseem](https://github.com/awaseem) as a free, open-source iPhone app blocker that uses NFC and QR codes. This repo is a fork of it, and the original iOS source is still here under `Foqos/` and its extension folders. The iOS README is at [docs/IOS_README.md](docs/IOS_README.md), and the iOS app is on the [App Store](https://apps.apple.com/ca/app/foqos/id6736793117).

The macOS app in `Foqos - macOS/` is built by [Milo Maurer](https://github.com/milomaurer23).

## Contributing

Issues and pull requests are welcome. If you're working on the Mac app, read [docs/MACOS_HANDOFF.md](docs/MACOS_HANDOFF.md) first. It covers the source map, how blocking works, and what's next.

## License

MIT, same as the original. See [LICENSE](LICENSE).
