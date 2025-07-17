#!/usr/bin/env pwsh
<#
.SYNOPSIS
    专门调试输出捕获问题的简化测试脚本
#>

Write-Host "=== Output Capture Debug Test ===" -ForegroundColor Green

# 设置路径
$analyzerScript = "..\..\CommentAnalyzer.ps1"
$testSolution = "..\..\..\..\Dropleton.csproj"

# 创建简单的测试文件
$testContent = @"
public class CaptureTestClass
{
    public int Value;
    public void DoSomething() { }
}
"@

$testFile = "CaptureDebugTest.cs"
$testContent | Out-File -FilePath $testFile -Encoding UTF8

Write-Host "Testing output capture with detailed analysis..." -ForegroundColor Yellow

# 测试detect模式并分析输出
Write-Host "=== DETECT MODE TEST ===" -ForegroundColor Cyan

# 方法1：收集所有输出
Write-Host "Method 1: Collecting all output..." -ForegroundColor Gray
$allOutput = @()
$allOutput = & $analyzerScript -Mode detect -SolutionPath $testSolution -ScriptPaths $testFile -DebugType "Analyzer" 2>&1

Write-Host "Total lines captured: $($allOutput.Count)" -ForegroundColor Gray
Write-Host "Sample lines (first 10):" -ForegroundColor Gray
$allOutput | Select-Object -First 10 | ForEach-Object { Write-Host "  [$($_.GetType().Name)] $_" -ForegroundColor Gray }

Write-Host ""

# 分析不同类型的消息
$debugMessages = $allOutput | Where-Object { $_ -match "\[DEBUG-.*\]" }
$userMessages = $allOutput | Where-Object { $_ -match "Analysis completed|found|Issues|diagnostics" }
$errorMessages = $allOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }

Write-Host "Message analysis:" -ForegroundColor Yellow
Write-Host "  Debug messages: $($debugMessages.Count)" -ForegroundColor Gray
Write-Host "  User messages: $($userMessages.Count)" -ForegroundColor Gray  
Write-Host "  Error messages: $($errorMessages.Count)" -ForegroundColor Gray

if ($debugMessages.Count -gt 0) {
    Write-Host "Debug messages found:" -ForegroundColor Green
    $debugMessages | ForEach-Object { Write-Host "    $_" -ForegroundColor Green }
}

if ($userMessages.Count -gt 0) {
    Write-Host "User messages found:" -ForegroundColor Green
    $userMessages | ForEach-Object { Write-Host "    $_" -ForegroundColor Green }
}

if ($errorMessages.Count -gt 0) {
    Write-Host "Error messages found:" -ForegroundColor Red
    $errorMessages | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}

Write-Host ""

# 测试fix模式
Write-Host "=== FIX MODE TEST ===" -ForegroundColor Cyan

$fixOutput = & $analyzerScript -Mode fix -SolutionPath $testSolution -ScriptPaths $testFile -DebugType "Analyzer" 2>&1

Write-Host "Fix mode lines captured: $($fixOutput.Count)" -ForegroundColor Gray

$fixDebugMessages = $fixOutput | Where-Object { $_ -match "\[DEBUG-.*\]" }
$fixUserMessages = $fixOutput | Where-Object { $_ -match "Fix completed|before|after|Issues" }

Write-Host "Fix mode message analysis:" -ForegroundColor Yellow
Write-Host "  Debug messages: $($fixDebugMessages.Count)" -ForegroundColor Gray
Write-Host "  User messages: $($fixUserMessages.Count)" -ForegroundColor Gray

if ($fixDebugMessages.Count -gt 0) {
    Write-Host "Fix debug messages:" -ForegroundColor Green
    $fixDebugMessages | ForEach-Object { Write-Host "    $_" -ForegroundColor Green }
}

if ($fixUserMessages.Count -gt 0) {
    Write-Host "Fix user messages:" -ForegroundColor Green
    $fixUserMessages | ForEach-Object { Write-Host "    $_" -ForegroundColor Green }
}

# 清理
Remove-Item $testFile -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Green
Write-Host "Detect Debug Messages: $($debugMessages.Count)" -ForegroundColor Gray
Write-Host "Detect User Messages: $($userMessages.Count)" -ForegroundColor Gray
Write-Host "Fix Debug Messages: $($fixDebugMessages.Count)" -ForegroundColor Gray
Write-Host "Fix User Messages: $($fixUserMessages.Count)" -ForegroundColor Gray

if (($debugMessages.Count -gt 0 -or $fixDebugMessages.Count -gt 0) -and 
    ($userMessages.Count -gt 0 -or $fixUserMessages.Count -gt 0)) {
    Write-Host "✅ Output capture is working correctly!" -ForegroundColor Green
} else {
    Write-Host "❌ Output capture has issues" -ForegroundColor Red
}

Write-Host "Test completed" -ForegroundColor Green 