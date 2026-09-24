# DeBloatify

Debloat and repair Windows 11. DeBloatify removes ads, Bing search, Copilot/Recall, telemetry and preinstalled junk apps. It also fixes common Windows 11 problems using Windows' own repair tools.

- **Undo is built in.** Every registry value, service and scheduled task DeBloatify changes is recorded first, and Undo puts it back exactly. It also creates a System Restore point before making changes.
- **Nothing essential is removed.** The Microsoft Store, winget, Edge/WebView2, Photos, Notepad, Paint, Calculator, Terminal, Snipping Tool, media codecs and Windows Security are protected.
- **No placebo tweaks.** There are no "gaming boost" registry myths. Every change says what it does and why.
- **No downloads.** It's plain PowerShell that ships with Windows, and you can read every line.

## Quick start

1. Download the repository (**Code > Download ZIP**) and extract it.
2. Double-click **`Run-DeBloatify.cmd`** and accept the administrator prompt.
3. Choose **1 - Recommended**, check the list of changes and confirm.
4. Restart your PC.

```
  DeBloatify  v1.0.0  -  debloat and repair Windows 11
  ----------------------------------------------------------------
  [1] Recommended   Removes ads, Bing, Copilot, telemetry and junk apps. Best for most people.
  [2] Minimal       Settings only (ads, Bing, Copilot, telemetry). Removes no apps.
  [3] Aggressive    Recommended + Xbox, OneDrive, Phone Link, Outlook, Teams and more.
  [4] Custom        Choose exactly which settings and apps.

  [5] Repair        Fix Windows Update, Start menu, search, network, corrupted files...
  [6] Undo          Put back settings DeBloatify changed.
  [7] Preview       See what a preset would change, without changing anything.
```

Not sure? Use **7 - Preview** first. It lists every change a preset would make without touching anything.

## What it changes

| Area | Examples |
|---|---|
| **Ads & suggestions** | Sponsored apps silently installed (Candy Crush, TikTok...), Start menu promotions, lock screen "fun facts", tips pop-ups, "Finish setting up your device" nags, OneDrive/Microsoft 365 banners in File Explorer, the Widgets news feed |
| **Bing & search** | Bing web results in Start search (Start search also gets faster), search highlights, cloud search, the "Learn about this picture" desktop icon |
| **Copilot & AI** | Windows Copilot, Recall, Click to Do, AI features in Paint and Notepad, and the Copilot app |
| **Microsoft Edge** | Copilot sidebar, shopping assistant, Rewards, new-tab news feed, promotions, background running, silent import from other browsers, desktop shortcut re-creation |
| **Privacy** | Telemetry to the lowest level your edition allows, advertising ID, activity history, feedback prompts, inking/typing collection, P2P update uploads |
| **Fixes** | Fast Startup (behind many "weird after shutdown" bugs), the slow-loading Downloads folder, long file paths, maintenance waking the PC at night, update restarts while you're signed in |
| **Apps** | Removes promo and discontinued apps (Bing apps, Clipchamp, Solitaire, Tips, Mail & Calendar, Skype, Cortana, third-party games) for every user, so new accounts don't get them either |
| **Interface** *(opt-in)* | Classic right-click menu, left-aligned taskbar, "End task" on the taskbar, open Explorer to This PC, hide the Sticky Keys prompt... |

Run `DeBloatify.ps1 -List` for the full list with ids, or press `?` followed by a number in the Custom menu to read what an item does.

### Presets

| Preset | What it includes |
|---|---|
| **Minimal** | Settings only: ads, Bing, Copilot/Recall, core telemetry and Edge nags. Removes no apps. |
| **Recommended** | Minimal, plus promo/discontinued apps, more privacy settings, the fixes and file extensions. The best choice for most people. |
| **Aggressive** | Recommended, plus Xbox/Game Bar, OneDrive, Phone Link, Outlook, Teams, To Do, Maps, Sticky Notes, preinstalled Spotify/Netflix/etc., the Widgets platform, Store apps running in the background and error reporting. |
| *Optional* | Personal-preference items that are never in a preset. Pick them in Custom or with `-Include`. |

## Repair tools

These are one-off fixes using Windows' built-in tools (DISM, SFC, netsh, and others):

