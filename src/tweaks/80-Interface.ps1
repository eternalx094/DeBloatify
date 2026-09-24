# Interface: personal-preference changes. Only "show file extensions" is in a preset;
# everything else is Optional and has to be picked (Custom menu or -Include).

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

@(
    @{
        Id          = 'ui.file-extensions'
        Category    = 'Interface'
        Level       = 'Recommended'
        Name        = 'Show file extensions'
        Description = 'Shows extensions such as .exe and .pdf, so "invoice.pdf.exe" can''t pass as a PDF.'
        Registry    = @(Reg $adv 'HideFileExt' 0)
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ui.classic-context-menu'
        Category    = 'Interface'
        Level       = 'Optional'
        Name        = 'Classic right-click menu'
        Description = 'Brings back the full Windows 10 right-click menu, with no "Show more options" step.'
        Registry    = @(Reg 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '' '' 'String')
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ui.taskbar-left'
        Category    = 'Interface'
        Level       = 'Optional'
        Name        = 'Align taskbar to the left'
        Description = 'Moves the Start button and taskbar icons to the left, as in Windows 10.'
        Registry    = @(Reg $adv 'TaskbarAl' 0)
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ui.search-icon'
        Category    = 'Interface'
        Level       = 'Optional'
        Name        = 'Taskbar search as icon only'
        Description = 'Replaces the wide taskbar search box with a search icon.'
        Registry    = @(Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1)
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ui.hide-task-view'
        Category    = 'Interface'
        Level       = 'Optional'
        Name        = 'Hide Task View button'
        Description = 'Removes the Task View button from the taskbar. Win+Tab still works.'
        Registry    = @(Reg $adv 'ShowTaskViewButton' 0)
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ui.explorer-this-pc'
        Category    = 'Interface'
        Level       = 'Optional'
        Name        = 'Open File Explorer to "This PC"'
        Description = 'File Explorer opens on This PC (your drives) instead of Home.'
        Registry    = @(Reg $adv 'LaunchTo' 1)
    }
    @{
        Id          = 'ui.hidden-files'
        Category    = 'Interface'
        Level       = 'Optional'
        Name        = 'Show hidden files'
        Description = 'Shows hidden files and folders in File Explorer.'
        Registry    = @(Reg $adv 'Hidden' 1)
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ui.end-task'
        Category    = 'Interface'
        Level       = 'Optional'
        Name        = 'Add "End task" to taskbar right-click'
        Description = 'Lets you force-close a frozen app by right-clicking it on the taskbar.'
        Registry    = @(Reg "$adv\TaskbarDeveloperSettings" 'TaskbarEndTask' 1)
    }
    @{
        Id          = 'ui.sticky-keys'
        Category    = 'Interface'
        Level       = 'Optional'
        Name        = 'Disable the Sticky Keys shortcut'
        Description = 'Stops the Sticky Keys prompt appearing when you press Shift five times (e.g. while gaming).'
        Registry    = @(Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506' 'String')
    }
    @{
        Id          = 'ui.recent-files'
        Category    = 'Interface'
        Level       = 'Optional'
        Name        = 'Hide recent files and frequent folders'
        Description = 'Stops File Explorer Home and Start from listing recently opened files and frequent folders.'
        Registry    = @(
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowRecent' 0
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowFrequent' 0
            Reg $adv 'Start_TrackDocs' 0
        )
        Restart     = 'Explorer'
    }
)
