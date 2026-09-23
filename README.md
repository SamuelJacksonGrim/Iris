<p align="center">
  <img src="iris-icon-256.png" width="120" alt="Iris icon - a drooped rose beside a gentle eye">
</p>

<h1 align="center">Iris</h1>

[![License: AGPL-3.0-only](https://img.shields.io/badge/license-AGPL--3.0--only-blue)](LICENSE)
[![dual-license](https://img.shields.io/badge/dual--license-AGPL--3.0--only%20or%20commercial-blueviolet)](LICENSING.md)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![release](https://img.shields.io/github/v/release/SamuelJacksonGrim/Iris)](https://github.com/SamuelJacksonGrim/Iris/releases/latest)
![status](https://img.shields.io/badge/status-released-success)

<p align="center"><em>A tiny, private, self-contained screenshot &amp; screen-recording tool for Windows.<br>
No third parties. No telemetry. No cloud. One file.</em></p>

---

## What it is

Iris takes **region screenshots** and records **looping GIF clips** of your screen — and
that's it, on purpose. No account, no uploader, no background service phoning home, no
data collection of any kind. Everything happens on your machine and stays there.

It's built for people who just want to grab a screenshot or a short clip **without
installing something that harvests their data** or drags in a pile of third-party
software.

## Why it's different

- **Genuinely self-contained.** The whole app is one `Iris.exe`. Under the hood it's a
  PowerShell + .NET app that uses only what Windows already ships with — no bundled
  binaries, no downloaded encoders, nothing to trust but the machine itself.
- **It never films itself.** Click a capture button and Iris hides before the shot, so
  the tool is never in its own screenshot or recording.
- **Captures anything you can see** — including elevated/admin windows, because it runs at
  your own privilege level instead of reaching in from outside.

## Features

- 📷 **Screenshot** — click, drag a region (with a live size readout), done. Saved as a
  timestamped PNG *and* dropped on your clipboard.
- 🎬 **Record** — drag a region, record it, and Iris writes an **animated, looping GIF**.
  A small Stop bar sits *outside* the recorded area so it isn't in the clip.
- ⌨️ **Global hotkey** — `Ctrl+Alt+S` snaps a region from anywhere, no window needed.
- 🌹 **Tray icon** — lives quietly in the tray; minimize hides it there.
- 🔒 **Local only** — no network code exists in it at all.

## Get it

Grab **`Iris.exe`** from the [Releases](../../releases) page and double-click it. That's
the whole install.

> **"Windows protected your PC"?** That's SmartScreen being cautious about any new program
> that isn't signed by a big company (code-signing certificates cost money). Click
> **More info → Run anyway**. Everything here is open source — you can read every line.

Screenshots and recordings save to your **`Pictures\Screenshots`** folder.

## Build from source

You only need Windows (PowerShell + .NET Framework 4.x — both already present on every
modern Windows install).

```powershell
# regenerate the icon (optional)
.\make-icon.ps1
# compile the single-file exe -> dist\Iris.exe
.\make-exe.ps1
```

`make-exe.ps1` compiles `Iris.cs` with the C# compiler already on the machine, embedding
`iris.ps1` and `iris.ico` inside the exe. No build tools to install.

## How it works

- `iris.ps1` — the app: WinForms UI, region capture, tray, hotkey.
- GIF encoding is dependency-free — WPF's `GifBitmapEncoder` with per-frame delays and a
  loop block patched in.
- `Iris.cs` — a tiny C# launcher that carries the script + icon and starts it with no
  console window.

## License

Dual-licensed: [AGPL-3.0-only](LICENSE) or a [commercial license](LICENSING.md).

---

<sub>🌹 Iris is the *eye* of a small family of local-first tools. Built to see, and to be given away.</sub>
