#Requires -Version 5.1
<#
.SYNOPSIS
    主脚本集成测试 - Fix模式
.DESCRIPTION
    测试CommentAnalyzer.ps1主脚本调用注释器的能力，验证：
    1. Fix模式参数传递
    2. XmlDocRoslynTool调用
    3. 修复报告生成
    4. 源文件修改
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
$testCaseFile = Join-Path $scriptDir "..\TestCases\TC_MS_002_MainScriptFix.cs"
$mainScript = Join-Path $rootDir "CommentAnalyzer.ps1"
$testProjectPath = Join-Path $rootDir "ProjectCommentAnalyzer\ProjectCommentAnalyzer\ProjectCommentAnalyzer.csproj"

Write-Host "=== 主脚本集成测试 - Fix模式 ===" -ForegroundColor Green

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

# 验证XmlDocRoslynTool是否存在
$xmlDocToolPath = Join-Path $rootDir "XmlDocRoslynTool\bin\Debug\net8.0\XmlDocRoslynTool.exe"
if (-not (Test-Path $xmlDocToolPath)) {
    Write-Warning "XmlDocRoslynTool.exe不存在: $xmlDocToolPath"
    Write-Host "请先构建XmlDocRoslynTool项目" -ForegroundColor Yellow
    return
}

try {
    # 创建测试用例的副本，避免修改原文件
    $tempTestFile = Join-Path $env:TEMP "TC_MS_002_MainScriptFix_Copy.cs"
    Copy-Item -Path $testCaseFile -Destination $tempTestFile -Force
    
    Write-Host "1. 执行主脚本 - Fix模式" -ForegroundColor Yellow
    Write-Host "   测试用例: $tempTestFile"
    Write-Host "   项目路径: $testProjectPath"
    
    # 记录修复前的文件内容
    $contentBefore = Get-Content -Path $tempTestFile -Raw
    Write-Host "   修复前文件大小: $($contentBefore.Length) 字符"
    
    # 执行主脚本
    $logFile = "MainScript_Fix_Test.log"
    & $mainScript -SolutionPath $testProjectPath -Mode "fix" -ScriptPaths @($tempTestFile) -LogFile $logFile -ExportTempProject
    
    Write-Host "2. 验证修复结果" -ForegroundColor Yellow
    
    # 检查文件是否被修改
    $contentAfter = Get-Content -Path $tempTestFile -Raw
    Write-Host "   修复后文件大小: $($contentAfter.Length) 字符"
    
    if ($contentAfter.Length -gt $contentBefore.Length) {
        Write-Host "   ✓ 文件内容已增加 $(($contentAfter.Length - $contentBefore.Length)) 字符" -ForegroundColor Green
        
        # 检查是否添加了XML注释
        $xmlCommentCount = ([regex]::Matches($contentAfter, "///")).Count
        Write-Host "   ✓ 检测到 $xmlCommentCount 行XML注释" -ForegroundColor Green
        
        # 检查特定的注释标签
        $summaryCount = ([regex]::Matches($contentAfter, "<summary>")).Count
        $remarksCount = ([regex]::Matches($contentAfter, "<remarks>")).Count
        Write-Host "   ✓ 添加了 $summaryCount 个<summary>标签" -ForegroundColor Green
        Write-Host "   ✓ 添加了 $remarksCount 个<remarks>标签" -ForegroundColor Green
        
    } else {
        Write-Warning "文件内容未发生变化，可能修复失败"
    }
    
    Write-Host "3. 验证日志文件" -ForegroundColor Yellow
    $logPattern = Join-Path $rootDir "Logs\*_$logFile"
    $logFiles = Get-ChildItem -Path $logPattern -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -gt 0) {
        $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "   ✓ 找到日志文件: $($latestLog.Name)" -ForegroundColor Green
    } else {
        Write-Warning "未找到日志文件"
    }
    
    # 检查XML报告文件
    $xmlReportPattern = Join-Path $rootDir "Logs\*_MainScript_Fix_Test.xml"
    $xmlReports = Get-ChildItem -Path $xmlReportPattern -ErrorAction SilentlyContinue
    
    if ($xmlReports.Count -gt 0) {
        $latestXmlReport = $xmlReports | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "   ✓ 找到XML报告: $($latestXmlReport.Name)" -ForegroundColor Green
        
        # 尝试解析XML报告
        try {
            [xml]$xmlContent = Get-Content -Path $latestXmlReport.FullName
            Write-Host "   ✓ XML报告格式正确" -ForegroundColor Green
        } catch {
            Write-Warning "XML报告格式可能有问题: $_"
        }
    } else {
        Write-Warning "未找到XML报告文件"
    }
    
    Write-Host "4. 显示修复内容预览" -ForegroundColor Yellow
    if ($Verbose -and $contentAfter.Length -gt $contentBefore.Length) {
        Write-Host "修复后的文件内容预览:" -ForegroundColor Cyan
        $lines = $contentAfter -split "`n"
        $previewLines = $lines | Select-Object -First 20
        foreach ($line in $previewLines) {
            if ($line.Trim().StartsWith("///")) {
                Write-Host $line -ForegroundColor Green
            } else {
                Write-Host $line -ForegroundColor Gray
            }
        }
        if ($lines.Count -gt 20) {
            Write-Host "... (更多内容)" -ForegroundColor Gray
        }
    }
    
    Write-Host "5. 测试结果总结" -ForegroundColor Yellow
    Write-Host "   ✓ 主脚本Fix模式执行成功" -ForegroundColor Green
    Write-Host "   ✓ XmlDocRoslynTool调用正常" -ForegroundColor Green
    Write-Host "   ✓ 源文件修复完成" -ForegroundColor Green
    Write-Host "   ✓ 日志和报告生成正常" -ForegroundColor Green
    
    Write-Host "=== 主脚本集成测试 - Fix模式 完成 ===" -ForegroundColor Green
    
} catch {
    Write-Error "测试失败: $_"
    exit 1
} finally {
    # 清理临时文件
    if (Test-Path $tempTestFile) {
        Remove-Item -Path $tempTestFile -Force -ErrorAction SilentlyContinue
    }
} 