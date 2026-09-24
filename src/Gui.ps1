# Graphical interface (WPF - part of Windows, nothing to install).
# Everything slow runs in src/GuiWorker.ps1 on a background runspace; a timer on the
# window's thread drains its log queue and calls the completion step when it finishes.
# Button handlers are plain functions (Invoke-GuiApply, ...) so tests can drive them.

$script:Gui = $null

$script:GuiXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="DeBloatify" Width="1120" Height="820" MinWidth="760" MinHeight="520"
        WindowStartupLocation="CenterScreen" Background="#F3F3F3"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" Foreground="#1B1B1B">
  <Window.Resources>
    <SolidColorBrush x:Key="Accent" Color="#0067C0"/>
    <SolidColorBrush x:Key="Muted" Color="#5F5F5F"/>
    <Style TargetType="Button">
      <Setter Property="Padding" Value="16,7"/>
      <Setter Property="Margin" Value="8,0,0,0"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="#CFCFCF"/>
      <Setter Property="Foreground" Value="#1B1B1B"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.85"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.7"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bd" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#0067C0"/>
      <Setter Property="BorderBrush" Value="#0067C0"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="#E3E3E3"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="8"/>
      <Setter Property="Padding" Value="16,14"/>
    </Style>
    <Style x:Key="CardTitle" TargetType="TextBlock">
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,6"/>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Padding" Value="18,7"/>
      <Setter Property="FontSize" Value="14"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="VerticalContentAlignment" Value="Top"/>
    </Style>
  </Window.Resources>

  <Grid Margin="20,16,20,12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="3*"/>
      <RowDefinition Height="*" MinHeight="100" MaxHeight="200"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Grid Grid.Row="0" Margin="0,0,0,12">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel>
        <TextBlock Text="DeBloatify" FontSize="26" FontWeight="SemiBold"/>
        <TextBlock Foreground="{StaticResource Muted}" TextWrapping="Wrap"
                   Text="Remove ads, Bing, Copilot, telemetry and junk apps, and fix common Windows 11 problems. Every setting can be undone."/>
      </StackPanel>
      <TextBlock x:Name="SystemInfo" Grid.Column="1" Foreground="{StaticResource Muted}" TextAlignment="Right" VerticalAlignment="Top" Margin="16,4,0,0"/>
    </Grid>

    <TabControl x:Name="Tabs" Grid.Row="1" Background="Transparent" BorderThickness="0" Padding="0,10,0,0">
      <TabItem Header="Debloat">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Border Style="{StaticResource Card}" Padding="14,6,14,10" Margin="0,0,0,10">
            <WrapPanel>
              <TextBlock Text="Start from a preset:" VerticalAlignment="Center" Margin="0,4,0,0"/>
              <Button x:Name="PresetMinimal" Content="Minimal" Margin="8,4,0,0" ToolTip="Settings only: ads, Bing, Copilot, telemetry. Removes no apps."/>
              <Button x:Name="PresetRecommended" Content="Recommended" Margin="8,4,0,0" ToolTip="Minimal plus junk and promo apps, more privacy and the fixes. Best for most people."/>
              <Button x:Name="PresetAggressive" Content="Aggressive" Margin="8,4,0,0" ToolTip="Recommended plus Xbox, OneDrive, Phone Link, Outlook, Teams and more."/>
              <Button x:Name="PresetClear" Content="Clear all" Margin="8,4,24,0"/>
              <TextBlock x:Name="SelectionSummary" VerticalAlignment="Center" Margin="0,4,0,0" Foreground="{StaticResource Muted}"/>
            </WrapPanel>
          </Border>
          <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="3*"/>
              <ColumnDefinition Width="12"/>
              <ColumnDefinition Width="2*"/>
            </Grid.ColumnDefinitions>
            <Border Style="{StaticResource Card}">
              <DockPanel>
                <TextBlock DockPanel.Dock="Top" Text="Settings to change" Style="{StaticResource CardTitle}"/>
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                  <StackPanel x:Name="TweakPanel" Margin="0,0,10,0"/>
                </ScrollViewer>
              </DockPanel>
            </Border>
            <Border Grid.Column="2" Style="{StaticResource Card}">
              <DockPanel>
                <TextBlock DockPanel.Dock="Top" Text="Apps to remove" Style="{StaticResource CardTitle}"/>
                <TextBlock DockPanel.Dock="Top" Foreground="{StaticResource Muted}" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,6"
                           Text="Removed for every account on this PC. You can reinstall any of them from the Microsoft Store."/>
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                  <StackPanel x:Name="AppPanel" Margin="0,0,10,0"/>
                </ScrollViewer>
              </DockPanel>
            </Border>
          </Grid>
          <DockPanel Grid.Row="2" Margin="0,10,0,0">
            <CheckBox x:Name="RestorePointBox" Content="Create a restore point first (recommended)" IsChecked="True" VerticalAlignment="Center" VerticalContentAlignment="Center"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
              <Button x:Name="PreviewButton" Content="Preview changes" ToolTip="List what would change, without changing anything."/>
              <Button x:Name="ApplyButton" Content="Apply" Style="{StaticResource AccentButton}" MinWidth="120"/>
            </StackPanel>
          </DockPanel>
        </Grid>
      </TabItem>

      <TabItem Header="Repair">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Border Style="{StaticResource Card}">
            <DockPanel>
              <TextBlock DockPanel.Dock="Top" Text="Fix common problems" Style="{StaticResource CardTitle}"/>
              <TextBlock DockPanel.Dock="Top" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,0,0,8"
                         Text="One-off fixes that use Windows' own repair tools. Tick what you need and press Run. These don't change any of your settings."/>
              <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel x:Name="RepairPanel" Margin="0,0,10,0"/>
              </ScrollViewer>
            </DockPanel>
          </Border>
          <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="RunRepairsButton" Content="Run selected repairs" Style="{StaticResource AccentButton}"/>
          </StackPanel>
        </Grid>
      </TabItem>

      <TabItem Header="Undo">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Border Style="{StaticResource Card}">
            <DockPanel>
              <TextBlock DockPanel.Dock="Top" Text="Put settings back" Style="{StaticResource CardTitle}"/>
              <TextBlock x:Name="UndoSummary" DockPanel.Dock="Top" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,0,0,8"/>
              <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel x:Name="UndoPanel" Margin="0,0,10,0"/>
              </ScrollViewer>
            </DockPanel>
          </Border>
          <DockPanel Grid.Row="1" Margin="0,10,0,0">
            <Button x:Name="SystemRestoreButton" Content="Open System Restore" Margin="0" ToolTip="Roll the whole PC back to a restore point, including removed apps."/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
              <Button x:Name="UndoSelectedButton" Content="Undo selected"/>
              <Button x:Name="UndoAllButton" Content="Undo everything" Style="{StaticResource AccentButton}"/>
            </StackPanel>
          </DockPanel>
        </Grid>
      </TabItem>
    </TabControl>

    <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,12,0,0" Padding="14,10">
      <DockPanel>
        <DockPanel DockPanel.Dock="Top" Margin="0,0,0,4">
          <CheckBox x:Name="ShowDetailsBox" DockPanel.Dock="Right" Content="Show details" VerticalContentAlignment="Center"/>
          <TextBlock Text="Activity" FontWeight="SemiBold"/>
        </DockPanel>
        <TextBox x:Name="LogBox" IsReadOnly="True" BorderThickness="0" Background="White" FontFamily="Cascadia Mono, Consolas"
                 FontSize="12" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
      </DockPanel>
    </Border>

    <Grid Grid.Row="3" Margin="2,8,2,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="220"/>
      </Grid.ColumnDefinitions>
      <TextBlock x:Name="StatusText" Foreground="{StaticResource Muted}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
      <ProgressBar x:Name="Progress" Grid.Column="1" Height="6" Visibility="Hidden"/>
    </Grid>
  </Grid>
