# Engine: loads the tweak and app catalogs, selects items for a preset, applies
# them while recording backups, and undoes them again.

$script:LevelRank = @{ Minimal = 1; Recommended = 2; Aggressive = 3; Optional = 99 }
$script:TargetUserSid = $null   # SID whose hive receives HKCU changes (set at startup)

# Compact constructor used by the tweak definition files.
function Reg {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Path,
        [Parameter(Mandatory, Position = 1)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory, Position = 2)][AllowEmptyString()]$Value,
        [Parameter(Position = 3)][ValidateSet('DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary')][string]$Type = 'DWord'
    )
    @{ Path = $Path; Name = $Name; Value = $Value; Type = $Type }
}

function Complete-CatalogItem {
    # Gives every catalog entry the same keys, so callers never have to check which ones exist.
    param([Parameter(Mandatory, ValueFromPipeline)][hashtable]$Item)
    process {
        foreach ($key in 'Category', 'Level', 'Description', 'Registry', 'Services', 'Tasks', 'Apply', 'Restart', 'Packages', 'Reboot', 'Action') {
            if (-not $Item.ContainsKey($key)) { $Item[$key] = $null }
        }
        $Item
    }
}

function Get-TweakCatalog {
    param([Parameter(Mandatory)][string]$Directory)
    $all = @()
    foreach ($file in Get-ChildItem -LiteralPath $Directory -Filter '*.ps1' | Sort-Object Name) {
        $all += @(& $file.FullName | Complete-CatalogItem)
    }
    $all
}

function Select-CatalogItems {
    # Presets are cumulative: Recommended includes Minimal, Aggressive includes both.
    # 'Optional' items are never part of a preset; they are only added with -Include.
    param(
        [Parameter(Mandatory)][object[]]$Catalog,
        [string]$Preset = '',   # '', Minimal, Recommended or Aggressive
        [string[]]$Include,
        [string[]]$Exclude
    )
    foreach ($item in $Catalog) {
        $selected = $false
        if ($Preset -and $script:LevelRank[$item.Level] -le $script:LevelRank[$Preset]) { $selected = $true }
        if (Test-IdMatch -Id $item.Id -Category $item.Category -Patterns $Include) { $selected = $true }
        if (Test-IdMatch -Id $item.Id -Category $item.Category -Patterns $Exclude) { $selected = $false }
        if ($selected) { $item }
    }
}

function Get-MissingRegistryKeys {
    # Returns the keys along $Path that do not exist yet, deepest first.
    param([Parameter(Mandatory)][string]$Path, [string]$Sid)
    $current = $Path.TrimEnd('\')
    while ($current -match '^HK(LM|CU):\\.+' -and -not (Test-RegistryKey -Path $current -Sid $Sid)) {
        $current
        $current = $current.Substring(0, $current.LastIndexOf('\'))
    }
}

function Get-ItemSid {
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -like 'HKCU:*') { return $script:TargetUserSid }
    $null
}

function Invoke-RegistryChange {
    param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)][hashtable]$Item, [switch]$DryRun)
    $sid = Get-ItemSid -Path $Item.Path
    $state = Get-RegistryValueState -Path $Item.Path -Name $Item.Name -Sid $sid
    $desired = ConvertTo-RegistryData -Type $Item.Type -Value $Item.Value
    if ($state.Exists -and $state.Type -eq $Item.Type -and (Test-RegistryDataEqual $state.Value $desired)) {
        return 'Unchanged'
    }
    $label = if ($Item.Name) { $Item.Name } else { '(default)' }
    if ($DryRun) {
        Write-Log ('would set {0}\{1} = {2}' -f $Item.Path, $label, ($Item.Value -join ',')) Detail
        return 'Changed'
    }
    $created = @(Get-MissingRegistryKeys -Path $Item.Path -Sid $sid)
    Add-RegistryBackup -TweakId $TweakId -Path $Item.Path -Name $Item.Name -Sid $sid -State $state
    foreach ($key in $created) { Add-CreatedKeyBackup -TweakId $TweakId -Path $key -Sid $sid }
    Set-RegistryValueRaw -Path $Item.Path -Name $Item.Name -Type $Item.Type -Value $Item.Value -Sid $sid
    Write-Log ('set {0}\{1} = {2}' -f $Item.Path, $label, ($Item.Value -join ',')) Detail
    'Changed'
}

