# Performance: only changes with a real, measurable effect. No placebo registry "boosts".

@(
    @{
        Id          = 'perf.retail-demo'
        Category    = 'Performance'
        Level       = 'Recommended'
        Name        = 'Disable Retail Demo service'
        Description = 'Disables the service that runs store display demos.'
        Services    = @(@{ Name = 'RetailDemo'; StartupType = 'Disabled' })
    }
    @{
        Id          = 'perf.game-dvr'
        Category    = 'Performance'
        Level       = 'Aggressive'
        Name        = 'Disable background game recording'
        Description = 'Turns off Game DVR background recording, which costs frame rate in games. Win+Alt+R recording stops working.'
        Registry    = @(
            Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
            Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
        )
    }
    @{
        Id          = 'perf.background-apps'
        Category    = 'Performance'
        Level       = 'Aggressive'
        Name        = 'Stop Store apps running in the background'
        Description = 'Microsoft Store apps can no longer run in the background. Saves battery, but notifications from Store apps (e.g. WhatsApp, Phone Link) may arrive only while the app is open.'
        Registry    = @(Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2)
    }
    @{
        Id          = 'perf.maps-broker'
        Category    = 'Performance'
        Level       = 'Aggressive'
        Name        = 'Set Downloaded Maps Manager to manual'
        Description = 'Stops the offline maps service starting with Windows. It still starts when an app needs it.'
        Services    = @(@{ Name = 'MapsBroker'; StartupType = 'Manual' })
    }
    @{
        Id          = 'perf.startup-delay'
        Category    = 'Performance'
        Level       = 'Optional'
        Name        = 'Remove startup app delay'
        Description = 'Windows waits a few seconds after sign-in before starting startup apps. This removes the delay.'
        Registry    = @(Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0)
    }
)