</Window>
'@

# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

function Initialize-GuiAssemblies {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
}

function New-GuiWindow {
    Initialize-GuiAssemblies
    $window = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$script:GuiXaml)))
    $controls = @{}
    foreach ($m in [regex]::Matches($script:GuiXaml, 'x:Name="([^"]+)"')) {
        $name = $m.Groups[1].Value
        $control = $window.FindName($name)
        if ($control) { $controls[$name] = $control }
    }
    @{ Window = $window; Controls = $controls }
}

function Set-GuiWindowSize {
    # Fit the window inside the usable screen area (small laptops, 125-150% scaling), so nothing
    # is cut off at the right or bottom.
    param([Parameter(Mandatory)]$Window)
    $area = [System.Windows.SystemParameters]::WorkArea
    $Window.MinWidth = [math]::Min($Window.MinWidth, $area.Width)
    $Window.MinHeight = [math]::Min($Window.MinHeight, $area.Height)
    $Window.Width = [math]::Max($Window.MinWidth, [math]::Min($Window.Width, $area.Width - 24))
    $Window.Height = [math]::Max($Window.MinHeight, [math]::Min($Window.Height, $area.Height - 24))
}

function New-GuiBrush {
    param([Parameter(Mandatory)][string]$Color)
    (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Color)
}

