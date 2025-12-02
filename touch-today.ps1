[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    # Touch files in subfolders too
    [switch]$Recurse,

    # Change if you ever want a different hour
    [ValidateRange(0,23)]
    [int]$TouchHour = 6,

    # Show what would be done without actually modifying files
    [switch]$DryRun
)

$today     = (Get-Date).Date                 # midnight today, local time
$touchTime = $today.AddHours($TouchHour)

Write-Verbose "Today's date: $today"
Write-Verbose "Touch time will be set to: $touchTime"

# Simple log file
$logPath = Join-Path $env:ProgramData 'TouchToday.log'
$mode = if ($DryRun) { "DRY-RUN" } else { "LIVE" }
Write-Verbose "Mode: $mode"
Write-Verbose "Log path: $logPath"
"$(Get-Date -Format o) :: Starting :: Mode=$mode :: Path=$Path :: Recurse=$Recurse :: TouchTime=$touchTime" | Add-Content $logPath

Write-Verbose "Searching for files in: $Path (Recurse: $Recurse)"
try {
    $files = Get-ChildItem -Path $Path -File -Recurse:$Recurse -ErrorAction Stop
    Write-Verbose "Found $($files.Count) total file(s)"
} catch {
    Write-Error "Cannot list files in '$Path': $($_.Exception.Message)"
    "$(Get-Date -Format o) :: ERROR :: $($_.Exception.Message)" | Add-Content $logPath
    exit 1
}

$todayString = $today.ToString("yyyyMMdd")
$targets = $files | Where-Object { 
    ($_.CreationTime.Date -eq $today) -and ($_.Name -like "$todayString*")
}

Write-Verbose "Filtering for files created today with pattern '$todayString*'"
Write-Verbose "Found $($targets.Count) file(s) to touch"

foreach ($f in $targets) {
    $currentCreation = $f.CreationTime
    $currentWrite = $f.LastWriteTime
    Write-Verbose "Processing: $($f.Name) | Current: Creation=$currentCreation, Write=$currentWrite | Target: $touchTime"
    try {
            if ($DryRun) {
                Write-Host "Would touch: $($f.Name) (old: $currentWrite -> new: $touchTime)"
                "$(Get-Date -Format o) :: DRY-RUN WOULD TOUCH :: $($f.FullName) :: old=$currentWrite :: new=$touchTime" | Add-Content $logPath
            } else {
                # Temporarily clear read-only if set
                $wasRO = $f.IsReadOnly
                if ($wasRO) { 
                    Write-Verbose "  File is read-only, temporarily clearing"
                    $f.IsReadOnly = $false 
                }

                Write-Verbose "  Setting timestamps to: $touchTime"
                # Touch to 06:00 AM local time
                $f.CreationTime = $touchTime
                $f.LastWriteTime = $touchTime

                if ($wasRO) { 
                    Write-Verbose "  Restoring read-only attribute"
                    $f.IsReadOnly = $true 
                }
                Write-Verbose "  Successfully touched: $($f.Name)"
                "$(Get-Date -Format o) :: TOUCHED :: $($f.FullName) :: old=$currentWrite :: new=$touchTime" | Add-Content $logPath
            }
    } catch {
        if (-not $DryRun) {
            Write-Warning "Failed to touch '$($f.FullName)': $($_.Exception.Message)"
        }
        "$(Get-Date -Format o) :: WARN :: $($f.FullName) :: $($_.Exception.Message)" | Add-Content $logPath
    }
}
