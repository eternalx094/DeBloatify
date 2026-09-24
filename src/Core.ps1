# DeBloatify core: logging, environment checks and the low-level primitives
# (registry, services, scheduled tasks, AppX) that every change goes through.
# The test suite swaps the primitives for in-memory fakes, so all direct system
# access belongs in this file.

$script:LogFile = $null
$script:Quiet = $false

function Write-Log {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('Info', 'Ok', 'Warn', 'Error', 'Step', 'Detail')][string]$Level = 'Info'
    )
    $colors = @{ Info = 'Gray'; Ok = 'Green'; Warn = 'Yellow'; Error = 'Red'; Step = 'Cyan'; Detail = 'DarkGray' }
    $prefix = @{ Info = '   '; Ok = '[+]'; Warn = '[!]'; Error = '[x]'; Step = '==>'; Detail = '   ' }
    if (-not $script:Quiet -or $Level -in 'Warn', 'Error', 'Step') {
        Write-Host ('{0} {1}' -f $prefix[$Level], $Message) -ForegroundColor $colors[$Level]
    }
    if ($script:LogFile) {
        $line = '[{0}] {1,-6} {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level.ToUpper(), $Message
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
    }
}

function Initialize-Logging {
    param([Parameter(Mandatory)][string]$Directory)
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $script:LogFile = Join-Path $Directory ('DeBloatify-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-CurrentUserSid {
    [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Get-WindowsInfo {
    # ProductName still says "Windows 10" on Windows 11, so the build number is the source of truth.
    $cv = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$cv.CurrentBuildNumber
    [pscustomobject]@{
        Build          = $build
        DisplayVersion = $cv.DisplayVersion
        Edition        = $cv.EditionID
        IsWindows11    = ($build -ge 22000)
    }
}

function Get-InteractiveUser {
    # The signed-in user can differ from the elevated account (a standard user who typed
    # admin credentials into UAC). Per-user settings must land in the signed-in user's hive.
    try {
        $session = (Get-Process -Id $PID).SessionId
        $explorer = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'" -ErrorAction Stop |
            Where-Object { $_.SessionId -eq $session } | Select-Object -First 1
        if (-not $explorer) { return $null }
        $owner = Invoke-CimMethod -InputObject $explorer -MethodName GetOwner -ErrorAction Stop
        $sid = Invoke-CimMethod -InputObject $explorer -MethodName GetOwnerSid -ErrorAction Stop
        if (-not $sid.Sid) { return $null }
        [pscustomobject]@{ Name = ('{0}\{1}' -f $owner.Domain, $owner.User); Sid = $sid.Sid }
    } catch {
        $null
    }
}

# ---------------------------------------------------------------------------
# Registry primitives
# ---------------------------------------------------------------------------
# Paths use the familiar 'HKLM:\...' / 'HKCU:\...' form. HKCU paths are resolved
# against a user SID: the current user's own hive when the SIDs match, otherwise
# HKEY_USERS\<sid> (the signed-in user's hive is always loaded).

function Resolve-RegistryLocation {
    param([Parameter(Mandatory)][string]$Path, [string]$Sid)
    if ($Path -notmatch '^(HKLM|HKCU):\\(.+)$') { throw "Unsupported registry path: $Path" }
    $hive = $Matches[1]
    $subKey = $Matches[2].TrimEnd('\')
    if ($hive -eq 'HKLM') {
        return [pscustomobject]@{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; SubKey = $subKey }
    }
    if ($Sid -and $Sid -ne (Get-CurrentUserSid)) {
        return [pscustomobject]@{ Hive = [Microsoft.Win32.RegistryHive]::Users; SubKey = "$Sid\$subKey" }
    }
    [pscustomobject]@{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; SubKey = $subKey }
}

function Open-RegistryBaseKey {
    param([Parameter(Mandatory)][Microsoft.Win32.RegistryHive]$Hive)
    # Always use the 64-bit view so HKLM\SOFTWARE is never redirected to WOW6432Node.
    [Microsoft.Win32.RegistryKey]::OpenBaseKey($Hive, [Microsoft.Win32.RegistryView]::Registry64)
}

function Test-RegistryKey {
    param([Parameter(Mandatory)][string]$Path, [string]$Sid)
    $loc = Resolve-RegistryLocation -Path $Path -Sid $Sid
    $base = Open-RegistryBaseKey -Hive $loc.Hive
    try {
        $key = $base.OpenSubKey($loc.SubKey, $false)
        if ($null -eq $key) { return $false }
        $key.Dispose()
        $true
    } finally { $base.Dispose() }
}

function Get-RegistryValueState {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowEmptyString()][string]$Name, [string]$Sid)
    $loc = Resolve-RegistryLocation -Path $Path -Sid $Sid
    $base = Open-RegistryBaseKey -Hive $loc.Hive
    try {
        $key = $base.OpenSubKey($loc.SubKey, $false)
        if ($null -eq $key) { return [pscustomobject]@{ Exists = $false; Type = $null; Value = $null } }
        try {
            if (@($key.GetValueNames()) -notcontains $Name) {
                return [pscustomobject]@{ Exists = $false; Type = $null; Value = $null }
            }
            $kind = $key.GetValueKind($Name)
            $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            [pscustomobject]@{ Exists = $true; Type = $kind.ToString(); Value = $value }
        } finally { $key.Dispose() }
    } finally { $base.Dispose() }
}

function Set-RegistryValueRaw {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][string]$Type,
        [AllowNull()][AllowEmptyString()]$Value,
        [string]$Sid
    )
    $loc = Resolve-RegistryLocation -Path $Path -Sid $Sid
    $base = Open-RegistryBaseKey -Hive $loc.Hive
    try {
        $key = $base.CreateSubKey($loc.SubKey, $true)
        try {
            $data = ConvertTo-RegistryData -Type $Type -Value $Value
            $key.SetValue($Name, $data, [Microsoft.Win32.RegistryValueKind]$Type)
        } finally { $key.Dispose() }
    } finally { $base.Dispose() }
}

