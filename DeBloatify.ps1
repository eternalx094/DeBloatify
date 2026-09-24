<#
.SYNOPSIS
    Debloat and repair Windows 11: remove ads, Bing, Copilot, telemetry and junk apps,
    and fix common Windows problems. Every setting it changes can be undone.

.DESCRIPTION
    Run without parameters to open the DeBloatify window (-Console for the text menu).
    Use parameters to run unattended.

    Presets are cumulative:
      Minimal      Settings only: ads, Bing search, Copilot/Recall, telemetry, Edge nags.
      Recommended  Minimal + junk/promo apps + more privacy and fixes. The default choice.
      Aggressive   Recommended + Xbox, OneDrive, Phone Link, Outlook, Teams, background apps...

    Use -List to see every tweak, app group and repair with its id.

.PARAMETER Preset
    Minimal, Recommended or Aggressive.
.PARAMETER Include
    Extra tweak/app ids to apply (wildcards and category names work: 'ui.*', 'Interface').
    Without -Preset, only these are applied. With -Undo, limits undo to these tweaks.
.PARAMETER Exclude
    Tweak/app ids to leave out of the preset.
.PARAMETER SkipApps
    Change settings only; don't remove any apps.
.PARAMETER Repair
    Repair ids to run, or 'All'.
.PARAMETER Undo
    Restore the settings DeBloatify changed.
.PARAMETER List
    List all tweaks, apps and repairs.
.PARAMETER DryRun
    Show what would change without changing anything.
.PARAMETER NoRestorePoint
    Don't create a System Restore point first.
.PARAMETER NoRestartExplorer
    Don't restart Explorer at the end.
.PARAMETER Console
    Use the text menu instead of the window.
.PARAMETER Force
    Don't stop when not on Windows 11 or when the restore point fails.

.EXAMPLE
    .\DeBloatify.ps1
    Opens the DeBloatify window.
.EXAMPLE
    .\DeBloatify.ps1 -Console
    Opens the text menu.
.EXAMPLE
    .\DeBloatify.ps1 -Preset Recommended
.EXAMPLE
    .\DeBloatify.ps1 -Preset Recommended -Exclude app.weather -Include ui.classic-context-menu,ui.taskbar-left
.EXAMPLE
    .\DeBloatify.ps1 -Repair repair.system-files,repair.windows-update
.EXAMPLE
    .\DeBloatify.ps1 -Undo -Include edge.*
#>
[CmdletBinding()]
param(
    [ValidateSet('Minimal', 'Recommended', 'Aggressive')][string]$Preset,
    [string[]]$Include,
    [string[]]$Exclude,
    [switch]$SkipApps,
    [string[]]$Repair,
    [switch]$Undo,
    [switch]$List,
    [switch]$DryRun,
    [switch]$NoRestorePoint,
    [switch]$NoRestartExplorer,
    [switch]$Console,
    [switch]$Force,
    [switch]$PauseOnExit
)

$ErrorActionPreference = 'Stop'
$script:Version = '1.0.0'
$boundParameters = $PSBoundParameters

$src = Join-Path $PSScriptRoot 'src'
foreach ($file in 'Core.ps1', 'Backup.ps1', 'Engine.ps1', 'Apps.ps1', 'Repairs.ps1', 'Ui.ps1', 'Gui.ps1') {
    . (Join-Path $src $file)
}

$Include = Split-ListArgument $Include
$Exclude = Split-ListArgument $Exclude
$Repair = Split-ListArgument $Repair

$interactive = -not ($Preset -or $Include -or $Repair -or $Undo -or $List)
$useGui = $interactive -and -not $Console

$tweakCatalog = @(Get-TweakCatalog -Directory (Join-Path $src 'tweaks'))
$appCatalog = @(Get-AppCatalog)
$repairCatalog = @(Get-RepairCatalog)

if ($List) {
    $rows = @($tweakCatalog | ForEach-Object { [pscustomobject]@{ Id = $_.Id; Level = $_.Level; Category = $_.Category; Name = $_.Name } }) +
        @($appCatalog | ForEach-Object { [pscustomobject]@{ Id = $_.Id; Level = $_.Level; Category = "Remove app: $($_.Category)"; Name = $_.Name } }) +
        @($repairCatalog | ForEach-Object { [pscustomobject]@{ Id = $_.Id; Level = '-'; Category = 'Repair'; Name = $_.Name } })
    $rows | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Host
    exit 0
}

# --- Make sure we run as 64-bit Windows PowerShell 5.1, elevated -------------------------
# The AppX and restore point cmdlets are only reliable in Windows PowerShell.

$isWindowsOs = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
if (-not $isWindowsOs) {
    Write-Host 'DeBloatify only runs on Windows.' -ForegroundColor Red
    exit 1
}
$wrongHost = ($PSVersionTable.PSEdition -ne 'Desktop') -or ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess)
$notAdmin = -not (Test-IsAdministrator)
if ($wrongHost -or $notAdmin) {
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        $powershell = Join-Path $env:SystemRoot 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    }
    $arguments = @(ConvertTo-ArgumentList -BoundParameters $boundParameters -ScriptPath $PSCommandPath)
    if ($notAdmin) {
        $elevate = @{ FilePath = $powershell; ArgumentList = $arguments; Verb = 'RunAs' }
        if ($useGui) {
            $elevate.WindowStyle = 'Hidden'   # the window is the whole UI; no console behind it
        } elseif (-not $PauseOnExit) {
            $elevate.ArgumentList += '-PauseOnExit'
        }
        try {
            Start-Process @elevate
            exit 0
        } catch {
            Write-Host 'DeBloatify needs administrator rights, and the UAC prompt was declined.' -ForegroundColor Red
            exit 1
        }
    }
    $child = Start-Process -FilePath $powershell -ArgumentList $arguments -NoNewWindow -Wait -PassThru
    exit $child.ExitCode
}

