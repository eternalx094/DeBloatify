# Microsoft Edge: Copilot, shopping, rewards and other promotions, set via Edge policy.
# Edge stays installed (Windows and many apps depend on it and on WebView2).
# While these policies exist, edge://settings shows "Your browser is managed by
# your organization" - that is expected. Undo removes them again.

$edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'

@(
    @{
        Id          = 'edge.copilot'
        Category    = 'Microsoft Edge'
        Level       = 'Minimal'
        Name        = 'Remove Copilot and the sidebar from Edge'
        Description = 'Hides the Copilot button and sidebar, disables the AI writing assistant and stops Edge downloading on-device AI models.'
        Registry    = @(
            Reg $edge 'HubsSidebarEnabled' 0
            Reg $edge 'StandaloneHubsSidebarEnabled' 0
            Reg $edge 'Microsoft365CopilotChatIconEnabled' 0
            Reg $edge 'ComposeInlineEnabled' 0
            Reg $edge 'GenAILocalFoundationalModelSettings' 1
        )
    }
    @{
        Id          = 'edge.shopping'
        Category    = 'Microsoft Edge'
        Level       = 'Minimal'
        Name        = 'Remove shopping and Rewards from Edge'
        Description = 'Turns off the shopping assistant (coupons/price pop-ups) and Microsoft Rewards.'
        Registry    = @(
            Reg $edge 'EdgeShoppingAssistantEnabled' 0
            Reg $edge 'ShowMicrosoftRewards' 0
        )
    }
    @{
        Id          = 'edge.promotions'
        Category    = 'Microsoft Edge'
        Level       = 'Minimal'
        Name        = 'Stop Edge promotions and nags'
        Description = 'Stops promotional tabs, "recommended" pop-ups, the first-run wizard and the campaign to make Edge your default browser.'
        Registry    = @(
            Reg $edge 'ShowRecommendationsEnabled' 0
            Reg $edge 'SpotlightExperiencesAndRecommendationsEnabled' 0
            Reg $edge 'PromotionalTabsEnabled' 0
            Reg $edge 'DefaultBrowserSettingsCampaignEnabled' 0
            Reg $edge 'HideFirstRunExperience' 1
            Reg $edge 'PersonalizationReportingEnabled' 0
        )
    }
    @{
        Id          = 'edge.new-tab'
        Category    = 'Microsoft Edge'
        Level       = 'Recommended'
        Name        = 'Remove the news feed from the new tab page'
        Description = 'Removes MSN news and sponsored tiles from Edge''s new tab page.'
        Registry    = @(
            Reg $edge 'NewTabPageContentEnabled' 0
            Reg $edge 'NewTabPageHideDefaultTopSites' 1
        )
    }
    @{
        Id          = 'edge.background'
        Category    = 'Microsoft Edge'
        Level       = 'Recommended'
        Name        = 'Stop Edge running in the background'
        Description = 'Disables Startup Boost and background mode, so Edge does not run when you are not using it.'
        Registry    = @(
            Reg $edge 'StartupBoostEnabled' 0
            Reg $edge 'BackgroundModeEnabled' 0
        )
    }
    @{
        Id          = 'edge.telemetry'
        Category    = 'Microsoft Edge'
        Level       = 'Recommended'
        Name        = 'Minimise Edge diagnostic data'
        Description = 'Sets Edge diagnostic data to "off" and sends Do Not Track.'
        Registry    = @(
            Reg $edge 'DiagnosticData' 0
            Reg $edge 'ConfigureDoNotTrack' 1
        )
    }
    @{
        Id          = 'edge.auto-import'
        Category    = 'Microsoft Edge'
        Level       = 'Recommended'
        Name        = 'Stop Edge importing other browsers'' data'
        Description = 'Stops Edge from silently importing tabs, passwords and history from Chrome or Firefox.'
        Registry    = @(Reg $edge 'AutoImportAtFirstRun' 4)
    }
    @{
        Id          = 'edge.desktop-shortcut'
        Category    = 'Microsoft Edge'
        Level       = 'Recommended'
        Name        = 'Stop Edge updates re-adding the desktop shortcut'
        Description = 'Stops Edge updates from putting the Edge shortcut back on your desktop.'
        Registry    = @(Reg 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'CreateDesktopShortcutDefault' 0)
    }
)
