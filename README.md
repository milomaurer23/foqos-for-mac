<p align="center">
  <img src="./images/foqos-logo.png" width="120" alt="Foqos app icon">
</p>

> [!IMPORTANT]
> **Looking for the official Foqos for Mac?** Ali Waseem makes one, and it syncs with your iPhone over iCloud.
> **[Download the official Foqos for Mac](https://github.com/awaseem/foqos/releases)** · [Mac app source](https://github.com/awaseem/foqos/tree/main/FoqosMac) · [Foqos repo](https://github.com/awaseem/foqos)

<h1 align="center">Foqos Mac (Milo's personal build)</h1>

<p align="center">
  A personal build by <a href="https://github.com/milomaurer23"><b>Milo Maurer</b></a> · based on <a href="https://github.com/awaseem/foqos"><b>Foqos</b></a> by <a href="https://github.com/awaseem"><b>Ali Waseem</b></a>
</p>

> [!NOTE]
> **Foqos was created by [Ali Waseem](https://github.com/awaseem).** The idea, the name, the iPhone app and the official Mac app are all his. I'm not affiliated with Ali or the official apps. This is my own build, made for how I work on my Mac. It isn't meant to compete with his.

<p align="center">
  <a href="https://github.com/milomaurer23/foqos-for-mac/releases/latest"><b>⬇ Download Milo's personal build</b></a><br>
  <sub>Free · macOS 14 or later · Apple Silicon and Intel</sub>
</p>

<p align="center">
  <img src="./docs/screenshots/home.png" width="860" alt="Foqos Mac (Milo's personal build) home screen with the focus tracker">
</p>

## Why I made this

I've used and enjoyed Foqos on my phone for a while. Most of my actual work happens on my computer, though, and that's where I lose the most time to a stray tab. I wanted the same kind of focus session on my Mac, so I built one. This is me filling that gap for myself, not a replacement for the original. I started it before Ali released his official Mac app, and I keep it as my own take.

Milo

## How this differs from the official Mac app

| | Official Foqos for Mac (Ali) | This personal build |
|---|---|---|
| Where you start a session | On your iPhone. The Mac follows over iCloud | On the Mac itself |
| Website blocking | A built-in macOS content filter | A marked block in `/etc/hosts` |
| Apps | Blocked on your iPhone. The Mac syncs website rules | Quits blocked Mac apps during a session |
| Focus history | Insights in the iPhone app | Calendar tracker and history on the Mac |
| Install | Signed and notarized, updates itself | One-time "Open Anyway" step |

If you use Foqos on your iPhone, start with [Ali's official Mac app](https://github.com/awaseem/foqos/releases).

## What it does

- **Profiles** for different modes, like Deep Work, Study Mode and Bedtime, each with its own sites and apps
- **Blocks websites** for as long as a session runs
- **Quits distracting apps** if you open them mid-session
- **Tracks your focus** with a calendar shaded by how long you focused each day
- **Starts from the menu bar** in one click

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="./docs/screenshots/profile.png" alt="A profile with its blocked sites and apps"><br><sub><b>A profile:</b> the sites and apps it blocks</sub></td>
    <td width="50%"><img src="./docs/screenshots/history.png" alt="Session history"><br><sub><b>History:</b> every session and how long it lasted</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="./docs/screenshots/new-profile.png" alt="Creating a new profile"><br><sub><b>New profile:</b> a name, an icon and a color</sub></td>
    <td width="50%"><img src="./docs/screenshots/settings.png" alt="Settings showing blocking status"><br><sub><b>Settings:</b> whether anything is blocked right now</sub></td>
  </tr>
</table>

## How it works

Sites are blocked by adding a clearly marked section to `/etc/hosts`, so macOS asks for your password when a session starts and stops. Apps are asked to quit while Foqos is open. Everything stays on your Mac.

It's a roadblock, not a jail. A tab that was already open before the session started can keep working until you close it.

## Install

1. [Download the latest `.zip`](https://github.com/milomaurer23/foqos-for-mac/releases/latest) and double-click it to unzip.
2. Drag **Foqos Mac (personal build).app** into your **Applications** folder. It has a different name from the official app, so you can have both.
3. **The first time you open it,** macOS will warn that it can't verify the app. That's because this is a free personal project and isn't signed through Apple's paid developer program yet. To open it anyway:
   - **macOS 15 or later:** double-click the app, click **Done**, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   - **macOS 14:** right-click the app, choose **Open**, then click **Open** again.

You only have to do this once. You'll need to be an admin on your Mac, because blocking sites asks for your password.

## Build it yourself

You need Xcode 26.5 or later.

```bash
git clone https://github.com/milomaurer23/foqos-for-mac.git
open "foqos-for-mac/Foqos - macOS/Foqos - macOS.xcodeproj"
```

Then press **Run** in Xcode.

---

## The original Foqos (iPhone)

[Foqos](https://github.com/awaseem/foqos) by [Ali Waseem](https://github.com/awaseem) is a free, open-source iPhone app that blocks distracting apps and websites using Apple's Screen Time. You can start a session by tapping an NFC tag, scanning a QR code, setting a timer or tapping a button. There's no account, no ads and no subscription.

- [Download it on the App Store](https://apps.apple.com/ca/app/foqos/id6736793117)
- [foqos.app](https://www.foqos.app/)
- [Source code](https://github.com/awaseem/foqos)
- [Support Ali's work](https://coff.ee/ambitionsoftware)

This repo is a fork of Ali's, so the iPhone source is still here. Its full original README is in [docs/IOS_README.md](docs/IOS_README.md).

## License

MIT, same as the original Foqos. See [LICENSE](LICENSE).
