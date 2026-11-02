# ScavTime - Never be late for a Raid!

**Version:** 1.0.0  
**Author:** Vargor / OptimisticSociopath  
**Mod GUID:** `com.vargor.scavtime`  
**Game:** SPT 4.1.6

ScavTime disables the random reduction of the player-Scav raid clock. The SPT backend sets `ReducedChancePercent` to `0` for applicable maps. It does **not** extend the regular PMC raid duration or directly modify bot waves, loot, extractions, player profiles or game files.

## Installation

This GitHub repository contains **source code**, not the installation-ready DLL. After building and testing, publish the installation ZIP as a separate release asset; the appropriate layout is:

```text
SPT_Runtime/user/mods/ScavTime/ScavTime.Server.dll
SPT_Runtime/user/mods/ScavTime/icon.png
```

Stop SPT before installing. Remove the previous `ScavFullRaidTime` folder if present, and avoid running the old mod and ScavTime together. Once installed, start the backend and check for `[ScavTime] ACTIVE` in its log. Verify the Scav raid timer in-game.

## Building from source (Windows, offline)

Requirements: Windows PowerShell **5.1 x64**, .NET SDK **10**, and a local SPT 4.1.6 installation at `C:\SPT` containing the server assemblies in `C:\SPT\SPT_Runtime`.

Clone or download this repository into a folder **outside** `C:\SPT`. Open Windows PowerShell 5.1 x64 and run this while in the repository's root folder:

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $repo = (Get-Location).Path
    $runner = Join-Path $repo 'RUN_WINDOWS_PS51.ps1'
    & (Join-Path $PSHOME 'powershell.exe') -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $runner -Mode BUILD_PACKAGE -GameRoot 'C:\SPT' -BundleRoot $repo -DownloadDir (Join-Path $env:USERPROFILE 'Downloads')
    if ($LASTEXITCODE -ne 0) { throw ('SCAVTIME_BUILD_FAILED_RC=' + $LASTEXITCODE) }
}
```

The runner references **local** SPT assemblies; it restores from an empty offline NuGet feed, runs behavior tests, builds the release DLL and creates `ScavTime-Never-be-late-for-a-Raid-v1.0.0.zip` in `Downloads`. It does not modify the SPT installation. The final output filename must not already exist, otherwise it fails closed. Do not publish a release until the installer ZIP has passed verification and runtime testing.

## Fika

ScavTime is server-side and has **no required Fika dependency**. On a Fika setup, install it only on the shared SPT backend. No client DLL or BepInEx plugin is included. The Fika detector only checks the presence of a server folder. **Live co-op functionality has not yet been verified**. A late-join/reconnect must not be described as resetting the host's active raid clock.

## Sources and tests

- `src/`: actual C# mod implementation and .NET project
- `tests/`: behavioral tests for the Scav-time change and Fika-folder detection
- `RUN_WINDOWS_PS51.ps1`: offline build and test runner
- `FIKA_TEST_PLAN_PL.md`: planned manual Fika checks
- `assets/icon.png`: requested mod artwork
- `FORGE_LISTING_EN.md`: draft listing text for the mod page

Do not commit SPT game assemblies, private accounts, or binary dependencies to this repository. The project depends on your own compatible SPT installation for its references.

## AI and artwork disclosure

This project was developed with substantial AI coding assistance, and its image asset was generated from a user-provided cartoon meme reference. Review The Forge's **current content rules**, including the prohibition on substantially AI-authored mods, the requirement to flag AI content, and copyright/permission requirements for derivatives, **before submitting**. Publishing the repository does not itself establish compliance or permission to redistribute any third-party art.

## Licensing

The C# source files are offered under the MIT license (see `LICENSE-CODE`). The artwork is **not** covered by that code license; its redistribution rights must be reviewed separately before public release.
