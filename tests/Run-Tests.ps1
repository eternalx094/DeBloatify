# DeBloatify test suite. Runs on Windows PowerShell 5.1 and on PowerShell 7 on any OS:
# the registry, service, task and AppX primitives are replaced with in-memory fakes,
# so nothing on the machine running the tests is touched.
#
#   powershell -File tests\Run-Tests.ps1      (or: pwsh tests/Run-Tests.ps1)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'src'
foreach ($file in 'Core.ps1', 'Backup.ps1', 'Engine.ps1', 'Apps.ps1', 'Repairs.ps1', 'Ui.ps1') {
    . (Join-Path $src $file)
}
$script:Version = 'test'

# ---------------------------------------------------------------------------
# Tiny test harness
# ---------------------------------------------------------------------------

$script:Passed = 0
$script:Failed = 0

function It {
    param([string]$Name, [scriptblock]$Body)
    try {
        Reset-FakeSystem
        & $Body
        $script:Passed++
        Write-Host "  [pass] $Name" -ForegroundColor Green
    } catch {
        $script:Failed++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        Write-Host "         $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "         line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())" -ForegroundColor DarkGray
    }
}

function Assert-True {
    param($Condition, [string]$Message = 'Expected condition to be true')
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message = 'Values differ')
    if ("$Expected" -cne "$Actual") { throw "$Message`n         expected: $Expected`n         actual:   $Actual" }
}

# ---------------------------------------------------------------------------
# Fake system
# ---------------------------------------------------------------------------

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

$catalogDir = Join-Path $src 'tweaks'
$tweaks = @(Get-TweakCatalog -Directory $catalogDir)
$apps = @(Get-AppCatalog)
$repairs = @(Get-RepairCatalog)
$allTweaks = @(Select-CatalogItems -Catalog $tweaks -Preset 'Aggressive' -Include '*')
$validLevels = 'Minimal', 'Recommended', 'Aggressive', 'Optional'
$validTypes = 'DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary'

# ---------------------------------------------------------------------------
Write-Host 'Source files'

It 'every PowerShell file parses without errors' {
    foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1') {
        $tokens = $null; $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
        Assert-True ($errors.Count -eq 0) "$($f.Name): $($errors | Select-Object -First 1)"
    }
}

It 'scripts are pure ASCII (Windows PowerShell 5.1 misreads UTF-8 without a BOM)' {
    # (-Include is unreliable in Windows PowerShell 5.1 - it also returns directories.)
    foreach ($f in @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { '.ps1', '.cmd' -contains $_.Extension })) {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $bad = @($bytes | Where-Object { $_ -gt 127 }).Count
        Assert-True ($bad -eq 0) "$($f.Name) contains $bad non-ASCII byte(s)"
    }
}

# ---------------------------------------------------------------------------
Write-Host 'Catalog'

It 'loads tweaks, apps and repairs' {
    Assert-True ($tweaks.Count -ge 40) "only $($tweaks.Count) tweaks loaded"
    Assert-True ($apps.Count -ge 20) "only $($apps.Count) apps loaded"
    Assert-True ($repairs.Count -ge 10) "only $($repairs.Count) repairs loaded"
}

