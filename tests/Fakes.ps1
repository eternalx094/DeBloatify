# In-memory fakes of the registry, services, scheduled tasks and AppX, used by
# tests/Run-Tests.ps1 and (through tests/WorkerHook.ps1) by the GUI worker in tests.
# Dot-source after src/*.ps1 so these replace the real primitives.

$script:TestSid = 'S-1-5-21-1000-1001'

function Reset-FakeSystem {
    $script:FakeKeys = @{}
    $script:FakeValues = @{}
    $script:FakeServices = @{}
    $script:FakeTasks = @{}
    $script:FakeInstalled = @()
    $script:FakeProvisioned = @()
    $script:FailPaths = @()
    $script:LogLines = New-Object System.Collections.ArrayList
    $script:TargetUserSid = $script:TestSid
    $script:BackupFile = Join-Path ([System.IO.Path]::GetTempPath()) ('debloatify-test-{0}.json' -f [guid]::NewGuid())
    Initialize-BackupStore -Path $script:BackupFile
    foreach ($k in 'HKLM:\SOFTWARE\Policies\Microsoft\Windows', 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'HKCU:\Software\Policies\Microsoft\Windows',
        'HKCU:\Control Panel\Accessibility\StickyKeys', 'HKCU:\Software\Classes\CLSID', 'HKCU:\System') {
        Add-FakeKey (Get-FakeKeyName $k $script:TestSid)
    }
}

