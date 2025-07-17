<#
.SYNOPSIS
    Fixer test case runner for <CASE_DESC> (<CASE_ID>)
.DESCRIPTION
    多轮修复Runner：每轮修复后记录诊断数和内容快照，只要诊断数有变化且不为0则继续修复，诊断数为0或与上轮相同则停止。每轮修复前后内容保存，输出diff，最终断言幂等性。
#>

# 路径准备
$repoRoot = (Resolve-Path "$PSScriptRoot/../../../.." -ErrorAction Stop).Path
$commentAnalyzer = (Resolve-Path (Join-Path $repoRoot "CustomPackages/CommentAnalyzer/CommentAnalyzer.ps1") -ErrorAction Stop).Path
$csproj = (Resolve-Path (Join-Path $repoRoot "Dropleton.csproj") -ErrorAction Stop).Path
$testFile = (Resolve-Path (Join-Path $PSScriptRoot "../FixerTestCases/<CASE_FILE>.cs") -ErrorAction Stop).Path
$logDir = (Resolve-Path (Join-Path $PSScriptRoot "../Logs") -ErrorAction SilentlyContinue)
if (-not $logDir) { $logDir = (New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot "../Logs")).FullName }

# 1. 恢复测试用例
Copy-Item -Path (Join-Path $PSScriptRoot "../FixerTestCases/Templates/<CASE_FILE>.txt") -Destination $testFile -Force

# 多轮修复主循环
$maxRounds = 10
$lastIssueCount = $null
$round = 1
$contentHistory = @()
$diagnosticHistory = @()
$lastContent = $null

while ($true) {
    # 记录修复前内容
    $beforeContent = Get-Content $testFile -Raw
    $contentHistory += ,$beforeContent
    $beforeContentPath = Join-Path $logDir "<CASE_ID>_FixResult_round${round}.before.txt"
    $beforeContent | Set-Content $beforeContentPath

    # 运行修复
    $logFile = Join-Path $logDir "<CASE_ID>_FixResult_round${round}.xml"
    Write-Host "[Step$round] Fix round $round..."
    & $commentAnalyzer -Mode fix -SolutionPath $csproj -ScriptPaths $testFile -LogFile $logFile

    # 读取诊断报告
    $report = Get-ChildItem -Path $logDir -Filter "*_report.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($report) {
        $json = Get-Content $report.FullName -Raw | ConvertFrom-Json
        $issueCount = $json.Summary.IssuesAfter
        $diagnosticHistory += $issueCount
        Write-Host "[Assert$round] Issues after fix: $issueCount"
    } else {
        Write-Host "❌ [FAIL] 未找到修复报告"
        break
    }

    # 记录修复后内容
    $afterContent = Get-Content $testFile -Raw
    $afterContentPath = Join-Path $logDir "<CASE_ID>_FixResult_round${round}.after.txt"
    $afterContent | Set-Content $afterContentPath

    # 输出diff
    $diffPath = Join-Path $logDir "<CASE_ID>_FixResult_round${round}.diff.txt"
    $diff = Compare-Object ($beforeContent -split "`n") ($afterContent -split "`n")
    if ($diff) {
        $diff | Out-File $diffPath
        Write-Host "[Diff] 修复前后内容有变化，diff已保存: $diffPath"
    } else {
        Write-Host "[Diff] 修复前后内容无变化"
    }

    # 判断是否继续
    if ($issueCount -eq 0) {
        Write-Host "✅ [PASS] 所有诊断已修复"
        break
    }
    if ($lastIssueCount -ne $null -and $issueCount -eq $lastIssueCount) {
        Write-Host "⚠️ [INFO] 诊断数未变化，流程收敛，需人工介入"
        break
    }
    $lastIssueCount = $issueCount
    $lastContent = $afterContent
    $round++
    if ($round -gt $maxRounds) {
        Write-Host "⚠️ [INFO] 达到最大修复轮数，终止"
        break
    }
}

# 幂等性断言
if ($contentHistory.Count -ge 2 -and $contentHistory[-1] -eq $contentHistory[-2]) {
    Write-Host "✅ [PASS] 幂等性通过，最后两轮内容一致"
    exit 0
} else {
    Write-Host "❌ [FAIL] 幂等性失败，最后两轮内容不一致"
    exit 1
} 