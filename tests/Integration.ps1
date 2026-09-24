# Integration test for disposable Windows CI runners. It REALLY applies every tweak
# through DeBloatify.ps1, undoes them again, and checks that every registry value,
# registry key, service and scheduled task is back to its original state.
#
# Do not run this on your own PC - use tests\Run-Tests.ps1 instead.

$ErrorActionPreference = 'Stop'
if ($env:CI -ne 'true') { throw 'Integration.ps1 changes system settings and only runs on CI (set CI=true to override).' }

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'src'
foreach ($file in 'Core.ps1', 'Backup.ps1', 'Engine.ps1', 'Apps.ps1') { . (Join-Path $src $file) }
$entryScript = Join-Path $root 'DeBloatify.ps1'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$tweaks = @(Select-CatalogItems -Catalog (Get-TweakCatalog -Directory (Join-Path $src 'tweaks')) -Preset 'Aggressive' -Include '*')
$sid = Get-CurrentUserSid
$failures = New-Object System.Collections.ArrayList

function Get-Sid([string]$Path) { if ($Path -like 'HKCU:*') { $sid } else { $null } }

function Get-Snapshot {
    $lines = @()
    foreach ($t in $tweaks) {
        foreach ($r in @($t.Registry | Where-Object { $_ })) {
            $s = Get-RegistryValueState -Path $r.Path -Name $r.Name -Sid (Get-Sid $r.Path)
            $lines += 'reg {0}\{1} = {2} {3} {4}' -f $r.Path, $r.Name, $s.Exists, $s.Type, (@($s.Value) -join ',')
            $key = $r.Path
            while ($key -match '^HK(LM|CU):\\.+') {
                $lines += 'key {0} = {1}' -f $key, (Test-RegistryKey -Path $key -Sid (Get-Sid $r.Path))
                $key = $key.Substring(0, $key.LastIndexOf('\'))
            }
        }
        foreach ($svc in @($t.Services | Where-Object { $_ })) {
            $s = Get-ServiceStartState -Name $svc.Name
            $lines += 'svc {0} = {1} {2} {3}' -f $svc.Name, $s.Exists, $s.Start, $s.Delayed
        }
        foreach ($task in @($t.Tasks | Where-Object { $_ })) {
            $s = Get-TaskEnabledState -TaskPath $task
            $lines += 'task {0} = {1} {2}' -f $task, $s.Exists, $s.Enabled
        }
    }
    @($lines | Sort-Object -Unique)
}

function Invoke-DeBloatify([string[]]$Arguments) {
    Write-Host ">> DeBloatify.ps1 $($Arguments -join ' ')" -ForegroundColor Cyan
    & $powershell -NoProfile -ExecutionPolicy Bypass -File $entryScript @Arguments | Out-Host
    $LASTEXITCODE
}

function Test-That([bool]$Condition, [string]$Message) {
    if ($Condition) { Write-Host "[pass] $Message" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Message" -ForegroundColor Red; [void]$failures.Add($Message) }
}

$before = Get-Snapshot
Write-Host "Tracking $($before.Count) registry values, keys, services and tasks"

# 1. Apply every tweak (Aggressive + all Optional), no apps.
$code = Invoke-DeBloatify @('-Preset', 'Aggressive', '-Include', '*', '-SkipApps', '-NoRestorePoint', '-NoRestartExplorer', '-Force')
Test-That ($code -eq 0) "apply exited with 0 (got $code)"

$notApplied = @()
foreach ($t in $tweaks) {
    foreach ($r in @($t.Registry | Where-Object { $_ })) {
        $s = Get-RegistryValueState -Path $r.Path -Name $r.Name -Sid (Get-Sid $r.Path)
        $want = ConvertTo-RegistryData -Type $r.Type -Value $r.Value
        if (-not ($s.Exists -and $s.Type -eq $r.Type -and (Test-RegistryDataEqual $s.Value $want))) { $notApplied += "$($t.Id): $($r.Path)\$($r.Name)" }
    }
    foreach ($svc in @($t.Services | Where-Object { $_ })) {
        $s = Get-ServiceStartState -Name $svc.Name
        $want = @{ Automatic = 2; Manual = 3; Disabled = 4 }[$svc.StartupType]
        if ($s.Exists -and $s.Start -ne $want) { $notApplied += "$($t.Id): service $($svc.Name)" }
    }
    foreach ($task in @($t.Tasks | Where-Object { $_ })) {
        $s = Get-TaskEnabledState -TaskPath $task
        if ($s.Exists -and $s.Enabled) { $notApplied += "$($t.Id): task $task" }
    }
}
Test-That ($notApplied.Count -eq 0) "every tweak applied $(if ($notApplied) { ': ' + ($notApplied -join '; ') })"
Test-That ((Compare-Object $before (Get-Snapshot)).Count -gt 0) 'apply changed the system'

# 2. Running again changes nothing.
$code = Invoke-DeBloatify @('-Preset', 'Aggressive', '-Include', '*', '-SkipApps', '-NoRestorePoint', '-NoRestartExplorer', '-Force')
Test-That ($code -eq 0) "second apply exited with 0 (got $code)"

# 3. Undo everything and compare with the starting state.
$code = Invoke-DeBloatify @('-Undo', '-NoRestartExplorer')
Test-That ($code -eq 0) "undo exited with 0 (got $code)"
$diff = @(Compare-Object $before (Get-Snapshot))
foreach ($d in $diff) { Write-Host ('   {0} {1}' -f $d.SideIndicator, $d.InputObject) -ForegroundColor Yellow }
Test-That ($diff.Count -eq 0) 'undo restored the original state exactly'
$backup = Get-Content -Raw (Join-Path $env:ProgramData 'DeBloatify\backup.json') | ConvertFrom-Json
Test-That (@($backup.Registry).Count + @($backup.Services).Count + @($backup.Tasks).Count -eq 0) 'backup is empty after a full undo'

# 4. Read-only paths: app detection and repair listing.
$code = Invoke-DeBloatify @('-Preset', 'Aggressive', '-DryRun', '-Force')
Test-That ($code -eq 0) "dry run with apps exited with 0 (got $code)"
$code = Invoke-DeBloatify @('-Repair', 'All', '-DryRun', '-Force')
Test-That ($code -eq 0) "repair dry run exited with 0 (got $code)"
$code = Invoke-DeBloatify @('-Repair', 'repair.wmi', '-Force')
Test-That ($code -eq 0) "WMI check repair exited with 0 (got $code)"

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "$($failures.Count) integration check(s) failed" -ForegroundColor Red
    exit 1
}
Write-Host 'All integration checks passed' -ForegroundColor Green
exit 0
