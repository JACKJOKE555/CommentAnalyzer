#!/usr/bin/env pwsh
<#
.SYNOPSIS
    测试 CommentAnalyzer 的 Debug 参数控制功能
.DESCRIPTION
    此脚本测试 CommentAnalyzer 的 -Debug 参数是否能正确控制日志输出级别。
    验证不同的 debug 类型是否能正确过滤和展示相应的调试信息。
.PARAMETER DebugType
    要测试的调试类型，支持 Workflow, Analyzer, Fixer, Parser, CodeGen, FileOp, NodeMatch, All
.EXAMPLE
    .\Test_Debug_Control.ps1 -DebugType "Workflow"
    .\Test_Debug_Control.ps1 -DebugType "All"
    .\Test_Debug_Control.ps1 -DebugType "Analyzer,Fixer"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DebugType = "Workflow"
)

# 获取脚本目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testRootDir = Split-Path -Parent $scriptDir
$analyzerRootDir = Split-Path -Parent $testRootDir

# 设置测试环境
$testCaseTemplate = Join-Path $testRootDir "DebugTests\DebugTestCase_Template.cs"
$testCaseFile = Join-Path $testRootDir "DebugTests\DebugTestCase_Temp_$([System.Guid]::NewGuid().ToString('N').Substring(0,8)).cs"
$testOutputDir = Join-Path $testRootDir "DebugTests\Output"
$analyzerScript = Join-Path $analyzerRootDir "CommentAnalyzer.ps1"
$testSolution = Join-Path $analyzerRootDir "..\..\Dropleton.csproj"

# 创建临时测试文件，确保每次测试都有问题需要检测
$templateContent = @"
// 专门用于调试控制测试的文件
// 故意缺少一些XML注释来触发所有调试类型

public class DebugTestClass
{
    public int TestField;
    
    public void TestMethod() { }
    
    public string TestProperty { get; set; }
}

public interface IDebugTestInterface
{
    void InterfaceMethod();
}

public struct DebugTestStruct
{
    public int StructField;
}
"@

$templateContent | Out-File -FilePath $testCaseFile -Encoding UTF8

# 确保输出目录存在
if (-not (Test-Path $testOutputDir)) {
    New-Item -ItemType Directory -Path $testOutputDir -Force | Out-Null
}

# 获取当前时间戳
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "=== Debug Control Test ===" -ForegroundColor Green
Write-Host "Test started at: $timestamp" -ForegroundColor Gray
Write-Host "Debug Type: $DebugType" -ForegroundColor Yellow
Write-Host "Test Case: $testCaseFile" -ForegroundColor Gray
Write-Host ""

# 测试 detect 模式
Write-Host "Testing DETECT mode with debug type: $DebugType" -ForegroundColor Cyan
Write-Host "Expected: Should see [DEBUG-$DebugType] messages" -ForegroundColor Gray

# 处理多个调试类型（逗号分隔）
$debugTypeArray = if ($DebugType.Contains(',')) {
    $DebugType.Split(',') | ForEach-Object { $_.Trim() }
} else {
    @($DebugType)
}

$detectArgs = @{
    SolutionPath = $testSolution
    Mode = "detect"
    ScriptPaths = $testCaseFile
    DebugType = $debugTypeArray
    ConsoleLogLevel = "minimal"
    FileLogLevel = "normal"
}

Write-Host "Running: $analyzerScript with detect mode and debug type $DebugType" -ForegroundColor Gray
Write-Host "--- OUTPUT START ---" -ForegroundColor Yellow

# 捕获输出 - 使用管道和变量直接分配
$detectOutput = & $analyzerScript @detectArgs 2>&1 | ForEach-Object { 
    Write-Host $_
    $_ # 输出到管道，供收集
}

Write-Host "--- OUTPUT END ---" -ForegroundColor Yellow
Write-Host ""

# 测试 fix 模式
Write-Host "Testing FIX mode with debug type: $DebugType" -ForegroundColor Cyan
Write-Host "Expected: Should see [DEBUG-$DebugType] messages from both analyzer and fixer" -ForegroundColor Gray

