# App catalog. Packages are AppX package-name patterns (wildcards allowed).
# Removal covers every user account, and the app is also deprovisioned so Windows
# doesn't install it again for new accounts. Everything here can be reinstalled
# from the Microsoft Store.
#
# Core components (Store, winget, Photos, Notepad, Paint, Calculator, Terminal,
# Snipping Tool, media codecs, Xbox sign-in pieces games need, ...) are never
# removed. See $script:ProtectedPackages in Engine.ps1.

function Get-AppCatalog {
    @(
        # --- Microsoft promos and discontinued apps -------------------------------------
        @{ Id = 'app.copilot'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Copilot'
            Packages = @('Microsoft.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider') }
        @{ Id = 'app.m365-hub'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Microsoft 365 (Office) hub app'
            Packages = @('Microsoft.MicrosoftOfficeHub') }
        @{ Id = 'app.bing-apps'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Bing apps (News, Search, Finance, Sports, Travel, ...)'
            Packages = @('Microsoft.BingNews', 'Microsoft.BingSearch', 'Microsoft.BingFinance', 'Microsoft.BingSports',
                'Microsoft.BingTravel', 'Microsoft.BingFoodAndDrink', 'Microsoft.BingHealthAndFitness', 'Microsoft.BingTranslator') }
        @{ Id = 'app.weather'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Weather (MSN)'
            Packages = @('Microsoft.BingWeather') }
        @{ Id = 'app.clipchamp'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Clipchamp video editor'
            Packages = @('Clipchamp.Clipchamp') }
        @{ Id = 'app.solitaire'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Solitaire Collection (with ads)'
            Packages = @('Microsoft.MicrosoftSolitaireCollection') }
        @{ Id = 'app.tips'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Tips'
            Packages = @('Microsoft.Getstarted') }
        @{ Id = 'app.feedback-hub'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Feedback Hub'
            Packages = @('Microsoft.WindowsFeedbackHub') }
        @{ Id = 'app.power-automate'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Power Automate'
            Packages = @('Microsoft.PowerAutomateDesktop') }
        @{ Id = 'app.family'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Microsoft Family Safety'
            Packages = @('MicrosoftCorporationII.MicrosoftFamily') }
        @{ Id = 'app.dev-home'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Dev Home (discontinued)'
            Packages = @('Microsoft.Windows.DevHome') }
        @{ Id = 'app.legacy'; Category = 'Microsoft apps'; Level = 'Recommended'; Name = 'Discontinued apps (Mail & Calendar, Movies & TV, Cortana, Skype, Paint 3D, 3D Viewer, ...)'
            Packages = @('microsoft.windowscommunicationsapps', 'Microsoft.ZuneVideo', 'Microsoft.549981C3F5F10', 'Microsoft.SkypeApp',
                'Microsoft.People', 'Microsoft.MSPaint', 'Microsoft.Microsoft3DViewer', 'Microsoft.3DBuilder', 'Microsoft.Print3D',
                'Microsoft.MixedReality.Portal', 'Microsoft.Messaging', 'Microsoft.OneConnect', 'Microsoft.Wallet',
                'Microsoft.Office.Sway', 'Microsoft.MicrosoftPowerBIForWindows', 'Microsoft.NetworkSpeedTest', 'MicrosoftTeams') }
        @{ Id = 'app.outlook'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'Outlook (new)'
            Packages = @('Microsoft.OutlookForWindows') }
        @{ Id = 'app.teams'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'Microsoft Teams'
            Packages = @('MSTeams') }
        @{ Id = 'app.todo'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'Microsoft To Do'
            Packages = @('Microsoft.Todos') }
        @{ Id = 'app.maps'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'Maps'
            Packages = @('Microsoft.WindowsMaps') }
        @{ Id = 'app.sticky-notes'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'Sticky Notes'
            Packages = @('Microsoft.MicrosoftStickyNotes') }
        @{ Id = 'app.onenote-uwp'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'OneNote for Windows 10 (not the Office version)'
            Packages = @('Microsoft.Office.OneNote') }
        @{ Id = 'app.journal'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'Journal and Whiteboard'
            Packages = @('Microsoft.MicrosoftJournal', 'Microsoft.Whiteboard') }
        @{ Id = 'app.phone-link'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'Phone Link'
            Packages = @('Microsoft.YourPhone', 'MicrosoftWindows.CrossDevice') }
        @{ Id = 'app.quick-assist'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'Quick Assist (often abused by tech-support scammers)'
            Packages = @('MicrosoftCorporationII.QuickAssist') }
        @{ Id = 'app.widgets'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'Widgets platform'
            Packages = @('MicrosoftWindows.Client.WebExperience') }
        @{ Id = 'app.sound-recorder'; Category = 'Microsoft apps'; Level = 'Optional'; Name = 'Sound Recorder'
            Packages = @('Microsoft.WindowsSoundRecorder') }
        @{ Id = 'app.clock'; Category = 'Microsoft apps'; Level = 'Optional'; Name = 'Clock (alarms and timers)'
            Packages = @('Microsoft.WindowsAlarms') }
        @{ Id = 'app.get-help'; Category = 'Microsoft apps'; Level = 'Optional'; Name = 'Get Help (Windows troubleshooters use this)'
            Packages = @('Microsoft.GetHelp') }

        # --- Xbox & gaming --------------------------------------------------------------
        @{ Id = 'app.xbox'; Category = 'Xbox & gaming'; Level = 'Aggressive'; Name = 'Xbox app and Game Bar (Game Bar also does screen recording)'
            Packages = @('Microsoft.GamingApp', 'Microsoft.XboxApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxGameOverlay',
                'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Edge.GameAssist') }

        # --- Third-party ----------------------------------------------------------------
        @{ Id = 'app.third-party-games'; Category = 'Third-party apps'; Level = 'Recommended'; Name = 'Preinstalled games and junk (Candy Crush, Disney Magic Kingdoms, ...)'
            Packages = @('king.com.*', '*CandyCrush*', '*BubbleWitch*', '*MarchofEmpires*', '*HiddenCity*', '*FarmVille*',
                '*Asphalt8Airborne*', '*RoyalRevolt*', '*CaesarsSlotsFreeCasino*', '*COOKINGFEVER*', '*DisneyMagicKingdoms*',
                '*EclipseManager*', '*ActiproSoftwareLLC*', '*AdobePhotoshopExpress*', '*Duolingo-LearnLanguagesforFree*',
                '*PandoraMediaInc*', '*Flipboard*', '*Shazam*', '*Wunderlist*', '*Viber*', '*WinZipUniversal*', 'XINGAG.XING',
                '*PicsArt-PhotoStudio*', '*PolarrPhotoEditorAcademicEdition*', '*Sidia.LiveWallpaper*', '*TuneInRadio*',
                '*iHeartRadio*', '*NYTCrossword*', '*OneCalendar*', '*PhototasticCollage*', '*DrawboardPDF*',
                '*CyberLinkMediaSuiteEssentials*', '*AutodeskSketchBook*', '*fitbitcoach*', '*McAfee*') }
        @{ Id = 'app.third-party-media'; Category = 'Third-party apps'; Level = 'Aggressive'; Name = 'Preinstalled streaming/social apps (Spotify, Netflix, Disney+, TikTok, LinkedIn, ...)'
            Packages = @('SpotifyAB.SpotifyMusic', '*Netflix*', 'Disney.37853FC22B2CE', 'AmazonVideo.PrimeVideo', 'Amazon.com.Amazon',
                'Facebook.*', '*Instagram*', 'BytedancePte.Ltd.TikTok', '*Twitter*', '*HULULLC.HULUPLUS*', '*SlingTV*',
                '*LinkedInforWindows*') }

        # --- Not an AppX package ------------------------------------------------------
        @{ Id = 'app.onedrive'; Category = 'Microsoft apps'; Level = 'Aggressive'; Name = 'OneDrive'
            Apply = { Uninstall-OneDrive } }
    ) | Complete-CatalogItem
}

function Uninstall-OneDrive {
    # If Desktop/Documents/Pictures are redirected into OneDrive ("folder backup"), uninstalling
    # would leave cloud-only files unreachable. Refuse and tell the user what to do instead.
    $shellFolders = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue
    foreach ($name in 'Desktop', 'Personal', 'My Pictures') {
        $value = $shellFolders.$name
        if ($value -and $value -match 'OneDrive') {
            throw 'Your Desktop/Documents/Pictures are backed up to OneDrive. Open OneDrive settings > Sync and backup > Manage back up, stop the backup (keep the files on this PC), then run this again.'
        }
    }

    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        & $winget.Source uninstall --id Microsoft.OneDrive --exact --silent --accept-source-agreements --disable-interactivity | Out-Null
        if ($LASTEXITCODE -eq 0) { return }
    }
    $setup = @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $setup) { throw 'OneDrive is not installed, or its uninstaller could not be found.' }
    $p = Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "OneDriveSetup.exe /uninstall exited with code $($p.ExitCode)" }
}
