# GUI smoke test for disposable Windows CI runners. Opens the real DeBloatify window,
# drives it through the same functions the buttons call (Preview, Apply, Undo, Repair),
# checks the results on the real system and saves screenshots to gui-screenshots/.
#
# It changes real settings (and undoes them), so it refuses to run outside CI.

$ErrorActionPreference = 'Stop'
if ($env:CI -ne 'true') { throw 'GuiSmoke.ps1 changes system settings and only runs on CI (set CI=true to override).' }

$root = Split-Path -Parent $PSScriptRoot
foreach ($file in 'Core.ps1', 'Backup.ps1', 'Engine.ps1', 'Apps.ps1', 'Repairs.ps1', 'Ui.ps1', 'Gui.ps1') {
    . (Join-Path (Join-Path $root 'src') $file)
}
$script:Version = 'smoke-test'
$data = Join-Path $env:ProgramData 'DeBloatify'
Initialize-Logging -Directory (Join-Path $data 'logs')
Initialize-BackupStore -Path (Join-Path $data 'backup.json')
$script:TargetUserSid = Get-CurrentUserSid

$shots = Join-Path $root 'gui-screenshots'
New-Item -ItemType Directory -Path $shots -Force | Out-Null
$script:Checks = New-Object System.Collections.ArrayList

function Test-That([bool]$Condition, [string]$Message) {
    [void]$script:Checks.Add([pscustomobject]@{ Ok = $Condition; Message = $Message })
    if ($Condition) { Write-Host "[pass] $Message" -ForegroundColor Green } else { Write-Host "[FAIL] $Message" -ForegroundColor Red }
}

function Save-Screenshot([string]$Name) {
    $window = $script:Gui.Window
    $window.UpdateLayout()
    $content = $window.Content
    $width = [int][math]::Ceiling($content.ActualWidth + $content.Margin.Left + $content.Margin.Right)
    $height = [int][math]::Ceiling($content.ActualHeight + $content.Margin.Top + $content.Margin.Bottom)
    # Window background first, then the content. Render() already places the content at its
    # margin offset, so it must not be shifted again.
    $background = New-Object System.Windows.Media.DrawingVisual
    $dc = $background.RenderOpen()
    $dc.DrawRectangle($window.Background, $null, (New-Object System.Windows.Rect(0, 0, $width, $height)))
    $dc.Close()
    $bitmap = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($width, $height, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($background)
    $bitmap.Render($content)
    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [System.IO.File]::Create((Join-Path $shots "$Name.png"))
    try { $encoder.Save($stream) } finally { $stream.Close() }
    Write-Host "saved screenshot $Name.png ($width x $height)"

    # Optional: also print a small JPEG into the job log, for reviewers who can't download artifacts.
    if ($env:DEBLOATIFY_PRINT_SCREENSHOTS) {
        $jpeg = New-Object System.Windows.Media.Imaging.JpegBitmapEncoder
        $jpeg.QualityLevel = 80
        $jpeg.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $memory = New-Object System.IO.MemoryStream
        $jpeg.Save($memory)
        $base64 = [Convert]::ToBase64String($memory.ToArray())
        for ($i = 0; $i -lt $base64.Length; $i += 4000) {
            Write-Host ('SHOT {0} {1}' -f $Name, $base64.Substring($i, [math]::Min(4000, $base64.Length - $i)))
        }
    }
}

function Test-FullyVisible([string]$Name) {
    # True when the control lies entirely inside the window's content area (not cut off).
    $content = $script:Gui.Window.Content
    $control = $script:Gui.Controls[$Name]
    $box = $control.TransformToAncestor($content).TransformBounds((New-Object System.Windows.Rect(0, 0, $control.ActualWidth, $control.ActualHeight)))
    ($box.Left -ge -1) -and ($box.Top -ge -1) -and ($box.Right -le $content.ActualWidth + 1) -and ($box.Bottom -le $content.ActualHeight + 1) -and ($control.ActualWidth -gt 0)
}

function Get-LogText { (@($script:Gui.LogLines | ForEach-Object { $_[1] }) -join "`n") }

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'

# Each step runs once the previous background operation has finished.
$script:Steps = New-Object System.Collections.Queue
$script:Steps.Enqueue({
        $c = $script:Gui.Controls
        Test-That (@(Get-GuiChecked $c.TweakPanel).Count -ge 30) 'window opens with the Recommended settings ticked'
        Test-That (@(Get-GuiChecked $c.AppPanel).Count -ge 8) 'window opens with the Recommended apps ticked'
        Test-That ($c.SelectionSummary.Text -match '\d+ of \d+ settings') "selection summary: $($c.SelectionSummary.Text)"
        $window = $script:Gui.Window
        Write-Host ("window {0:N0} x {1:N0}, work area {2:N0} x {3:N0}" -f $window.ActualWidth, $window.ActualHeight, [System.Windows.SystemParameters]::WorkArea.Width, [System.Windows.SystemParameters]::WorkArea.Height)
        foreach ($name in 'ApplyButton', 'PreviewButton', 'SelectionSummary', 'SystemInfo', 'ShowDetailsBox', 'StatusText', 'LogBox') {
            Test-That (Test-FullyVisible $name) "$name is fully visible (not cut off)"
        }
        Save-Screenshot '1-debloat-tab'
        Set-GuiPreset 'Aggressive'
        Test-That (@(Get-GuiChecked $c.AppPanel).Count -gt 20) 'Aggressive preset ticks more apps'
        Invoke-GuiApply -Preview
    })
$script:Steps.Enqueue({
        $c = $script:Gui.Controls
        Test-That ($c.StatusText.Text -like 'Preview:*') "preview finished: $($c.StatusText.Text)"
        Test-That ((Get-LogText) -match 'will apply') 'preview results are listed in the activity log'
        Save-Screenshot '2-preview'
        $script:Before = @(
            Get-RegistryValueState -Path $adv -Name 'HideFileExt'
            Get-RegistryValueState -Path $edge -Name 'EdgeShoppingAssistantEnabled'
        )
        Set-GuiChecked $c.TweakPanel @('ui.file-extensions', 'edge.shopping')
        Set-GuiChecked $c.AppPanel @()
        $c.RestorePointBox.IsChecked = $false
        Invoke-GuiApply
    })
$script:Steps.Enqueue({
        $c = $script:Gui.Controls
        $ext = Get-RegistryValueState -Path $adv -Name 'HideFileExt'
        $shop = Get-RegistryValueState -Path $edge -Name 'EdgeShoppingAssistantEnabled'
        Test-That ($ext.Exists -and $ext.Value -eq 0) 'Apply turned on file extensions'
        Test-That ($shop.Exists -and $shop.Value -eq 0) 'Apply set the Edge shopping policy'
        Test-That ($c.StatusText.Text -like 'Done.*') "apply status: $($c.StatusText.Text)"
        $undoItems = @($c.UndoPanel.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] })
        Test-That ($undoItems.Count -eq 2) "Undo tab lists the 2 applied settings (found $($undoItems.Count))"
        $c.Tabs.SelectedIndex = 2
        $script:Gui.Window.UpdateLayout()
    })