function New-GuiText {
    param([string]$Text, [double]$Size = 13, [string]$Color = '#1B1B1B', [switch]$Bold, [switch]$Wrap)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.FontSize = $Size
    $t.Foreground = New-GuiBrush $Color
    if ($Bold) { $t.FontWeight = [System.Windows.FontWeights]::SemiBold }
    if ($Wrap) { $t.TextWrapping = 'Wrap' }
    $t
}

function New-GuiBadge {
    param([Parameter(Mandatory)][string]$Level)
    $colors = @{
        Minimal     = @('#E6F4EA', '#1E6B34')
        Recommended = @('#E6F4EA', '#1E6B34')
        Aggressive  = @('#FDF0E1', '#8A4B00')
        Optional    = @('#EEEEEE', '#555555')
    }
    $c = $colors[$Level]
    if (-not $c) { $c = $colors.Optional }
    $border = New-Object System.Windows.Controls.Border
    $border.Background = New-GuiBrush $c[0]
    $border.CornerRadius = New-Object System.Windows.CornerRadius(4)
    $border.Padding = New-Object System.Windows.Thickness(6, 0, 6, 1)
    $border.Margin = New-Object System.Windows.Thickness(8, 1, 0, 0)
    $border.VerticalAlignment = 'Center'
    $border.Child = New-GuiText -Text $Level -Size 11 -Color $c[1]
    $border
}

function New-GuiOption {
    # One checkbox row: bold name, level badge, optional grey description underneath.
    param([Parameter(Mandatory)]$Item, [string]$Detail, [string]$Tooltip)
    $header = New-Object System.Windows.Controls.WrapPanel
    [void]$header.Children.Add((New-GuiText -Text $Item.Name -Bold -Wrap))
    if ($Item.Level) { [void]$header.Children.Add((New-GuiBadge -Level $Item.Level)) }
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = New-Object System.Windows.Thickness(4, 0, 0, 0)
    [void]$stack.Children.Add($header)
    if ($Detail) {
        $d = New-GuiText -Text $Detail -Size 12 -Color '#5F5F5F' -Wrap
        $d.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
        [void]$stack.Children.Add($d)
    }
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $stack
    $cb.Tag = $Item.Id
    $cb.Margin = New-Object System.Windows.Thickness(0, 5, 0, 5)
    if ($Tooltip) { $cb.ToolTip = $Tooltip }
    $cb
}

function Add-GuiOptions {
    param([Parameter(Mandatory)]$Panel, [object[]]$Items, [switch]$ShowDescription, [switch]$ShowPackages)
    $Panel.Children.Clear()
    $category = $null
    foreach ($item in @($Items | Where-Object { $_ })) {
        if ($item.Category -and $item.Category -ne $category) {
            $h = New-GuiText -Text $item.Category -Size 13 -Color '#0067C0' -Bold
            $top = if ($null -eq $category) { 2 } else { 14 }
            $h.Margin = New-Object System.Windows.Thickness(0, $top, 0, 2)
            [void]$Panel.Children.Add($h)
            $category = $item.Category
        }
        $detail = if ($ShowDescription) { $item.Description } else { $null }
        $tooltip = if ($ShowPackages -and $item.Packages) { 'Packages: ' + ($item.Packages -join ', ') } else { $null }
        $cb = New-GuiOption -Item $item -Detail $detail -Tooltip $tooltip
        $cb.Add_Click({ Update-GuiSelectionSummary })
        [void]$Panel.Children.Add($cb)
    }
}

