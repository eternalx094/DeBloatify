# Console UI: menus, pickers, plans and summaries, plus the run orchestration
# shared by the interactive menu and the command line.

function Show-Banner {
    param([string]$Subtitle)
    Clear-Host
    Write-Host ''
    Write-Host '  DeBloatify' -ForegroundColor Cyan -NoNewline
    Write-Host ("  v{0}  -  debloat and repair Windows 11" -f $script:Version) -ForegroundColor DarkGray
    Write-Host ('  ' + ('-' * 64)) -ForegroundColor DarkGray
    if ($Subtitle) { Write-Host "  $Subtitle" -ForegroundColor White; Write-Host '' }
}

function Write-MenuItem {
    param([string]$Key, [string]$Title, [string]$Text)
    Write-Host ('  [{0}] ' -f $Key) -ForegroundColor Cyan -NoNewline
    Write-Host ('{0,-14}' -f $Title) -ForegroundColor White -NoNewline
    Write-Host $Text -ForegroundColor Gray
}

function Confirm-Choice {
    param([Parameter(Mandatory)][string]$Prompt)
    $answer = Read-Host "  $Prompt [Y/N]"
    $answer -match '^\s*(y|yes)\s*$'
}

function Wait-ForEnter {
    Write-Host ''
    [void](Read-Host '  Press Enter to continue')
}

