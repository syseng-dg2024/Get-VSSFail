<#
.SYNOPSIS
Searches for writer-related keywords around the VSS_WS_FAILED_AT_FREEZE event.

.DESCRIPTION
This script reads a vsstrace log file, finds the first VSS_WS_FAILED_AT_FREEZE
event, extracts its timestamp, and then searches for lines containing keywords
like "writer", "freeze", "thaw", "backup", and "commit" within a 5-second window.

.PARAMETER LogFilePath
The path to the vsstrace log file.

.OUTPUTS
Prints any log entries containing writer-related keywords near the failure.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$LogFilePath
)

# Function to extract timestamp from a log line (same as before)
function Get-LogTimestamp {
    param(
        [string]$Line
    )
    if ($Line -match '^\[\s*(?<timestamp>\d{1,2}:\d{2}:\d{2}\.\d{3})*') {
        return [datetime]::ParseExact($Matches['timestamp'], "H:mm:ss.fff", $null)
    }
    return $null
}

Write-Host "Analyzing log file: $($LogFilePath)" -ForegroundColor Yellow
Write-Host "-------------------- Searching for Writer Keywords Near Freeze Failure --------------------" -ForegroundColor Yellow

$AllLines = Get-Content $LogFilePath
$FirstFailedIndex = -1
$FailedTimestampDT = $null
$SearchWindowSeconds = 5
$Keywords = @("writer", "freeze", "thaw", "backup", "commit")

# Find the first VSS_WS_FAILED_AT_FREEZE event and its timestamp
for ($i = 0; $i -lt $AllLines.Count; $i++) {
    if ($AllLines[$i] -like "*VSS_WS_FAILED_AT_FREEZE*") {
        $FirstFailedIndex = $i
        $FailedTimestampDT = Get-LogTimestamp -Line $AllLines[$i]
        if ($FailedTimestampDT) {
            Write-Host "First VSS_WS_FAILED_AT_FREEZE event found at line: $($FirstFailedIndex + 1) with timestamp: $($FailedTimestampDT.ToString("HH:mm:ss.fff"))" -ForegroundColor Red
        }
        break
    }
}

if ($FirstFailedIndex -ge 0 -and $FailedTimestampDT) {
    Write-Host "Searching for keywords 'writer', 'freeze', 'thaw', 'backup', 'commit' within a $($SearchWindowSeconds) second window..." -ForegroundColor Yellow
    for ($i = ([Math]::Max(0, $FirstFailedIndex - ($SearchWindowSeconds * 1000))); $i -le ([Math]::Min($FirstFailedIndex + ($SearchWindowSeconds * 1000), $AllLines.Count - 1)); $i++) {
        $Line = $AllLines[$i]
        $Timestamp = Get-LogTimestamp -Line $Line
        if ($Timestamp) {
            $TimeDifferenceSeconds = [Math]::Abs(($Timestamp - $FailedTimestampDT).TotalSeconds)
            if ($TimeDifferenceSeconds -le $SearchWindowSeconds) {
                foreach ($Keyword in $Keywords) {
                    if ($Line -like "*$Keyword*") {
                        Write-Host "Found Keyword '$Keyword' (line $($i + 1), $($Timestamp.ToString("HH:mm:ss.fff"))): $($Line)" -ForegroundColor Green
                        break # To avoid printing the same line multiple times for different keywords
                    }
                }
            }
        } else {
            foreach ($Keyword in $Keywords) {
                if ($Line -like "*$Keyword*") {
                    Write-Host "Found Keyword '$Keyword' (line $($i + 1), no timestamp parsed): $($Line)" -ForegroundColor Yellow
                    break
                }
            }
        }
    }
} else {
    Write-Host "Could not find the first VSS_WS_FAILED_AT_FREEZE event or its timestamp." -ForegroundColor Red
}

Write-Host "Analysis Complete." -ForegroundColor Yellow