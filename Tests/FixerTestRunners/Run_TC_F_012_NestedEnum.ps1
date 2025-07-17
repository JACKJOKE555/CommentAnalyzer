# TC_F_012: 验证嵌套枚举修复测试功能测试
# 测试策略: 修复后检测告警数是否为0

Write-Host "=== TC_F_012: 嵌套枚举修复测试 ===" -ForegroundColor Cyan

# 路径设置
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testCaseDir = Split-Path -Parent $scriptDir
$commentAnalyzer = Join-Path (Split-Path -Parent $testCaseDir) "CommentAnalyzer.ps1"
$testFile = Join-Path $testCaseDir "FixerTestCases/TC_F_012_NestedEnum.cs"
$templateFile = Join-Path $testCaseDir "FixerTestCases/Templates/TC_F_012_NestedEnum.txt"

Write-Host "测试文件: $testFile" -ForegroundColor White

# Step 1: 恢复测试文件到初始状态
Write-Host "[Step1] 恢复测试文件到初始状态..." -ForegroundColor Yellow
if (Test-Path $templateFile) {
    Copy-Item -Path $templateFile -Destination $testFile -Force
    Write-Host "✓ 已恢复测试文件" -ForegroundColor Green
} else {
    Write-Host "❌ [FAIL] 找不到模板文件: $templateFile" -ForegroundColor Red
    exit 1
}

# Step 2: 运行修复器
Write-Host "[Step2] 运行修复器..." -ForegroundColor Yellow
Set-Location (Split-Path -Parent $testCaseDir)
& $commentAnalyzer -Mode fix -SolutionPath "../../Dropleton.csproj" -ScriptPaths $testFile
Write-Host "修复器退出码: $LASTEXITCODE"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ [FAIL] 修复器运行失败" -ForegroundColor Red
    exit 1
}

# Step 3: 检查修复结果
Write-Host "[Step3] 检查修复结果..." -ForegroundColor Yellow
Set-Location (Split-Path -Parent $testCaseDir)
& $commentAnalyzer -Mode detect -SolutionPath "../../Dropleton.csproj" -ScriptPaths $testFile
Write-Host "检测器退出码: $LASTEXITCODE"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ [PASS] 修复成功，所有问题已解决" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ [FAIL] 修复后仍有问题" -ForegroundColor Red
    exit 1
} 