function Get-GuiChecked {
    param([Parameter(Mandatory)]$Panel)
    @($Panel.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.IsChecked } | ForEach-Object { [string]$_.Tag })
}

function Set-GuiChecked {
    param([Parameter(Mandatory)]$Panel, [string[]]$Ids)
    foreach ($child in $Panel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox]) { $child.IsChecked = (@($Ids) -contains [string]$child.Tag) }
    }
}

# ---------------------------------------------------------------------------
# State, log and messages
# ---------------------------------------------------------------------------

function Show-GuiMessage {
    # Returns $true for OK/Yes. In test mode no dialog is shown and $TestAnswer is returned.
    param([Parameter(Mandatory)][string]$Text, [ValidateSet('Info', 'Warn', 'Error', 'Question')][string]$Kind = 'Info', [switch]$YesNo, [bool]$TestAnswer = $true)
    if ($script:Gui -and $script:Gui.TestMode) { return $TestAnswer }
    Initialize-GuiAssemblies
    $icon = @{ Info = 'Information'; Warn = 'Warning'; Error = 'Error'; Question = 'Question' }[$Kind]
    $buttons = if ($YesNo) { 'YesNo' } else { 'OK' }
    if ($script:Gui -and $script:Gui.Window) {
        $answer = [System.Windows.MessageBox]::Show($script:Gui.Window, $Text, 'DeBloatify', $buttons, $icon)
    } else {
        $answer = [System.Windows.MessageBox]::Show($Text, 'DeBloatify', $buttons, $icon)
    }
    ($answer -eq 'Yes' -or $answer -eq 'OK')
}

function Format-GuiLogLine {
    param([string]$Level, [string]$Message)
    switch ($Level) {
        'Step' { return ('-- {0} --' -f $Message) }
        'Ok' { return ('  +  {0}' -f $Message) }
        'Warn' { return ('  !  {0}' -f $Message) }
        'Error' { return ('  x  {0}' -f $Message) }
        'Detail' { return ('       {0}' -f $Message) }
        default { return ('     {0}' -f $Message) }
    }
}

function Add-GuiLog {
    param([string]$Level, [string]$Message)
    [void]$script:Gui.LogLines.Add(@($Level, $Message))
    if ($Level -eq 'Detail' -and -not $script:Gui.Controls.ShowDetailsBox.IsChecked) { return }
    $box = $script:Gui.Controls.LogBox
    if ($box.Text.Length -gt 0) { $box.AppendText("`r`n") }
    $box.AppendText((Format-GuiLogLine -Level $Level -Message $Message))
    $box.ScrollToEnd()
}

function Update-GuiLogView {
    $showDetails = [bool]$script:Gui.Controls.ShowDetailsBox.IsChecked
    $lines = foreach ($l in $script:Gui.LogLines) {
        if ($l[0] -ne 'Detail' -or $showDetails) { Format-GuiLogLine -Level $l[0] -Message $l[1] }
    }
    $script:Gui.Controls.LogBox.Text = (@($lines) -join "`r`n")
    $script:Gui.Controls.LogBox.ScrollToEnd()
}

function Set-GuiStatus {
    param([string]$Text)
    $script:Gui.Controls.StatusText.Text = $Text
}

