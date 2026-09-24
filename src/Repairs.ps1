# Repair tools: one-off fixes for common Windows 11 problems. These don't change
# settings, so there is nothing to undo. Each one only uses Windows' own tools.

$script:CaptureNativeOutput = $false   # the GUI worker sets this: there is no console to write to

function Invoke-NativeTool {
    # In the console, Start-Process writes straight to the window, which keeps sfc/dism output
    # readable (piping their UTF-16 output through PowerShell garbles it). In the GUI the output
    # is captured to temp files and sent to the activity log instead.
    param([Parameter(Mandatory, Position = 0)][string]$FilePath, [Parameter(Position = 1)][string[]]$ArgumentList = @())
    Write-Log ('running {0} {1}' -f $FilePath, ($ArgumentList -join ' ')) Detail
    $params = @{ FilePath = $FilePath; Wait = $true; PassThru = $true }
    if ($ArgumentList.Count -gt 0) { $params.ArgumentList = $ArgumentList }
    if (-not $script:CaptureNativeOutput) {
        $p = Start-Process @params -NoNewWindow
        return $p.ExitCode
    }
    $out = [System.IO.Path]::GetTempFileName()
    $err = [System.IO.Path]::GetTempFileName()
    try {
        $p = Start-Process @params -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
        foreach ($file in $out, $err) {
            foreach ($line in @(ConvertFrom-NativeOutput -Bytes ([System.IO.File]::ReadAllBytes($file)))) { Write-Log $line Detail }
        }
        $p.ExitCode
    } finally {
        Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
    }
}

function ConvertFrom-NativeOutput {
    # Turns captured tool output into readable lines: handles UTF-16 (sfc) and drops
    # progress-bar noise such as "[=====  45.0%  ]" or "Verification 12% complete."
    param([byte[]]$Bytes)
    if (-not $Bytes -or $Bytes.Length -eq 0) { return }
    if ($Bytes.Length -ge 2 -and $Bytes[1] -eq 0) {
        $text = [System.Text.Encoding]::Unicode.GetString($Bytes)
    } else {
        $text = [Console]::OutputEncoding.GetString($Bytes)
    }
    foreach ($line in ($text -split "[`r`n]+")) {
        $t = $line.Replace([string][char]0, '').Trim()
        if (-not $t) { continue }
        if ($t -match '^\[[=\s\d.%]*\]$' -or $t -match '\d+(\.\d+)?\s?%') { continue }
        $t
    }
}