function Invoke-ServiceChange {
    param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)][hashtable]$Item, [switch]$DryRun)
    $target = @{ Automatic = 2; Manual = 3; Disabled = 4 }[$Item.StartupType]
    $state = Get-ServiceStartState -Name $Item.Name
    if (-not $state.Exists) { return 'Skipped' }
    if ($state.Start -eq $target -and -not ($target -eq 2 -and $state.Delayed)) { return 'Unchanged' }
    if ($DryRun) {
        Write-Log ('would set service {0} to {1}' -f $Item.Name, $Item.StartupType) Detail
        return 'Changed'
    }
    Add-ServiceBackup -TweakId $TweakId -Name $Item.Name -State $state
    # Keep the delayed-start flag on manual/disabled services, as Windows itself does.
    Set-ServiceStartState -Name $Item.Name -Start $target -Delayed (($target -ne 2) -and $state.Delayed)
    Write-Log ('service {0} -> {1}' -f $Item.Name, $Item.StartupType) Detail
    'Changed'
}

function Invoke-TaskChange {
    param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)][string]$TaskPath, [switch]$DryRun)
    $state = Get-TaskEnabledState -TaskPath $TaskPath
    if (-not $state.Exists) { return 'Skipped' }
    if (-not $state.Enabled) { return 'Unchanged' }
    if ($DryRun) {
        Write-Log "would disable task $TaskPath" Detail
        return 'Changed'
    }
    Add-TaskBackup -TweakId $TweakId -TaskPath $TaskPath
    Set-TaskEnabledState -TaskPath $TaskPath -Enabled $false
    Write-Log "disabled task $TaskPath" Detail
    'Changed'
}

function New-RunResult {
    [pscustomobject]@{ Changed = 0; Unchanged = 0; Skipped = 0; Failed = 0; RestartExplorer = $false; Reboot = $false; Errors = @() }
}

function Invoke-Tweak {
    param([Parameter(Mandatory)][hashtable]$Tweak, [switch]$DryRun)
    $r = New-RunResult
    $steps = @()
    foreach ($i in @($Tweak.Registry)) { if ($i) { $steps += , @('Registry', $i) } }
    foreach ($i in @($Tweak.Services)) { if ($i) { $steps += , @('Service', $i) } }
    foreach ($i in @($Tweak.Tasks)) { if ($i) { $steps += , @('Task', $i) } }

    foreach ($step in $steps) {
        try {
            $outcome = switch ($step[0]) {
                'Registry' { Invoke-RegistryChange -TweakId $Tweak.Id -Item $step[1] -DryRun:$DryRun }
                'Service' { Invoke-ServiceChange -TweakId $Tweak.Id -Item $step[1] -DryRun:$DryRun }
                'Task' { Invoke-TaskChange -TweakId $Tweak.Id -TaskPath $step[1] -DryRun:$DryRun }
            }
            $r.$outcome++
        } catch {
            $r.Failed++
            $r.Errors += $_.Exception.Message
        }
    }

    if ($Tweak.Apply) {
        if ($DryRun) {
            Write-Log 'would run custom action' Detail
            $r.Changed++
        } else {
            try { & $Tweak.Apply | Out-Null; $r.Changed++ } catch { $r.Failed++; $r.Errors += $_.Exception.Message }
        }
    }

    if (-not $DryRun) { Save-BackupStore }
    if ($r.Changed -gt 0) {
        if ($Tweak.Restart -eq 'Explorer') { $r.RestartExplorer = $true }
        if ($Tweak.Restart -eq 'Reboot') { $r.Reboot = $true }
    }
    $r
}

function Merge-RunResult {
    param($Total, $Part)
    foreach ($p in 'Changed', 'Unchanged', 'Skipped', 'Failed') { $Total.$p += $Part.$p }
    $Total.RestartExplorer = $Total.RestartExplorer -or $Part.RestartExplorer
    $Total.Reboot = $Total.Reboot -or $Part.Reboot
    $Total.Errors += $Part.Errors
}

function Invoke-Tweaks {
    param([object[]]$Tweaks, [switch]$DryRun)
    $total = New-RunResult
    $category = $null
    foreach ($t in @($Tweaks)) {
        if (-not $t) { continue }
        if ($t.Category -ne $category) {
            $category = $t.Category
            Write-Log $category Step
        }
        $r = Invoke-Tweak -Tweak $t -DryRun:$DryRun
        Merge-RunResult -Total $total -Part $r
        if ($r.Failed -gt 0) {
            Write-Log ('{0} ({1} of {2} changes failed)' -f $t.Name, $r.Failed, ($r.Failed + $r.Changed)) Warn
            foreach ($e in $r.Errors) { Write-Log "  $e" Detail }
        } elseif ($r.Changed -gt 0) {
            $verb = if ($DryRun) { 'will apply' } else { 'applied' }
            Write-Log ('{0} ({1})' -f $t.Name, $verb) Ok
        } elseif ($r.Unchanged -eq 0 -and $r.Skipped -gt 0) {
            Write-Log ('{0} (not present on this PC)' -f $t.Name) Info
        } else {
            Write-Log ('{0} (already set)' -f $t.Name) Info
        }
    }
    $total
}

