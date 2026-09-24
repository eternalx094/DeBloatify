# Privacy: telemetry, advertising ID and background data collection.

$dataCollection = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'

@(
    @{
        Id          = 'privacy.telemetry'
        Category    = 'Privacy'
        Level       = 'Minimal'
        Name        = 'Minimise diagnostic data (telemetry)'
        Description = 'Sets diagnostic data to the lowest level your edition allows (Home/Pro: "Required only"; Enterprise/Education: off), limits diagnostic log and crash-dump uploads, and disables the Connected User Experiences and Telemetry service.'
        Registry    = @(
            Reg $dataCollection 'AllowTelemetry' 0
            Reg $dataCollection 'LimitDiagnosticLogCollection' 1
            Reg $dataCollection 'LimitDumpCollection' 1
        )
        Services    = @(@{ Name = 'DiagTrack'; StartupType = 'Disabled' })
    }
    @{
        Id          = 'privacy.telemetry-tasks'
        Category    = 'Privacy'
        Level       = 'Recommended'
        Name        = 'Disable telemetry scheduled tasks'
        Description = 'Disables the Customer Experience Improvement Program, compatibility appraiser and disk diagnostic data collection tasks.'
        Tasks       = @(
            '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
            '\Microsoft\Windows\Autochk\Proxy'
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
            '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'
        )
    }
    @{
        Id          = 'privacy.advertising-id'
        Category    = 'Privacy'
        Level       = 'Minimal'
        Name        = 'Disable advertising ID'
        Description = 'Stops apps from using your advertising ID to show personalised ads.'
        Registry    = @(
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
            Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
        )
    }
    @{
        Id          = 'privacy.tailored-experiences'
        Category    = 'Privacy'
        Level       = 'Minimal'
        Name        = 'Disable tailored experiences'
        Description = 'Stops Microsoft from using your diagnostic data to show personalised tips, ads and recommendations.'
        Registry    = @(
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
            Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1
        )
    }
    @{
        Id          = 'privacy.activity-history'
        Category    = 'Privacy'
        Level       = 'Minimal'
        Name        = 'Disable activity history'
        Description = 'Stops Windows from collecting and uploading a history of the apps, files and sites you use.'
        Registry    = @(
            Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0
            Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
            Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
        )
    }
    @{
        Id          = 'privacy.feedback'
        Category    = 'Privacy'
        Level       = 'Minimal'
        Name        = 'Stop feedback requests'
        Description = 'Stops "How likely are you to recommend Windows" pop-ups and the Feedback Hub survey tasks.'
        Registry    = @(
            Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
            Reg $dataCollection 'DoNotShowFeedbackNotifications' 1
        )
        Tasks       = @(
            '\Microsoft\Windows\Feedback\Siuf\DmClient'
            '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
        )
    }
    @{
        Id          = 'privacy.inking-typing'
        Category    = 'Privacy'
        Level       = 'Recommended'
        Name        = 'Disable inking and typing data collection'
        Description = 'Stops Windows from building a personal dictionary from your typing and handwriting and sending it to Microsoft.'
        Registry    = @(
            Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1
            Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1
            Reg 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 0
            Reg 'HKCU:\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 0
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\InkingAndTypingPersonalization' 'Value' 0
        )
    }
    @{
        Id          = 'privacy.online-speech'
        Category    = 'Privacy'
        Level       = 'Recommended'
        Name        = 'Disable online speech recognition'
        Description = 'Keeps voice input on the device instead of sending it to Microsoft. Voice typing (Win+H) may need this turned back on.'
        Registry    = @(Reg 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0)
    }
    @{
        Id          = 'privacy.language-list'
        Category    = 'Privacy'
        Level       = 'Recommended'
        Name        = 'Hide language list from websites'
        Description = 'Stops websites from reading your installed language list (used for fingerprinting).'
        Registry    = @(Reg 'HKCU:\Control Panel\International\User Profile' 'HttpAcceptLanguageOptOut' 1)
    }
    @{
        Id          = 'privacy.delivery-optimization'
        Category    = 'Privacy'
        Level       = 'Recommended'
        Name        = 'Stop sharing updates with other PCs'
        Description = 'Downloads Windows updates straight from Microsoft instead of uploading pieces of them to other PCs on the internet.'
        Registry    = @(Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0)
    }
    @{
        Id          = 'privacy.app-launch-tracking'
        Category    = 'Privacy'
        Level       = 'Aggressive'
        Name        = 'Disable app launch tracking'
        Description = 'Stops Windows from tracking which apps you open. This also empties the "Most used" list in Start.'
        Registry    = @(Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs' 0)
        Restart     = 'Explorer'
    }
    @{
        Id          = 'privacy.error-reporting'
        Category    = 'Privacy'
        Level       = 'Aggressive'
        Name        = 'Disable Windows Error Reporting'
        Description = 'Stops crash reports being sent to Microsoft. You will no longer get "a solution is available" follow-ups.'
        Registry    = @(Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1)
        Tasks       = @('\Microsoft\Windows\Windows Error Reporting\QueueReporting')
    }
    @{
        Id          = 'privacy.wap-push'
        Category    = 'Privacy'
        Level       = 'Aggressive'
        Name        = 'Disable WAP push message routing service'
        Description = 'Disables dmwappushservice, which relays telemetry and device-management messages. Leave it on if your PC is managed by work or school (Intune/MDM).'
        Services    = @(@{ Name = 'dmwappushservice'; StartupType = 'Disabled' })
    }
)
