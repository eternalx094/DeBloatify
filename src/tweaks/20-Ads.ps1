# Ads & suggestions: sponsored apps, tips, nags and upsells built into the shell.

$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$cloudContent = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'

@(
    @{
        Id          = 'ads.sponsored-apps'
        Category    = 'Ads & Suggestions'
        Level       = 'Minimal'
        Name        = 'Stop sponsored apps being installed'
        Description = 'Stops Windows from silently installing promoted apps and games (Candy Crush, TikTok, etc.) and pinning them to Start.'
        Registry    = @(
            Reg $cdm 'SilentInstalledAppsEnabled' 0
            Reg $cdm 'PreInstalledAppsEnabled' 0
            Reg $cdm 'PreInstalledAppsEverEnabled' 0
            Reg $cdm 'OemPreInstalledAppsEnabled' 0
            Reg $cdm 'FeatureManagementEnabled' 0
            Reg $cloudContent 'DisableWindowsConsumerFeatures' 1
            Reg $cloudContent 'DisableConsumerAccountStateContent' 1
            Reg $cloudContent 'DisableCloudOptimizedContent' 1
        )
    }
    @{
        Id          = 'ads.tips-suggestions'
        Category    = 'Ads & Suggestions'
        Level       = 'Minimal'
        Name        = 'Disable tips, tricks and suggestions'
        Description = 'Turns off "Get tips and suggestions", suggested content in Settings, suggestions in Start and the post-update "welcome experience".'
        Registry    = @(
            Reg $cdm 'SystemPaneSuggestionsEnabled' 0
            Reg $cdm 'SoftLandingEnabled' 0
            Reg $cdm 'SubscribedContent-338388Enabled' 0
            Reg $cdm 'SubscribedContent-338389Enabled' 0
            Reg $cdm 'SubscribedContent-338393Enabled' 0
            Reg $cdm 'SubscribedContent-353694Enabled' 0
            Reg $cdm 'SubscribedContent-353696Enabled' 0
            Reg $cdm 'SubscribedContent-353698Enabled' 0
            Reg $cdm 'SubscribedContent-310093Enabled' 0
        )
    }
    @{
        Id          = 'ads.lock-screen'
        Category    = 'Ads & Suggestions'
        Level       = 'Minimal'
        Name        = 'Remove lock screen tips and ads'
        Description = 'Removes "fun facts, tips, tricks and more" from the lock screen. Your wallpaper (including Spotlight) is not changed.'
        Registry    = @(
            Reg $cdm 'RotatingLockScreenOverlayEnabled' 0
            Reg $cdm 'SubscribedContent-338387Enabled' 0
        )
    }
    @{
        Id          = 'ads.start-recommendations'
        Category    = 'Ads & Suggestions'
        Level       = 'Minimal'
        Name        = 'Remove promotions from Start'
        Description = 'Turns off "recommendations for tips, shortcuts, new apps and more" and Microsoft account nags in the Start menu.'
        Registry    = @(
            Reg $adv 'Start_IrisRecommendations' 0
            Reg $adv 'Start_AccountNotifications' 0
        )
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ads.explorer-onedrive'
        Category    = 'Ads & Suggestions'
        Level       = 'Minimal'
        Name        = 'Remove OneDrive/Microsoft 365 ads in File Explorer'
        Description = 'Turns off "sync provider notifications", the banners File Explorer shows to upsell OneDrive and Microsoft 365.'
        Registry    = @(Reg $adv 'ShowSyncProviderNotifications' 0)
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ads.setup-nags'
        Category    = 'Ads & Suggestions'
        Level       = 'Minimal'
        Name        = 'Stop "Finish setting up your device" nags'
        Description = 'Stops the full-screen "Let us finish setting up your device" prompts that push a Microsoft account, OneDrive, Microsoft 365 and Game Pass.'
        Registry    = @(
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' 'EnableAccountNotifications' 0
        )
    }
    @{
        Id          = 'ads.suggested-notifications'
        Category    = 'Ads & Suggestions'
        Level       = 'Minimal'
        Name        = 'Block "suggested" notifications'
        Description = 'Blocks the Suggested notification channel Windows uses for promotions.'
        Registry    = @(Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested' 'Enabled' 0)
    }
    @{
        Id          = 'ads.explorer-office-files'
        Category    = 'Ads & Suggestions'
        Level       = 'Recommended'
        Name        = 'Hide Office.com files in File Explorer Home'
        Description = 'Stops File Explorer Home from listing cloud files from Office.com.'
        Registry    = @(Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowCloudFilesInQuickAccess' 0)
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ads.widgets'
        Category    = 'Ads & Suggestions'
        Level       = 'Recommended'
        Name        = 'Disable Widgets and the news feed'
        Description = 'Turns off the Widgets board (MSN news, weather, stocks) and its taskbar button.'
        Registry    = @(Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0)
        Restart     = 'Explorer'
    }
)