# ---------------------------------------------------------------------------
# Apps
# ---------------------------------------------------------------------------

$script:ProtectedPackages = @(
    'Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp', 'Microsoft.DesktopAppInstaller', 'Microsoft.Winget.*',
    'Microsoft.SecHealthUI', 'Microsoft.VCLibs*', 'Microsoft.UI.Xaml*', 'Microsoft.NET.*', 'Microsoft.WindowsAppRuntime*',
    'Microsoft.Services.Store.Engagement', 'Microsoft.Windows.ShellExperienceHost', 'Microsoft.Windows.StartMenuExperienceHost',
    'MicrosoftWindows.Client.CBS', 'MicrosoftWindows.Client.Core', 'Microsoft.AAD.BrokerPlugin', 'Microsoft.AccountsControl',
    'Microsoft.Windows.CloudExperienceHost', 'Microsoft.Windows.Search', 'Microsoft.Xbox.TCUI', 'Microsoft.XboxIdentityProvider',
    'Microsoft.WindowsNotepad', 'Microsoft.WindowsCalculator', 'Microsoft.Windows.Photos', 'Microsoft.Paint',
    'Microsoft.ScreenSketch', 'Microsoft.WindowsTerminal', 'Microsoft.*Extension*', 'Microsoft.LanguageExperiencePack*'
)

function Test-ProtectedPackage {
    param([Parameter(Mandatory)][string]$Name)
    foreach ($p in $script:ProtectedPackages) { if ($Name -like $p) { return $true } }
    $false
}

function Invoke-AppRemoval {
    param([object[]]$Apps, [switch]$DryRun)
    $total = New-RunResult
    $apps = @($Apps | Where-Object { $_ })
    if ($apps.Count -eq 0) { return $total }

    Write-Log 'Apps' Step
    Write-Log 'Reading installed packages (this can take a moment)...' Detail
    $installed = @(Get-InstalledAppxPackages)
    $provisioned = @(Get-ProvisionedAppxPackages)

    foreach ($app in $apps) {
        if ($app.Apply) {
            if ($DryRun) {
                Write-Log ('{0} (will remove)' -f $app.Name) Ok
                $total.Changed++
                continue
            }
            try {
                & $app.Apply | Out-Null
                Write-Log ('{0} (removed)' -f $app.Name) Ok
                $total.Changed++
            } catch {
                Write-Log ('{0}: {1}' -f $app.Name, $_.Exception.Message) Warn
                $total.Failed++
                $total.Errors += $_.Exception.Message
            }
            continue
        }

        $pkgs = @($installed | Where-Object {
                $n = $_.Name
                (@($app.Packages | Where-Object { $n -like $_ }).Count -gt 0) -and
                -not $_.IsFramework -and -not $_.NonRemovable -and -not (Test-ProtectedPackage -Name $n)
            })
        $prov = @($provisioned | Where-Object {
                $n = $_.DisplayName
                (@($app.Packages | Where-Object { $n -like $_ }).Count -gt 0) -and -not (Test-ProtectedPackage -Name $n)
            })

        if ($pkgs.Count -eq 0 -and $prov.Count -eq 0) {
            Write-Log ('{0} (not installed)' -f $app.Name) Info
            $total.Unchanged++
            continue
        }
        if ($DryRun) {
            $names = @($pkgs | ForEach-Object { $_.Name }) + @($prov | ForEach-Object { $_.DisplayName }) | Sort-Object -Unique
            Write-Log ('{0} (will remove: {1})' -f $app.Name, ($names -join ', ')) Ok
            $total.Changed++
            continue
        }

        $failed = @()
        foreach ($p in $pkgs) {
            try { Remove-InstalledAppx -PackageFullName $p.PackageFullName; Write-Log "removed $($p.PackageFullName)" Detail }
            catch { $failed += "$($p.Name): $($_.Exception.Message)" }
        }
        # Deprovisioning stops Windows from reinstalling the app for new user accounts.
        foreach ($p in $prov) {
            try { Remove-ProvisionedAppx -PackageName $p.PackageName; Write-Log "deprovisioned $($p.PackageName)" Detail }
            catch { $failed += "$($p.DisplayName) (provisioned): $($_.Exception.Message)" }
        }
        if ($failed.Count -gt 0) {
            Write-Log ('{0} (partly removed)' -f $app.Name) Warn
            foreach ($f in $failed) { Write-Log "  $f" Detail }
            $total.Failed++
            $total.Errors += $failed
        } else {
            Write-Log ('{0} (removed)' -f $app.Name) Ok
            $total.Changed++
        }
    }
    $total
}

# ---------------------------------------------------------------------------
# Undo
# ---------------------------------------------------------------------------

