# ==========================================
# 1. Project Paths
# ==========================================
$projectPaths = @(
    "D:\Codes\repo1",
    "D:\Codes\repo2",
	"D:\Codes\repo3"
)

# ==========================================
# 2. Authors
# ==========================================
$authors = @("Hentai02", "xxx", "xxxx")

# ==========================================
# 3. Time range setting (format: YYYY-MM-DD)
# ==========================================
#$sinceDate = "2026-05-01"  # Start date (inclusive)
#$untilDate = (Get-Date).ToString("yyyy-MM-dd")  # End date (inclusive)

$sinceDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
$untilDate = (Get-Date).ToString("yyyy-MM-dd")

#$sinceDate = (Get-Date -Day 1).ToString("yyyy-MM-dd")
#$untilDate = (Get-Date).ToString("yyyy-MM-dd")

# ==========================================
# 4. Core Logic
# ==========================================
function Get-GitStats {
    param([array]$Authors, [array]$Projects, $Since, $Until)
    $data = @()
    $root = Get-Location
    
    foreach ($p in $Projects) {
        if (Test-Path $p) {
            Set-Location $p
            $pName = Split-Path $p -Leaf
            
            $pullCmd = git pull 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "$pullCmd" -ForegroundColor Red
            }else {
			    Write-Host "$pullCmd" -ForegroundColor Green
		    }
            
            #Write-Host "Analyzing: $pName within range $Since to $Until" -ForegroundColor Cyan
            Write-Host "Analyzing: $pName" -ForegroundColor Cyan
            foreach ($a in $Authors) {
                if ($Since) { $sinceArg = "--since=`"$Since 00:00:00`"" }
                if ($Until) { $untilArg = "--until=`"$Until 23:59:59`"" }
                $logs = git log --author="$a" --since="$Since 00:00:00" --until="$Until 23:59:59" --pretty=format:"%ad" --date=short --numstat 2>$null
                
                $currDate = $null
                if ($null -ne $logs) {
                    foreach ($line in $logs) {
                        if ($line -match '^\d{4}-\d{2}-\d{2}$') { $currDate = $line }
                        elseif ($line -match '^(\d+)\s+(\d+)\s+(.+)$') {
                            if ($null -ne $currDate) {
                                $dateParts = $currDate -split '-'
                                $data += [PSCustomObject]@{
                                    Year = $dateParts[0]; Month = $dateParts[1]; Day = $dateParts[2]
                                    Author = $a; Project = $pName; Added = [int]$matches[1]; Removed = [int]$matches[2]
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Set-Location $root
    return $data
}

Write-Host "--- Git Daily Statistics ($sinceDate to $untilDate) ---" -ForegroundColor Yellow
$raw = Get-GitStats -Authors $authors -Projects $projectPaths -Since $sinceDate -Until $untilDate

if ($raw.Count -gt 0) {
    $final = $raw | Group-Object Year, Month, Day, Author | ForEach-Object {
        $keys = $_.Name -split ', '
        $add = ($_.Group | Measure-Object Added -Sum).Sum
        $rem = ($_.Group | Measure-Object Removed -Sum).Sum
        [PSCustomObject]@{
            Year = $keys[0]; Month = $keys[1]; Day = $keys[2]; Author = $keys[3]
            Added = $add; Removed = $rem; Net = $add - $rem; Files = $_.Group.Count
        }
    } | Sort-Object Year, Month, Day -Descending

    $final | Format-Table -AutoSize

    $ts = Get-Date -Format "yyyyMMdd_HHmm"
    $final | Export-Csv -Path "git_report_$ts.csv" -NoTypeInformation -Encoding UTF8
    Write-Host "Success! Report saved to git_report_$ts.csv" -ForegroundColor Green
} else {
    Write-Host "No data found!" -ForegroundColor Red
}
Read-Host "Press Enter to Exit"