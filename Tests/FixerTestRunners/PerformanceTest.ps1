# CommentAnalyzer 性能测试脚本
# 验证日志级别优化的效果

Write-Host "=== CommentAnalyzer 性能测试 ===" -ForegroundColor Cyan

# 测试用例列表
$testCases = @(
    "TC_F_001_TypeNoCommentBlock",
    "TC_F_002_TypeMissingSummary"
)

$results = @()

foreach ($testCase in $testCases) {
    $scriptPath = "Run_$testCase.ps1"
    
    if (Test-Path $scriptPath) {
        Write-Host "`n--- 测试: $testCase ---" -ForegroundColor White
        
        $startTime = Get-Date
        
        # 运行测试脚本
        & "./$scriptPath" > $null
        $exitCode = $LASTEXITCODE
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        $status = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }
        $statusColor = if ($exitCode -eq 0) { "Green" } else { "Red" }
        
        Write-Host "✅ [$status] $testCase - 耗时: $([math]::Round($duration, 2))秒" -ForegroundColor $statusColor
        
        $results += @{
            TestCase = $testCase
            Status = $status
            Duration = $duration
            ExitCode = $exitCode
        }
    } else {
        Write-Host "❌ [SKIP] $testCase - 脚本文件不存在" -ForegroundColor Yellow
    }
}

# 性能统计
Write-Host "`n=== 性能统计 ===" -ForegroundColor Cyan
$totalTime = ($results | Measure-Object Duration -Sum).Sum
$avgTime = if ($results.Count -gt 0) { $totalTime / $results.Count } else { 0 }
$passCount = ($results | Where-Object { $_.Status -eq "PASS" }).Count

Write-Host "总测试数: $($results.Count)" -ForegroundColor White
Write-Host "通过数: $passCount" -ForegroundColor Green
Write-Host "失败数: $($results.Count - $passCount)" -ForegroundColor Red
Write-Host "总耗时: $([math]::Round($totalTime, 2))秒" -ForegroundColor White
Write-Host "平均耗时: $([math]::Round($avgTime, 2))秒/测试" -ForegroundColor White

# 性能评估
if ($avgTime -lt 30) {
    Write-Host "🚀 性能评级: 优秀 (平均<30秒)" -ForegroundColor Green
} elseif ($avgTime -lt 60) {
    Write-Host "⚡ 性能评级: 良好 (平均30-60秒)" -ForegroundColor Yellow
} else {
    Write-Host "🐌 性能评级: 需要优化 (平均>60秒)" -ForegroundColor Red
}

Write-Host "`n=== 优化效果对比 ===" -ForegroundColor Cyan
Write-Host "优化前: 平均60-70秒/测试" -ForegroundColor Red
Write-Host "优化后: 平均$([math]::Round($avgTime, 2))秒/测试" -ForegroundColor Green
if ($avgTime -gt 0) {
    $improvement = ((65 - $avgTime) / 65) * 100
    Write-Host "性能提升: $([math]::Round($improvement, 1))%" -ForegroundColor Green
} 