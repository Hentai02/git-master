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
# 3. Core Logic
# ==========================================
function Get-GitStats {
    param([array]$Authors, [array]$Projects)
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
            
            Write-Host "Analyzing: $pName" -ForegroundColor Cyan
            foreach ($a in $Authors) {
                $logs = git log --author="$a" --pretty=format:"COMMIT_START|%ad" --date=short --numstat 2>$null
                $currDate = $null
                if ($null -ne $logs) {
                    foreach ($line in $logs) {
                        if ($line -match '^COMMIT_START\|(\d{4}-\d{2}-\d{2})$') { 
                            $currDate = $Matches[1] 
                            $dateParts = $currDate -split '-'
                            $data += [PSCustomObject]@{
                                Year = $dateParts[0]; Month = $dateParts[1]; Day = $dateParts[2]
                                Author = $a; Project = $pName; Added = 0; Removed = 0; IsCommit = 1; IsFile = 0
                            }
                        }
                        elseif ($line -match '^(\d+)\s+(\d+)\s+(.+)$') {
                            if ($null -ne $currDate) {
                                $dateParts = $currDate -split '-'
                                $data += [PSCustomObject]@{
                                    Year = $dateParts[0]; Month = $dateParts[1]; Day = $dateParts[2]
                                    Author = $a; Project = $pName; Added = [int]$Matches[1]; Removed = [int]$Matches[2]; IsCommit = 0; IsFile = 1
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

Write-Host "--- Git Daily Statistics (So far) ---" -ForegroundColor Yellow
$raw = Get-GitStats -Authors $authors -Projects $projectPaths

if ($raw.Count -gt 0) {
    $final = $raw | Group-Object Year, Month, Day, Author | ForEach-Object {
        $keys = $_.Name -split ', '
        $add = ($_.Group | Measure-Object Added -Sum).Sum
        $rem = ($_.Group | Measure-Object Removed -Sum).Sum
        $commitsCount = [int]@($_.Group | Where-Object { $_.IsCommit -eq 1 }).Count
        $filesCount   = [int]@($_.Group | Where-Object { $_.IsFile -eq 1 }).Count

        [PSCustomObject]@{
            Year    = $keys[0]
            Month   = $keys[1]
            Day     = $keys[2]
            Author  = $keys[3]
            Commits = $commitsCount
            Added   = $add
            Removed = $rem
            Net     = $add - $rem
            Files   = $filesCount
        }
    } | Sort-Object Year, Month, Day -Descending

    $final | Format-Table -AutoSize

    $ts = Get-Date -Format "yyyyMMdd_HHmm"
    $final | Export-Csv -Path "git_report_sofar_$ts.csv" -NoTypeInformation -Encoding UTF8
    Write-Host "Success! Report saved to git_report_sofar_$ts.csv" -ForegroundColor Green
} else {
    Write-Host "No data found!" -ForegroundColor Red
}
Read-Host "Press Enter to Exit"