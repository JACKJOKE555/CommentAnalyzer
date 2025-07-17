#!/usr/bin/env pwsh
<#
.SYNOPSIS
    批量测试所有 Debug 类型的控制功能
.DESCRIPTION
    此脚本依次测试所有支持的 debug 类型，验证每种类型都能正确控制日志输出。
.EXAMPLE
    .\Run_All_Debug_Tests.ps1
#>

[CmdletBinding()]
param()

# 获取脚本目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testScript = Join-Path $scriptDir "Test_Debug_Control.ps1"

# 定义所有要测试的debug类型
$debugTypes = @(
    "Workflow",
    "Analyzer", 
    "Fixer",
    "Parser",
    "CodeGen",
    "FileOp",
    "NodeMatch",
    "All",
    "Workflow,Analyzer",
    "Fixer,CodeGen"
)

Write-Host "=== Batch Debug Control Test ===" -ForegroundColor Green
Write-Host "Testing all debug types: $($debugTypes -join ', ')" -ForegroundColor Gray
Write-Host "Test started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$results = @()
$totalTests = $debugTypes.Count
$passedTests = 0

foreach ($debugType in $debugTypes) {
    Write-Host "=" * 60 -ForegroundColor Yellow
    Write-Host "Testing Debug Type: $debugType" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Yellow
    
    try {
        # 运行测试
        $testResult = & $testScript -DebugType $debugType
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "✅ Test PASSED for $debugType" -ForegroundColor Green
            $passedTests++
            $results += @{
                DebugType = $debugType
                Result = "PASSED"
                Error = $null
            }
        } else {
            Write-Host "❌ Test FAILED for $debugType" -ForegroundColor Red
            $results += @{
                DebugType = $debugType
                Result = "FAILED"
                Error = "Exit code: $exitCode"
            }
        }
    }
    catch {
        Write-Host "❌ Test ERROR for $debugType" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        $results += @{
            DebugType = $debugType
            Result = "ERROR"
            Error = $_.Exception.Message
        }
    }
    
    Write-Host ""
}

# 生成测试报告
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "=== BATCH TEST SUMMARY ===" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "Total Tests: $totalTests" -ForegroundColor Gray
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($passedTests / $totalTests) * 100, 2))%" -ForegroundColor Gray

Write-Host ""
Write-Host "Detailed Results:" -ForegroundColor Gray
Write-Host "─" * 50 -ForegroundColor Gray

foreach ($result in $results) {
    $status = if ($result.Result -eq "PASSED") { "✅" } else { "❌" }
    $color = if ($result.Result -eq "PASSED") { "Green" } else { "Red" }
    
    Write-Host "$status $($result.DebugType) - $($result.Result)" -ForegroundColor $color
    if ($result.Error) {
        Write-Host "    Error: $($result.Error)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Test completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# 生成JSON报告
$reportPath = Join-Path $scriptDir "debug_test_report.json"
$report = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    TotalTests = $totalTests
    PassedTests = $passedTests
    FailedTests = $totalTests - $passedTests
    SuccessRate = [math]::Round(($passedTests / $totalTests) * 100, 2)
    Results = $results
}

$report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "📄 Test report saved to: $reportPath" -ForegroundColor Gray

if ($passedTests -eq $totalTests) {
    Write-Host "🎉 ALL TESTS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  SOME TESTS FAILED!" -ForegroundColor Red
    exit 1
} 