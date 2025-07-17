#!/usr/bin/env pwsh
<#
.SYNOPSIS
    简化的输出捕获测试，用于诊断PowerShell输出捕获问题
#>

Write-Host "=== Simple Capture Test ===" -ForegroundColor Green

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

$testFile = "SimpleTest.cs"
$testContent | Out-File -FilePath $testFile -Encoding UTF8

Write-Host "Testing output capture methods..." -ForegroundColor Yellow

# 方法1：测试fix模式（调试消息应该在这里出现）
Write-Host "Method 1: FIX mode with direct capture" -ForegroundColor Cyan
$output1 = & $analyzerScript -Mode fix -SolutionPath $testSolution -ScriptPaths $testFile -DebugType "Parser" 2>&1
Write-Host "Captured $($output1.Count) lines" -ForegroundColor Gray
$output1 | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

Write-Host ""

# 方法2：使用Out-String然后Split (fix模式)
Write-Host "Method 2: FIX mode with Out-String and Split" -ForegroundColor Cyan
$output2 = (& $analyzerScript -Mode fix -SolutionPath $testSolution -ScriptPaths $testFile -DebugType "Parser" 2>&1 | Out-String) -split "`n"
Write-Host "Captured $($output2.Count) lines" -ForegroundColor Gray
$output2 | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

Write-Host ""

# 方法3：使用临时文件 (fix模式)
Write-Host "Method 3: FIX mode with Temporary file" -ForegroundColor Cyan
$tempFile = [System.IO.Path]::GetTempFileName()
& $analyzerScript -Mode fix -SolutionPath $testSolution -ScriptPaths $testFile -DebugType "Parser" 2>&1 | Out-File $tempFile -Encoding UTF8
$output3 = Get-Content $tempFile
Remove-Item $tempFile -Force
Write-Host "Captured $($output3.Count) lines" -ForegroundColor Gray
$output3 | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

Write-Host ""

# 检查调试消息
Write-Host "Searching for debug messages..." -ForegroundColor Yellow
$allOutput = $output1 + $output2 + $output3

$debugMessages = $allOutput | Where-Object { $_ -match "\[DEBUG-.*\]" }
if ($debugMessages.Count -gt 0) {
    Write-Host "✅ Found debug messages:" -ForegroundColor Green
    $debugMessages | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ No debug messages found" -ForegroundColor Red
}

# 清理
Remove-Item $testFile -Force -ErrorAction SilentlyContinue

Write-Host "Test completed" -ForegroundColor Green 