| Repair | Fixes |
|---|---|
| Repair system files (DISM + SFC) | Crashes, broken features and corrupted system files |
| Reset Windows Update | Updates that are stuck or keep failing |
| Fix Start menu, taskbar and search box | Start won't open, blank taskbar, search box won't type |
| Rebuild the search index | Search can't find files or apps |
| Clear icon and thumbnail cache | Blank or wrong icons |
| Reset network stack | "Connected, no internet", DNS errors |
| Fix Microsoft Store | Store won't open, downloads stuck |
| Fix the clock | Time drifting, which also breaks sign-ins and HTTPS |
| Clear stuck print jobs | Print queue won't clear |
| Restart audio services | Sound suddenly stops |
| Check and repair WMI | Errors in Task Manager, Settings and management tools |
| Scan system drive | Disk errors (online scan, no restart) |
| Free up disk space | Temp files, the Delivery Optimization cache and superseded updates |

**About "fixing all Windows 11 bugs":** no script can do that. Most Windows bugs are in Microsoft's own code and are fixed by Windows updates. DeBloatify does two things: it repairs *corruption* (files, caches, update components), and it works around *well-known problem settings* (Fast Startup, folder type sniffing, web search in Start). If a problem started after a specific update, **Settings > Windows Update > Update history > Uninstall updates** is often the real fix.

## Undo

- **Menu > 6 - Undo** restores every recorded setting, or only the ones you choose.
- From the command line: `DeBloatify.ps1 -Undo`, or `DeBloatify.ps1 -Undo -Include edge.*` for part of it.
- **Removed apps are not restored by Undo.** Reinstall them from the Microsoft Store, or roll back with the restore point (**Menu > 6 > R**, or run `rstrui.exe`).
- The backup lives in `C:\ProgramData\DeBloatify\backup.json` and logs are in `C:\ProgramData\DeBloatify\logs`.

## Command line

```powershell
.\DeBloatify.ps1 -Preset Recommended                         # unattended
.\DeBloatify.ps1 -Preset Recommended -DryRun                 # preview only
.\DeBloatify.ps1 -Preset Recommended -Exclude app.weather,edge.*
.\DeBloatify.ps1 -Preset Minimal -Include ui.classic-context-menu,ui.taskbar-left
.\DeBloatify.ps1 -Include Interface -SkipApps                # a whole category
.\DeBloatify.ps1 -Repair repair.system-files,repair.windows-update
.\DeBloatify.ps1 -Repair All
.\DeBloatify.ps1 -Undo
.\DeBloatify.ps1 -List
```

Other switches: `-SkipApps`, `-NoRestorePoint`, `-NoRestartExplorer`, and `-Force` (run on Windows 10 or without a restore point). The exit code is 0 on success, 1 if the run stopped, and 2 if some changes failed.

If you launch the `.ps1` directly and PowerShell refuses to run it, use `Run-DeBloatify.cmd` instead, or run `powershell -ExecutionPolicy Bypass -File .\DeBloatify.ps1`.

## Good to know

- **Edge says "Managed by your organization".** That's how Edge shows that policies are set, and the Edge tweaks are policies. Undoing the Edge tweaks removes the message.
- **Home vs Pro.** Windows Home/Pro can't turn telemetry fully off (the minimum is "Required"). A few policies (the consumer-features switch, the no-auto-restart rule) are only honoured on Pro, Enterprise or Education. They are harmless elsewhere.
- **OneDrive (Aggressive)** refuses to uninstall while your Desktop/Documents/Pictures are backed up to OneDrive. Uninstalling then could leave cloud-only files unreachable. Turn off folder backup in OneDrive first.
- **Standard user accounts.** If you type an administrator's password into the UAC prompt, per-user settings still go to the signed-in account, not the administrator's.
- **Feature updates** (e.g. 24H2 to 25H2) sometimes bring apps or settings back. Run DeBloatify again afterwards; it only changes what needs changing.

## Development

```powershell
powershell -File tests\Run-Tests.ps1     # unit tests (also: pwsh tests/Run-Tests.ps1 on Linux/macOS)
```

The unit tests replace the registry, services, scheduled tasks and AppX with in-memory fakes. They check the catalog, the presets, and that apply followed by undo returns the system to its exact original state. CI also runs them on Windows PowerShell 5.1 and PowerShell 7. It runs `tests/Integration.ps1` on a disposable Windows runner too: that applies every tweak for real, undoes it, and compares the state.

Layout:

```
DeBloatify.ps1        entry point (menu + command line, self-elevates)
Run-DeBloatify.cmd    double-click launcher
src/Core.ps1          logging, environment checks, registry/service/task/AppX primitives
src/Backup.ps1        backup store used by Undo
src/Engine.ps1        preset selection, apply, undo, app removal
src/Apps.ps1          app catalog
src/Repairs.ps1       repair tools
src/Ui.ps1            console menus
src/tweaks/*.ps1      tweak definitions (plain data)
```

To add a tweak, add an entry to the right file in `src/tweaks/`. Registry values, services and scheduled tasks declared there are backed up and undone automatically.