function Set-GuiBusy {
    param([bool]$Busy, [string]$Status)
    $names = 'PresetMinimal', 'PresetRecommended', 'PresetAggressive', 'PresetClear', 'PreviewButton', 'ApplyButton',
    'RestorePointBox', 'TweakPanel', 'AppPanel', 'RepairPanel', 'RunRepairsButton', 'UndoPanel', 'UndoSelectedButton', 'UndoAllButton'
    foreach ($n in $names) { $script:Gui.Controls[$n].IsEnabled = -not $Busy }
    $script:Gui.Controls.Progress.IsIndeterminate = $Busy
    $script:Gui.Controls.Progress.Visibility = if ($Busy) { 'Visible' } else { 'Hidden' }
    if ($Status) { Set-GuiStatus $Status }
}

function Update-GuiSelectionSummary {
    $c = $script:Gui.Controls
    $t = @(Get-GuiChecked $c.TweakPanel).Count
    $a = @(Get-GuiChecked $c.AppPanel).Count
    $c.SelectionSummary.Text = '{0} of {1} settings and {2} of {3} apps selected' -f $t, @($script:Gui.Context.Tweaks).Count, $a, @($script:Gui.Context.Apps).Count
}

function Set-GuiPreset {
    param([string]$Preset)
    $tweaks = @()
    $apps = @()
    if ($Preset) {
        $tweaks = @(Select-CatalogItems -Catalog $script:Gui.Context.Tweaks -Preset $Preset | ForEach-Object { $_.Id })
        $apps = @(Select-CatalogItems -Catalog $script:Gui.Context.Apps -Preset $Preset | ForEach-Object { $_.Id })
    }
    Set-GuiChecked $script:Gui.Controls.TweakPanel $tweaks
    Set-GuiChecked $script:Gui.Controls.AppPanel $apps
    Update-GuiSelectionSummary
}

function Update-GuiUndoTab {
    Initialize-BackupStore -Path $script:BackupPath
    $ids = @(Get-BackedUpTweakIds)
    $items = foreach ($id in $ids) {
        $t = @($script:Gui.Context.Tweaks | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
        if ($t) { $t } else { Complete-CatalogItem @{ Id = $id; Name = $id; Category = 'Other'; Level = '' } }
    }
    Add-GuiOptions -Panel $script:Gui.Controls.UndoPanel -Items @($items)
    $script:Gui.Controls.UndoSummary.Text = if ($ids.Count -eq 0) {
        "Nothing to undo: DeBloatify hasn't changed any settings on this PC (or they have all been put back). Removed apps can be reinstalled from the Microsoft Store."
    } else {
        "DeBloatify has recorded {0} change(s) from these {1} setting(s). Tick the ones to put back, or undo everything. Removed apps are not brought back by Undo - reinstall them from the Microsoft Store, or use System Restore." -f (Get-BackupCount), $ids.Count
    }
}

# ---------------------------------------------------------------------------
# Background operations
# ---------------------------------------------------------------------------

function New-GuiSync {
    # Shared between the window and the worker: log queue, result and error.
    [hashtable]::Synchronized(@{
            Queue  = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
            Result = $null
            Error  = $null
        })
}

function New-GuiWorker {
    # A PowerShell instance, in its own runspace, set up to run src/GuiWorker.ps1.
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Operation, [hashtable]$Options = @{}, [Parameter(Mandatory)]$Sync)
    $state = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    # Run the worker script regardless of the machine's policy (the launcher already used Bypass).
    if ([System.Environment]::OSVersion.Platform -eq 'Win32NT') { $state.ExecutionPolicy = 'Bypass' }
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($state)
    $runspace.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    $worker = Join-Path (Join-Path $Root 'src') 'GuiWorker.ps1'
    [void]$ps.AddCommand($worker).AddParameter('Root', $Root).AddParameter('Sync', $Sync).AddParameter('Operation', $Operation).AddParameter('Options', $Options)
    $ps
}

