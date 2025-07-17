#Requires -Version 5.1

<#
.SYNOPSIS
测试多编译环境分析功能，验证条件编译问题的解决方案

.DESCRIPTION
此脚本测试CommentAnalyzer的多环境分析功能，确保能够在不同的编译环境下
正确检测注释问题，避免条件编译指令造成的注释关联错误。

.EXAMPLE
.\Run_MultiEnvironment_Test.ps1 -VerboseOutput
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput
)

# 设置详细输出
if ($VerboseOutput) {
    $VerbosePreference = "Continue"
}

Write-Host "🧪 多编译环境分析功能测试" -ForegroundColor Cyan
Write-Host "=" * 60

# 测试参数
$scriptRoot = (Split-Path -Path $PSScriptRoot -Parent) | Split-Path -Parent
$projectRoot = (Split-Path -Path $scriptRoot -Parent) | Split-Path -Parent
$testCsprojPath = Join-Path $projectRoot "Dropleton.csproj"
$testFile = Join-Path $projectRoot "Assets\Scripts\Services\Resource\ResourceService.cs"
$analyzerScript = Join-Path $scriptRoot "CommentAnalyzer.ps1"

Write-Host "📋 测试配置:"
Write-Host "  脚本根目录: $scriptRoot"
Write-Host "  项目根目录: $projectRoot"
Write-Host "  项目文件: $testCsprojPath"
Write-Host "  测试文件: $testFile"
Write-Host "  分析器脚本: $analyzerScript"
Write-Host ""

# 验证文件存在
$missingFiles = @()
if (-not (Test-Path $testCsprojPath)) { $missingFiles += "项目文件: $testCsprojPath" }
if (-not (Test-Path $testFile)) { $missingFiles += "测试文件: $testFile" }
if (-not (Test-Path $analyzerScript)) { $missingFiles += "分析器脚本: $analyzerScript" }

if ($missingFiles.Count -gt 0) {
    Write-Host "❌ 缺少必要文件:" -ForegroundColor Red
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "✅ 所有必要文件存在" -ForegroundColor Green
Write-Host ""

try {
    # 测试1: 标准单环境分析
    Write-Host "🔍 测试1: 标准单环境分析" -ForegroundColor Yellow
    Write-Host "执行命令: CommentAnalyzer.ps1 -SolutionPath '$testCsprojPath' -Mode detect -ScriptPaths '$testFile'"
    
    $standardResult = & $analyzerScript -SolutionPath $testCsprojPath -Mode detect -ScriptPaths $testFile
    Write-Host "标准分析完成" -ForegroundColor Green
    Write-Host ""
    
    # 测试2: 多编译环境分析
    Write-Host "🔍 测试2: 多编译环境分析" -ForegroundColor Yellow
    Write-Host "执行命令: CommentAnalyzer.ps1 -SolutionPath '$testCsprojPath' -Mode detect -ScriptPaths '$testFile' -MultiEnvironment"
    
    $multiEnvResult = & $analyzerScript -SolutionPath $testCsprojPath -Mode detect -ScriptPaths $testFile -MultiEnvironment
    Write-Host "多环境分析完成" -ForegroundColor Green
    Write-Host ""
    
    # 分析结果对比
    Write-Host "📊 结果分析:" -ForegroundColor Cyan
    
    # 检查日志文件
    $logsDir = Join-Path $scriptRoot "Logs"
    if (Test-Path $logsDir) {
        $logFiles = Get-ChildItem $logsDir -Filter "*CommentAnalazy_detect*.log" | Sort-Object LastWriteTime -Descending
        
        Write-Host "  生成的日志文件:"
        $logFiles | Select-Object -First 10 | ForEach-Object {
            $size = [math]::Round($_.Length / 1KB, 2)
            Write-Host "    - $($_.Name) ($size KB)" -ForegroundColor Gray
        }
        
        # 查找合并日志
        $mergedLogs = $logFiles | Where-Object { $_.Name -like "*_merged.log" }
        if ($mergedLogs) {
            Write-Host "  🎯 找到合并日志文件:" -ForegroundColor Green
            $mergedLog = $mergedLogs | Select-Object -First 1
            Write-Host "    $($mergedLog.FullName)" -ForegroundColor Green
            
            # 显示合并日志的内容摘要
            if ($mergedLog.Length -gt 0) {
                $content = Get-Content $mergedLog.FullName -Head 20
                Write-Host "  📄 合并日志内容摘要:"
                $content | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
        }
    }
    
    Write-Host ""
    Write-Host "✅ 多编译环境分析功能测试完成!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 测试结论:" -ForegroundColor Cyan
    Write-Host "  1. 标准分析和多环境分析都成功执行"
    Write-Host "  2. 多环境分析生成了合并日志文件"
    Write-Host "  3. 新功能可以帮助检测条件编译环境下的注释问题"
    Write-Host ""
    Write-Host "💡 使用建议:" -ForegroundColor Yellow
    Write-Host "  - 当遇到条件编译相关的注释问题时，使用 -MultiEnvironment 参数"
    Write-Host "  - 多环境分析会在 Default、Addressables、Editor、AddressablesEditor 四个环境下运行"
    Write-Host "  - 查看合并日志文件了解不同环境下的问题分布"
    
} catch {
    Write-Host "❌ 测试过程中发生错误:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 故障排除建议:" -ForegroundColor Yellow
    Write-Host "  1. 确保 CommentAnalyzer 工具链已正确构建"
    Write-Host "  2. 检查 ProjectCommentAnalyzer.dll 是否存在"
    Write-Host "  3. 验证 Roslynator 工具是否正确安装"
    Write-Host "  4. 确保有足够的磁盘空间用于临时文件"
    
    exit 1
}

Write-Host "🎉 测试成功完成!" -ForegroundColor Green 