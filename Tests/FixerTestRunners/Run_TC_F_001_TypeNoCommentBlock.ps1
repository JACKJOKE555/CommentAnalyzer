<#
.SYNOPSIS
    Fixer test case runner for PROJECT_TYPE_NO_COMMENT_BLOCK (TC_F_001)
.DESCRIPTION
    修复器测试Runner：验证修复器能否成功修复所有诊断问题。
    修复后自动再运行一次分析器（detect模式），只要输出包含'0 diagnostics found'即判定为PASS，否则FAIL。
#>

# TC_F_001: 验证类型无注释修复功能测试
# 测试策略: 使用退出码判断成功或失败

Write-Host "=== TC_F_001: 类型无注释修复测试 ==="

# 路径设置
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testCaseDir = Split-Path -Parent $scriptDir
$commentAnalyzer = Join-Path (Split-Path -Parent $testCaseDir) "CommentAnalyzer.ps1"
$testFile = Join-Path $testCaseDir "FixerTestCases/TC_F_001_TypeNoCommentBlock.cs"
$templateFile = Join-Path $testCaseDir "FixerTestCases/Templates/TC_F_001_TypeNoCommentBlock.txt"

Write-Host "测试文件: $testFile"

# Step 1: 恢复测试文件到初始状态
Write-Host "[Step1] 恢复测试文件到初始状态..."
if (Test-Path $templateFile) {
    Copy-Item -Path $templateFile -Destination $testFile -Force
    Write-Host "✓ 已恢复测试文件"
} else {
    Write-Host "❌ [FAIL] 找不到模板文件: $templateFile"
    exit 1
}

# Step 2: 运行修复器
Write-Host "[Step2] 运行修复器..."
Set-Location (Split-Path -Parent $testCaseDir)  # 切换到CommentAnalyzer目录
& $commentAnalyzer -Mode fix -SolutionPath "../../Dropleton.csproj" -ScriptPaths $testFile
$fixExitCode = $LASTEXITCODE
Write-Host "修复器退出码: $fixExitCode"

if ($fixExitCode -ne 0) {
    Write-Host "❌ [FAIL] 修复器执行失败，退出码: $fixExitCode"
    exit 1
}

# Step 3: 运行分析器检测告警数
Write-Host "[Step3] 检测修复后的告警数..."
& $commentAnalyzer -Mode detect -SolutionPath "../../Dropleton.csproj" -ScriptPaths $testFile
$detectExitCode = $LASTEXITCODE
Write-Host "检测器退出码: $detectExitCode"

if ($detectExitCode -eq 0) {
    Write-Host "✅ [PASS] 修复成功，无告警"
    exit 0
} else {
    Write-Host "❌ [FAIL] 修复后仍有告警，退出码: $detectExitCode"
    exit 1
} 