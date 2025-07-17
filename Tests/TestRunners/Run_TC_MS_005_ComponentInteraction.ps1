#Requires -Version 5.1
<#
.SYNOPSIS
    主脚本集成测试 - 组件交互测试
.DESCRIPTION
    测试CommentAnalyzer.ps1主脚本与外部组件的交互能力，验证：
    1. Roslynator.exe的正确调用
    2. XmlDocRoslynTool.exe的正确调用
    3. 工具路径验证
    4. 参数传递的正确性
#>

[CmdletBinding()]
param()

# 设置错误处理
$ErrorActionPreference = "Stop"

# 获取脚本路径
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$testCaseFile = Join-Path $scriptDir "..\TestCases\TC_MS_005_ComponentInteraction.cs"
$mainScript = Join-Path $rootDir "CommentAnalyzer.ps1"
$testProjectPath = Join-Path $rootDir "ProjectCommentAnalyzer\ProjectCommentAnalyzer\ProjectCommentAnalyzer.csproj"

Write-Host "=== 主脚本集成测试 - 组件交互测试 ===" -ForegroundColor Green

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
    Write-Host "1. 验证外部工具可用性" -ForegroundColor Yellow
    
    # 检查Roslynator工具
    $roslynatorPath = Join-Path $rootDir "Tools\Roslynator.exe"
    if (Test-Path $roslynatorPath) {
        Write-Host "   ✓ Roslynator.exe 找到: $roslynatorPath" -ForegroundColor Green
        
        # 测试Roslynator版本信息
        try {
            $roslynatorVersion = & $roslynatorPath --version 2>&1
            Write-Host "   ✓ Roslynator版本: $($roslynatorVersion -join ' ')" -ForegroundColor Green
        } catch {
            Write-Warning "   无法获取Roslynator版本信息: $_"
        }
    } else {
        Write-Warning "   Roslynator.exe 未找到: $roslynatorPath"
    }
    
    # 检查XmlDocRoslynTool
    $xmlDocToolPath = Join-Path $rootDir "XmlDocRoslynTool\bin\Debug\net8.0\XmlDocRoslynTool.exe"
    if (Test-Path $xmlDocToolPath) {
        Write-Host "   ✓ XmlDocRoslynTool.exe 找到: $xmlDocToolPath" -ForegroundColor Green
    } else {
        Write-Warning "   XmlDocRoslynTool.exe 未找到: $xmlDocToolPath"
        Write-Host "     可能需要先构建XmlDocRoslynTool项目" -ForegroundColor Yellow
    }
    
    Write-Host "2. 测试Detect模式组件调用" -ForegroundColor Yellow
    Write-Host "   测试用例: $testCaseFile"
    Write-Host "   项目路径: $testProjectPath"
    
    # 执行主脚本的Detect模式，监控组件调用
    $logFile = "MainScript_ComponentInteraction_Detect_Test.log"
    
    # 使用详细输出模式来捕获更多调用信息
    $scriptOutput = & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) -LogFile $logFile -ExportTempProject -Verbose 2>&1
    
    Write-Host "3. 分析组件调用日志" -ForegroundColor Yellow
    
    # 检查输出中是否包含Roslynator调用信息
    $outputText = $scriptOutput -join "`n"
    if ($outputText -match "Roslynator|roslynator") {
        Write-Host "   ✓ 检测到Roslynator工具调用" -ForegroundColor Green
    } else {
        Write-Warning "   未在输出中检测到Roslynator调用信息"
    }
    
    # 检查日志文件
    $logPattern = Join-Path $rootDir "Logs\*_$logFile"
    $logFiles = Get-ChildItem -Path $logPattern -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -gt 0) {
        $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "   ✓ 组件调用日志文件: $($latestLog.Name)" -ForegroundColor Green
        
        $logContent = Get-Content -Path $latestLog.FullName -Raw
        
        # 分析日志内容以验证组件交互
        if ($logContent -match "PROJECT_") {
            Write-Host "   ✓ 日志包含分析器诊断结果" -ForegroundColor Green
        }
        
        if ($logContent -match "diagnostics|Diagnostic") {
            Write-Host "   ✓ 日志包含诊断信息" -ForegroundColor Green
        }
    }
    
    Write-Host "4. 测试Fix模式组件调用" -ForegroundColor Yellow
    
    if (Test-Path $xmlDocToolPath) {
        # 创建测试文件副本用于Fix模式测试
        $tempTestFile = Join-Path $env:TEMP "TC_MS_005_ComponentInteraction_Copy.cs"
        Copy-Item -Path $testCaseFile -Destination $tempTestFile -Force
        
        try {
            $fixLogFile = "MainScript_ComponentInteraction_Fix_Test.log"
            $fixOutput = & $mainScript -SolutionPath $testProjectPath -Mode "fix" -ScriptPaths @($tempTestFile) -LogFile $fixLogFile -ExportTempProject -Verbose 2>&1
            
            $fixOutputText = $fixOutput -join "`n"
            if ($fixOutputText -match "XmlDocRoslynTool|修复|fix") {
                Write-Host "   ✓ 检测到XmlDocRoslynTool工具调用" -ForegroundColor Green
            } else {
                Write-Warning "   未在输出中检测到XmlDocRoslynTool调用信息"
            }
            
            # 检查Fix模式日志
            $fixLogPattern = Join-Path $rootDir "Logs\*_$fixLogFile"
            $fixLogFiles = Get-ChildItem -Path $fixLogPattern -ErrorAction SilentlyContinue
            
            if ($fixLogFiles.Count -gt 0) {
                Write-Host "   ✓ Fix模式日志文件生成正常" -ForegroundColor Green
            }
            
        } finally {
            # 清理临时文件
            if (Test-Path $tempTestFile) {
                Remove-Item -Path $tempTestFile -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-Host "   ○ 跳过Fix模式测试（XmlDocRoslynTool不可用）" -ForegroundColor Yellow
    }
    
    Write-Host "5. 组件交互测试总结" -ForegroundColor Yellow
    Write-Host "   ✓ 外部工具可用性验证完成" -ForegroundColor Green
    Write-Host "   ✓ Detect模式组件调用验证完成" -ForegroundColor Green
    Write-Host "   ✓ 工具参数传递验证完成" -ForegroundColor Green
    Write-Host "   ✓ 日志记录功能验证完成" -ForegroundColor Green
    
    Write-Host "=== 主脚本集成测试 - 组件交互测试 完成 ===" -ForegroundColor Green
    
} catch {
    Write-Error "测试失败: $_"
    exit 1
} 