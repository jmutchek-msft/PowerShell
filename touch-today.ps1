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

# Simple log file
$logPath = Join-Path $env:ProgramData 'TouchToday.log'
$mode = if ($DryRun) { "DRY-RUN" } else { "LIVE" }
"$(Get-Date -Format o) :: Starting :: Mode=$mode :: Path=$Path :: Recurse=$Recurse :: TouchTime=$touchTime" | Add-Content $logPath

try {
    $files = Get-ChildItem -Path $Path -File -Recurse:$Recurse -ErrorAction Stop
} catch {
    Write-Error "Cannot list files in '$Path': $($_.Exception.Message)"
    "$(Get-Date -Format o) :: ERROR :: $($_.Exception.Message)" | Add-Content $logPath
    exit 1
}

$todayString = $today.ToString("yyyyMMdd")
$targets = $files | Where-Object { 
    ($_.CreationTime.Date -eq $today) -and ($_.Name -like "$todayString*")
}

foreach ($f in $targets) {
    try {
            if ($DryRun) {
                Write-Host "Would touch: $($f.Name) (old: $oldWrite -> new: $touchTime)"
                "$(Get-Date -Format o) :: DRY-RUN WOULD TOUCH :: $($f.FullName) :: old=$oldWrite :: new=$touchTime" | Add-Content $logPath
            } else {
                # Temporarily clear read-only if set
                $wasRO = $f.IsReadOnly
                if ($wasRO) { $f.IsReadOnly = $false }

                # Touch to 06:00 AM local time
                $f.CreationTime = $touchTime
                $f.LastWriteTime = $touchTime

                if ($wasRO) { $f.IsReadOnly = $true }
                "$(Get-Date -Format o) :: TOUCHED :: $($f.FullName) :: old=$oldWrite :: new=$touchTime" | Add-Content $logPath
            }
    } catch {
        if (-not $DryRun) {
            Write-Warning "Failed to touch '$($f.FullName)': $($_.Exception.Message)"
        }
        "$(Get-Date -Format o) :: WARN :: $($f.FullName) :: $($_.Exception.Message)" | Add-Content $logPath
    }
}
