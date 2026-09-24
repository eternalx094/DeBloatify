# Bing & search: keep Start/taskbar search local.

$searchPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
$searchSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'

@(
    @{
        Id          = 'search.bing'
        Category    = 'Bing & Search'
        Level       = 'Minimal'
        Name        = 'Remove Bing from Start menu search'
        Description = 'Start and taskbar search only show results from your PC; typing no longer sends keystrokes to Bing. This also makes search noticeably faster.'
        Registry    = @(
            Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
            Reg $searchPolicy 'DisableWebSearch' 1
            Reg $searchPolicy 'ConnectedSearchUseWeb' 0
        )
        Restart     = 'Explorer'
    }
    @{
        Id          = 'search.highlights'
        Category    = 'Bing & Search'
        Level       = 'Minimal'
        Name        = 'Disable search highlights'
        Description = 'Removes the Bing trivia, doodles and "trending searches" from the search box and search panel.'
        Registry    = @(
            Reg $searchSettings 'IsDynamicSearchBoxEnabled' 0
            Reg $searchPolicy 'EnableDynamicContentInWSB' 0
        )
        Restart     = 'Explorer'
    }
    @{
        Id          = 'search.cortana'
        Category    = 'Bing & Search'
        Level       = 'Minimal'
        Name        = 'Disable Cortana'
        Description = 'Disables Cortana in search (retired, but the policy still stops leftovers).'
        Registry    = @(
            Reg $searchPolicy 'AllowCortana' 0
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
        )
    }
    @{
        Id          = 'search.cloud'
        Category    = 'Bing & Search'
        Level       = 'Recommended'
        Name        = 'Disable cloud content search'
        Description = 'Stops search from pulling results from your Microsoft account, OneDrive and Outlook.'
        Registry    = @(
            Reg $searchSettings 'IsMSACloudSearchEnabled' 0
            Reg $searchSettings 'IsAADCloudSearchEnabled' 0
            Reg $searchPolicy 'AllowCloudSearch' 0
        )
    }
    @{
        Id          = 'search.history'
        Category    = 'Bing & Search'
        Level       = 'Recommended'
        Name        = 'Disable search history'
        Description = 'Stops Windows from keeping a history of what you search for on this device.'
        Registry    = @(Reg $searchSettings 'IsDeviceSearchHistoryEnabled' 0)
    }
    @{
        Id          = 'search.spotlight-icon'
        Category    = 'Bing & Search'
        Level       = 'Recommended'
        Name        = 'Hide "Learn about this picture" desktop icon'
        Description = 'Hides the Windows Spotlight desktop icon, which opens Bing. The Spotlight wallpaper itself keeps working.'
        Registry    = @(Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' '{2cc5ca98-6485-489a-920e-b3e88a6ccce3}' 1)
        Restart     = 'Explorer'
    }
)
