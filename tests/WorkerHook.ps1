# Test hook for src/GuiWorker.ps1 (passed as $Options.TestHook). Swaps in the fake system
# and binds it to the test's state through $Options.Shared - hashtables are shared by
# reference between runspaces, so the test sees every change the worker makes.

. (Join-Path $PSScriptRoot 'Fakes.ps1')

$shared = $Options.Shared
$script:TestSid = $shared.Sid
$script:FakeKeys = $shared.Keys
$script:FakeValues = $shared.Values
$script:FakeServices = $shared.Services
$script:FakeTasks = $shared.Tasks
$script:FakeInstalled = @()
$script:FakeProvisioned = @()
$script:FailPaths = @()
$script:LogLines = New-Object System.Collections.ArrayList

# A repair that writes tool output and a log line, to check both reach the window.
function Get-RepairCatalog {
    @(Complete-CatalogItem @{
            Id = 'repair.fake'; Name = 'Fake repair'; Description = 'test'; Reboot = $true
            Action = { 'output from the tool'; Write-Log 'inner message' Info }
        })
}
