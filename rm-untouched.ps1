# This script identifies files in a provided directory that have never been modified (CreationTime = LastWriteTime).
# If a specific date is provided, only files created on that date are processed. If no date is provided, all unmodified files are processed.
# These files are listed to stdout and moved to the recycle bin. If a --dry-run flag is present, it displays the list but does not move the files.
#
# Examples:
#   .\rm-untouched.ps1 -Path "C:\Temp"                                    # Remove all unmodified files in C:\Temp
#   .\rm-untouched.ps1 -Path "C:\Temp" -Recurse                           # Remove all unmodified files in C:\Temp and subfolders
#   .\rm-untouched.ps1 -Path "C:\Temp" -Date "2025-12-02"                 # Remove unmodified files created on Dec 2, 2025
#   .\rm-untouched.ps1 -Path "C:\Temp" -Date "12/2/2025" -Recurse         # Same as above with subfolders
#   .\rm-untouched.ps1 -Path "C:\Temp" -DryRun -Verbose                   # See what would be removed without doing it

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,
    
    [Parameter(Mandatory = $false, Position = 1)]
    [DateTime]$Date,
    
    # Search subfolders recursively
    [switch]$Recurse,
    
    [switch]$DryRun
)

# Validate directory exists
Write-Verbose "Validating directory: $Path"
if (-not (Test-Path -Path $Path -PathType Container)) {
    Write-Error "Directory '$Path' does not exist or is not a directory."
    exit 1
}
Write-Verbose "Directory exists and is valid"

# Get target date if specified
if ($PSBoundParameters.ContainsKey('Date')) {
    $targetDate = $Date.ToString("yyyy-MM-dd")
    Write-Verbose "Target date specified: $targetDate"
} else {
    $targetDate = $null
    Write-Verbose "No date specified - will process all unmodified files"
}
$mode = if ($DryRun) { "DRY-RUN" } else { "LIVE" }
Write-Verbose "Mode: $mode"
Write-Verbose "Recurse: $Recurse"

# Find files created today that have never been modified (CreationTime equals LastWriteTime)
if ($Recurse) {
    Write-Verbose "Searching for files recursively in: $Path"
} else {
    Write-Verbose "Searching for files in: $Path (not including subfolders)"
}
$allFiles = Get-ChildItem -Path $Path -File -Recurse:$Recurse
Write-Verbose "Found $($allFiles.Count) total file(s)"

if ($targetDate) {
    Write-Verbose "Filtering for files created on $targetDate with no modifications (CreationTime = LastWriteTime)"
    $untouchedFiles = $allFiles | Where-Object {
        $creationDate = $_.CreationTime.ToString("yyyy-MM-dd")
        
        # File was created on target date and creation time equals last write time (never modified)
        ($creationDate -eq $targetDate) -and ($_.CreationTime -eq $_.LastWriteTime)
    }
} else {
    Write-Verbose "Filtering for all files with no modifications (CreationTime = LastWriteTime)"
    $untouchedFiles = $allFiles | Where-Object {
        # File has never been modified (creation time equals last write time)
        $_.CreationTime -eq $_.LastWriteTime
    }
}
Write-Verbose "Found $($untouchedFiles.Count) untouched file(s) matching criteria"

if ($untouchedFiles.Count -eq 0) {
    if ($targetDate) {
        Write-Host "No untouched files created on $targetDate were found in '$Path'."
    } else {
        Write-Host "No untouched files were found in '$Path'."
    }
    exit 0
}

# Display the files
if ($targetDate) {
    Write-Host "Found $($untouchedFiles.Count) untouched file(s) created on $targetDate "
} else {
    Write-Host "Found $($untouchedFiles.Count) untouched file(s):"
}
foreach ($file in $untouchedFiles) {
    Write-Host "  $($file.FullName)"
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry run mode: Files would be moved to recycle bin, but no action was taken."
    Write-Verbose "Dry run completed - no files were deleted"
} else {
    Write-Host ""
    Write-Host "Moving files to recycle bin..."
    
    # Load Windows Shell COM object for moving to recycle bin
    Write-Verbose "Creating Shell.Application COM object for recycle bin operations"
    $shell = New-Object -ComObject Shell.Application
    
    foreach ($file in $untouchedFiles) {
        Write-Verbose "Processing file: $($file.Name)"
        try {
            # Get the folder and file name
            $parentPath = Split-Path $file.FullName -Parent
            $fileName = Split-Path $file.FullName -Leaf
            Write-Verbose "  Parent folder: $parentPath"
            Write-Verbose "  File name: $fileName"
            
            $folder = $shell.Namespace($parentPath)
            $item = $folder.ParseName($fileName)
            
            # Move to recycle bin (verb 10 = "Delete" which moves to recycle bin)
            Write-Verbose "  Invoking delete verb to move to recycle bin"
            $item.InvokeVerb("delete")
            Write-Host "  Moved to recycle bin: $($file.FullName)"
            Write-Verbose "  Successfully moved to recycle bin"
        }
        catch {
            Write-Error "Failed to move file to recycle bin: $($file.FullName) - $($_.Exception.Message)"
            Write-Verbose "  Error: $($_.Exception.Message)"
        }
    }
    
    # Clean up COM object
    Write-Verbose "Releasing Shell.Application COM object"
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
    Write-Verbose "COM object released successfully"
    
    Write-Host ""
    Write-Host "Operation completed."
}