function Start-GuiOperation {
    param([Parameter(Mandatory)][string]$Operation, [hashtable]$Options = @{}, [string]$Status, [scriptblock]$OnComplete)
    $sync = New-GuiSync
    $Options.LogFile = $script:LogFile
    $Options.BackupPath = $script:BackupPath
    $Options.TargetUserSid = $script:TargetUserSid
    $Options.NoRestartExplorer = [bool]$script:Gui.Context.NoRestartExplorer
    if ($script:Gui.TestHook) { $Options.TestHook = $script:Gui.TestHook }
    $ps = New-GuiWorker -Root $script:Gui.Context.Root -Operation $Operation -Options $Options -Sync $sync
    $script:Gui.Job = @{ PowerShell = $ps; Runspace = $ps.Runspace; Handle = $ps.BeginInvoke(); Sync = $sync; OnComplete = $OnComplete }
    Set-GuiBusy -Busy $true -Status $Status
    $script:Gui.Timer.Start()
}

function Receive-GuiQueue {
    param($Sync)
    $line = $null
    while ($Sync.Queue.TryDequeue([ref]$line)) {
        $i = $line.IndexOf('|')
        Add-GuiLog -Level $line.Substring(0, $i) -Message $line.Substring($i + 1)
    }
}

function Receive-GuiWorker {
    # Timer tick: show new log lines; when the worker is done, clean up and run the completion step.
    $job = $script:Gui.Job
    if (-not $job) { $script:Gui.Timer.Stop(); return }
    Receive-GuiQueue $job.Sync
    if (-not $job.Handle.IsCompleted) { return }

    $script:Gui.Timer.Stop()
    $script:Gui.Job = $null
    try {
        [void]$job.PowerShell.EndInvoke($job.Handle)
    } catch {
        if (-not $job.Sync.Error) { $job.Sync.Error = $_.Exception.Message }
    }
    foreach ($e in @($job.PowerShell.Streams.Error)) { Add-GuiLog -Level 'Detail' -Message ([string]$e) }
    Receive-GuiQueue $job.Sync
    $job.PowerShell.Dispose()
    $job.Runspace.Dispose()
    Set-GuiBusy -Busy $false

    if ($job.Sync.Error) {
        Set-GuiStatus 'Something went wrong - see the activity log.'
        Show-GuiMessage -Text ("Something went wrong:`n`n{0}`n`nLog file: {1}" -f $job.Sync.Error, $script:LogFile) -Kind Error | Out-Null
        return
    }
    if ($job.OnComplete) { & $job.OnComplete $job.Sync }
}

function Invoke-GuiHandler {
    # Wraps button handlers so an unexpected error shows a message instead of killing the window.
    param([Parameter(Mandatory)][scriptblock]$Body)
    try {
        & $Body
    } catch {
        Add-GuiLog -Level 'Error' -Message $_.Exception.Message
        Show-GuiMessage -Text ("Something went wrong:`n`n{0}" -f $_.Exception.Message) -Kind Error | Out-Null
    }
}

function Format-GuiResult {
    param($Result, [string]$Done = 'Done')
    '{0}. {1} changed, {2} already set, {3} failed.' -f $Done, $Result.Changed, $Result.Unchanged, $Result.Failed
}

# ---------------------------------------------------------------------------
# Actions (what the buttons do)
# ---------------------------------------------------------------------------

function Invoke-GuiApply {
    param([switch]$Preview)
    $c = $script:Gui.Controls
    $tweakIds = @(Get-GuiChecked $c.TweakPanel)
    $appIds = @(Get-GuiChecked $c.AppPanel)
    if ($tweakIds.Count + $appIds.Count -eq 0) {
        Show-GuiMessage -Text 'Nothing is selected. Pick a preset or tick some items first.' | Out-Null
        return
    }
    $script:Gui.Pending = @{ TweakIds = $tweakIds; AppIds = $appIds }

    if ($Preview) {
        Add-GuiLog -Level 'Step' -Message 'Preview (nothing will be changed)'
        Start-GuiOperation -Operation 'Preview' -Options @{ TweakIds = $tweakIds; AppIds = $appIds } -Status 'Checking what would change...' -OnComplete {
            param($Sync)
            $r = $Sync.Result
            Set-GuiStatus ('Preview: {0} change(s) would be made, {1} already in place. Nothing was changed.' -f $r.Changed, $r.Unchanged)
        }
        return
    }

    $question = "Apply {0} setting(s) and remove {1} app group(s)?`n`nSettings can be put back later on the Undo tab. Removed apps can be reinstalled from the Microsoft Store." -f $tweakIds.Count, $appIds.Count
    if (-not (Show-GuiMessage -Text $question -Kind Question -YesNo)) { return }
    if ($c.RestorePointBox.IsChecked) {
        Start-GuiOperation -Operation 'RestorePoint' -Status 'Creating a restore point (this can take a minute)...' -OnComplete {
            param($Sync)
            if (-not $Sync.Result) {
                $text = "Windows could not create a restore point (see the activity log).`n`nContinue anyway? DeBloatify's own Undo still works for settings."
                if (-not (Show-GuiMessage -Text $text -Kind Warn -YesNo)) { Set-GuiStatus 'Cancelled.'; return }
            }
            Start-GuiApplyStep
        }
    } else {
        Start-GuiApplyStep
    }
}

