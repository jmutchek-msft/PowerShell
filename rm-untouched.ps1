# This script identifies any files in a provided directory that were created on the day the script is run but never modified. These files are listed to stdout and moved to the recycle bin. If a --dry-run flag is present, it displays the list but does not move the files.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,
    
    [switch]$DryRun
)

# Validate directory exists
if (-not (Test-Path -Path $Path -PathType Container)) {
    Write-Error "Directory '$Path' does not exist or is not a directory."
    exit 1
}

# Get today's date (date only, no time)
$today = Get-Date -Format "yyyy-MM-dd"

# Find files created today that have never been modified (CreationTime equals LastWriteTime)
$untouchedFiles = Get-ChildItem -Path $Path -File -Recurse | Where-Object {
    $creationDate = $_.CreationTime.ToString("yyyy-MM-dd")
    $lastWriteDate = $_.LastWriteTime.ToString("yyyy-MM-dd")
    
    # File was created today and creation time equals last write time (never modified)
    ($creationDate -eq $today) -and ($_.CreationTime -eq $_.LastWriteTime)
}

if ($untouchedFiles.Count -eq 0) {
    Write-Host "No untouched files created today were found in '$Path'."
    exit 0
}

# Display the files
Write-Host "Found $($untouchedFiles.Count) untouched file(s) created today:"
foreach ($file in $untouchedFiles) {
    Write-Host "  $($file.FullName)"
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry run mode: Files would be moved to recycle bin, but no action was taken."
} else {
    Write-Host ""
    Write-Host "Moving files to recycle bin..."
    
    # Load Windows Shell COM object for moving to recycle bin
    $shell = New-Object -ComObject Shell.Application
    
    foreach ($file in $untouchedFiles) {
        try {
            # Get the folder and file name
            $folder = $shell.Namespace((Split-Path $file.FullName -Parent))
            $item = $folder.ParseName((Split-Path $file.FullName -Leaf))
            
            # Move to recycle bin (verb 10 = "Delete" which moves to recycle bin)
            $item.InvokeVerb("delete")
            Write-Host "  Moved to recycle bin: $($file.FullName)"
        }
        catch {
            Write-Error "Failed to move file to recycle bin: $($file.FullName) - $($_.Exception.Message)"
        }
    }
    
    # Clean up COM object
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
    
    Write-Host ""
    Write-Host "Operation completed."
}