function Remove-RegistryValueRaw {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowEmptyString()][string]$Name, [string]$Sid)
    $loc = Resolve-RegistryLocation -Path $Path -Sid $Sid
    $base = Open-RegistryBaseKey -Hive $loc.Hive
    try {
        $key = $base.OpenSubKey($loc.SubKey, $true)
        if ($null -eq $key) { return }
        try { $key.DeleteValue($Name, $false) } finally { $key.Dispose() }
    } finally { $base.Dispose() }
}

function Remove-RegistryKeyIfEmpty {
    # Only ever deletes keys DeBloatify created, and only when nothing else lives in them.
    param([Parameter(Mandatory)][string]$Path, [string]$Sid)
    $loc = Resolve-RegistryLocation -Path $Path -Sid $Sid
    $base = Open-RegistryBaseKey -Hive $loc.Hive
    try {
        $key = $base.OpenSubKey($loc.SubKey, $false)
        if ($null -eq $key) { return $true }
        $empty = ($key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0)
        $key.Dispose()
        if ($empty) { $base.DeleteSubKey($loc.SubKey, $false) }
        $empty
    } finally { $base.Dispose() }
}

# ---------------------------------------------------------------------------
# Service primitives. Start values: 2 = Automatic, 3 = Manual, 4 = Disabled.
# ---------------------------------------------------------------------------

function Get-ServiceStartState {
    param([Parameter(Mandatory)][string]$Name)
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    $start = Get-RegistryValueState -Path $path -Name 'Start'
    if (-not $start.Exists) { return [pscustomobject]@{ Exists = $false; Start = $null; Delayed = $false } }
    $delayed = Get-RegistryValueState -Path $path -Name 'DelayedAutostart'
    [pscustomobject]@{ Exists = $true; Start = [int]$start.Value; Delayed = ($delayed.Exists -and [int]$delayed.Value -eq 1) }
}

function Set-ServiceStartState {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][int]$Start, [bool]$Delayed = $false)
    $mode = switch ($Start) {
        2 { if ($Delayed) { 'delayed-auto' } else { 'auto' } }
        3 { 'demand' }
        4 { 'disabled' }
        default { $null }
    }
    if ($mode) {
        # sc.exe updates the Service Control Manager immediately; a raw registry write would wait for a reboot.
        # (No 2>&1: under $ErrorActionPreference = 'Stop', Windows PowerShell 5.1 turns stderr into an exception.)
        $output = & sc.exe config $Name start= $mode
        if ($LASTEXITCODE -ne 0) { throw "sc.exe config $Name start= $mode failed: $output" }
    } else {
        Set-RegistryValueRaw -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$Name" -Name 'Start' -Type 'DWord' -Value $Start
    }
    if ($Start -eq 4) { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# Scheduled task primitives. Tasks are addressed by full path, e.g.
# '\Microsoft\Windows\Feedback\Siuf\DmClient'.
# ---------------------------------------------------------------------------

function Split-TaskPath {
    param([Parameter(Mandatory)][string]$TaskPath)
    $i = $TaskPath.LastIndexOf('\')
    [pscustomobject]@{ Folder = $TaskPath.Substring(0, $i + 1); Name = $TaskPath.Substring($i + 1) }
}

function Get-TaskEnabledState {
    param([Parameter(Mandatory)][string]$TaskPath)
    $p = Split-TaskPath -TaskPath $TaskPath
    $task = Get-ScheduledTask -TaskPath $p.Folder -TaskName $p.Name -ErrorAction SilentlyContinue
    if (-not $task) { return [pscustomobject]@{ Exists = $false; Enabled = $false } }
    [pscustomobject]@{ Exists = $true; Enabled = ($task.State -ne 'Disabled') }
}

function Set-TaskEnabledState {
    param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][bool]$Enabled)
    $p = Split-TaskPath -TaskPath $TaskPath
    if ($Enabled) {
        Enable-ScheduledTask -TaskPath $p.Folder -TaskName $p.Name -ErrorAction Stop | Out-Null
    } else {
        Disable-ScheduledTask -TaskPath $p.Folder -TaskName $p.Name -ErrorAction Stop | Out-Null
    }
}

