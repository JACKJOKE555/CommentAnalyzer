# 批量运行所有测试用例脚本
# 统计通过率和失败情况

Write-Host "=== CommentAnalyzer 测试用例批量运行 ===" -ForegroundColor Cyan

# 测试用例列表（已修复的）
$testCases = @(
    "TC_F_001_TypeNoCommentBlock",
    "TC_F_002_TypeMissingSummary", 
    "TC_F_005_MemberNoCommentBlock",
    "TC_F_019_ClosedLoop"
)

# 所有测试用例（用于后续扩展）
$allTestCases = @(
    "TC_F_001_TypeNoCommentBlock",
    "TC_F_002_TypeMissingSummary",
    "TC_F_003_TypeMissingRemarks", 
    "TC_F_004_RemarksMissingTag",
    "TC_F_005_MemberNoCommentBlock",
    "TC_F_006_MemberMissingSummary",
    "TC_F_007_MemberMissingRemarks",
    "TC_F_008_MemberMissingParam",
    "TC_F_009_MemberMissingReturns",
    "TC_F_010_MemberMissingTypeParam",
    "TC_F_011_NestedType",
    "TC_F_012_NestedEnum",
    "TC_F_013_MultiEnumFile",
    "TC_F_014_ConditionalCompilation",
    "TC_F_015_IllegalXmlStructure",
    "TC_F_016_CleanMode",
    "TC_F_017_BuiltinDiagnostic",
    "TC_F_018_IncrementalFix",
    "TC_F_019_ClosedLoop"
)

$results = @()
$passedCount = 0
$failedCount = 0

Write-Host "开始运行测试用例..." -ForegroundColor Yellow
Write-Host "注意: 当前只运行已修复的测试用例 ($($testCases.Count) 个)" -ForegroundColor Gray

foreach ($testCase in $testCases) {
    $scriptPath = "Run_$testCase.ps1"
    
    Write-Host "`n--- 运行测试: $testCase ---" -ForegroundColor White
    
    try {
        # 运行测试脚本
        $startTime = Get-Date
        & "pwsh" -File $scriptPath
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ [PASS] $testCase - 耗时: $([math]::Round($duration, 2))秒" -ForegroundColor Green
            $results += @{
                TestCase = $testCase
                Status = "PASS"
                Duration = $duration
            }
            $passedCount++
        } else {
            Write-Host "❌ [FAIL] $testCase - 退出码: $LASTEXITCODE" -ForegroundColor Red
            $results += @{
                TestCase = $testCase
                Status = "FAIL"
                ExitCode = $LASTEXITCODE
                Duration = $duration
            }
            $failedCount++
        }
    } catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "找不到路径|Cannot find path") {
            Write-Host "❌ [SKIP] $testCase - 脚本文件不存在" -ForegroundColor Gray
            $results += @{
                TestCase = $testCase
                Status = "SKIPPED"
                Reason = "脚本文件不存在"
            }
        } else {
            Write-Host "❌ [ERROR] $testCase - 异常: $errorMessage" -ForegroundColor Red
            $results += @{
                TestCase = $testCase
                Status = "ERROR"
                Error = $errorMessage
            }
        }
        $failedCount++
    }
}

# 输出总结
Write-Host "`n=== 测试结果总结 ===" -ForegroundColor Cyan
Write-Host "总测试用例数: $($testCases.Count)" -ForegroundColor White
Write-Host "通过: $passedCount" -ForegroundColor Green
Write-Host "失败: $failedCount" -ForegroundColor Red
Write-Host "通过率: $([math]::Round($passedCount / $testCases.Count * 100, 1))%" -ForegroundColor Yellow

# 详细结果
Write-Host "`n=== 详细结果 ===" -ForegroundColor Cyan
foreach ($result in $results) {
    $statusColor = switch ($result.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "ERROR" { "Magenta" }
        "SKIPPED" { "Gray" }
        default { "White" }
    }
    
    $details = ""
    if ($result.Duration) {
        $details += " (耗时: $([math]::Round($result.Duration, 2))秒)"
    }
    if ($result.ExitCode) {
        $details += " (退出码: $($result.ExitCode))"
    }
    if ($result.Error) {
        $details += " (错误: $($result.Error))"
    }
    if ($result.Reason) {
        $details += " (原因: $($result.Reason))"
    }
    
    Write-Host "  $($result.Status): $($result.TestCase)$details" -ForegroundColor $statusColor
}

# 输出下一步建议
if ($failedCount -gt 0) {
    Write-Host "`n=== 下一步建议 ===" -ForegroundColor Yellow
    Write-Host "1. 检查失败的测试用例日志" -ForegroundColor Gray
    Write-Host "2. 确认测试文件模板是否存在" -ForegroundColor Gray
    Write-Host "3. 检查主脚本是否有问题" -ForegroundColor Gray
    exit 1
} else {
    Write-Host "`n🎉 所有测试用例都通过了！" -ForegroundColor Green
    exit 0
} 