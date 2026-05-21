# merge_git_logs_with_author_lines.ps1
# ------------------------
# 功能：
# 1. 遍历多个 Git 仓库
# 2. 提取每次提交的作者、时间、修改的文件
# 3. 支持起止时间筛选
# 4. 支持指定作者（可多个）
# 5. 输出每行包括：timestamp|author|M|filepath|added|deleted
# 6. 输出日志在脚本当前目录，文件名带当前时间
# ------------------------

# 获取脚本当前目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# 输出日志文件名带当前时间
$timestampNow = Get-Date -Format "yyyyMMdd_HHmmss"
$outputLog = Join-Path $scriptDir "merged_gitinspector_$timestampNow.log"

# 配置仓库路径列表
$repos = @(
    "D:\Codes\repo1",
    "D:\Codes\repo2",
	"D:\Codes\repo3"
)

# 配置时间范围
$since = "2025-09-01"
$until = "2025-12-31"

# 配置指定作者列表（空数组表示不过滤作者）
$authors = @("Hentai02","xxxx","xxx")

# 清空日志文件（如果已存在）
if (Test-Path $outputLog) {
    Remove-Item $outputLog
}

# 遍历每个仓库
foreach ($repo in $repos) {
    Write-Host "正在处理仓库: $repo"
    Set-Location $repo

    # 获取指定时间范围的提交 hash 列表
    $commits = git log --since="$since" --until="$until" --pretty=format:"%H"

    foreach ($commit in $commits) {
        # 获取作者
        $author = git show -s --format="%an" $commit

        # 如果指定了作者列表，且当前提交作者不在列表中，则跳过
        if ($authors.Count -gt 0 -and ($authors -notcontains $author)) {
            continue
        }

        # 获取 Unix 时间戳
        $timestamp = git show -s --format="%at" $commit

        # 获取提交每个文件的新增/删除行数
        # 输出格式：added deleted filepath
        $fileChanges = git show --numstat --format="" $commit

        foreach ($line in $fileChanges) {
            if ($line -match "^\s*(\d+|-)\s+(\d+|-)\s+(.+)$") {
                $added = $matches[1]
                $deleted = $matches[2]
                $file = $matches[3]

                # gitinspector 默认修改标记为 M
                "$timestamp|$author|M|$file|$added|$deleted" | Out-File -FilePath $outputLog -Append -Encoding utf8
            }
        }
    }
}

Write-Host "合并日志完成: $outputLog"
Read-Host "Press Enter to Exit"