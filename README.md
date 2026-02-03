# Adrenaline Hook (C# WPF recreation)

This is a Visual Studio **WPF** solution that recreates the core workflow of your PowerShell tool:

- Scan **UWP / GamePass** apps
- Scan **installed (Win32)** software
- Select items and **hook** them into AMD Adrenalin by appending entries to:
  - `%LOCALAPPDATA%\AMD\CN\gmdb.blb`
- View / remove hooked entries
- Backup / restore / reset the database
- Open AMD Software

## Build

1. Install **Visual Studio 2022** with:
   - **.NET desktop development**
   - **.NET 8 SDK**
2. Open `AdrenalineHookWpf.sln`
3. Build + Run (the app requests **Administrator** via `app.manifest`)

## Notes

- UWP scanning uses `Windows.Management.Deployment.PackageManager` and may skip framework/system packages.
- Executable discovery is bounded (depth + file limits) to avoid extremely slow scans.
- Your AMD database file is treated as JSON for edit/merge, just like your PowerShell script.

## Where files are written

- gmdb: `%LOCALAPPDATA%\AMD\CN\gmdb.blb`
- backup: `%LOCALAPPDATA%\AMD\CN\backup.blb`
- log: `%LOCALAPPDATA%\TetraDev\AdrenalineHookWpf\log.txt`
