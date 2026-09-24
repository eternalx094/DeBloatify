# DeBloatify - notes for Claude

DeBloatify is a Windows 11 debloat and repair tool written in PowerShell. It removes ads, Bing search, Copilot/Recall, telemetry and junk apps, and has a Repair menu for common Windows problems. The owner has run it on their own Windows 11 PC (it worked), and shares it with friends and family who are not technical. Keep the wording plain and the defaults safe.

## How it's built

- `DeBloatify.ps1` is the entry point. It relaunches itself as 64-bit Windows PowerShell 5.1, elevated. With no parameters it opens the GUI (`-Console` gives the text menu); presets, `-Repair` and `-Undo` run unattended.
- `Run-DeBloatify.cmd` is the double-click launcher. It detects being run from inside a ZIP; Windows then unpacks only that one file.
- `src/Core.ps1` holds logging and **all** system access (registry through .NET `RegistryKey` in the 64-bit view, services through `sc.exe`, scheduled tasks, AppX). Nothing else touches the system directly.
- `src/Backup.ps1` is the undo store (`%ProgramData%\DeBloatify\backup.json`). It keeps only the *first* original value of each change and is saved after every tweak.
- `src/Engine.ps1` does preset selection, apply, undo and app removal. `Complete-CatalogItem` gives every catalog entry the same keys.
- `src/tweaks/*.ps1` are the tweak definitions, as plain data. Registry values, services and tasks declared there are backed up and undone automatically. `Apply` scriptblocks are not reversible.
- `src/Apps.ps1` is the app catalog. `$script:ProtectedPackages` in Engine.ps1 must never be removed (Store, winget, Photos, Notepad, Paint, codecs, Xbox sign-in pieces...).
- `src/Repairs.ps1` holds the repair actions (DISM/SFC, Windows Update reset, etc.).
- `src/Ui.ps1` is the console menu. `src/Gui.ps1` + `src/GuiWorker.ps1` are the WPF window; slow work runs in a background runspace and streams log lines back through a queue.
- GUI rules: never call a script block made in another runspace (the worker reloads the catalogs itself); keep window state in `$script:Gui`, not in closures; button logic lives in plain functions (`Invoke-GuiApply`, `Invoke-GuiUndo`, ...) so `tests/GuiSmoke.ps1` can drive it; message boxes go through `Show-GuiMessage` (auto-answered in test mode; restart prompts answer No).
- Levels: Minimal < Recommended < Aggressive are cumulative presets. `Optional` items are never in a preset.
- HKCU changes go to the *signed-in* user's hive (HKU\<sid>) even when a different admin account approved UAC.

## Rules learned the hard way

- **Scripts must be pure ASCII.** Windows PowerShell 5.1 misreads UTF-8 files without a BOM. There's a test for this.
- **Windows PowerShell 5.1 compatibility:** no `??`, `?:`, `&&`, or `ConvertFrom-Json -AsHashtable`.
- **Never use `2>&1` on native commands.** With `$ErrorActionPreference = 'Stop'`, 5.1 turns stderr into an exception.
- **`sc.exe config` clears the DelayedAutostart flag** even for Manual/Disabled services. `Set-ServiceStartState` writes it back.
- **`Get-ChildItem -Include` returns directories in 5.1.** Filter on `.Extension` instead.
- **Returning arrays:** functions that return arrays use the unary comma (`return , $x`) where the type matters (byte[], string[]).
- **GitHub Actions:** step-level `shell:` can't use expressions. Use job `defaults.run.shell`.
- **No placebo "performance" tweaks.** Only add changes with a real, explainable effect, and say what each one does.

## Testing

- `pwsh tests/Run-Tests.ps1` (or `powershell -File tests\Run-Tests.ps1`) runs the unit tests under StrictMode, with in-memory fakes of the registry, services, tasks and AppX (`tests/Fakes.ps1`; `tests/WorkerHook.ps1` gives the GUI worker the same fakes). They check the catalog, the GUI worker, and that apply followed by undo gives back the exact original state.
- `tests/Integration.ps1` and `tests/GuiSmoke.ps1` change real system settings and only run in CI, on disposable Windows runners.
- CI (`.github/workflows/tests.yml`) runs the unit tests on Windows PowerShell 5.1, PowerShell 7 on Windows, and Linux; PSScriptAnalyzer; the real apply + undo integration test; and a GUI smoke test that saves screenshots as an artifact.
- PowerShell isn't preinstalled in the cloud dev container. Download pwsh from the GitHub releases tarball; PSGallery is blocked there.