$fixArgs = @{
    SolutionPath = $testSolution
    Mode = "fix"
    ScriptPaths = $testCaseFile
    DebugType = $debugTypeArray
    ConsoleLogLevel = "minimal"
    FileLogLevel = "normal"
}

Write-Host "Running: $analyzerScript with fix mode and debug type $DebugType" -ForegroundColor Gray
Write-Host "--- OUTPUT START ---" -ForegroundColor Yellow

# 捕获输出 - 使用管道和变量直接分配
$fixOutput = & $analyzerScript @fixArgs 2>&1 | ForEach-Object { 
    Write-Host $_
    $_ # 输出到管道，供收集
}

Write-Host "--- OUTPUT END ---" -ForegroundColor Yellow
Write-Host ""

# 分析输出结果
Write-Host "=== Analysis Results ===" -ForegroundColor Green

# 检查是否有相应的 DEBUG 消息
$debugMessages = @()
$debugMessages += $detectOutput | Where-Object { $_ -match "\[DEBUG-.*\]" }
$debugMessages += $fixOutput | Where-Object { $_ -match "\[DEBUG-.*\]" }

Write-Host "Debug: detectOutput has $($detectOutput.Count) lines" -ForegroundColor Magenta
Write-Host "Debug: fixOutput has $($fixOutput.Count) lines" -ForegroundColor Magenta

# 显示前几行输出用于调试
Write-Host "Debug: First 5 lines of detectOutput:" -ForegroundColor Magenta
$detectOutput | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Magenta }

Write-Host "Debug: First 5 lines of fixOutput:" -ForegroundColor Magenta
$fixOutput | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Magenta }

if ($debugMessages.Count -gt 0) {
    Write-Host "✅ Found $($debugMessages.Count) debug messages:" -ForegroundColor Green
    $debugMessages | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ No debug messages found" -ForegroundColor Red
}

# 检查是否有不期望的 DEBUG 消息（如果指定了特定类型）
if ($DebugType -ne "All") {
    $unexpectedDebugMessages = @()
    $expectedTypes = $debugTypeArray
    
    foreach ($msg in $debugMessages) {
        $found = $false
        foreach ($expectedType in $expectedTypes) {
            if ($msg -match "\[DEBUG-$expectedType\]") {
                $found = $true
                break
            }
        }
        if (-not $found) {
            $unexpectedDebugMessages += $msg
        }
    }
    
    if ($unexpectedDebugMessages.Count -gt 0) {
        Write-Host "⚠️  Found $($unexpectedDebugMessages.Count) unexpected debug messages:" -ForegroundColor Yellow
        $unexpectedDebugMessages | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    } else {
        Write-Host "✅ All debug messages match expected types" -ForegroundColor Green
    }
}

# 检查是否有用户信息（应该总是有）
$userMessages = @()
$userMessages += $detectOutput | Where-Object { $_ -match "Analysis completed|found|passed" }
$userMessages += $fixOutput | Where-Object { $_ -match "Fix completed|before|after" }

if ($userMessages.Count -gt 0) {
    Write-Host "✅ Found $($userMessages.Count) user messages (normal operation info)" -ForegroundColor Green
} else {
    Write-Host "❌ No user messages found - this may indicate a problem" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Green
Write-Host "Debug Type Tested: $DebugType" -ForegroundColor Gray
Write-Host "Debug Messages Found: $($debugMessages.Count)" -ForegroundColor Gray
Write-Host "User Messages Found: $($userMessages.Count)" -ForegroundColor Gray
Write-Host "Test completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# 清理临时测试文件
if (Test-Path $testCaseFile) {
    Remove-Item $testCaseFile -Force
    Write-Host "Cleaned up temporary test file: $testCaseFile" -ForegroundColor Gray
}

if ($debugMessages.Count -gt 0 -and $userMessages.Count -gt 0) {
    Write-Host "✅ Test PASSED - Debug control is working correctly" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Test FAILED - Debug control may not be working properly" -ForegroundColor Red
    exit 1
} 