function Invoke-Undo {
    # Restores everything recorded in the backup store, optionally limited to some tweak ids.
    param([string[]]$TweakIds, [switch]$DryRun)
    $total = New-RunResult
    $currentSid = Get-CurrentUserSid
    $wanted = {
        param($entry)
        (-not $TweakIds) -or (Test-IdMatch -Id ([string]$entry.TweakId) -Patterns $TweakIds)
    }

    # Registry values, newest first.
    $entries = @($script:Backup.Registry | Where-Object { & $wanted $_ })
    [array]::Reverse($entries)
    foreach ($e in $entries) {
        $label = if ($e.Name) { $e.Name } else { '(default)' }
        if ($e.Sid -and $e.Sid -ne $currentSid -and -not (Test-RegistryKey -Path 'HKCU:\Software' -Sid $e.Sid)) {
            Write-Log "skipped $($e.Path)\$label - it belongs to another user who is not signed in" Warn
            $total.Skipped++
            continue
        }
        $action = if ($e.Existed) { "restore $($e.Path)\$label" } else { "remove $($e.Path)\$label" }
        if ($DryRun) { Write-Log "would $action" Detail; $total.Changed++; continue }
        try {
            if ($e.Existed) {
                Set-RegistryValueRaw -Path $e.Path -Name $e.Name -Type $e.Type -Value $e.Value -Sid $e.Sid
            } else {
                Remove-RegistryValueRaw -Path $e.Path -Name $e.Name -Sid $e.Sid
            }
            [void]$script:Backup.Registry.Remove($e)
            Write-Log $action Detail
            $total.Changed++
        } catch {
            Write-Log "could not $action`: $($_.Exception.Message)" Warn
            $total.Failed++
        }
    }

    # Keys DeBloatify created, deepest first, removed only if now empty.
    $keys = @($script:Backup.CreatedKeys | Where-Object { & $wanted $_ } |
            Sort-Object -Property @{ Expression = { ($_.Path -split '\\').Count }; Descending = $true })
    foreach ($k in $keys) {
        if ($DryRun) { continue }
        try {
            if (-not $k.Sid -or $k.Sid -eq $currentSid -or (Test-RegistryKey -Path 'HKCU:\Software' -Sid $k.Sid)) {
                if (Remove-RegistryKeyIfEmpty -Path $k.Path -Sid $k.Sid) { Write-Log "removed key $($k.Path)" Detail }
                [void]$script:Backup.CreatedKeys.Remove($k)
            }
        } catch {
            Write-Log "could not remove key $($k.Path): $($_.Exception.Message)" Detail
        }
    }

    foreach ($s in @($script:Backup.Services | Where-Object { & $wanted $_ })) {
        if ($DryRun) { Write-Log "would restore service $($s.Name)" Detail; $total.Changed++; continue }
        try {
            Set-ServiceStartState -Name $s.Name -Start ([int]$s.Start) -Delayed ([bool]$s.Delayed)
            [void]$script:Backup.Services.Remove($s)
            Write-Log "restored service $($s.Name)" Detail
            $total.Changed++
        } catch {
            Write-Log "could not restore service $($s.Name): $($_.Exception.Message)" Warn
            $total.Failed++
        }
    }

    foreach ($t in @($script:Backup.Tasks | Where-Object { & $wanted $_ })) {
        if ($DryRun) { Write-Log "would re-enable task $($t.Path)" Detail; $total.Changed++; continue }
        try {
            Set-TaskEnabledState -TaskPath $t.Path -Enabled $true
            [void]$script:Backup.Tasks.Remove($t)
            Write-Log "re-enabled task $($t.Path)" Detail
            $total.Changed++
        } catch {
            Write-Log "could not re-enable task $($t.Path): $($_.Exception.Message)" Warn
            $total.Failed++
        }
    }

    if (-not $DryRun) { Save-BackupStore }
    if ($total.Changed -gt 0) { $total.RestartExplorer = $true }
    $total
}

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

function Restart-Explorer {
    Write-Log 'Restarting Explorer so the changes show up...' Info
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

function New-SafetyRestorePoint {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $name = 'SystemRestorePointCreationFrequency'
    $original = $null
    try {
        # Windows silently skips restore points if one was made in the last 24 hours; lift that for this call.
        $original = Get-RegistryValueState -Path $key -Name $name
        Set-RegistryValueRaw -Path $key -Name $name -Type 'DWord' -Value 0
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description ('DeBloatify {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm')) -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log 'Restore point created' Ok
        $true
    } catch {
        Write-Log "Could not create a restore point: $($_.Exception.Message)" Warn
        $false
    } finally {
        try {
            if ($original -and $original.Exists) {
                Set-RegistryValueRaw -Path $key -Name $name -Type $original.Type -Value $original.Value
            } else {
                Remove-RegistryValueRaw -Path $key -Name $name
            }
        } catch { }
    }
}