function Select-FromList {
    # Checkbox-style picker. Returns @{ Cancelled = $bool; Items = @(...) }.
    param([Parameter(Mandatory)][object[]]$Items, [Parameter(Mandatory)][string]$Title, [string[]]$Preselected)
    $selected = @{}
    foreach ($item in $Items) { $selected[$item.Id] = ($Preselected -contains $item.Id) }
    while ($true) {
        Show-Banner -Subtitle $Title
        $n = 0
        $lastCategory = $null
        foreach ($item in $Items) {
            $n++
            if ($item.Category -ne $lastCategory) {
                if ($lastCategory) { Write-Host '' }
                Write-Host ('  {0}' -f $item.Category) -ForegroundColor Cyan
                $lastCategory = $item.Category
            }
            $on = $selected[$item.Id]
            $mark = if ($on) { 'x' } else { ' ' }
            $color = if ($on) { 'White' } else { 'Gray' }
            Write-Host ('  {0,3}. [{1}] {2}' -f $n, $mark, $item.Name) -ForegroundColor $color -NoNewline
            Write-Host ('  {0}' -f $item.Level) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host '  Type numbers to toggle (e.g. 3 or 1,4,7-9).  A = all  N = none  ?3 = explain item 3' -ForegroundColor Gray
        Write-Host '  Enter = continue   B = back' -ForegroundColor Gray
        $in = (Read-Host '  >').Trim()
        if ($in -eq '') {
            return @{ Cancelled = $false; Items = @($Items | Where-Object { $selected[$_.Id] }) }
        } elseif ($in -match '^[bB]$') {
            return @{ Cancelled = $true; Items = @() }
        } elseif ($in -match '^[aA]$') {
            foreach ($item in $Items) { $selected[$item.Id] = $true }
        } elseif ($in -match '^[nN]$') {
            foreach ($item in $Items) { $selected[$item.Id] = $false }
        } elseif ($in -match '^\?\s*(\d+)$') {
            $i = [int]$Matches[1]
            if ($i -ge 1 -and $i -le $Items.Count) { Show-ItemDetails -Item $Items[$i - 1] }
        } else {
            foreach ($i in @(ConvertFrom-RangeText -Text $in -Max $Items.Count)) {
                $id = $Items[$i - 1].Id
                $selected[$id] = -not $selected[$id]
            }
        }
    }
}

function Show-ItemDetails {
    param([Parameter(Mandatory)]$Item)
    Write-Host ''
    Write-Host ('  {0}  ({1}, {2})' -f $Item.Name, $Item.Id, $Item.Level) -ForegroundColor White
    if ($Item.Description) { Write-Host ('  {0}' -f $Item.Description) -ForegroundColor Gray }
    if ($Item.Packages) { Write-Host ('  Packages: {0}' -f ($Item.Packages -join ', ')) -ForegroundColor DarkGray }
    Wait-ForEnter
}

function Show-Plan {
    param([string]$Title, [object[]]$Tweaks, [object[]]$Apps)
    Show-Banner -Subtitle $Title
    $tweaks = @($Tweaks | Where-Object { $_ })
    $apps = @($Apps | Where-Object { $_ })
    if ($tweaks.Count -gt 0) {
        Write-Host ('  Settings to change ({0}):' -f $tweaks.Count) -ForegroundColor White
        foreach ($group in ($tweaks | Group-Object { $_.Category })) {
            Write-Host ('    {0}' -f $group.Name) -ForegroundColor Cyan
            foreach ($t in $group.Group) { Write-Host ('      - {0}' -f $t.Name) -ForegroundColor Gray }
        }
    }
    if ($apps.Count -gt 0) {
        Write-Host ''
        Write-Host ('  Apps to remove ({0}):' -f $apps.Count) -ForegroundColor White
        foreach ($a in $apps) { Write-Host ('      - {0}' -f $a.Name) -ForegroundColor Gray }
    }
    Write-Host ''
}

function Show-Summary {
    param([Parameter(Mandatory)]$Result, [switch]$DryRun, [string]$Action = 'Done')
    Write-Host ''
    Write-Host ('  ' + ('-' * 64)) -ForegroundColor DarkGray
    if ($DryRun) {
        Write-Log ('Preview only - nothing was changed. {0} change(s) would be made, {1} already in place.' -f $Result.Changed, $Result.Unchanged) Ok
    } else {
        $msg = '{0}. {1} changed, {2} already set, {3} not present, {4} failed.' -f $Action, $Result.Changed, $Result.Unchanged, $Result.Skipped, $Result.Failed
        $level = if ($Result.Failed -gt 0) { 'Warn' } else { 'Ok' }
        Write-Log $msg $level
        if ($Result.Changed -gt 0) { Write-Log 'Restart your PC so every change takes effect.' Info }
    }
    if ($script:LogFile) { Write-Log "Log: $script:LogFile" Detail }
    if (-not $DryRun -and $Action -eq 'Done' -and $Result.Changed -gt 0) {
        Write-Log 'To undo: run DeBloatify again and pick Undo (or: DeBloatify.ps1 -Undo).' Detail
    }
}

function Start-DebloatRun {
    param(
        [object[]]$Tweaks,
        [object[]]$Apps,
        [switch]$DryRun,
        [switch]$NoRestorePoint,
        [switch]$NoRestartExplorer,
        [switch]$Force,
        [switch]$Interactive
    )
    $tweaks = @($Tweaks | Where-Object { $_ })
    $apps = @($Apps | Where-Object { $_ })
    if ($tweaks.Count + $apps.Count -eq 0) {
        Write-Log 'Nothing selected.' Warn
        return $null
    }

    if (-not $DryRun -and -not $NoRestorePoint) {
        Write-Log 'Creating a restore point' Step
        if (-not (New-SafetyRestorePoint)) {
            $proceed = $Force
            if ($Interactive -and -not $Force) {
                $proceed = Confirm-Choice "Continue without a restore point? DeBloatify's own Undo still works for settings."
            } elseif (-not $Force) {
                Write-Log 'Stopped. Use -Force to continue without a restore point, or -NoRestorePoint to skip it.' Error
            }
            if (-not $proceed) { return $null }
        }
    }

    $result = Invoke-Tweaks -Tweaks $tweaks -DryRun:$DryRun
    Merge-RunResult -Total $result -Part (Invoke-AppRemoval -Apps $apps -DryRun:$DryRun)

    if (-not $DryRun -and $result.RestartExplorer -and -not $NoRestartExplorer) { Restart-Explorer }
    Show-Summary -Result $result -DryRun:$DryRun
    $result
}

function Start-UndoRun {
    param([string[]]$TweakIds, [switch]$DryRun, [switch]$NoRestartExplorer)
    if ((Get-BackupCount) -eq 0) {
        Write-Log 'Nothing to undo - DeBloatify has no recorded changes on this PC.' Info
        return $null
    }
    Write-Log 'Undoing changes' Step
    $result = Invoke-Undo -TweakIds $TweakIds -DryRun:$DryRun
    if (-not $DryRun -and $result.RestartExplorer -and -not $NoRestartExplorer) { Restart-Explorer }
    Show-Summary -Result $result -DryRun:$DryRun -Action 'Undo finished'
    Write-Log 'Removed apps are not restored by Undo - reinstall them from the Microsoft Store, or use System Restore.' Detail
    $result
}

function Request-Restart {
    if (Confirm-Choice 'Restart the PC now?') { Restart-Computer -Force }
}

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------

function Show-MainMenu {
    param([Parameter(Mandatory)][hashtable]$Context)
    while ($true) {
        Show-Banner
        Write-MenuItem '1' 'Recommended' 'Removes ads, Bing, Copilot, telemetry and junk apps. Best for most people.'
        Write-MenuItem '2' 'Minimal' 'Settings only (ads, Bing, Copilot, telemetry). Removes no apps.'
        Write-MenuItem '3' 'Aggressive' 'Recommended + Xbox, OneDrive, Phone Link, Outlook, Teams and more.'
        Write-MenuItem '4' 'Custom' 'Choose exactly which settings and apps.'
        Write-Host ''
        Write-MenuItem '5' 'Repair' 'Fix Windows Update, Start menu, search, network, corrupted files...'
        Write-MenuItem '6' 'Undo' 'Put back settings DeBloatify changed.'
        Write-MenuItem '7' 'Preview' 'See what a preset would change, without changing anything.'
        Write-Host ''
        Write-MenuItem 'Q' 'Quit' ''
        Write-Host ''
        $choice = (Read-Host '  Choose').Trim().ToUpper()
        switch ($choice) {
            '1' { Invoke-PresetMenu -Context $Context -Preset 'Recommended' }
            '2' { Invoke-PresetMenu -Context $Context -Preset 'Minimal' }
            '3' { Invoke-PresetMenu -Context $Context -Preset 'Aggressive' }
            '4' { Invoke-CustomMenu -Context $Context }
            '5' { Invoke-RepairMenu -Context $Context }
            '6' { Invoke-UndoMenu -Context $Context }
            '7' { Invoke-PreviewMenu -Context $Context }
            'Q' { return }
        }
    }
}

function Invoke-SelectionRun {
    param([hashtable]$Context, [string]$Title, [object[]]$Tweaks, [object[]]$Apps)
    Show-Plan -Title $Title -Tweaks $Tweaks -Apps $Apps
    if (-not (Confirm-Choice 'Apply these changes? A restore point is created first.')) { return }
    Write-Host ''
    $result = Start-DebloatRun -Tweaks $Tweaks -Apps $Apps -Interactive -NoRestartExplorer:$Context.NoRestartExplorer
    Write-Host ''
    if ($result -and $result.Changed -gt 0) { Request-Restart } else { Wait-ForEnter }
}

function Invoke-PresetMenu {
    param([hashtable]$Context, [string]$Preset)
    $tweaks = @(Select-CatalogItems -Catalog $Context.Tweaks -Preset $Preset)
    $apps = @(Select-CatalogItems -Catalog $Context.Apps -Preset $Preset)
    Invoke-SelectionRun -Context $Context -Title "$Preset preset" -Tweaks $tweaks -Apps $apps
}

function Invoke-CustomMenu {
    param([hashtable]$Context)
    $recommendedTweaks = @(Select-CatalogItems -Catalog $Context.Tweaks -Preset 'Recommended' | ForEach-Object { $_.Id })
    $pickTweaks = Select-FromList -Items $Context.Tweaks -Title 'Custom (1/2): settings to change' -Preselected $recommendedTweaks
    if ($pickTweaks.Cancelled) { return }
    $recommendedApps = @(Select-CatalogItems -Catalog $Context.Apps -Preset 'Recommended' | ForEach-Object { $_.Id })
    $pickApps = Select-FromList -Items $Context.Apps -Title 'Custom (2/2): apps to remove' -Preselected $recommendedApps
    if ($pickApps.Cancelled) { return }
    Invoke-SelectionRun -Context $Context -Title 'Custom selection' -Tweaks $pickTweaks.Items -Apps $pickApps.Items
}

function Invoke-PreviewMenu {
    param([hashtable]$Context)
    Show-Banner -Subtitle 'Preview (nothing will be changed)'
    Write-MenuItem '1' 'Recommended' ''
    Write-MenuItem '2' 'Minimal' ''
    Write-MenuItem '3' 'Aggressive' ''
    Write-Host ''
    $preset = switch ((Read-Host '  Preview which preset').Trim()) { '1' { 'Recommended' } '2' { 'Minimal' } '3' { 'Aggressive' } default { $null } }
    if (-not $preset) { return }
    Write-Host ''
    $tweaks = @(Select-CatalogItems -Catalog $Context.Tweaks -Preset $preset)
    $apps = @(Select-CatalogItems -Catalog $Context.Apps -Preset $preset)
    [void](Start-DebloatRun -Tweaks $tweaks -Apps $apps -DryRun)
    Wait-ForEnter
}

function Invoke-RepairMenu {
    param([hashtable]$Context)
    $repairs = @($Context.Repairs)
    while ($true) {
        Show-Banner -Subtitle 'Repair tools'
        for ($i = 0; $i -lt $repairs.Count; $i++) {
            Write-Host ('  {0,3}. {1}' -f ($i + 1), $repairs[$i].Name) -ForegroundColor White
            Write-Host ('       {0}' -f $repairs[$i].Description) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host '  Type the numbers to run (e.g. 1 or 2,4-6). Enter = back' -ForegroundColor Gray
        $in = (Read-Host '  >').Trim()
        if ($in -eq '') { return }
        $picked = @(ConvertFrom-RangeText -Text $in -Max $repairs.Count | ForEach-Object { $repairs[$_ - 1] })
        if ($picked.Count -eq 0) { continue }
        Write-Host ''
        foreach ($r in $picked) { Write-Host ('    - {0}' -f $r.Name) -ForegroundColor Gray }
        if (-not (Confirm-Choice 'Run these repairs?')) { continue }
        Write-Host ''
        $reboot = Invoke-Repairs -Repairs $picked
        Write-Host ''
        if ($reboot) {
            Write-Log 'A restart is needed to finish these repairs.' Warn
            Request-Restart
        } else {
            Wait-ForEnter
        }
    }
}

function Invoke-UndoMenu {
    param([hashtable]$Context)
    Show-Banner -Subtitle 'Undo'
    $ids = @(Get-BackedUpTweakIds)
    if ($ids.Count -eq 0) {
        Write-Log 'Nothing to undo - DeBloatify has no recorded changes on this PC.' Info
        Write-Log 'Removed apps can be reinstalled from the Microsoft Store. For a full rollback use System Restore.' Detail
        Write-Host ''
        if (Confirm-Choice 'Open System Restore?') { Start-Process rstrui.exe }
        return
    }
    Write-Host ('  DeBloatify has recorded {0} change(s) from {1} tweak(s).' -f (Get-BackupCount), $ids.Count) -ForegroundColor White
    Write-Host ''
    Write-MenuItem 'A' 'Undo all' 'Restore every recorded setting.'
    Write-MenuItem 'S' 'Select' 'Choose which tweaks to undo.'
    Write-MenuItem 'R' 'System Restore' 'Open System Restore to roll back to the restore point.'
    Write-MenuItem 'B' 'Back' ''
    Write-Host ''
    switch ((Read-Host '  Choose').Trim().ToUpper()) {
        'A' {
            if (Confirm-Choice 'Undo all recorded changes?') {
                Write-Host ''
                [void](Start-UndoRun -NoRestartExplorer:$Context.NoRestartExplorer)
                Wait-ForEnter
            }
        }
        'S' {
            $items = foreach ($id in $ids) {
                $t = $Context.Tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
                if ($t) { $t } else { Complete-CatalogItem @{ Id = $id; Name = $id; Category = 'Other'; Level = '' } }
            }
            $pick = Select-FromList -Items @($items) -Title 'Undo: choose tweaks to revert'
            if ($pick.Cancelled -or $pick.Items.Count -eq 0) { return }
            Write-Host ''
            [void](Start-UndoRun -TweakIds @($pick.Items | ForEach-Object { $_.Id }) -NoRestartExplorer:$Context.NoRestartExplorer)
            Wait-ForEnter
        }
        'R' { Start-Process rstrui.exe }
    }
}
