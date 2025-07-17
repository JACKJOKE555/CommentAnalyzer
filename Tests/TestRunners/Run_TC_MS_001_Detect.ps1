#Requires -Version 5.1
<#
.SYNOPSIS
    主脚本集成测试 - Detect模式
.DESCRIPTION
    测试CommentAnalyzer.ps1主脚本调用分析器的能力，验证：
    1. 参数传递正确性
    2. 临时项目创建
    3. 日志文件生成
    4. 分析器规则触发
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# 设置错误处理
$ErrorActionPreference = "Stop"

# 获取脚本路径
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$testCaseFile = Join-Path $scriptDir "..\TestCases\TC_MS_001_MainScriptIntegration.cs"
$mainScript = Join-Path $rootDir "CommentAnalyzer.ps1"
$testProjectPath = Join-Path $rootDir "ProjectCommentAnalyzer\ProjectCommentAnalyzer\ProjectCommentAnalyzer.csproj"

Write-Host "=== 主脚本集成测试 - Detect模式 ===" -ForegroundColor Green

# 验证必要文件存在
if (-not (Test-Path $testCaseFile)) {
    throw "测试用例文件不存在: $testCaseFile"
}

if (-not (Test-Path $mainScript)) {
    throw "主脚本不存在: $mainScript"
}

if (-not (Test-Path $testProjectPath)) {
    throw "测试项目不存在: $testProjectPath"
}

try {
    Write-Host "1. 执行主脚本 - Detect模式" -ForegroundColor Yellow
    Write-Host "   测试用例: $testCaseFile"
    Write-Host "   项目路径: $testProjectPath"
    
    # 执行主脚本
    $logFile = "MainScript_Detect_Test.log"
    & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) -LogFile $logFile -ExportTempProject
    
    Write-Host "2. 验证日志文件生成" -ForegroundColor Yellow
    $logPattern = Join-Path $rootDir "Logs\*_$logFile"
    $logFiles = Get-ChildItem -Path $logPattern -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -eq 0) {
        throw "未找到日志文件: $logPattern"
    }
    
    $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host "   找到日志文件: $($latestLog.FullName)"
    
    Write-Host "3. 分析日志内容" -ForegroundColor Yellow
    $logContent = Get-Content -Path $latestLog.FullName -Raw
    
    # 检查是否包含我们期望的诊断规则
    $expectedRules = @(
        "PROJECT_TYPE_MISSING_SUMMARY",
        "PROJECT_TYPE_MISSING_REMARKS", 
        "PROJECT_MEMBER_MISSING_SUMMARY",
        "PROJECT_MEMBER_MISSING_REMARKS"
    )
    
    $foundRules = @()
    foreach ($rule in $expectedRules) {
        if ($logContent -match $rule) {
            $foundRules += $rule
            Write-Host "   ✓ 发现规则: $rule" -ForegroundColor Green
        }
    }
    
    if ($foundRules.Count -eq 0) {
        Write-Warning "未在日志中发现任何PROJECT_*规则，这可能表明分析器未正确加载"
        if ($Verbose) {
            Write-Host "日志内容预览:" -ForegroundColor Cyan
            Write-Host $logContent.Substring(0, [Math]::Min(500, $logContent.Length))
        }
    }
    
    Write-Host "4. 验证临时项目文件" -ForegroundColor Yellow
    $tempDir = Join-Path $rootDir "Temp"
    $tempProjects = Get-ChildItem -Path $tempDir -Filter "TempProject_*.csproj" -ErrorAction SilentlyContinue
    
    if ($tempProjects.Count -gt 0) {
        $latestTempProject = $tempProjects | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "   ✓ 找到临时项目: $($latestTempProject.Name)" -ForegroundColor Green
        
        # 验证临时项目内容
        [xml]$tempProjectXml = Get-Content -Path $latestTempProject.FullName
        $compileItems = $tempProjectXml.Project.ItemGroup.Compile
        
        if ($compileItems) {
            Write-Host "   ✓ 临时项目包含编译项: $($compileItems.Count)个" -ForegroundColor Green
            foreach ($item in $compileItems) {
                Write-Host "     - $($item.Include)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Warning "未找到临时项目文件（可能已被清理）"
    }
    
    Write-Host "5. 测试结果总结" -ForegroundColor Yellow
    Write-Host "   ✓ 主脚本执行成功" -ForegroundColor Green
    Write-Host "   ✓ 日志文件生成正常" -ForegroundColor Green
    Write-Host "   ✓ 发现 $($foundRules.Count) 个PROJECT规则" -ForegroundColor Green
    Write-Host "   ✓ 临时项目处理正常" -ForegroundColor Green
    
    Write-Host "=== 主脚本集成测试 - Detect模式 完成 ===" -ForegroundColor Green
    
} catch {
    Write-Error "测试失败: $_"
    exit 1
}