function Start-GuiApplyStep {
    $p = $script:Gui.Pending
    Start-GuiOperation -Operation 'Apply' -Options @{ TweakIds = $p.TweakIds; AppIds = $p.AppIds } -Status 'Applying changes...' -OnComplete {
        param($Sync)
        Update-GuiUndoTab
        $r = $Sync.Result
        $text = Format-GuiResult $r
        Set-GuiStatus $text
        if ($r.Failed -gt 0) { $text += "`n`nSome changes failed. Tick 'Show details' under Activity to see why." }
        if ($r.Changed -gt 0) {
            if (Show-GuiMessage -Text "$text`n`nRestart now so every change takes effect?" -Kind Question -YesNo -TestAnswer $false) { Restart-Computer -Force }
        } else {
            Show-GuiMessage -Text $text | Out-Null
        }
    }
}

function Invoke-GuiRepairs {
    $ids = @(Get-GuiChecked $script:Gui.Controls.RepairPanel)
    if ($ids.Count -eq 0) {
        Show-GuiMessage -Text 'Tick at least one repair first.' | Out-Null
        return
    }
    $text = "Run {0} repair(s)?`n`nSome take a while - repairing system files can take 30 minutes. You can keep using the PC meanwhile." -f $ids.Count
    if (-not (Show-GuiMessage -Text $text -Kind Question -YesNo)) { return }
    Start-GuiOperation -Operation 'Repair' -Options @{ RepairIds = $ids } -Status 'Running repairs...' -OnComplete {
        param($Sync)
        $r = $Sync.Result
        $text = if ($r.Failed -gt 0) { '{0} repair(s) finished, {1} failed - see the activity log.' -f $r.Changed, $r.Failed } else { 'Repairs finished.' }
        Set-GuiStatus $text
        if ($r.Reboot) {
            if (Show-GuiMessage -Text "$text`n`nA restart is needed to finish. Restart now?" -Kind Question -YesNo -TestAnswer $false) { Restart-Computer -Force }
        } else {
            Show-GuiMessage -Text $text | Out-Null
        }
    }
}