function Get-FakeKeyName {
    param([string]$Path, [string]$Sid)
    $p = $Path.TrimEnd('\').ToLowerInvariant()
    if ($p -like 'hkcu:*') {
        if (-not $Sid) { $Sid = $script:TestSid }
        return '{0}|{1}' -f $Sid.ToLowerInvariant(), $p
    }
    '|' + $p
}

function Add-FakeKey {
    param([string]$KeyName)
    $k = $KeyName
    while ($true) {
        $script:FakeKeys[$k] = $true
        $i = $k.LastIndexOf('\')
        if ($i -lt 0) { break }
        $parent = $k.Substring(0, $i)
        if ($parent -match ':$') { break }
        $k = $parent
    }
}

function Get-CurrentUserSid { $script:TestSid }
function Write-Log { param([string]$Message, [string]$Level = 'Info') [void]$script:LogLines.Add("$Level $Message") }
function Restart-Explorer { }

function Test-RegistryKey {
    param([string]$Path, [string]$Sid)
    $script:FakeKeys.ContainsKey((Get-FakeKeyName $Path $Sid))
}

function Get-RegistryValueState {
    param([string]$Path, [AllowEmptyString()][string]$Name, [string]$Sid)
    $k = '{0}|{1}' -f (Get-FakeKeyName $Path $Sid), $Name.ToLowerInvariant()
    if ($script:FakeValues.ContainsKey($k)) {
        $v = $script:FakeValues[$k]
        return [pscustomobject]@{ Exists = $true; Type = $v.Type; Value = $v.Value }
    }
    [pscustomobject]@{ Exists = $false; Type = $null; Value = $null }
}

function Set-RegistryValueRaw {
    param([string]$Path, [AllowEmptyString()][string]$Name, [string]$Type, [AllowNull()][AllowEmptyString()]$Value, [string]$Sid)
    if ($script:FailPaths -contains $Path) { throw "Access denied: $Path" }
    $key = Get-FakeKeyName $Path $Sid
    Add-FakeKey $key
    $script:FakeValues['{0}|{1}' -f $key, $Name.ToLowerInvariant()] = @{ Type = $Type; Value = (ConvertTo-RegistryData -Type $Type -Value $Value) }
}

function Remove-RegistryValueRaw {
    param([string]$Path, [AllowEmptyString()][string]$Name, [string]$Sid)
    $script:FakeValues.Remove(('{0}|{1}' -f (Get-FakeKeyName $Path $Sid), $Name.ToLowerInvariant()))
}

function Remove-RegistryKeyIfEmpty {
    param([string]$Path, [string]$Sid)
    $key = Get-FakeKeyName $Path $Sid
    if (-not $script:FakeKeys.ContainsKey($key)) { return $true }
    $hasValues = @($script:FakeValues.Keys | Where-Object { $_.StartsWith("$key|") }).Count -gt 0
    $hasSubKeys = @($script:FakeKeys.Keys | Where-Object { $_.StartsWith("$key\") }).Count -gt 0
    if ($hasValues -or $hasSubKeys) { return $false }
    $script:FakeKeys.Remove($key)
    $true
}

function Get-ServiceStartState {
    param([string]$Name)
    if (-not $script:FakeServices.ContainsKey($Name)) { return [pscustomobject]@{ Exists = $false; Start = $null; Delayed = $false } }
    $s = $script:FakeServices[$Name]
    [pscustomobject]@{ Exists = $true; Start = $s.Start; Delayed = $s.Delayed }
}

function Set-ServiceStartState {
    param([string]$Name, [int]$Start, [bool]$Delayed = $false)
    $script:FakeServices[$Name] = @{ Start = $Start; Delayed = $Delayed }
}

function Get-TaskEnabledState {
    param([string]$TaskPath)
    if (-not $script:FakeTasks.ContainsKey($TaskPath)) { return [pscustomobject]@{ Exists = $false; Enabled = $false } }
    [pscustomobject]@{ Exists = $true; Enabled = $script:FakeTasks[$TaskPath] }
}

function Set-TaskEnabledState {
    param([string]$TaskPath, [bool]$Enabled)
    $script:FakeTasks[$TaskPath] = $Enabled
}

function Get-InstalledAppxPackages { @($script:FakeInstalled) }
function Get-ProvisionedAppxPackages { @($script:FakeProvisioned) }
function Remove-InstalledAppx {
    param([string]$PackageFullName)
    $script:FakeInstalled = @($script:FakeInstalled | Where-Object { $_.PackageFullName -ne $PackageFullName })
}
function Remove-ProvisionedAppx {
    param([string]$PackageName)
    $script:FakeProvisioned = @($script:FakeProvisioned | Where-Object { $_.PackageName -ne $PackageName })
}

function New-FakePackage {
    param([string]$Name, [switch]$Framework, [switch]$NonRemovable)
    [pscustomobject]@{ Name = $Name; PackageFullName = "$($Name)_1.0.0.0_x64__8wekyb3d8bbwe"; IsFramework = [bool]$Framework; NonRemovable = [bool]$NonRemovable }
}

function Get-FakeSnapshot {
    $lines = @()
    $lines += @($script:FakeKeys.Keys | Sort-Object | ForEach-Object { "key $_" })
    $lines += @($script:FakeValues.Keys | Sort-Object | ForEach-Object {
            $v = $script:FakeValues[$_]
            'val {0} = {1}:{2}' -f $_, $v.Type, (@($v.Value) -join ',')
        })
    $lines += @($script:FakeServices.Keys | Sort-Object | ForEach-Object { 'svc {0} = {1}/{2}' -f $_, $script:FakeServices[$_].Start, $script:FakeServices[$_].Delayed })
    $lines += @($script:FakeTasks.Keys | Sort-Object | ForEach-Object { 'task {0} = {1}' -f $_, $script:FakeTasks[$_] })
    $lines -join "`n"
}

function Set-RealisticStartingState {
    # Values that exist on a typical Windows 11 install before DeBloatify runs.
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-RegistryValueRaw -Path $adv -Name 'HideFileExt' -Type 'DWord' -Value 1 -Sid $script:TestSid
    Set-RegistryValueRaw -Path $adv -Name 'TaskbarAl' -Type 'DWord' -Value 1 -Sid $script:TestSid
    Set-RegistryValueRaw -Path $adv -Name 'Start_TrackProgs' -Type 'DWord' -Value 0 -Sid $script:TestSid   # already set
    Set-RegistryValueRaw -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -Type 'DWord' -Value 1 -Sid $script:TestSid
    Set-RegistryValueRaw -Path 'HKCU:\Control Panel\Accessibility\StickyKeys' -Name 'Flags' -Type 'String' -Value '510' -Sid $script:TestSid
    Set-RegistryValueRaw -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Type 'DWord' -Value 3
    Set-RegistryValueRaw -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Type 'DWord' -Value 1
    # A policy key that already holds an unrelated value must survive undo.
    Set-RegistryValueRaw -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name 'SomeCompanyPolicy' -Type 'String' -Value 'keep-me'
    $script:FakeServices['DiagTrack'] = @{ Start = 2; Delayed = $false }
    $script:FakeServices['MapsBroker'] = @{ Start = 2; Delayed = $true }
    $script:FakeServices['RetailDemo'] = @{ Start = 3; Delayed = $false }
    $script:FakeServices['dmwappushservice'] = @{ Start = 3; Delayed = $true }   # manual, delayed flag set (Windows default)
    $script:FakeTasks['\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'] = $true
    $script:FakeTasks['\Microsoft\Windows\Autochk\Proxy'] = $false   # already disabled
    $script:FakeTasks['\Microsoft\Windows\Feedback\Siuf\DmClient'] = $true
}
