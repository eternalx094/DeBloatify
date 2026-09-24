# Backup store: remembers the original state of everything DeBloatify changes so
# Undo can put it back. Only the *first* original value is kept - re-running a
# preset never overwrites the backup with DeBloatify's own values.
#
# Stored as JSON in %ProgramData%\DeBloatify\backup.json and saved after every
# tweak, so an interrupted run can still be undone.

$script:BackupPath = $null
$script:Backup = $null

function Initialize-BackupStore {
    param([Parameter(Mandatory)][string]$Path)
    $script:BackupPath = $Path
    $script:Backup = @{
        Registry    = New-Object System.Collections.ArrayList
        CreatedKeys = New-Object System.Collections.ArrayList
        Services    = New-Object System.Collections.ArrayList
        Tasks       = New-Object System.Collections.ArrayList
    }
    if (-not (Test-Path -LiteralPath $Path)) { return }

    $data = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($section in 'Registry', 'CreatedKeys', 'Services', 'Tasks') {
        if ($data.PSObject.Properties.Name -notcontains $section) { continue }
        foreach ($entry in @($data.$section)) {
            if ($null -ne $entry) { [void]$script:Backup[$section].Add($entry) }
        }
    }
}

function Save-BackupStore {
    if (-not $script:BackupPath) { return }
    $dir = Split-Path -Parent $script:BackupPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $doc = [ordered]@{
        Version     = 1
        Updated     = (Get-Date).ToString('o')
        Registry    = @($script:Backup.Registry)
        CreatedKeys = @($script:Backup.CreatedKeys)
        Services    = @($script:Backup.Services)
        Tasks       = @($script:Backup.Tasks)
    }
    # Write to a temp file first so a crash mid-write can't corrupt the only copy.
    $tmp = "$script:BackupPath.tmp"
    ConvertTo-Json -InputObject $doc -Depth 8 | Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $script:BackupPath -Force
}

function Get-BackupCount {
    $script:Backup.Registry.Count + $script:Backup.Services.Count + $script:Backup.Tasks.Count
}

function Get-BackedUpTweakIds {
    $ids = @()
    foreach ($section in 'Registry', 'Services', 'Tasks') {
        $ids += @($script:Backup[$section] | ForEach-Object { $_.TweakId })
    }
    @($ids | Where-Object { $_ } | Sort-Object -Unique)
}

function Find-RegistryBackup {
    param([string]$Path, [string]$Name, [string]$Sid)
    foreach ($e in $script:Backup.Registry) {
        if ($e.Path -eq $Path -and $e.Name -eq $Name -and $e.Sid -eq $Sid) { return $e }
    }
    $null
}

function Add-RegistryBackup {
    param([string]$TweakId, [string]$Path, [string]$Name, [string]$Sid, $State)
    if (Find-RegistryBackup -Path $Path -Name $Name -Sid $Sid) { return }
    [void]$script:Backup.Registry.Add([pscustomobject]@{
            TweakId = $TweakId
            Path    = $Path
            Name    = $Name
            Sid     = $Sid
            Existed = [bool]$State.Exists
            Type    = $State.Type
            Value   = $State.Value
        })
}

function Add-CreatedKeyBackup {
    param([string]$TweakId, [string]$Path, [string]$Sid)
    foreach ($e in $script:Backup.CreatedKeys) {
        if ($e.Path -eq $Path -and $e.Sid -eq $Sid) { return }
    }
    [void]$script:Backup.CreatedKeys.Add([pscustomobject]@{ TweakId = $TweakId; Path = $Path; Sid = $Sid })
}

function Add-ServiceBackup {
    param([string]$TweakId, [string]$Name, $State)
    foreach ($e in $script:Backup.Services) { if ($e.Name -eq $Name) { return } }
    [void]$script:Backup.Services.Add([pscustomobject]@{
            TweakId = $TweakId
            Name    = $Name
            Start   = $State.Start
            Delayed = [bool]$State.Delayed
        })
}

function Add-TaskBackup {
    param([string]$TweakId, [string]$TaskPath)
    foreach ($e in $script:Backup.Tasks) { if ($e.Path -eq $TaskPath) { return } }
    [void]$script:Backup.Tasks.Add([pscustomobject]@{ TweakId = $TweakId; Path = $TaskPath })
}
