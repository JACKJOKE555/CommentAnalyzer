#Requires -Version 5.1
<#
.SYNOPSIS
    CommentAnalyzer 主入口脚本全部测试运行器
.DESCRIPTION
    批量执行所有主入口脚本测试(TC_MS_系列)，提供完整的测试覆盖验证。
    
    测试覆盖范围：
    - TC_MS_001: 基础集成测试 (Detect模式)
    - TC_MS_002: 修复功能测试 (Fix模式) 
    - TC_MS_003: 错误处理测试
    - TC_MS_004: 文件管理测试
    - TC_MS_005: 组件交互测试
.PARAMETER TestFilter
    可选的测试过滤器，支持通配符模式 (例如: "TC_MS_001*" 只运行001测试)
.PARAMETER ContinueOnError
    遇到测试失败时是否继续执行剩余测试
.PARAMETER GenerateReport
    是否生成测试报告
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TestFilter = "TC_MS_*",
    
    [Parameter(Mandatory=$false)]
    [switch]$ContinueOnError,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# 设置错误处理
$ErrorActionPreference = if ($ContinueOnError) { "Continue" } else { "Stop" }

# 获取脚本路径
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)

Write-Host "=== CommentAnalyzer 主入口脚本全部测试 ===" -ForegroundColor Cyan
Write-Host "测试开始时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "测试过滤器: $TestFilter" -ForegroundColor Gray
Write-Host ""

# 定义所有主入口脚本测试用例
$allTests = @(
    @{
        Name = "TC_MS_001_Detect"
        Script = "Run_TC_MS_001_Detect.ps1"
        Description = "基础集成测试 - Detect模式"
        Category = "基础功能"
    },
    @{
        Name = "TC_MS_001_Detect_EN"
        Script = "Run_TC_MS_001_Detect_EN.ps1"
        Description = "基础集成测试 - Detect模式(英文)"
        Category = "国际化"
    },
    @{
        Name = "TC_MS_002_Fix"
        Script = "Run_TC_MS_002_Fix.ps1"
        Description = "修复功能测试 - Fix模式"
        Category = "修复功能"
    },
    @{
        Name = "TC_MS_003_ErrorHandling"
        Script = "Run_TC_MS_003_ErrorHandling.ps1"
        Description = "错误处理测试"
        Category = "错误处理"
    },
    @{
        Name = "TC_MS_004_FileManagement"
        Script = "Run_TC_MS_004_FileManagement.ps1"
        Description = "文件管理测试"
        Category = "文件管理"
    },
    @{
        Name = "TC_MS_005_ComponentInteraction"
        Script = "Run_TC_MS_005_ComponentInteraction.ps1"
        Description = "组件交互测试"
        Category = "组件交互"
    },
    @{
        Name = "TC_MS_006_DebugControl"
        Script = "Run_TC_MS_006_DebugControl.ps1"
        Description = "Debug输出控制测试"
        Category = "输出控制"
    },
    @{
        Name = "TC_MS_007_OutputIntegrity"
        Script = "Run_TC_MS_007_OutputIntegrity.ps1"
        Description = "输出完整性测试"
        Category = "输出控制"
    }
)

# 过滤测试用例
$selectedTests = $allTests | Where-Object { $_.Name -like $TestFilter }

if ($selectedTests.Count -eq 0) {
    Write-Warning "没有找到匹配过滤器 '$TestFilter' 的测试用例"
    exit 1
}

Write-Host "找到 $($selectedTests.Count) 个匹配的测试用例:" -ForegroundColor Green
foreach ($test in $selectedTests) {
    Write-Host "  - $($test.Name): $($test.Description)" -ForegroundColor Gray
}
Write-Host ""

# 测试结果统计
$testResults = @()
$startTime = Get-Date