function Invoke-GuiUndo {
    param([switch]$All)
    if ((Get-BackupCount) -eq 0) {
        Show-GuiMessage -Text 'Nothing to undo - DeBloatify has no recorded changes on this PC.' | Out-Null
        return
    }
    $ids = @()
    if (-not $All) {
        $ids = @(Get-GuiChecked $script:Gui.Controls.UndoPanel)
        if ($ids.Count -eq 0) {
            Show-GuiMessage -Text "Tick the settings to put back first, or use 'Undo everything'." | Out-Null
            return
        }
    }
    $what = if ($All) { 'every setting DeBloatify changed' } else { '{0} selected setting(s)' -f $ids.Count }
    if (-not (Show-GuiMessage -Text "Put back $what?" -Kind Question -YesNo)) { return }
    Start-GuiOperation -Operation 'Undo' -Options @{ TweakIds = $ids } -Status 'Putting settings back...' -OnComplete {
        param($Sync)
        Update-GuiUndoTab
        $r = $Sync.Result
        $text = Format-GuiResult $r 'Undo finished'
        Set-GuiStatus $text
        if ($r.Changed -gt 0) {
            if (Show-GuiMessage -Text "$text`n`nRestart now so every change takes effect?" -Kind Question -YesNo -TestAnswer $false) { Restart-Computer -Force }
        } else {
            Show-GuiMessage -Text $text | Out-Null
        }
    }
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

function Show-DeBloatifyGui {
    # Context: Tweaks, Apps, Repairs (catalogs), Root (repo folder), Windows (Get-WindowsInfo), NoRestartExplorer.
    # TestScript runs once the window is on screen (used by tests/GuiSmoke.ps1).
    param([Parameter(Mandatory)][hashtable]$Context, [switch]$TestMode, [string]$TestHook, [scriptblock]$TestScript)
    $ui = New-GuiWindow
    $script:Gui = @{
        Window   = $ui.Window
        Controls = $ui.Controls
        Context  = $Context
        LogLines = New-Object System.Collections.ArrayList
        Job      = $null
        Pending  = $null
        Timer    = $null
        TestMode = [bool]$TestMode
        TestHook = $TestHook
    }
    $c = $script:Gui.Controls
    $script:Gui.Window.Title = 'DeBloatify {0}' -f $script:Version
    Set-GuiWindowSize -Window $script:Gui.Window

    $w = $Context.Windows
    if ($w) {
        $version = if ($w.DisplayVersion) { " ($($w.DisplayVersion))" } else { '' }
        $c.SystemInfo.Text = "Windows build {0}{1}`n{2}" -f $w.Build, $version, $w.Edition
    }

    Add-GuiOptions -Panel $c.TweakPanel -Items $Context.Tweaks -ShowDescription
    Add-GuiOptions -Panel $c.AppPanel -Items $Context.Apps -ShowPackages
    Add-GuiOptions -Panel $c.RepairPanel -Items $Context.Repairs -ShowDescription
    Update-GuiUndoTab
    Set-GuiPreset 'Recommended'
    Set-GuiStatus 'Ready. The Recommended preset is selected - press Preview to see what it changes, or Apply.'
    if ($script:LogFile) { Add-GuiLog -Level 'Detail' -Message "Log file: $script:LogFile" }

    $c.PresetMinimal.Add_Click({ Invoke-GuiHandler { Set-GuiPreset 'Minimal' } })
    $c.PresetRecommended.Add_Click({ Invoke-GuiHandler { Set-GuiPreset 'Recommended' } })
    $c.PresetAggressive.Add_Click({ Invoke-GuiHandler { Set-GuiPreset 'Aggressive' } })
    $c.PresetClear.Add_Click({ Invoke-GuiHandler { Set-GuiPreset '' } })
    $c.PreviewButton.Add_Click({ Invoke-GuiHandler { Invoke-GuiApply -Preview } })
    $c.ApplyButton.Add_Click({ Invoke-GuiHandler { Invoke-GuiApply } })
    $c.RunRepairsButton.Add_Click({ Invoke-GuiHandler { Invoke-GuiRepairs } })
    $c.UndoSelectedButton.Add_Click({ Invoke-GuiHandler { Invoke-GuiUndo } })
    $c.UndoAllButton.Add_Click({ Invoke-GuiHandler { Invoke-GuiUndo -All } })
    $c.SystemRestoreButton.Add_Click({ Invoke-GuiHandler { Start-Process rstrui.exe } })
    $c.ShowDetailsBox.Add_Click({ Invoke-GuiHandler { Update-GuiLogView } })

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(150)
    $timer.Add_Tick({ Invoke-GuiHandler { Receive-GuiWorker } })
    $script:Gui.Timer = $timer

    $script:Gui.Window.Add_Closing({
            param($sender, $e)
            if ($script:Gui.Job) {
                $text = "DeBloatify is still working. Closing now can leave a change half-done.`n`nClose anyway?"
                if (-not (Show-GuiMessage -Text $text -Kind Warn -YesNo)) { $e.Cancel = $true }
            }
        })
    if ($TestScript) { $script:Gui.Window.Add_ContentRendered($TestScript) }

    [void]$script:Gui.Window.ShowDialog()
    $timer.Stop()
}
