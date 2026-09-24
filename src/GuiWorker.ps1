# Background worker for the GUI. The window starts this script in its own runspace for
# each operation, so the window stays responsive while apps are removed or DISM runs.
# Log lines go back to the window through $Sync.Queue as "Level|Message"; the outcome
# is left in $Sync.Result (and $Sync.Error if something unexpected went wrong).
#
# The catalogs are loaded again here rather than passed in: script blocks belong to the
# runspace that created them and must not be invoked from another thread.

param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][hashtable]$Sync,
    [Parameter(Mandatory)][ValidateSet('RestorePoint', 'Preview', 'Apply', 'Undo', 'Repair')][string]$Operation,
    [hashtable]$Options = @{}
)

$ErrorActionPreference = 'Stop'
$src = Join-Path $Root 'src'
foreach ($file in 'Core.ps1', 'Backup.ps1', 'Engine.ps1', 'Apps.ps1', 'Repairs.ps1') {
    . (Join-Path $src $file)
}
if ($Options.TestHook) { . $Options.TestHook }   # tests swap in fake system primitives here

$script:LogFile = $Options.LogFile
$script:TargetUserSid = $Options.TargetUserSid
$script:CaptureNativeOutput = $true
$script:WorkerSync = $Sync

function Write-Log {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Message, [string]$Level = 'Info')
    $script:WorkerSync.Queue.Enqueue(('{0}|{1}' -f $Level, $Message))
    if ($script:LogFile) {
        $line = '[{0}] {1,-6} {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level.ToUpper(), $Message
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
    }
}

function Restart-ExplorerIfNeeded {
    param($Result)
    if ($Result.RestartExplorer -and -not $Options.NoRestartExplorer) { Restart-Explorer }
}

try {
    if ($Options.BackupPath) { Initialize-BackupStore -Path $Options.BackupPath }

    switch ($Operation) {
        'RestorePoint' {
            Write-Log 'Creating a restore point' Step
            $Sync.Result = [bool](New-SafetyRestorePoint)
        }
        { $_ -eq 'Preview' -or $_ -eq 'Apply' } {
            $dryRun = ($Operation -eq 'Preview')
            $tweakIds = @($Options.TweakIds)
            $appIds = @($Options.AppIds)
            $tweaks = @(Get-TweakCatalog -Directory (Join-Path $src 'tweaks') | Where-Object { $tweakIds -contains $_.Id })
            $apps = @(Get-AppCatalog | Where-Object { $appIds -contains $_.Id })
            $result = Invoke-Tweaks -Tweaks $tweaks -DryRun:$dryRun
            Merge-RunResult -Total $result -Part (Invoke-AppRemoval -Apps $apps -DryRun:$dryRun)
            if (-not $dryRun) { Restart-ExplorerIfNeeded $result }
            $Sync.Result = $result
        }
        'Undo' {
            Write-Log 'Undoing changes' Step
            $result = Invoke-Undo -TweakIds @($Options.TweakIds)
            Restart-ExplorerIfNeeded $result
            $Sync.Result = $result
        }
        'Repair' {
            $repairIds = @($Options.RepairIds)
            $result = New-RunResult
            foreach ($repair in @(Get-RepairCatalog | Where-Object { $repairIds -contains $_.Id })) {
                Write-Log $repair.Name Step
                try {
                    & $repair.Action | ForEach-Object { if ("$_".Trim()) { Write-Log ([string]$_) Detail } }
                    Write-Log "$($repair.Name) - done" Ok
                    $result.Changed++
                    if ($repair.Reboot) { $result.Reboot = $true }
                } catch {
                    Write-Log "$($repair.Name) failed: $($_.Exception.Message)" Error
                    $result.Failed++
                }
            }
            $Sync.Result = $result
        }
    }
} catch {
    $Sync.Error = $_.Exception.Message
    Write-Log "Unexpected error: $($_.Exception.Message)" Error
}