# 执行测试
foreach ($test in $selectedTests) {
    $testStartTime = Get-Date
    Write-Host "正在执行: $($test.Name)" -ForegroundColor Yellow
    Write-Host "描述: $($test.Description)" -ForegroundColor Gray
    Write-Host "类别: $($test.Category)" -ForegroundColor Gray
    
    $testScriptPath = Join-Path $scriptDir $test.Script
    $testPassed = $false
    $testError = $null
    $testOutput = @()
    
    if (-not (Test-Path $testScriptPath)) {
        $testError = "测试脚本不存在: $testScriptPath"
        Write-Warning $testError
    } else {
        try {
            # 执行测试脚本
            if ($Verbose) {
                $testOutput = & $testScriptPath -Verbose 2>&1
            } else {
                $testOutput = & $testScriptPath 2>&1
            }
            
            $testPassed = $LASTEXITCODE -eq 0
            if (-not $testPassed) {
                $testError = "测试脚本返回非零退出码: $LASTEXITCODE"
            }
            
        } catch {
            $testError = $_.Exception.Message
            $testPassed = $false
        }
    }
    
    $testEndTime = Get-Date
    $testDuration = $testEndTime - $testStartTime
    
    # 记录测试结果
    $result = @{
        Name = $test.Name
        Description = $test.Description
        Category = $test.Category
        Passed = $testPassed
        Error = $testError
        Duration = $testDuration
        Output = $testOutput
        StartTime = $testStartTime
        EndTime = $testEndTime
    }
    $testResults += $result
    
    # 显示测试结果
    if ($testPassed) {
        Write-Host "✓ $($test.Name) 通过 (用时: $($testDuration.TotalSeconds.ToString('F2'))秒)" -ForegroundColor Green
    } else {
        Write-Host "✗ $($test.Name) 失败 (用时: $($testDuration.TotalSeconds.ToString('F2'))秒)" -ForegroundColor Red
        if ($testError) {
            Write-Host "  错误: $testError" -ForegroundColor Red
        }
        
        if (-not $ContinueOnError) {
            Write-Host "测试中止 (使用 -ContinueOnError 继续执行剩余测试)" -ForegroundColor Yellow
            break
        }
    }
    
    Write-Host ""
}

$endTime = Get-Date
$totalDuration = $endTime - $startTime

# 生成测试总结
Write-Host "=== 测试总结 ===" -ForegroundColor Cyan
Write-Host "测试完成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "总用时: $($totalDuration.TotalSeconds.ToString('F2'))秒" -ForegroundColor Gray
Write-Host ""

$passedCount = ($testResults | Where-Object { $_.Passed }).Count
$failedCount = $testResults.Count - $passedCount

Write-Host "测试统计:" -ForegroundColor White
Write-Host "  总数: $($testResults.Count)" -ForegroundColor Gray
Write-Host "  通过: $passedCount" -ForegroundColor Green
Write-Host "  失败: $failedCount" -ForegroundColor Red
Write-Host "  成功率: $([math]::Round($passedCount / $testResults.Count * 100, 2))%" -ForegroundColor $(if ($failedCount -eq 0) { "Green" } else { "Yellow" })

# 按类别统计
Write-Host ""
Write-Host "按类别统计:" -ForegroundColor White
$categories = $testResults | Group-Object Category
foreach ($category in $categories) {
    $categoryPassed = ($category.Group | Where-Object { $_.Passed }).Count
    $categoryTotal = $category.Group.Count
    Write-Host "  $($category.Name): $categoryPassed/$categoryTotal 通过" -ForegroundColor Gray
}

# 显示失败的测试详情
if ($failedCount -gt 0) {
    Write-Host ""
    Write-Host "失败测试详情:" -ForegroundColor Red
    $failedTests = $testResults | Where-Object { -not $_.Passed }
    foreach ($failed in $failedTests) {
        Write-Host "  - $($failed.Name): $($failed.Error)" -ForegroundColor Red
    }
}

# 生成测试报告
if ($GenerateReport) {
    $reportPath = Join-Path $rootDir "Logs\MainScript_TestReport_$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    
    $report = @{
        Timestamp = $startTime.ToString('yyyy-MM-dd HH:mm:ss')
        TestFilter = $TestFilter
        Summary = @{
            Total = $testResults.Count
            Passed = $passedCount
            Failed = $failedCount
            SuccessRate = [math]::Round($passedCount / $testResults.Count * 100, 2)
            Duration = $totalDuration.TotalSeconds
        }
        Results = $testResults | ForEach-Object {
            @{
                Name = $_.Name
                Description = $_.Description
                Category = $_.Category
                Passed = $_.Passed
                Error = $_.Error
                Duration = $_.Duration.TotalSeconds
                StartTime = $_.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
                EndTime = $_.EndTime.ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
    }
    
    # 确保Logs目录存在
    $logsDir = Split-Path -Parent $reportPath
    if (-not (Test-Path $logsDir)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host ""
    Write-Host "测试报告已生成: $reportPath" -ForegroundColor Green
}

# 设置退出码
if ($failedCount -gt 0) {
    exit 1
} else {
    exit 0
} 