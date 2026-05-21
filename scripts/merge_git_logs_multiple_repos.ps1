# merge_git_logs_multiple_repos.ps1
# ------------------------
# 功能：
# 1. 遍历多个 Git 仓库
# 2. 提取每次提交的作者、时间、修改的文件
# 3. 支持起止时间筛选
# 4. 支持指定作者（可多个）
# 5. 自动获取每个文件新增/删除行数
# 6. 输出 GitInspector 可用日志到脚本目录，文件名带时间戳
# ------------------------

# 1️⃣ 脚本当前目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# 2️⃣ 输出日志文件名带时间戳
$timestampNow = Get-Date -Format "yyyyMMdd_HHmmss"
$outputLog = Join-Path $scriptDir "merged_gitinspector_$timestampNow.log"

# 3️⃣ 仓库列表
$repos = @(
    "D:\Codes\repo1",
    "D:\Codes\repo2",
    "D:\Codes\repo3"
)

# 4️⃣ 时间范围
$since = "2025-01-01"
$until = "2025-12-31"

# 5️⃣ 指定作者列表（空数组表示不过滤）
$authors = @("Alice","Bob")

# 6️⃣ 清空日志文件（如果已存在）
if (Test-Path $outputLog) {
    Remove-Item $outputLog
}

# 7️⃣ 遍历每个仓库
foreach ($repo in $repos) {
    Write-Host "正在处理仓库: $repo"
    Set-Location $repo

    # 获取指定时间范围提交 hash 列表
    $commits = git log --since="$since" --until="$until" --pretty=format:"%H"

    foreach ($commit in $commits) {
        # 获取作者
        $author = git show -s --format="%an" $commit

        # 作者筛选
        if ($authors.Count -gt 0 -and ($authors -notcontains $author)) {
            continue
        }

        # Unix 时间戳
        $timestamp = git show -s --format="%at" $commit

        # 获取每个文件新增/删除行数
        $fileChanges = git show --numstat --format="" $commit

        foreach ($line in $fileChanges) {
            if ($line -match "^\s*(\d+|-)\s+(\d+|-)\s+(.+)$") {
                $added = $matches[1]
                $deleted = $matches[2]
                $file = $matches[3]

                # 如果是二进制文件，将 '-' 转为 0
                if ($added -eq "-") { $added = 0 }
                if ($deleted -eq "-") { $deleted = 0 }

                # 输出日志
                "$timestamp|$author|M|$file|$added|$deleted" | Out-File -FilePath $outputLog -Append -Encoding utf8
            }
        }
    }
}

Write-Host "合并日志完成: $outputLog"
Read-Host "Press Enter to Exit"