# --- Setup -----------------------------------------------------------------------------

$dataRoot = Join-Path $env:ProgramData 'DeBloatify'
Initialize-Logging -Directory (Join-Path $dataRoot 'logs')
Initialize-BackupStore -Path (Join-Path $dataRoot 'backup.json')

$exitCode = 0

try {
    $windows = Get-WindowsInfo
    Write-Log ('DeBloatify {0} on Windows build {1} ({2}, {3})' -f $script:Version, $windows.Build, $windows.DisplayVersion, $windows.Edition) Detail

    if (-not $windows.IsWindows11) {
        Write-Log "This PC runs build $($windows.Build). DeBloatify is made for Windows 11 (build 22000 or newer)." Warn
        if (-not $Force) {
            $question = "This PC runs Windows build $($windows.Build). DeBloatify is made for Windows 11 (build 22000 or newer).`n`nContinue anyway?"
            $proceed = if ($useGui) { Show-GuiMessage -Text $question -Kind Warn -YesNo } elseif ($interactive) { Confirm-Choice 'Continue anyway?' } else { $false }
            if (-not $proceed) {
                if (-not $interactive) { Write-Log 'Stopped. Use -Force to run anyway.' Error }
                exit 1
            }
        }
    }

    # Per-user settings go to the signed-in user, even if a different admin account approved UAC.
    $script:TargetUserSid = Get-CurrentUserSid
    $signedIn = Get-InteractiveUser
    if ($signedIn -and $signedIn.Sid -ne $script:TargetUserSid) {
        $script:TargetUserSid = $signedIn.Sid
        Write-Log "Per-user settings will be applied to the signed-in user $($signedIn.Name)." Info
    }

    if ($useGui) {
        try {
            Show-DeBloatifyGui -Context @{
                Tweaks            = $tweakCatalog
                Apps              = $appCatalog
                Repairs           = $repairCatalog
                Root              = $PSScriptRoot
                Windows           = $windows
                NoRestartExplorer = [bool]$NoRestartExplorer
            }
        } catch {
            # The console is hidden in window mode, so errors must be shown in a message box.
            Write-Log "Could not open the window: $($_.Exception.Message)" Error
            Write-Log $_.ScriptStackTrace Detail
            $message = "DeBloatify could not open its window:`n`n{0}`n`nThe text version still works: run Run-DeBloatify.cmd -Console`n`nLog: {1}" -f $_.Exception.Message, $script:LogFile
            Show-GuiMessage -Text $message -Kind Error | Out-Null
            $exitCode = 1
        }
    } elseif ($interactive) {
        Show-MainMenu -Context @{
            Tweaks            = $tweakCatalog
            Apps              = $appCatalog
            Repairs           = $repairCatalog
            NoRestartExplorer = [bool]$NoRestartExplorer
        }
    } elseif ($Undo) {
        $result = Start-UndoRun -TweakIds $Include -DryRun:$DryRun -NoRestartExplorer:$NoRestartExplorer
        if ($result -and $result.Failed -gt 0) { $exitCode = 2 }
    } else {
        if ($Preset -or $Include) {
            $presetName = if ($Preset) { $Preset } else { '' }
            $tweaks = @(Select-CatalogItems -Catalog $tweakCatalog -Preset $presetName -Include $Include -Exclude $Exclude)
            $apps = @()
            if (-not $SkipApps) { $apps = @(Select-CatalogItems -Catalog $appCatalog -Preset $presetName -Include $Include -Exclude $Exclude) }
            $unknown = @($Include | Where-Object {
                    $p = $_
                    -not (@($tweakCatalog + $appCatalog) | Where-Object { Test-IdMatch -Id $_.Id -Category $_.Category -Patterns @($p) })
                })
            foreach ($u in $unknown) { Write-Log "No tweak or app matches '$u' (see -List)." Warn }

            $result = Start-DebloatRun -Tweaks $tweaks -Apps $apps -DryRun:$DryRun -NoRestorePoint:$NoRestorePoint -NoRestartExplorer:$NoRestartExplorer -Force:$Force
            if (-not $result) { $exitCode = 1 } elseif ($result.Failed -gt 0) { $exitCode = 2 }
        }
        if ($Repair) {
            $repairs = if ($Repair -contains 'All') { $repairCatalog } else { @(Select-CatalogItems -Catalog $repairCatalog -Include $Repair) }
            if ($repairs.Count -eq 0) {
                Write-Log 'No repair matches that id (see -List).' Warn
                $exitCode = 1
            } elseif ($DryRun) {
                foreach ($r in $repairs) { Write-Log "would run: $($r.Name)" Info }
            } elseif (Invoke-Repairs -Repairs $repairs) {
                Write-Log 'Restart your PC to finish the repairs.' Warn
            }
        }
    }
} catch {
    Write-Log "Unexpected error: $($_.Exception.Message)" Error
    Write-Log $_.ScriptStackTrace Detail
    if ($useGui) {
        try { Show-GuiMessage -Text ("DeBloatify stopped with an error:`n`n{0}`n`nLog: {1}" -f $_.Exception.Message, $script:LogFile) -Kind Error | Out-Null } catch { }
    }
    $exitCode = 1
} finally {
    if ($PauseOnExit -and -not $interactive) {
        Write-Host ''
        [void](Read-Host '  Press Enter to close')
    }
}
exit $exitCode