$script:Steps.Enqueue({
        Save-Screenshot '3-undo-tab'
        Invoke-GuiUndo -All
    })
$script:Steps.Enqueue({
        $c = $script:Gui.Controls
        $ext = Get-RegistryValueState -Path $adv -Name 'HideFileExt'
        $shop = Get-RegistryValueState -Path $edge -Name 'EdgeShoppingAssistantEnabled'
        Test-That (($ext.Exists -eq $script:Before[0].Exists) -and ("$($ext.Value)" -eq "$($script:Before[0].Value)")) 'Undo restored the file extension setting'
        Test-That ($shop.Exists -eq $script:Before[1].Exists) 'Undo removed the Edge policy again'
        Test-That (@($c.UndoPanel.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] }).Count -eq 0) 'Undo tab is empty afterwards'
        $c.Tabs.SelectedIndex = 1
        Set-GuiChecked $c.RepairPanel @('repair.wmi')
        $c.ShowDetailsBox.IsChecked = $true
        Update-GuiLogView
        Invoke-GuiRepairs
    })
$script:Steps.Enqueue({
        Test-That ((Get-LogText) -match 'WMI repository is consistent') 'repair tool output appears in the activity log'
        Test-That ($script:Gui.Controls.StatusText.Text -eq 'Repairs finished.') "repair status: $($script:Gui.Controls.StatusText.Text)"
        Save-Screenshot '4-repair-tab'
    })

$driver = {
    $script:SmokeStarted = Get-Date
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(300)
    $timer.Add_Tick({
            param($sender)
            if ($script:Gui.Job) {
                if (((Get-Date) - $script:SmokeStarted).TotalMinutes -gt 8) {
                    Test-That $false 'timed out waiting for a background operation'
                    $sender.Stop()
                    $script:Gui.Window.Close()
                }
                return
            }
            if ($script:Steps.Count -eq 0) {
                $sender.Stop()
                $script:Gui.Window.Close()
                return
            }
            $step = $script:Steps.Dequeue()
            try { & $step } catch {
                Test-That $false "step failed: $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
                $script:Steps.Clear()
            }
        })
    $timer.Start()
}

Show-DeBloatifyGui -TestMode -TestScript $driver -Context @{
    Tweaks            = @(Get-TweakCatalog -Directory (Join-Path (Join-Path $root 'src') 'tweaks'))
    Apps              = @(Get-AppCatalog)
    Repairs           = @(Get-RepairCatalog)
    Root              = $root
    Windows           = Get-WindowsInfo
    NoRestartExplorer = $true
}

$failed = @($script:Checks | Where-Object { -not $_.Ok })
Write-Host ''
if ($script:Checks.Count -lt 22 -or $failed.Count -gt 0) {
    Write-Host ("{0} of {1} GUI checks failed (a full run makes 22 checks)" -f $failed.Count, $script:Checks.Count) -ForegroundColor Red
    exit 1
}
Write-Host "All $($script:Checks.Count) GUI checks passed" -ForegroundColor Green
exit 0
