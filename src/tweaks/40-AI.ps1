# Copilot & AI: Copilot, Recall, Click to Do and the AI features in inbox apps.
# The Copilot app itself is removed in the Apps step (app.copilot).

$windowsAI = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
$windowsAIUser = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI'
$paint = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'

@(
    @{
        Id          = 'ai.copilot'
        Category    = 'Copilot & AI'
        Level       = 'Minimal'
        Name        = 'Turn off Windows Copilot'
        Description = 'Removes the Copilot taskbar button and sets the "Turn off Windows Copilot" policy for this user and the machine.'
        Registry    = @(
            Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
            Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
            Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
        )
        Restart     = 'Explorer'
    }
    @{
        Id          = 'ai.recall'
        Category    = 'Copilot & AI'
        Level       = 'Minimal'
        Name        = 'Disable Recall'
        Description = 'Stops Recall from taking snapshots of your screen and blocks it from being enabled. Only affects Copilot+ PCs.'
        Registry    = @(
            Reg $windowsAI 'DisableAIDataAnalysis' 1
            Reg $windowsAI 'AllowRecallEnablement' 0
            Reg $windowsAIUser 'DisableAIDataAnalysis' 1
        )
        Restart     = 'Reboot'
    }
    @{
        Id          = 'ai.click-to-do'
        Category    = 'Copilot & AI'
        Level       = 'Minimal'
        Name        = 'Disable Click to Do'
        Description = 'Disables the Click to Do AI overlay (Win + mouse click / Win+Q). Only affects Copilot+ PCs.'
        Registry    = @(
            Reg $windowsAI 'DisableClickToDo' 1
            Reg $windowsAIUser 'DisableClickToDo' 1
        )
    }
    @{
        Id          = 'ai.paint'
        Category    = 'Copilot & AI'
        Level       = 'Recommended'
        Name        = 'Disable AI features in Paint'
        Description = 'Turns off Cocreator, Image Creator and Generative Fill in Paint.'
        Registry    = @(
            Reg $paint 'DisableCocreator' 1
            Reg $paint 'DisableImageCreator' 1
            Reg $paint 'DisableGenerativeFill' 1
        )
    }
    @{
        Id          = 'ai.notepad'
        Category    = 'Copilot & AI'
        Level       = 'Recommended'
        Name        = 'Disable AI features in Notepad'
        Description = 'Removes Copilot Rewrite/Summarize from Notepad.'
        Registry    = @(Reg 'HKLM:\SOFTWARE\Policies\WindowsNotepad' 'DisableAIFeatures' 1)
    }
)