# ---------------------------------------------------------------------------
# AppX primitives
# ---------------------------------------------------------------------------

function Get-InstalledAppxPackages {
    @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Select-Object Name, PackageFullName, IsFramework, NonRemovable)
}

function Get-ProvisionedAppxPackages {
    @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Select-Object DisplayName, PackageName)
}

function Remove-InstalledAppx {
    param([Parameter(Mandatory)][string]$PackageFullName)
    Remove-AppxPackage -Package $PackageFullName -AllUsers -ErrorAction Stop
}

function Remove-ProvisionedAppx {
    param([Parameter(Mandatory)][string]$PackageName)
    Remove-AppxProvisionedPackage -Online -PackageName $PackageName -ErrorAction Stop | Out-Null
}

# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------

function ConvertTo-RegistryData {
    param([Parameter(Mandatory)][string]$Type, [AllowNull()][AllowEmptyString()]$Value)
    switch ($Type) {
        'DWord' {
            # .NET wants a signed Int32; map 0x80000000-0xFFFFFFFF onto the negative range.
            $n = [int64]$Value
            if ($n -gt [int32]::MaxValue) { $n -= 4294967296 }
            return [int32]$n
        }
        'QWord' { return [int64]$Value }
        'Binary' { return , ([byte[]]@($Value)) }
        'MultiString' { return , ([string[]]@($Value)) }
        'String' { return [string]$Value }
        'ExpandString' { return [string]$Value }
        default { throw "Unsupported registry value type: $Type" }
    }
}

function Test-RegistryDataEqual {
    param([AllowNull()]$Left, [AllowNull()]$Right)
    if ($Left -is [array] -or $Right -is [array]) {
        $a = @($Left); $b = @($Right)
        if ($a.Count -ne $b.Count) { return $false }
        for ($i = 0; $i -lt $a.Count; $i++) {
            if ([string]$a[$i] -cne [string]$b[$i]) { return $false }
        }
        return $true
    }
    if ($null -eq $Left -or $null -eq $Right) { return ($null -eq $Left -and $null -eq $Right) }
    [string]$Left -ceq [string]$Right
}

function Test-IdMatch {
    # True when $Id matches any of the patterns (exact id, wildcard such as 'edge.*', or a category name).
    param([Parameter(Mandatory)][string]$Id, [string]$Category, [string[]]$Patterns)
    foreach ($p in @($Patterns)) {
        if (-not $p) { continue }
        if ($Id -like $p) { return $true }
        if ($Category -and $Category -eq $p) { return $true }
    }
    $false
}

function ConvertFrom-RangeText {
    # '1,4,7-9' -> 1 4 7 8 9 (limited to 1..$Max, de-duplicated, in input order)
    param([AllowEmptyString()][string]$Text, [Parameter(Mandatory)][int]$Max)
    $seen = @{}
    foreach ($part in ($Text -split '[,\s]+')) {
        $numbers = @()
        if ($part -match '^(\d+)-(\d+)$') {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            if ($a -gt $b) { $a, $b = $b, $a }
            $numbers = $a..$b
        } elseif ($part -match '^\d+$') {
            $numbers = @([int]$part)
        }
        foreach ($n in $numbers) {
            if ($n -ge 1 -and $n -le $Max -and -not $seen.ContainsKey($n)) {
                $seen[$n] = $true
                $n
            }
        }
    }
}

function ConvertTo-ArgumentList {
    # Rebuilds a powershell.exe command line from bound parameters (used to relaunch elevated).
    param([Parameter(Mandatory)][System.Collections.IDictionary]$BoundParameters, [Parameter(Mandatory)][string]$ScriptPath)
    $out = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $ScriptPath))
    foreach ($key in $BoundParameters.Keys) {
        $value = $BoundParameters[$key]
        if ($value -is [System.Management.Automation.SwitchParameter]) {
            if ($value.IsPresent) { $out += "-$key" }
        } elseif ($value -is [array]) {
            $out += "-$key"
            $out += ('"{0}"' -f ((@($value) | ForEach-Object { [string]$_ }) -join ','))
        } else {
            $out += "-$key"
            $out += ('"{0}"' -f $value)
        }
    }
    $out
}

function Split-ListArgument {
    # Accepts both real arrays and comma-separated strings (powershell.exe -File passes 'a,b' as one string).
    param([string[]]$Value)
    @($Value | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
