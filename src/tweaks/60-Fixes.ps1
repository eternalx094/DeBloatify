# Fixes: reversible workarounds for well-known Windows 11 annoyances and bugs.
# One-off repairs (SFC/DISM, Windows Update reset, ...) live in src/Repairs.ps1.

@(
    @{
        Id          = 'fix.fast-startup'
        Category    = 'Fixes'
        Level       = 'Recommended'
        Name        = 'Disable Fast Startup'
        Description = 'Fast Startup makes "Shut down" a partial hibernate. It causes updates and driver installs that never finish, devices that stop working until a restart, and locked drives when dual-booting. After this, Shut down is a real shut down (boot may take a few seconds longer).'
        Registry    = @(Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0)
    }
    @{
        Id          = 'fix.slow-folders'
        Category    = 'Fixes'
        Level       = 'Recommended'
        Name        = 'Fix slow-loading folders (Downloads)'
        Description = 'Stops File Explorer from guessing each folder''s type by scanning its contents. This is the cause of the Downloads folder taking seconds to open.'
        Registry    = @(Reg 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell' 'FolderType' 'NotSpecified' 'String')
        Restart     = 'Explorer'
    }
    @{
        Id          = 'fix.long-paths'
        Category    = 'Fixes'
        Level       = 'Recommended'
        Name        = 'Enable long file paths'
        Description = 'Lets apps use file paths longer than 260 characters, fixing "path too long" errors when copying, extracting or building projects.'
        Registry    = @(Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1)
    }
    @{
        Id          = 'fix.maintenance-wake'
        Category    = 'Fixes'
        Level       = 'Recommended'
        Name        = 'Stop maintenance waking the PC at night'
        Description = 'Stops scheduled maintenance from waking the PC from sleep, which is a common cause of laptops that are hot or flat in the morning.'
        Registry    = @(Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'WakeUp' 0)
    }
    @{
        Id          = 'fix.update-auto-reboot'
        Category    = 'Fixes'
        Level       = 'Recommended'
        Name        = 'No automatic update restarts while signed in'
        Description = 'Windows Update will not restart the PC on its own while someone is signed in. Honoured on Pro, Enterprise and Education.'
        Registry    = @(Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1)
    }
    @{
        Id          = 'fix.update-drivers'
        Category    = 'Fixes'
        Level       = 'Optional'
        Name        = 'Stop Windows Update replacing drivers'
        Description = 'Stops Windows Update from installing drivers. Useful when it keeps replacing a working GPU/audio driver with an older one. You then have to update drivers yourself.'
        Registry    = @(Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1)
    }
    @{
        Id          = 'fix.bsod-no-autorestart'
        Category    = 'Fixes'
        Level       = 'Optional'
        Name        = 'Keep blue screens on screen'
        Description = 'Stops Windows restarting straight after a blue screen, so you can read the stop code.'
        Registry    = @(Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' 'AutoReboot' 0)
    }
)
