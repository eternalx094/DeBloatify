**Windows 11 without the ads, Bing, Copilot and junk apps - and every change can be undone.**

DeBloatify is a small, free tool with a simple window. It removes the promotions and bloat Microsoft ships with Windows 11 and fixes common problems using Windows' own repair tools. Nothing to install, and you can read every line of code in this repository.

## What it does

- **Ads and suggestions off:** Start menu promotions, "tips and suggestions", lock screen ads, "Finish setting up your device" nags, OneDrive/Microsoft 365 banners in File Explorer, the Widgets news feed, and sponsored apps that silently install themselves
- **Bing out of Start search:** search only shows what's on your PC, and it gets faster too
- **Copilot and AI off:** Windows Copilot, Recall, Click to Do, and the AI features in Paint and Notepad
- **Less tracking:** telemetry set to the lowest level your edition allows, plus the advertising ID, activity history and feedback pop-ups turned off
- **Edge calmed down:** no Copilot sidebar, shopping pop-ups, Rewards, news feed on new tabs, or running in the background
- **Junk apps removed:** preinstalled games, promo apps and discontinued apps (Candy Crush, Clipchamp, Bing News, Solitaire, Mail & Calendar and more)
- **Known annoyances fixed:** the slow-loading Downloads folder, Fast Startup glitches, laptops waking up at night, surprise update restarts
- **Repair tab:** one-click fixes for Windows Update, a broken Start menu or search, network problems, corrupted system files, the Microsoft Store, the clock, printing and sound

## Safe by design

- **Preview first:** see exactly what will change before anything does
- **Undo anything:** every setting DeBloatify changes is recorded, and the Undo tab puts it back exactly as it was
- **Restore point:** created automatically before changes are applied
- **Core apps protected:** the Microsoft Store, Photos, Notepad, Paint, Calculator, Snipping Tool, Terminal, Windows Security and media codecs are never removed
- **No placebo "speed boosts":** every item says in plain English what it does

## How to use

1. Download **DeBloatify-{VERSION}.zip** below.
2. Right-click the ZIP and choose **Extract All...** (it won't run from inside the ZIP).
3. Double-click **Run-DeBloatify.cmd** and click **Yes** on the administrator prompt.
4. The **Recommended** preset is already ticked. Press **Preview changes** to see the list, then **Apply**, then restart your PC.

Not sure which preset to pick? **Recommended** suits most people. **Minimal** only changes settings and removes no apps. **Aggressive** also removes Xbox, OneDrive, Phone Link, Outlook and Teams.

## Good to know

- Windows may warn that the publisher can't be verified: DeBloatify isn't code-signed. Some antivirus programs are also wary of any debloat tool. All the code is readable in this repository.
- Edge will say "Managed by your organization" - that's how Edge shows the settings that remove its sidebar and ads. Undoing the Edge settings removes the message.
- Removed apps can be reinstalled from the Microsoft Store at any time.
- Big Windows updates sometimes bring things back. Just run DeBloatify again.
- It can't fix bugs inside Windows itself - only Microsoft's updates can do that. It removes the junk and repairs the common breakages.

**Requirements:** Windows 11 and an administrator account. Nothing else to install.

Found a problem? [Open an issue](https://github.com/eternalx094/DeBloatify/issues/new/choose) and attach the log from `C:\ProgramData\DeBloatify\logs`.

SHA-256 of the ZIP: `{SHA256}`