It 'ids are unique and well-formed' {
    $ids = @($tweaks + $apps + $repairs | ForEach-Object { $_.Id })
    $dupes = @($ids | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    Assert-True ($dupes.Count -eq 0) "duplicate ids: $($dupes -join ', ')"
    foreach ($id in $ids) { Assert-True ($id -cmatch '^[a-z0-9]+\.[a-z0-9-]+$') "bad id format: $id" }
}

It 'every tweak has the required fields and valid values' {
    foreach ($t in $tweaks) {
        foreach ($field in 'Id', 'Category', 'Level', 'Name', 'Description') {
            Assert-True ($t.ContainsKey($field) -and $t[$field]) "$($t.Id) is missing $field"
        }
        Assert-True ($validLevels -contains $t.Level) "$($t.Id) has invalid level '$($t.Level)'"
        Assert-True ($t.Registry -or $t.Services -or $t.Tasks -or $t.Apply) "$($t.Id) does nothing"
        if ($t.Restart) { Assert-True ('Explorer', 'Reboot' -contains $t.Restart) "$($t.Id) has invalid Restart" }
        foreach ($r in @($t.Registry | Where-Object { $_ })) {
            Assert-True ($r.Path -match '^HK(LM|CU):\\[^\\]') "$($t.Id): bad registry path '$($r.Path)'"
            Assert-True ($r.Path -notmatch '\\$') "$($t.Id): trailing backslash in '$($r.Path)'"
            Assert-True ($validTypes -contains $r.Type) "$($t.Id): bad type '$($r.Type)'"
            [void](ConvertTo-RegistryData -Type $r.Type -Value $r.Value)
        }
        foreach ($s in @($t.Services | Where-Object { $_ })) {
            Assert-True ('Automatic', 'Manual', 'Disabled' -contains $s.StartupType) "$($t.Id): bad StartupType"
        }
        foreach ($task in @($t.Tasks | Where-Object { $_ })) {
            Assert-True ($task -match '^\\.+\\[^\\]+$') "$($t.Id): bad task path '$task'"
        }
    }
}

It 'no two tweaks change the same registry value, service or task' {
    $seen = @{}
    foreach ($t in $tweaks) {
        $targets = @(@($t.Registry | Where-Object { $_ } | ForEach-Object { 'reg ' + ('{0}|{1}' -f $_.Path, $_.Name).ToLowerInvariant() }) +
            @($t.Services | Where-Object { $_ } | ForEach-Object { 'svc ' + $_.Name.ToLowerInvariant() }) +
            @($t.Tasks | Where-Object { $_ } | ForEach-Object { 'task ' + $_.ToLowerInvariant() }))
        foreach ($target in $targets) {
            Assert-True (-not $seen.ContainsKey($target)) "$target is changed by both $($seen[$target]) and $($t.Id)"
            $seen[$target] = $t.Id
        }
    }
}

It 'every app entry removes something, with specific package patterns' {
    foreach ($a in $apps) {
        foreach ($field in 'Id', 'Category', 'Level', 'Name') { Assert-True ($a[$field]) "$($a.Id) is missing $field" }
        Assert-True ($validLevels -contains $a.Level) "$($a.Id) has invalid level"
        Assert-True ($a.Packages -or $a.Apply) "$($a.Id) removes nothing"
        foreach ($p in @($a.Packages | Where-Object { $_ })) {
            Assert-True (($p -replace '[*?]', '').Length -ge 5) "$($a.Id): pattern '$p' is too broad"
        }
    }
}

It 'no app pattern matches a core Windows component' {
    $core = 'Microsoft.WindowsStore', 'Microsoft.DesktopAppInstaller', 'Microsoft.Windows.Photos', 'Microsoft.Paint',
    'Microsoft.WindowsNotepad', 'Microsoft.WindowsCalculator', 'Microsoft.ScreenSketch', 'Microsoft.WindowsTerminal',
    'Microsoft.SecHealthUI', 'Microsoft.Xbox.TCUI', 'Microsoft.XboxIdentityProvider', 'Microsoft.ZuneMusic',
    'Microsoft.WindowsCamera', 'Microsoft.HEVCVideoExtension', 'Microsoft.WebMediaExtensions', 'Microsoft.VCLibs.140.00',
    'Microsoft.UI.Xaml.2.8', 'MicrosoftWindows.Client.CBS', 'Microsoft.Windows.StartMenuExperienceHost', 'Microsoft.StorePurchaseApp',
    'Microsoft.WindowsAppRuntime.1.5', 'Microsoft.AV1VideoExtension', 'Microsoft.ApplicationCompatibilityEnhancements'
    foreach ($a in $apps) {
        foreach ($p in @($a.Packages | Where-Object { $_ })) {
            foreach ($c in $core) { Assert-True (-not ($c -like $p)) "$($a.Id) pattern '$p' matches core package $c" }
        }
    }
    foreach ($c in $core | Where-Object { $_ -ne 'Microsoft.ZuneMusic' -and $_ -ne 'Microsoft.WindowsCamera' -and $_ -ne 'Microsoft.ApplicationCompatibilityEnhancements' }) {
        Assert-True (Test-ProtectedPackage -Name $c) "$c is not in the protected list"
    }
}

It 'presets are cumulative and Optional items are opt-in only' {
    foreach ($catalog in @(, $tweaks) + @(, $apps)) {
        $min = @(Select-CatalogItems -Catalog $catalog -Preset 'Minimal' | ForEach-Object { $_.Id })
        $rec = @(Select-CatalogItems -Catalog $catalog -Preset 'Recommended' | ForEach-Object { $_.Id })
        $agg = @(Select-CatalogItems -Catalog $catalog -Preset 'Aggressive' | ForEach-Object { $_.Id })
        foreach ($id in $min) { Assert-True ($rec -contains $id) "$id is Minimal but not in Recommended" }
        foreach ($id in $rec) { Assert-True ($agg -contains $id) "$id is Recommended but not in Aggressive" }
        $optional = @($catalog | Where-Object { $_.Level -eq 'Optional' } | ForEach-Object { $_.Id })
        foreach ($id in $optional) { Assert-True ($agg -notcontains $id) "Optional item $id is in a preset" }
    }
}

It 'Include and Exclude accept ids, wildcards and category names' {
    $sel = @(Select-CatalogItems -Catalog $tweaks -Preset 'Minimal' -Include 'ui.taskbar-left' -Exclude 'edge.*' | ForEach-Object { $_.Id })
    Assert-True ($sel -contains 'ui.taskbar-left') 'Include did not add an Optional tweak'
    Assert-True (@($sel | Where-Object { $_ -like 'edge.*' }).Count -eq 0) 'Exclude wildcard did not remove Edge tweaks'
    Assert-True ($sel -contains 'privacy.telemetry') 'Minimal tweak missing'
    $ui = @(Select-CatalogItems -Catalog $tweaks -Include 'Interface')
    Assert-Equal @($tweaks | Where-Object { $_.Category -eq 'Interface' }).Count $ui.Count 'category include'
    Assert-Equal 0 @(Select-CatalogItems -Catalog $tweaks).Count 'no preset and no include should select nothing'
}

# ---------------------------------------------------------------------------
Write-Host 'Helpers'

It 'ConvertFrom-RangeText parses lists and ranges' {
    Assert-Equal '1 4 7 8 9' (@(ConvertFrom-RangeText -Text '1,4,7-9' -Max 20) -join ' ')
    Assert-Equal '7 8 9' (@(ConvertFrom-RangeText -Text '9-7' -Max 20) -join ' ')
    Assert-Equal '2 3' (@(ConvertFrom-RangeText -Text '0 2 3 99 2 abc' -Max 5) -join ' ')
    Assert-Equal '' (@(ConvertFrom-RangeText -Text '' -Max 5) -join ' ')
}

It 'ConvertTo-RegistryData converts every type' {
    Assert-Equal -1 (ConvertTo-RegistryData -Type 'DWord' -Value 4294967295)
    Assert-Equal 0 (ConvertTo-RegistryData -Type 'DWord' -Value 0)
    $bin = ConvertTo-RegistryData -Type 'Binary' -Value @(1, 2, 255)
    Assert-True ($bin -is [byte[]]) "Binary gave $($bin.GetType().Name)"
    $one = ConvertTo-RegistryData -Type 'MultiString' -Value 'solo'
    Assert-True ($one -is [string[]]) "MultiString gave $($one.GetType().Name)"
    Assert-Equal '' (ConvertTo-RegistryData -Type 'String' -Value '')
}

It 'Test-RegistryDataEqual compares scalars and arrays' {
    Assert-True (Test-RegistryDataEqual 0 0)
    Assert-True (-not (Test-RegistryDataEqual 0 1))
    Assert-True (-not (Test-RegistryDataEqual 'abc' 'ABC')) 'strings compare case-sensitively'
    Assert-True (Test-RegistryDataEqual ([byte[]](1, 2)) ([byte[]](1, 2)))
    Assert-True (-not (Test-RegistryDataEqual ([byte[]](1, 2)) ([byte[]](1, 2, 3))))
    Assert-True (-not (Test-RegistryDataEqual $null 0))
}

It 'Split-ListArgument handles arrays and comma-separated strings' {
    Assert-Equal 'a b c' ((Split-ListArgument @('a', 'b, c')) -join ' ')
    Assert-Equal 0 @(Split-ListArgument $null).Count
}

It 'ConvertTo-ArgumentList rebuilds a relaunch command line' {
    $bound = [ordered]@{ Preset = 'Recommended'; Include = @('ui.a', 'ui.b'); DryRun = [System.Management.Automation.SwitchParameter]$true; Force = [System.Management.Automation.SwitchParameter]$false }
    $line = (ConvertTo-ArgumentList -BoundParameters $bound -ScriptPath 'C:\My Tools\DeBloatify.ps1') -join ' '
    Assert-Equal '-NoProfile -ExecutionPolicy Bypass -File "C:\My Tools\DeBloatify.ps1" -Preset "Recommended" -Include "ui.a,ui.b" -DryRun' $line
}

# ---------------------------------------------------------------------------
Write-Host 'Apply and undo'

It 'applying every tweak sets every value, and undo restores the exact original state' {
    Set-RealisticStartingState
    $before = Get-FakeSnapshot
    $result = Invoke-Tweaks -Tweaks $allTweaks
    Assert-Equal 0 $result.Failed 'failures during apply'
    foreach ($t in $allTweaks) {
        foreach ($r in @($t.Registry | Where-Object { $_ })) {
            $sid = if ($r.Path -like 'HKCU:*') { $script:TestSid } else { $null }
            $s = Get-RegistryValueState -Path $r.Path -Name $r.Name -Sid $sid
            Assert-True ($s.Exists -and $s.Type -eq $r.Type -and (Test-RegistryDataEqual $s.Value (ConvertTo-RegistryData $r.Type $r.Value))) "$($t.Id): $($r.Path)\$($r.Name) not applied"
        }
    }
    Assert-Equal 4 $script:FakeServices['DiagTrack'].Start 'DiagTrack not disabled'
    Assert-Equal 3 $script:FakeServices['MapsBroker'].Start 'MapsBroker not manual'
    Assert-Equal 4 $script:FakeServices['dmwappushservice'].Start 'dmwappushservice not disabled'
    Assert-Equal $true $script:FakeServices['dmwappushservice'].Delayed 'delayed-start flag dropped on a disabled service'
    Assert-Equal $false $script:FakeTasks['\Microsoft\Windows\Feedback\Siuf\DmClient'] 'task not disabled'
    Assert-True ($result.RestartExplorer) 'Explorer restart not requested'

    $undo = Invoke-Undo
    Assert-Equal 0 $undo.Failed 'failures during undo'
    Assert-Equal $before (Get-FakeSnapshot) 'state after undo differs from the original'
    Assert-Equal 0 (Get-BackupCount) 'backup not emptied after full undo'
    Assert-Equal 'keep-me' (Get-RegistryValueState -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name 'SomeCompanyPolicy').Value 'unrelated policy lost'
}

It 'a second run keeps the first original value in the backup' {
    Set-RealisticStartingState
    $before = Get-FakeSnapshot
    [void](Invoke-Tweaks -Tweaks $allTweaks)
    $recorded = Get-BackupCount
    # The user flips a setting back by hand, then runs DeBloatify again.
    Set-RegistryValueRaw -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Type 'DWord' -Value 1
    $second = Invoke-Tweaks -Tweaks $allTweaks
    Assert-Equal 1 $second.Changed 'second run should change exactly the value the user flipped'
    Assert-Equal $recorded (Get-BackupCount) 'second run added backup entries instead of keeping the original'
    Assert-Equal 3 (@($script:Backup.Registry | Where-Object { $_.Name -eq 'AllowTelemetry' })[0].Value) 'backup lost the original value'
    [void](Invoke-Undo)
    Assert-Equal $before (Get-FakeSnapshot) 'undo after two runs did not restore the original state'
}

It 'the backup survives a restart of the tool (JSON round trip, all value types)' {
    $odd = Complete-CatalogItem @{
        Id = 'test.types'; Category = 'Test'; Level = 'Optional'; Name = 'types'; Description = 'types'
        Registry = @(
            Reg 'HKLM:\SOFTWARE\Test' 'Bin' @(9, 8, 7) 'Binary'
            Reg 'HKLM:\SOFTWARE\Test' 'Multi' @('x', 'y') 'MultiString'
            Reg 'HKLM:\SOFTWARE\Test' 'Big' 4294967295
            Reg 'HKLM:\SOFTWARE\Test' 'Q' 5 'QWord'
            Reg 'HKLM:\SOFTWARE\Test' 'Exp' '%SystemRoot%\y' 'ExpandString'
        )
    }
    Set-RegistryValueRaw -Path 'HKLM:\SOFTWARE\Test' -Name 'Bin' -Type 'Binary' -Value @(1, 2, 3)
    Set-RegistryValueRaw -Path 'HKLM:\SOFTWARE\Test' -Name 'Multi' -Type 'MultiString' -Value @('only')
    Set-RegistryValueRaw -Path 'HKLM:\SOFTWARE\Test' -Name 'Big' -Type 'DWord' -Value 4294967294
    Set-RegistryValueRaw -Path 'HKLM:\SOFTWARE\Test' -Name 'Exp' -Type 'ExpandString' -Value '%TEMP%\x'
    Set-RealisticStartingState
    $before = Get-FakeSnapshot
    [void](Invoke-Tweaks -Tweaks ($allTweaks + $odd))
    Initialize-BackupStore -Path $script:BackupFile   # reload from disk, as a new session would
    Assert-True ((Get-BackupCount) -gt 50) 'backup not reloaded'
    [void](Invoke-Undo)
    Assert-Equal $before (Get-FakeSnapshot) 'state after reload + undo differs'
}

It 'undo can be limited to some tweaks' {
    Set-RealisticStartingState
    $before = Get-FakeSnapshot
    [void](Invoke-Tweaks -Tweaks $allTweaks)
    [void](Invoke-Undo -TweakIds 'edge.*')
    Assert-True (-not (Get-RegistryValueState -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name 'HubsSidebarEnabled').Exists) 'Edge policy not undone'
    Assert-Equal 0 (Get-RegistryValueState -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry').Value 'non-Edge tweak was undone too'
    Assert-True ((Get-BackedUpTweakIds) -notcontains 'edge.copilot') 'undone tweak still in backup'
    [void](Invoke-Undo)
    Assert-Equal $before (Get-FakeSnapshot) 'full undo after partial undo differs'
}

It 'dry run changes nothing and records nothing' {
    Set-RealisticStartingState
    $before = Get-FakeSnapshot
    $result = Invoke-Tweaks -Tweaks $allTweaks -DryRun
    Assert-True ($result.Changed -gt 50) "dry run reported only $($result.Changed) changes"
    Assert-Equal $before (Get-FakeSnapshot) 'dry run changed state'
    Assert-Equal 0 (Get-BackupCount) 'dry run wrote a backup'
}

It 'a failing change is reported and the rest still apply' {
    Set-RealisticStartingState
    $script:FailPaths = @('HKLM:\SOFTWARE\Policies\Microsoft\Edge')
    $result = Invoke-Tweaks -Tweaks $allTweaks
    Assert-True ($result.Failed -gt 0) 'failure not reported'
    Assert-Equal 0 (Get-RegistryValueState -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry').Value 'other tweaks did not apply'
}

It 'per-user values go to the target user and are skipped on undo if that user is not signed in' {
    $script:TargetUserSid = 'S-1-5-21-1000-2002'
    Add-FakeKey (Get-FakeKeyName 'HKCU:\Software' $script:TargetUserSid)
    $t = @($tweaks | Where-Object { $_.Id -eq 'ui.file-extensions' })
    [void](Invoke-Tweaks -Tweaks $t)
    Assert-Equal 0 (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Sid 'S-1-5-21-1000-2002').Value 'value not written to the target user'
    Assert-True (-not (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Sid $script:TestSid).Exists) 'value leaked into the elevated user'
    # That user signs out: their hive is unloaded.
    foreach ($k in @($script:FakeKeys.Keys | Where-Object { $_ -like 's-1-5-21-1000-2002|*' })) { $script:FakeKeys.Remove($k) }
    $undo = Invoke-Undo
    Assert-Equal 1 $undo.Skipped 'entry for signed-out user not skipped'
    Assert-Equal 1 (Get-BackupCount) 'skipped entry should stay in the backup'
}

# ---------------------------------------------------------------------------
Write-Host 'Apps'

It 'removes selected apps for all users, deprovisions them, and never touches core packages' {
    $script:FakeInstalled = @(
        New-FakePackage 'Microsoft.BingNews'
        New-FakePackage 'Microsoft.Copilot'
        New-FakePackage 'king.com.CandyCrushSaga'
        New-FakePackage 'Microsoft.GamingApp'
        New-FakePackage 'Microsoft.WindowsStore'
        New-FakePackage 'Microsoft.Paint'
        New-FakePackage 'Microsoft.BingWeather' -NonRemovable
        New-FakePackage 'Microsoft.VCLibs.140.00' -Framework
        New-FakePackage 'Microsoft.BingFinance' -Framework
    )
    $script:FakeProvisioned = @(
        [pscustomobject]@{ DisplayName = 'Microsoft.BingNews'; PackageName = 'Microsoft.BingNews_1_neutral' }
        [pscustomobject]@{ DisplayName = 'Microsoft.WindowsStore'; PackageName = 'Microsoft.WindowsStore_1_neutral' }
    )
    $selected = @(Select-CatalogItems -Catalog $apps -Preset 'Recommended' -Exclude 'app.onedrive')
    $result = Invoke-AppRemoval -Apps $selected
    $left = @($script:FakeInstalled | ForEach-Object { $_.Name })
    foreach ($gone in 'Microsoft.BingNews', 'Microsoft.Copilot', 'king.com.CandyCrushSaga') { Assert-True ($left -notcontains $gone) "$gone not removed" }
    foreach ($kept in 'Microsoft.GamingApp', 'Microsoft.WindowsStore', 'Microsoft.Paint', 'Microsoft.BingWeather', 'Microsoft.VCLibs.140.00', 'Microsoft.BingFinance') { Assert-True ($left -contains $kept) "$kept was removed" }
    Assert-Equal 'Microsoft.WindowsStore' (@($script:FakeProvisioned | ForEach-Object { $_.DisplayName }) -join ',') 'deprovisioning wrong'
    Assert-Equal 0 $result.Failed 'app removal reported failures'
}

It 'app dry run removes nothing' {
    $script:FakeInstalled = @(New-FakePackage 'Microsoft.BingNews')
    $result = Invoke-AppRemoval -Apps @($apps | Where-Object { $_.Id -eq 'app.bing-apps' }) -DryRun
    Assert-Equal 1 $result.Changed
    Assert-Equal 1 @($script:FakeInstalled).Count 'dry run removed a package'
}

# ---------------------------------------------------------------------------
Write-Host ''
$color = if ($script:Failed -gt 0) { 'Red' } else { 'Green' }
Write-Host ('{0} passed, {1} failed' -f $script:Passed, $script:Failed) -ForegroundColor $color
Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Filter 'debloatify-test-*.json' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
if ($script:Failed -gt 0) { exit 1 }
exit 0