function Get-RepairCatalog {
    @(
        @{
            Id          = 'repair.system-files'
            Name        = 'Repair system files (DISM + SFC)'
            Description = 'Repairs the Windows component store with DISM, then checks and replaces corrupted system files with SFC. Fixes a wide range of crashes and broken features. Takes 10-30 minutes.'
            Reboot      = $true
            Action      = {
                $dism = Invoke-NativeTool 'dism.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth')
                if ($dism -ne 0) { Write-Log "DISM exited with code $dism - SFC will still run" Warn }
                $sfc = Invoke-NativeTool 'sfc.exe' @('/scannow')
                if ($sfc -ne 0) { Write-Log "SFC exited with code $sfc - see C:\Windows\Logs\CBS\CBS.log" Warn }
            }
        }
        @{
            Id          = 'repair.windows-update'
            Name        = 'Reset Windows Update'
            Description = 'Stops the update services, clears the download cache (SoftwareDistribution) and signature database (catroot2), then starts them again. Fixes updates that are stuck or fail with an error code.'
            Reboot      = $true
            Action      = {
                $services = 'wuauserv', 'bits', 'cryptsvc', 'msiserver'
                Stop-Service -Name $services -Force -ErrorAction SilentlyContinue
                foreach ($dir in "$env:SystemRoot\SoftwareDistribution", "$env:SystemRoot\System32\catroot2") {
                    if (-not (Test-Path -LiteralPath $dir)) { continue }
                    $old = "$dir.old"
                    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Recurse -Force -ErrorAction SilentlyContinue }
                    try {
                        # cryptsvc sometimes restarts itself; stop it again right before the rename.
                        Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue
                        Rename-Item -LiteralPath $dir -NewName (Split-Path -Leaf $old) -ErrorAction Stop
                        Write-Log "renamed $dir to $old" Detail
                    } catch {
                        Write-Log "could not rename $dir ($($_.Exception.Message))" Warn
                    }
                }
                Start-Service -Name $services -ErrorAction SilentlyContinue
            }
        }
        @{
            Id          = 'repair.start-menu'
            Name        = 'Fix Start menu, taskbar and search box'
            Description = 'Re-registers the Start menu, taskbar and shell packages and restarts them. Fixes a Start menu that won''t open, a blank taskbar or a search box that won''t type.'
            Action      = {
                $names = 'Microsoft.Windows.StartMenuExperienceHost', 'Microsoft.Windows.ShellExperienceHost', 'MicrosoftWindows.Client.CBS', 'MicrosoftWindows.Client.Core'
                foreach ($pkg in @(Get-AppxPackage -AllUsers | Where-Object { $names -contains $_.Name })) {
                    try {
                        Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $pkg.InstallLocation 'AppxManifest.xml') -ErrorAction Stop
                        Write-Log "re-registered $($pkg.Name)" Detail
                    } catch {
                        Write-Log "could not re-register $($pkg.Name): $($_.Exception.Message)" Warn
                    }
                }
                Stop-Process -Name StartMenuExperienceHost, ShellExperienceHost, SearchHost -Force -ErrorAction SilentlyContinue
                Restart-Explorer
            }
        }
        @{
            Id          = 'repair.search-index'
            Name        = 'Rebuild the search index'
            Description = 'Rebuilds the Windows Search index. Fixes search that can''t find files or apps you know are there. Search results fill back in over the next hour or so.'
            Action      = {
                Stop-Service -Name WSearch -Force -ErrorAction Stop
                Set-RegistryValueRaw -Path 'HKLM:\SOFTWARE\Microsoft\Windows Search' -Name 'SetupCompletedSuccessfully' -Type 'DWord' -Value 0
                Start-Service -Name WSearch -ErrorAction Stop
                Stop-Process -Name SearchHost -Force -ErrorAction SilentlyContinue
            }
        }
        @{
            Id          = 'repair.icon-cache'
            Name        = 'Clear icon and thumbnail cache'
            Description = 'Deletes the icon and thumbnail caches. Fixes blank, wrong or missing icons on the desktop, taskbar and in File Explorer.'
            Action      = {
                $explorerDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500
                $files = @(Get-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'IconCache.db') -Force -ErrorAction SilentlyContinue) +
                    @(Get-ChildItem -LiteralPath $explorerDir -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -like 'iconcache_*.db' -or $_.Name -like 'thumbcache_*.db' })
                $removed = 0
                foreach ($f in $files) {
                    try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $removed++ } catch { }
                }
                Write-Log "deleted $removed of $($files.Count) cache files (files in use are rebuilt after a restart)" Detail
                if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
                & "$env:SystemRoot\System32\ie4uinit.exe" -show
            }
        }
        @{
            Id          = 'repair.network'
            Name        = 'Reset network stack'
            Description = 'Resets Winsock and TCP/IP and flushes the DNS cache. Fixes "connected, no internet", DNS errors and broken connections after VPN or security software. Saved Wi-Fi networks are kept.'
            Reboot      = $true
            Action      = {
                Invoke-NativeTool 'netsh.exe' @('winsock', 'reset') | Out-Null
                Invoke-NativeTool 'netsh.exe' @('int', 'ip', 'reset') | Out-Null
                Invoke-NativeTool 'ipconfig.exe' @('/flushdns') | Out-Null
            }
        }
        @{
            Id          = 'repair.store'
            Name        = 'Fix Microsoft Store'
            Description = 'Clears the Store cache and re-registers the Store. Fixes a Store that won''t open or downloads that are stuck.'
            Action      = {
                foreach ($pkg in @(Get-AppxPackage -AllUsers -Name 'Microsoft.WindowsStore')) {
                    try {
                        Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $pkg.InstallLocation 'AppxManifest.xml') -ErrorAction Stop
                    } catch {
                        Write-Log "could not re-register the Store: $($_.Exception.Message)" Warn
                    }
                }
                # wsreset clears the cache and then opens the Store.
                Invoke-NativeTool 'wsreset.exe' @() | Out-Null
            }
        }
        @{
            Id          = 'repair.time-sync'
            Name        = 'Fix the clock (time sync)'
            Description = 'Restarts the Windows Time service and forces a resync. Fixes a clock that is minutes off, which also breaks sign-ins and HTTPS sites.'
            Action      = {
                Set-Service -Name w32time -StartupType Manual -ErrorAction SilentlyContinue
                Start-Service -Name w32time -ErrorAction Stop
                if ((Invoke-NativeTool 'w32tm.exe' @('/resync', '/force')) -ne 0) {
                    Invoke-NativeTool 'w32tm.exe' @('/config', '/update') | Out-Null
                    Restart-Service -Name w32time -Force
                    if ((Invoke-NativeTool 'w32tm.exe' @('/resync', '/force')) -ne 0) { throw 'w32tm could not resync. Check your internet connection.' }
                }
            }
        }
        @{
            Id          = 'repair.print-spooler'
            Name        = 'Clear stuck print jobs'
            Description = 'Stops the print spooler, deletes stuck jobs and starts it again. Fixes a print queue that won''t clear.'
            Action      = {
                Stop-Service -Name Spooler -Force -ErrorAction Stop
                Get-ChildItem -LiteralPath "$env:SystemRoot\System32\spool\PRINTERS" -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Start-Service -Name Spooler -ErrorAction Stop
            }
        }
        @{
            Id          = 'repair.audio'
            Name        = 'Restart audio services'
            Description = 'Restarts the Windows Audio services. Fixes sound that stops working, or devices that don''t switch.'
            Action      = {
                Stop-Service -Name Audiosrv -Force -ErrorAction SilentlyContinue
                Stop-Service -Name AudioEndpointBuilder -Force -ErrorAction SilentlyContinue
                Start-Service -Name AudioEndpointBuilder -ErrorAction Stop
                Start-Service -Name Audiosrv -ErrorAction Stop
            }
        }
        @{
            Id          = 'repair.wmi'
            Name        = 'Check and repair WMI'
            Description = 'Checks the WMI repository and salvages it if it is inconsistent. Fixes errors in Task Manager, Settings and management tools that rely on WMI.'
            Action      = {
                $code = Invoke-NativeTool 'winmgmt.exe' @('/verifyrepository')
                if ($code -ne 0) {
                    Write-Log 'WMI repository is inconsistent, salvaging...' Warn
                    Invoke-NativeTool 'winmgmt.exe' @('/salvagerepository') | Out-Null
                }
            }
        }
        @{
            Id          = 'repair.disk-check'
            Name        = 'Scan system drive for errors'
            Description = 'Runs an online CHKDSK scan of the system drive (no restart needed). If it finds problems, it tells you how to fix them at next boot.'
            Action      = {
                $code = Invoke-NativeTool 'chkdsk.exe' @($env:SystemDrive, '/scan')
                if ($code -ne 0) { Write-Log "Problems found. Run 'chkdsk $env:SystemDrive /f' in an admin terminal and restart to fix them." Warn }
            }
        }
        @{
            Id          = 'repair.cleanup'
            Name        = 'Free up disk space'
            Description = 'Deletes temp files and the Delivery Optimization cache and cleans up superseded Windows updates. Afterwards installed updates can''t be uninstalled.'
            Action      = {
                $drive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))
                $before = $drive.Free
                foreach ($dir in $env:TEMP, "$env:SystemRoot\Temp") {
                    Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
                if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
                    Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
                }
                Invoke-NativeTool 'dism.exe' @('/Online', '/Cleanup-Image', '/StartComponentCleanup') | Out-Null
                $freed = ((Get-PSDrive -Name $drive.Name).Free - $before) / 1GB
                Write-Log ('freed about {0:N2} GB' -f [math]::Max(0, $freed)) Detail
            }
        }
    ) | Complete-CatalogItem
}

function Invoke-Repairs {
    param([object[]]$Repairs)
    $reboot = $false
    foreach ($r in @($Repairs | Where-Object { $_ })) {
        Write-Log $r.Name Step
        try {
            & $r.Action | Out-Host
            Write-Log "$($r.Name) - done" Ok
            if ($r.Reboot) { $reboot = $true }
        } catch {
            Write-Log "$($r.Name) failed: $($_.Exception.Message)" Error
        }
    }
    $reboot
}
