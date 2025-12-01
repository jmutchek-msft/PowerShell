# --- set your folder here ---
$dir        = "C:\Users\jmutchek\OneDrive - Microsoft\10-self\12-journal\12.10-journal"
$scriptPath = "C:\Users\jmutchek\local\70-code\75-github-microsoft\PowerShell\rm-untouched.ps1"

$action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Path `"$dir`" -Recurse"

$trigger  = New-ScheduledTaskTrigger -Daily -At 5:00pm

# $settings = New-ScheduledTaskSettingsSet `
            #   -StartWhenAvailable `     # run ASAP after missed start when system wakes
            #   -WakeToRun `             # wake the laptop to run at 7 AM
            #   -AllowStartIfOnBatteries `
            #   -DontStopIfGoingOnBatteries

# Runs elevated under your account while you're logged on.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName 'RM-Untouched-Files-Created-Today' `
    -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
    -Description 'Set LastWriteTime=17:00 for files created today in the specified directory'
