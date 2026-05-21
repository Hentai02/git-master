# Project paths list
$projectPaths = @(
    "D:\Codes\repo1",
    "D:\Codes\repo2",
	"D:\Codes\repo3"
)

function Get-GitAuthorStatsEn {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AuthorName,
        [string]$ProjectPath,
        [string]$Since,
        [string]$Until,
        [switch]$Detailed = $false
    )
    
    # Save original directory
    $originalLocation = Get-Location
    
    # If project path specified, switch to that directory
    if ($ProjectPath) {
        if (Test-Path $ProjectPath) {
            Set-Location -Path $ProjectPath
            Write-Host "Switched to project: $ProjectPath" -ForegroundColor Gray
        } else {
            Write-Host "Error: Project directory not found: $ProjectPath" -ForegroundColor Red
            return $null
        }
    }
    
    # Check if current directory is a Git repository
    $isGitRepo = git rev-parse --is-inside-work-tree 2>$null
    if (-not $isGitRepo) {
        Write-Host "Error: Current directory is not a Git repository: $(Get-Location)" -ForegroundColor Red
        Set-Location -Path $originalLocation
        return $null
    }
    
    # ========== 1. Count commits ==========
    $commitCount = 0
	$commits = git rev-list --all --author=$AuthorName --count
	if ($commits) {
        $commitCount = $commits
    }
	
	#$shortlogOutput = git shortlog -s -n -e --all 2>$null
    #if ($shortlogOutput) {
    #    $authorLine = $shortlogOutput | Where-Object { $_ -match $AuthorName }
    #    if ($authorLine) {
    #        if ($authorLine -match '^\s*(\d+)\s+') {
    #            $commitCount = [int]$matches[1]
    #        }
    #    }
    #}
	
	
    #$commits = git log --author="$AuthorName" --oneline 2>$null
    #if ($commits) {
    #    $commitCount = ($commits | Measure-Object).Count
    #}
    
    # If no commits, return immediately
    if ($commitCount -eq 0) {
        Write-Host "No commits found for author: $AuthorName in $(Get-Location)" -ForegroundColor Yellow
        Set-Location -Path $originalLocation
        return $null
    }
    
    # ========== 2. Count code lines ==========
    $stats = @()
    
    try {
        # Build git command arguments
        $gitArgs = @("log", "--author=`"$AuthorName`"", "--pretty=tformat:", "--numstat")
        
        if ($Since) { $gitArgs += "--since=`"$Since`"" }
        if ($Until) { $gitArgs += "--until=`"$Until`"" }
        
        $numstatOutput = git @gitArgs 2>$null
        
        if ($numstatOutput) {
            $stats = $numstatOutput | ForEach-Object {
                $parts = $_ -split '\s+'
                if ($parts.Count -ge 2 -and $parts[0] -match '^\d+$' -and $parts[1] -match '^\d+$') {
                    [PSCustomObject]@{
                        Added = [int]$parts[0]
                        Removed = [int]$parts[1]
                        FileName = if ($parts.Count -ge 3) { $parts[2] } else { "" }
                    }
                }
            }
        }
    } catch {
        Write-Host "Error getting numstat: $_" -ForegroundColor Red
    }
    
    $totalAdded = ($stats | Measure-Object -Property Added -Sum).Sum
    $totalRemoved = ($stats | Measure-Object -Property Removed -Sum).Sum
    
    # ========== 3. Count file operations ==========
    $filesModified = @{}
    $uniqueFiles = @{}
    
    # Get files from --numstat
    $stats | ForEach-Object {
        if ($_.FileName) {
            $uniqueFiles[$_.FileName] = $true
            if (-not $filesModified.ContainsKey($_.FileName)) {
                $filesModified[$_.FileName] = @{
                    Added = $_.Added
                    Removed = $_.Removed
                    Status = "M"
                }
            }
        }
    }
    
    # Use --name-status for file operation status
    $filesCreated = @()
    $filesDeleted = @()
    $filesModifiedList = @()
    
    try {
        # Build name-status command
        $nameStatusArgs = @("log", "--author=`"$AuthorName`"", "--name-status", "--pretty=format:")
        
        if ($Since) { $nameStatusArgs += "--since=`"$Since`"" }
        if ($Until) { $nameStatusArgs += "--until=`"$Until`"" }
        
        $nameStatusOutput = git @nameStatusArgs 2>$null
        
        if ($nameStatusOutput) {
            $nameStatusOutput | ForEach-Object {
                if ($_ -match '^([A-Z])\s+(.+)$') {
                    $status = $matches[1]
                    $filePath = $matches[2].Trim()
                    
                    $uniqueFiles[$filePath] = $true
                    
                    switch ($status) {
                        "A" { 
                            $filesCreated += $filePath
                            if ($filesModified.ContainsKey($filePath)) {
                                $filesModified[$filePath].Status = "A"
                            } else {
                                $filesModified[$filePath] = @{
                                    Added = 0
                                    Removed = 0
                                    Status = "A"
                                }
                            }
                        }
                        "D" { 
                            $filesDeleted += $filePath
                            if ($filesModified.ContainsKey($filePath)) {
                                $filesModified[$filePath].Status = "D"
                            } else {
                                $filesModified[$filePath] = @{
                                    Added = 0
                                    Removed = 0
                                    Status = "D"
                                }
                            }
                        }
                        "M" { 
                            $filesModifiedList += $filePath
                            if ($filesModified.ContainsKey($filePath)) {
                                $filesModified[$filePath].Status = "M"
                            } else {
                                $filesModified[$filePath] = @{
                                    Added = 0
                                    Removed = 0
                                    Status = "M"
                                }
                            }
                        }
                        "R" { 
                            # Rename: old file as deleted, new file as added
                            if ($_ -match '^R(\d+)\s+(.+?)\s+(.+)$') {
                                $oldFile = $matches[2]
                                $newFile = $matches[3]
                                $filesDeleted += $oldFile
                                $filesCreated += $newFile
                                $uniqueFiles[$oldFile] = $true
                                $uniqueFiles[$newFile] = $true
                            }
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "Error getting name-status: $_" -ForegroundColor Red
    }
    
    # Remove duplicates
    $filesCreated = $filesCreated | Sort-Object | Get-Unique
    $filesDeleted = $filesDeleted | Sort-Object | Get-Unique
    $filesModifiedList = $filesModifiedList | Sort-Object | Get-Unique
    
    # Count totals
    $totalFiles = $uniqueFiles.Count
    $createdCount = $filesCreated.Count
    $deletedCount = $filesDeleted.Count
    $modifiedCount = $filesModifiedList.Count
    
    # ========== 4. Get first and last commit dates ==========
    $firstCommit = $null
    $lastCommit = $null
    
    try {
        # Get first commit
        $firstCommitArgs = @("log", "--author=`"$AuthorName`"", "--pretty=format:`"%ad`"", "--date=short", "--reverse")
        if ($Since) { $firstCommitArgs += "--since=`"$Since`"" }
        if ($Until) { $firstCommitArgs += "--until=`"$Until`"" }
        
        $firstCommit = (git @firstCommitArgs 2>$null | Select-Object -First 1)
        
        # Get last commit
        $lastCommitArgs = @("log", "--author=`"$AuthorName`"", "--pretty=format:`"%ad`"", "--date=short", "-1")
        if ($Since) { $lastCommitArgs += "--since=`"$Since`"" }
        if ($Until) { $lastCommitArgs += "--until=`"$Until`"" }
        
        $lastCommit = (git @lastCommitArgs 2>$null | Select-Object -First 1)
    } catch {
        Write-Host "Error getting commit dates: $_" -ForegroundColor Red
    }
    
    # ========== 5. Build result object ==========
    $result = [PSCustomObject]@{
        # Basic info
        Author = $AuthorName
        Project = if ($ProjectPath) { (Get-Item $ProjectPath).Name } else { (Get-Location).Path }
        Period = if ($Since -or $Until) { "$Since to $Until" } else { "All time" }
        
        # Commit stats
        CommitCount = $commitCount
        FirstCommit = $firstCommit
        LastCommit = $lastCommit
        
        # Code line stats
        AddedLines = $totalAdded
        RemovedLines = $totalRemoved
        NetLines = $totalAdded - $totalRemoved
        TotalChanges = $totalAdded + $totalRemoved
        
        # File stats
        TotalFiles = $totalFiles
        FilesCreated = $createdCount
        FilesDeleted = $deletedCount
        FilesModified = $modifiedCount
    }
    
    # If detailed mode enabled, add extra info
    if ($Detailed) {
        # File type statistics
        $fileTypeStats = @{}
        foreach ($file in $uniqueFiles.Keys) {
            $extension = [System.IO.Path]::GetExtension($file)
            if ([string]::IsNullOrEmpty($extension)) {
                $extension = "(no extension)"
            }
            
            if (-not $fileTypeStats.ContainsKey($extension)) {
                $fileTypeStats[$extension] = @{
                    Count = 0
                    Added = 0
                    Removed = 0
                }
            }
            
            $fileTypeStats[$extension].Count++
            
            if ($filesModified.ContainsKey($file)) {
                $fileTypeStats[$extension].Added += $filesModified[$file].Added
                $fileTypeStats[$extension].Removed += $filesModified[$file].Removed
            }
        }
        
        $result | Add-Member -NotePropertyName "FileTypeStats" -NotePropertyValue $fileTypeStats
        $result | Add-Member -NotePropertyName "CreatedFileList" -NotePropertyValue $filesCreated
        $result | Add-Member -NotePropertyName "DeletedFileList" -NotePropertyValue $filesDeleted
        $result | Add-Member -NotePropertyName "ModifiedFileList" -NotePropertyValue $filesModifiedList
    }
    
    # Return to original directory
    Set-Location -Path $originalLocation
    
    return $result
}

# ========== Display function ==========
function Show-GitStats {
    param(
        [Parameter(Mandatory=$true)]
        $Stats
    )
    
    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "GIT STATISTICS FOR: $($Stats.Author)" -ForegroundColor Cyan
    Write-Host "PROJECT: $($Stats.Project)" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    
    Write-Host "Period: $($Stats.Period)"
    Write-Host "Commits: $($Stats.CommitCount)"
    Write-Host "First commit: $($Stats.FirstCommit)"
    Write-Host "Last commit: $($Stats.LastCommit)"
    Write-Host ""
    
    Write-Host "Code lines:" -ForegroundColor Yellow
    Write-Host "  Added: $($Stats.AddedLines)"
    Write-Host "  Removed: $($Stats.RemovedLines)"
    Write-Host "  Net change: $($Stats.NetLines)"
    Write-Host "  Total changes: $($Stats.TotalChanges)"
    Write-Host ""
    
    Write-Host "File operations:" -ForegroundColor Yellow
    Write-Host "  Total files touched: $($Stats.TotalFiles)"
    Write-Host "  Files created: $($Stats.FilesCreated)"
    Write-Host "  Files deleted: $($Stats.FilesDeleted)"
    Write-Host "  Files modified: $($Stats.FilesModified)"
    
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

# ========== Batch statistics for multiple projects and authors ==========
function Get-StatsForAllProjects {
    param(
        [array]$Authors,
        [array]$Projects
    )
    
    $allStats = @()
    
    foreach ($project in $Projects) {
        Write-Host "`n" + ("=" * 50) -ForegroundColor Green
        Write-Host "PROJECT: $project" -ForegroundColor Green
        Write-Host ("=" * 50) -ForegroundColor Green
        
        if (-not (Test-Path $project)) {
            Write-Host "Project directory not found: $project" -ForegroundColor Red
            continue
        }
		
		# Update project
		$originalLocation = Get-Location
        Set-Location -Path $project
		
		$pullCmd = git pull 2>&1
		if ($LASTEXITCODE -eq 0) {
			Write-Host "$pullCmd" -ForegroundColor Green
		} else {
			Write-Host "$pullCmd" -ForegroundColor Red
		}
		
		Set-Location -Path $originalLocation
		# Update project
        
        $projectStats = @()
        
        foreach ($author in $Authors) {
            Write-Host "`nProcessing author: $author" -ForegroundColor Gray
            
            try {
                $stats = Get-GitAuthorStatsEn -AuthorName $author -ProjectPath $project
                if ($stats) {
                    Show-GitStats -Stats $stats
                    $stats | Add-Member -NotePropertyName "ProjectPath" -NotePropertyValue $project -Force
                    $projectStats += $stats
                    $allStats += $stats
                }
            } catch {
                Write-Host "Error processing $author in $project : $_" -ForegroundColor Red
            }
        }
        
        # Display rankings within project
        if ($projectStats.Count -gt 0) {
            Write-Host "`nPROJECT RANKING: $(Split-Path $project -Leaf)" -ForegroundColor Magenta
            
            Write-Host "By commits:" -ForegroundColor Yellow
            $i = 1
            $projectStats | Sort-Object CommitCount -Descending | ForEach-Object {
                Write-Host "  $i. $($_.Author): $($_.CommitCount) commits, $($_.AddedLines) lines added"
                $i++
            }
            
            Write-Host "`nBy net lines:" -ForegroundColor Green
            $i = 1
            $projectStats | Sort-Object NetLines -Descending | ForEach-Object {
                $symbol = if ($_.NetLines -gt 0) { "[+]" } elseif ($_.NetLines -lt 0) { "[-]" } else { "[=]" }
                Write-Host "  $i. $($_.Author): $symbol $($_.NetLines) lines (Added:$($_.AddedLines) Removed:$($_.RemovedLines))"
                $i++
            }
            
            Write-Host "`nBy total files:" -ForegroundColor Cyan
            $i = 1
            $projectStats | Sort-Object TotalFiles -Descending | ForEach-Object {
                Write-Host "  $i. $($_.Author): $($_.TotalFiles) files (Created:$($_.FilesCreated) Modified:$($_.FilesModified) Deleted:$($_.FilesDeleted))"
                $i++
            }
            
            Write-Host "`nBy total changes:" -ForegroundColor Blue
            $i = 1
            $projectStats | Sort-Object TotalChanges -Descending | ForEach-Object {
                Write-Host "  $i. $($_.Author): $($_.TotalChanges) changes"
                $i++
            }
        }
    }
    
    return $allStats
}

# ========== Summary table display ==========
function Show-SummaryTable {
    param(
        [array]$StatsList
    )
    
    if ($StatsList.Count -eq 0) {
        Write-Host "No statistics to display" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n" + ("=" * 130) -ForegroundColor Green
    Write-Host "SUMMARY OF ALL PROJECTS AND AUTHORS" -ForegroundColor Green
    Write-Host ("=" * 130) -ForegroundColor Green
    
    # Create table data
    $tableData = foreach ($stats in $StatsList) {
        [PSCustomObject]@{
            Project = Split-Path $stats.ProjectPath -Leaf
            Author = $stats.Author
            Commits = $stats.CommitCount
            Added = $stats.AddedLines
            Removed = $stats.RemovedLines
            Net = $stats.NetLines
            Total = $stats.TotalChanges
            Files = $stats.TotalFiles
            Created = $stats.FilesCreated
            Modified = $stats.FilesModified
            Deleted = $stats.FilesDeleted
        }
    }
    
    # Display table
    $tableData | Format-Table -AutoSize -Property @(
        @{Label="Project"; Expression={$_.Project}; Width=10},
        @{Label="Author"; Expression={$_.Author}; Width=12},
        @{Label="Commits"; Expression={$_.Commits}; Width=7; Align='Right'},
        @{Label="Added"; Expression={$_.Added}; Width=9; Align='Right'},
        @{Label="Removed"; Expression={$_.Removed}; Width=9; Align='Right'},
        @{Label="Net"; Expression={
            if ($_.Net -gt 0) { "+$($_.Net)" } else { "$($_.Net)" }
        }; Width=9; Align='Right'},
        @{Label="Total"; Expression={$_.Total}; Width=10; Align='Right'},
        @{Label="Files"; Expression={$_.Files}; Width=7; Align='Right'},
        @{Label="Created"; Expression={$_.Created}; Width=8; Align='Right'},
        @{Label="Modified"; Expression={$_.Modified}; Width=9; Align='Right'},
        @{Label="Deleted"; Expression={$_.Deleted}; Width=8; Align='Right'}
    )
    
    Write-Host ("=" * 130) -ForegroundColor Green
    
    # Display overall rankings
    Write-Host "`nOVERALL RANKINGS" -ForegroundColor Cyan
    
    # 1. By commit count
    Write-Host "1. Top authors by commits:" -ForegroundColor Yellow
    $i = 1
    $StatsList | Group-Object Author | ForEach-Object {
        $totalCommits = ($_.Group | Measure-Object CommitCount -Sum).Sum
        $totalAdded = ($_.Group | Measure-Object AddedLines -Sum).Sum
        $totalNet = ($_.Group | Measure-Object NetLines -Sum).Sum
        $totalFiles = ($_.Group | Measure-Object TotalFiles -Sum).Sum
        [PSCustomObject]@{
            Author = $_.Name
            TotalCommits = $totalCommits
            TotalAdded = $totalAdded
            TotalNet = $totalNet
            TotalFiles = $totalFiles
            Projects = $_.Group.Count
        }
    } | Sort-Object TotalCommits -Descending | Select-Object -First 5 | ForEach-Object {
        $netSymbol = if ($_.TotalNet -gt 0) { "[+] " } elseif ($_.TotalNet -lt 0) { "[-] " } else { "[=] " }
        Write-Host "  $i. $($_.Author): $($_.TotalCommits) commits, $($_.TotalAdded) lines added, $($_.TotalFiles) files, $netSymbol$($_.TotalNet) net (across $($_.Projects) projects)"
        $i++
    }
    
    # 2. By added lines
    Write-Host "`n2. Top authors by lines added:" -ForegroundColor Yellow
    $i = 1
    $StatsList | Group-Object Author | ForEach-Object {
        $totalAdded = ($_.Group | Measure-Object AddedLines -Sum).Sum
        $totalRemoved = ($_.Group | Measure-Object RemovedLines -Sum).Sum
        $totalNet = $totalAdded - $totalRemoved
        $totalCommits = ($_.Group | Measure-Object CommitCount -Sum).Sum
        $totalFiles = ($_.Group | Measure-Object TotalFiles -Sum).Sum
        [PSCustomObject]@{
            Author = $_.Name
            TotalAdded = $totalAdded
            TotalRemoved = $totalRemoved
            TotalNet = $totalNet
            TotalCommits = $totalCommits
            TotalFiles = $totalFiles
        }
    } | Sort-Object TotalAdded -Descending | Select-Object -First 5 | ForEach-Object {
        $netSymbol = if ($_.TotalNet -gt 0) { "[+] " } elseif ($_.TotalNet -lt 0) { "[-] " } else { "[=] " }
        Write-Host "  $i. $($_.Author): $($_.TotalAdded) lines added, $($_.TotalRemoved) removed, $($_.TotalFiles) files, $netSymbol$($_.TotalNet) net, $($_.TotalCommits) commits"
        $i++
    }
    
    # 3. By net lines
    Write-Host "`n3. Top authors by net lines:" -ForegroundColor Green
    $i = 1
    $StatsList | Group-Object Author | ForEach-Object {
        $totalAdded = ($_.Group | Measure-Object AddedLines -Sum).Sum
        $totalRemoved = ($_.Group | Measure-Object RemovedLines -Sum).Sum
        $totalNet = $totalAdded - $totalRemoved
        $totalCommits = ($_.Group | Measure-Object CommitCount -Sum).Sum
        $totalFiles = ($_.Group | Measure-Object TotalFiles -Sum).Sum
        $efficiency = if ($totalCommits -gt 0) { [math]::Round($totalNet / $totalCommits, 1) } else { 0 }
        [PSCustomObject]@{
            Author = $_.Name
            TotalNet = $totalNet
            TotalAdded = $totalAdded
            TotalRemoved = $totalRemoved
            TotalCommits = $totalCommits
            TotalFiles = $totalFiles
            Efficiency = $efficiency
        }
    } | Sort-Object TotalNet -Descending | Select-Object -First 10 | ForEach-Object {
        $symbol = if ($_.TotalNet -gt 0) { "[+]" } elseif ($_.TotalNet -lt 0) { "[-]" } else { "[=]" }
        $netDisplay = if ($_.TotalNet -gt 0) { "+$($_.TotalNet)" } else { "$($_.TotalNet)" }
        Write-Host "  $i. $($_.Author): $symbol $netDisplay lines (Added:$($_.TotalAdded) Removed:$($_.TotalRemoved) Files:$($_.TotalFiles))"
        if ($_.Efficiency -ne 0) {
            $efficiencySymbol = if ($_.Efficiency -gt 0) { "[+]" } else { "[-]" }
            Write-Host "     Efficiency: $efficiencySymbol$($_.Efficiency) lines/commit" -ForegroundColor Gray
        }
        $i++
    }
    
    # 4. By total files (新增文件排行)
    Write-Host "`n4. Top authors by files touched:" -ForegroundColor Magenta
    $i = 1
    $StatsList | Group-Object Author | ForEach-Object {
        $totalFiles = ($_.Group | Measure-Object TotalFiles -Sum).Sum
        $createdFiles = ($_.Group | Measure-Object FilesCreated -Sum).Sum
        $modifiedFiles = ($_.Group | Measure-Object FilesModified -Sum).Sum
        $deletedFiles = ($_.Group | Measure-Object FilesDeleted -Sum).Sum
        $totalCommits = ($_.Group | Measure-Object CommitCount -Sum).Sum
        $totalAdded = ($_.Group | Measure-Object AddedLines -Sum).Sum
        [PSCustomObject]@{
            Author = $_.Name
            TotalFiles = $totalFiles
            CreatedFiles = $createdFiles
            ModifiedFiles = $modifiedFiles
            DeletedFiles = $deletedFiles
            TotalCommits = $totalCommits
            TotalAdded = $totalAdded
            Projects = $_.Group.Count
        }
    } | Sort-Object TotalFiles -Descending | Select-Object -First 10 | ForEach-Object {
        $fileActivity = "Created:$($_.CreatedFiles) Modified:$($_.ModifiedFiles) Deleted:$($_.DeletedFiles)"
        Write-Host "  $i. $($_.Author): $($_.TotalFiles) files ($fileActivity)"
        Write-Host "     Commits:$($_.TotalCommits) Added lines:$($_.TotalAdded) Projects:$($_.Projects)" -ForegroundColor Gray
        $i++
    }
    
    # 5. By total changes
    Write-Host "`n5. Top authors by total changes:" -ForegroundColor Blue
    $i = 1
    $StatsList | Group-Object Author | ForEach-Object {
        $totalChanges = ($_.Group | Measure-Object TotalChanges -Sum).Sum
        $totalAdded = ($_.Group | Measure-Object AddedLines -Sum).Sum
        $totalNet = ($_.Group | Measure-Object NetLines -Sum).Sum
        $totalFiles = ($_.Group | Measure-Object TotalFiles -Sum).Sum
        [PSCustomObject]@{
            Author = $_.Name
            TotalChanges = $totalChanges
            TotalAdded = $totalAdded
            TotalNet = $totalNet
            TotalFiles = $totalFiles
        }
    } | Sort-Object TotalChanges -Descending | Select-Object -First 5 | ForEach-Object {
        $netSymbol = if ($_.TotalNet -gt 0) { "[+] " } elseif ($_.TotalNet -lt 0) { "[-] " } else { "[=] " }
        Write-Host "  $i. $($_.Author): $($_.TotalChanges) total changes, $($_.TotalAdded) added, $($_.TotalFiles) files, $netSymbol$($_.TotalNet) net"
        $i++
    }
    
    # 6. By efficiency (net lines per commit)
    Write-Host "`n6. Most efficient authors (net lines per commit):" -ForegroundColor DarkCyan
    $i = 1
    $StatsList | Group-Object Author | ForEach-Object {
        $totalCommits = ($_.Group | Measure-Object CommitCount -Sum).Sum
        $totalNet = ($_.Group | Measure-Object NetLines -Sum).Sum
        $efficiency = if ($totalCommits -gt 0) { [math]::Round($totalNet / $totalCommits, 1) } else { 0 }
        $totalAdded = ($_.Group | Measure-Object AddedLines -Sum).Sum
        $totalFiles = ($_.Group | Measure-Object TotalFiles -Sum).Sum
        [PSCustomObject]@{
            Author = $_.Name
            Efficiency = $efficiency
            TotalNet = $totalNet
            TotalCommits = $totalCommits
            TotalAdded = $totalAdded
            TotalFiles = $totalFiles
        }
    } | Where-Object { $_.TotalCommits -ge 5 } | Sort-Object Efficiency -Descending | Select-Object -First 8 | ForEach-Object {
        $symbol = if ($_.Efficiency -gt 0) { ">" } elseif ($_.Efficiency -lt 0) { "<" } else { "=" }
        $efficiencyDisplay = if ($_.Efficiency -gt 0) { "+$($_.Efficiency)" } else { "$($_.Efficiency)" }
        Write-Host "  $i. $($_.Author): $symbol $efficiencyDisplay lines/commit (Net:$($_.TotalNet), Commits:$($_.TotalCommits), Files:$($_.TotalFiles))"
        $i++
    }
    
    # 7. By file efficiency (files per commit)
    Write-Host "`n7. Most active file contributors (files per commit):" -ForegroundColor DarkMagenta
    $i = 1
    $StatsList | Group-Object Author | ForEach-Object {
        $totalCommits = ($_.Group | Measure-Object CommitCount -Sum).Sum
        $totalFiles = ($_.Group | Measure-Object TotalFiles -Sum).Sum
        $fileEfficiency = if ($totalCommits -gt 0) { [math]::Round($totalFiles / $totalCommits, 1) } else { 0 }
        $totalAdded = ($_.Group | Measure-Object AddedLines -Sum).Sum
        $createdFiles = ($_.Group | Measure-Object FilesCreated -Sum).Sum
        [PSCustomObject]@{
            Author = $_.Name
            FileEfficiency = $fileEfficiency
            TotalFiles = $totalFiles
            TotalCommits = $totalCommits
            TotalAdded = $totalAdded
            CreatedFiles = $createdFiles
        }
    } | Where-Object { $_.TotalCommits -ge 5 } | Sort-Object FileEfficiency -Descending | Select-Object -First 8 | ForEach-Object {
        Write-Host "  $i. $($_.Author): $($_.FileEfficiency) files/commit (Total:$($_.TotalFiles) files, Created:$($_.CreatedFiles), Commits:$($_.TotalCommits))"
        $i++
    }
}

# ========== Net lines analysis function ==========
function Analyze-NetLines {
    param(
        [array]$StatsList
    )
    
    if ($StatsList.Count -eq 0) {
        Write-Host "No data for net lines analysis" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n" + ("=" * 90) -ForegroundColor Cyan
    Write-Host "NET LINES ANALYSIS" -ForegroundColor Cyan
    Write-Host ("=" * 90) -ForegroundColor Cyan
    
    # Group by author
    $authorStats = $StatsList | Group-Object Author | ForEach-Object {
        $totalAdded = ($_.Group | Measure-Object AddedLines -Sum).Sum
        $totalRemoved = ($_.Group | Measure-Object RemovedLines -Sum).Sum
        $totalNet = $totalAdded - $totalRemoved
        $totalCommits = ($_.Group | Measure-Object CommitCount -Sum).Sum
        $totalChanges = $totalAdded + $totalRemoved
        $totalFiles = ($_.Group | Measure-Object TotalFiles -Sum).Sum
        $createdFiles = ($_.Group | Measure-Object FilesCreated -Sum).Sum
        $projects = $_.Group.Count
        
        # Calculate efficiency metrics
        $efficiency = if ($totalCommits -gt 0) { [math]::Round($totalNet / $totalCommits, 1) } else { 0 }
        $changeEfficiency = if ($totalCommits -gt 0) { [math]::Round($totalChanges / $totalCommits, 1) } else { 0 }
        $fileEfficiency = if ($totalCommits -gt 0) { [math]::Round($totalFiles / $totalCommits, 1) } else { 0 }
        $netRatio = if ($totalChanges -gt 0) { [math]::Round(($totalNet / $totalChanges) * 100, 1) } else { 0 }
        
        [PSCustomObject]@{
            Author = $_.Name
            TotalNet = $totalNet
            TotalAdded = $totalAdded
            TotalRemoved = $totalRemoved
            TotalCommits = $totalCommits
            TotalChanges = $totalChanges
            TotalFiles = $totalFiles
            CreatedFiles = $createdFiles
            Projects = $projects
            Efficiency = $efficiency
            ChangeEfficiency = $changeEfficiency
            FileEfficiency = $fileEfficiency
            NetRatio = $netRatio
        }
    } | Sort-Object TotalNet -Descending
    
    # Display analysis
    Write-Host "`nPOSITIVE CONTRIBUTORS (Net lines > 0):" -ForegroundColor Green
    $positiveAuthors = $authorStats | Where-Object { $_.TotalNet -gt 0 }
    if ($positiveAuthors.Count -gt 0) {
        $positiveAuthors | ForEach-Object {
            $netDisplay = if ($_.TotalNet -gt 0) { "+$($_.TotalNet)" } else { "$($_.TotalNet)" }
            Write-Host "  $($_.Author): $netDisplay lines"
            Write-Host "    Added:$($_.TotalAdded) Removed:$($_.TotalRemoved) Commits:$($_.TotalCommits) Files:$($_.TotalFiles) Projects:$($_.Projects)" -ForegroundColor Gray
            Write-Host "    Efficiency: $($_.Efficiency) net/commit, $($_.ChangeEfficiency) changes/commit, $($_.FileEfficiency) files/commit, Net ratio: $($_.NetRatio)%" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  No positive contributors found" -ForegroundColor Gray
    }
    
    Write-Host "`nNEGATIVE CONTRIBUTORS (Net lines < 0):" -ForegroundColor Red
    $negativeAuthors = $authorStats | Where-Object { $_.TotalNet -lt 0 }
    if ($negativeAuthors.Count -gt 0) {
        $negativeAuthors | Sort-Object TotalNet | ForEach-Object {
            Write-Host "  $($_.Author): $($_.TotalNet) lines"
            Write-Host "    Added:$($_.TotalAdded) Removed:$($_.TotalRemoved) Commits:$($_.TotalCommits) Files:$($_.TotalFiles)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No negative contributors found" -ForegroundColor Gray
    }
    
    Write-Host "`nNEUTRAL CONTRIBUTORS (Net lines = 0):" -ForegroundColor Yellow
    $neutralAuthors = $authorStats | Where-Object { $_.TotalNet -eq 0 }
    if ($neutralAuthors.Count -gt 0) {
        $neutralAuthors | ForEach-Object {
            Write-Host "  $($_.Author): 0 lines (Added:$($_.TotalAdded) = Removed:$($_.TotalRemoved)) Files:$($_.TotalFiles)" -ForegroundColor Gray
        }
    }
    
    # Summary statistics
    $totalNetAll = ($authorStats | Measure-Object TotalNet -Sum).Sum
    $totalAddedAll = ($authorStats | Measure-Object TotalAdded -Sum).Sum
    $totalRemovedAll = ($authorStats | Measure-Object TotalRemoved -Sum).Sum
    $totalFilesAll = ($authorStats | Measure-Object TotalFiles -Sum).Sum
    
    Write-Host "`nSUMMARY:" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "  Total net lines across all authors: $(if($totalNetAll -gt 0){'+'})$totalNetAll" -ForegroundColor White
    Write-Host "  Total lines added: $totalAddedAll" -ForegroundColor White
    Write-Host "  Total lines removed: $totalRemovedAll" -ForegroundColor White
    Write-Host "  Total files touched: $totalFilesAll" -ForegroundColor White
    Write-Host "  Number of authors analyzed: $($authorStats.Count)" -ForegroundColor White
    Write-Host "  Positive contributors: $($positiveAuthors.Count)" -ForegroundColor Green
    Write-Host "  Negative contributors: $($negativeAuthors.Count)" -ForegroundColor Red
    Write-Host "  Neutral contributors: $($neutralAuthors.Count)" -ForegroundColor Yellow
    
    Write-Host ("=" * 90) -ForegroundColor Cyan
}

# ========== File analysis function ==========
function Analyze-Files {
    param(
        [array]$StatsList
    )
    
    if ($StatsList.Count -eq 0) {
        Write-Host "No data for file analysis" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n" + ("=" * 90) -ForegroundColor Magenta
    Write-Host "FILE OPERATIONS ANALYSIS" -ForegroundColor Magenta
    Write-Host ("=" * 90) -ForegroundColor Magenta
    
    # Group by author
    $authorStats = $StatsList | Group-Object Author | ForEach-Object {
        $totalFiles = ($_.Group | Measure-Object TotalFiles -Sum).Sum
        $createdFiles = ($_.Group | Measure-Object FilesCreated -Sum).Sum
        $modifiedFiles = ($_.Group | Measure-Object FilesModified -Sum).Sum
        $deletedFiles = ($_.Group | Measure-Object FilesDeleted -Sum).Sum
        $totalCommits = ($_.Group | Measure-Object CommitCount -Sum).Sum
        $totalAdded = ($_.Group | Measure-Object AddedLines -Sum).Sum
        $totalNet = ($_.Group | Measure-Object NetLines -Sum).Sum
        $projects = $_.Group.Count
        
        # Calculate file metrics
        $fileEfficiency = if ($totalCommits -gt 0) { [math]::Round($totalFiles / $totalCommits, 1) } else { 0 }
        $creationRate = if ($totalFiles -gt 0) { [math]::Round(($createdFiles / $totalFiles) * 100, 1) } else { 0 }
        $modificationRate = if ($totalFiles -gt 0) { [math]::Round(($modifiedFiles / $totalFiles) * 100, 1) } else { 0 }
        $linesPerFile = if ($totalFiles -gt 0) { [math]::Round($totalAdded / $totalFiles, 1) } else { 0 }
        
        [PSCustomObject]@{
            Author = $_.Name
            TotalFiles = $totalFiles
            CreatedFiles = $createdFiles
            ModifiedFiles = $modifiedFiles
            DeletedFiles = $deletedFiles
            TotalCommits = $totalCommits
            TotalAdded = $totalAdded
            TotalNet = $totalNet
            Projects = $projects
            FileEfficiency = $fileEfficiency
            CreationRate = $creationRate
            ModificationRate = $modificationRate
            LinesPerFile = $linesPerFile
        }
    } | Sort-Object TotalFiles -Descending
    
    # Display file creators ranking
    Write-Host "`nTOP FILE CREATORS:" -ForegroundColor Green
    $i = 1
    $authorStats | Sort-Object CreatedFiles -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $i. $($_.Author): $($_.CreatedFiles) files created"
        Write-Host "     Total files:$($_.TotalFiles) Modified:$($_.ModifiedFiles) Deleted:$($_.DeletedFiles)" -ForegroundColor Gray
        $i++
    }
    
    # Display file modifiers ranking
    Write-Host "`nTOP FILE MODIFIERS:" -ForegroundColor Yellow
    $i = 1
    $authorStats | Sort-Object ModifiedFiles -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $i. $($_.Author): $($_.ModifiedFiles) files modified"
        Write-Host "     Created:$($_.CreatedFiles) Total:$($_.TotalFiles) Creation rate:$($_.CreationRate)%" -ForegroundColor Gray
        $i++
    }
    
    # Display overall file activity
    Write-Host "`nOVERALL FILE ACTIVITY:" -ForegroundColor Cyan
    $i = 1
    $authorStats | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $i. $($_.Author): $($_.TotalFiles) total files"
        Write-Host "     C:$($_.CreatedFiles) M:$($_.ModifiedFiles) D:$($_.DeletedFiles) File/Commit:$($_.FileEfficiency) Lines/File:$($_.LinesPerFile)" -ForegroundColor Gray
        $i++
    }
    
    # Summary statistics
    $totalFilesAll = ($authorStats | Measure-Object TotalFiles -Sum).Sum
    $createdFilesAll = ($authorStats | Measure-Object CreatedFiles -Sum).Sum
    $modifiedFilesAll = ($authorStats | Measure-Object ModifiedFiles -Sum).Sum
    $deletedFilesAll = ($authorStats | Measure-Object DeletedFiles -Sum).Sum
    
    Write-Host "`nFILE OPERATIONS SUMMARY:" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "  Total files touched: $totalFilesAll" -ForegroundColor White
    Write-Host "  Files created: $createdFilesAll ($([math]::Round(($createdFilesAll / $totalFilesAll) * 100, 1))%)" -ForegroundColor White
    Write-Host "  Files modified: $modifiedFilesAll ($([math]::Round(($modifiedFilesAll / $totalFilesAll) * 100, 1))%)" -ForegroundColor White
    Write-Host "  Files deleted: $deletedFilesAll ($([math]::Round(($deletedFilesAll / $totalFilesAll) * 100, 1))%)" -ForegroundColor White
    Write-Host "  Unique files (deduplicated): $([math]::Round($totalFilesAll / $StatsList.Count, 0)) average per author" -ForegroundColor White
    
    Write-Host ("=" * 90) -ForegroundColor Magenta
}

# ========== Main program ==========

Write-Host "=== GIT STATISTICS TOOL ===" -ForegroundColor Green
Write-Host "Projects to analyze:" -ForegroundColor Yellow
foreach ($path in $projectPaths) {
    Write-Host "  - $path"
}

$authors = @("Hentai02", "xxx", "xxxx")

Write-Host "`nAuthors to analyze:" -ForegroundColor Yellow
foreach ($author in $authors) {
    Write-Host "  - $author"
}

Write-Host "`nStarting analysis..." -ForegroundColor Green

# Execute statistics
$allStats = Get-StatsForAllProjects -Authors $authors -Projects $projectPaths

# Display summary
if ($allStats.Count -gt 0) {
    Show-SummaryTable -StatsList $allStats
    
    # Net lines analysis
    Analyze-NetLines -StatsList $allStats
    
    # File analysis
    Analyze-Files -StatsList $allStats
    
    # Save results to file
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outputFile = "git-stats-$timestamp.csv"
    
    $allStats | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host "`nResults saved to: $outputFile" -ForegroundColor Green
} else {
    Write-Host "No statistics collected." -ForegroundColor Yellow
}

# Keep window open
Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
Read-Host