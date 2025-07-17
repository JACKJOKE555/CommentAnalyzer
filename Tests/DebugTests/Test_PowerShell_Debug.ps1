#!/usr/bin/env pwsh
<#
.SYNOPSIS
    专门测试PowerShell脚本调试输出捕获的简化测试
#>

Write-Host "=== PowerShell Debug Capture Test ===" -ForegroundColor Green

# 设置路径
$analyzerScript = "..\..\CommentAnalyzer.ps1"
$testSolution = "..\..\..\..\Dropleton.csproj"

# 创建简单的测试文件
$testContent = @"
public class TestClass
{
    public int Value;
}
"@

$testFile = "PowerShellDebugTest.cs"
$testContent | Out-File -FilePath $testFile -Encoding UTF8

Write-Host "Testing PowerShell script debug output capture..." -ForegroundColor Yellow

# 测试detect模式（PowerShell脚本中有调试输出）
Write-Host "Testing DETECT mode (PowerShell script debug messages)" -ForegroundColor Cyan
$output = & $analyzerScript -Mode detect -SolutionPath $testSolution -ScriptPaths $testFile -DebugType "Workflow" 2>&1

Write-Host "Captured $($output.Count) lines" -ForegroundColor Gray
Write-Host "First 10 lines:" -ForegroundColor Gray
$output | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

Write-Host ""

# 搜索PowerShell脚本中的调试消息（应该有Workflow类型的调试消息）
$debugMessages = $output | Where-Object { $_ -match "\[DEBUG-.*\]" }
if ($debugMessages.Count -gt 0) {
    Write-Host "✅ Found PowerShell debug messages:" -ForegroundColor Green
    $debugMessages | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ No PowerShell debug messages found" -ForegroundColor Red
}

# 搜索用户信息消息
$userMessages = $output | Where-Object { $_ -match "Found \d+ diagnostic issues" }
if ($userMessages.Count -gt 0) {
    Write-Host "✅ Found user messages:" -ForegroundColor Green
    $userMessages | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ No user messages found" -ForegroundColor Red
}

# 清理
Remove-Item $testFile -Force -ErrorAction SilentlyContinue

Write-Host "Test completed" -ForegroundColor Green 