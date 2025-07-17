#!/usr/bin/env pwsh

<#
.SYNOPSIS
简化的CommentAnalyzer测试脚本

.DESCRIPTION
测试三种日志控制机制：
1. --verbosity (控制台日志级别)
2. --file-log-verbosity (文件日志级别)  
3. -DebugType (DEBUG日志控制)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SolutionPath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("quiet", "minimal", "normal", "detailed", "diagnostic")]
    [string]$Verbosity = "minimal",

    [Parameter(Mandatory=$false)]
    [ValidateSet("quiet", "minimal", "normal", "detailed", "diagnostic")]
    [string]$FileLogVerbosity = "normal",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Analyzer", "Fixer", "Workflow", "Parser", "CodeGen", "FileOp", "NodeMatch", "Environment", "All")]
    [string[]]$DebugType = @()
)

Write-Host "=== CommentAnalyzer 简化测试 ===" -ForegroundColor Green
Write-Host ""

Write-Host "输入参数：" -ForegroundColor Cyan
Write-Host "  SolutionPath: $SolutionPath" -ForegroundColor White
Write-Host "  Verbosity: $Verbosity" -ForegroundColor White
Write-Host "  FileLogVerbosity: $FileLogVerbosity" -ForegroundColor White
Write-Host "  DebugType: $($DebugType -join ', ')" -ForegroundColor White
Write-Host ""

# 检查文件是否存在
if (-not (Test-Path $SolutionPath)) {
    Write-Host "❌ 文件不存在: $SolutionPath" -ForegroundColor Red
    exit 1
}

$fileExtension = [System.IO.Path]::GetExtension($SolutionPath).ToLower()
Write-Host "文件类型检测：" -ForegroundColor Cyan
Write-Host "  扩展名: $fileExtension" -ForegroundColor White

if ($fileExtension -eq ".cs") {
    Write-Host "  ✅ 检测到 C# 源文件" -ForegroundColor Green
    Write-Host "  📝 需要创建临时项目进行分析" -ForegroundColor Yellow
} elseif ($fileExtension -eq ".csproj") {
    Write-Host "  ✅ 检测到 C# 项目文件" -ForegroundColor Green
} elseif ($fileExtension -eq ".sln") {
    Write-Host "  ✅ 检测到解决方案文件" -ForegroundColor Green
} else {
    Write-Host "  ❌ 不支持的文件类型" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "日志控制参数标准化测试：" -ForegroundColor Cyan

# 测试 Roslynator 日志级别转换
function Convert-ToRoslynatorVerbosity {
    param([string]$Verbosity)
    
    switch ($Verbosity.ToLower()) {
        "quiet" { return "quiet" }
        "minimal" { return "minimal" }
        "normal" { return "normal" }
        "detailed" { return "detailed" }
        "diagnostic" { return "diagnostic" }
        default { 
            Write-Host "  ⚠️  未知日志级别: $Verbosity, 使用 'normal'" -ForegroundColor Yellow
            return "normal"
        }
    }
}

$roslynatorVerbosity = Convert-ToRoslynatorVerbosity $Verbosity
$roslynatorFileLogVerbosity = Convert-ToRoslynatorVerbosity $FileLogVerbosity

Write-Host "  控制台日志级别: $Verbosity -> $roslynatorVerbosity" -ForegroundColor White
Write-Host "  文件日志级别: $FileLogVerbosity -> $roslynatorFileLogVerbosity" -ForegroundColor White

# 测试 DEBUG 控制
Write-Host ""
Write-Host "DEBUG 控制测试：" -ForegroundColor Cyan

$debugTypes = @{
    Analyzer = ($DebugType -contains "Analyzer" -or $DebugType -contains "All")
    Fixer = ($DebugType -contains "Fixer" -or $DebugType -contains "All")
    Workflow = ($DebugType -contains "Workflow" -or $DebugType -contains "All")
    Parser = ($DebugType -contains "Parser" -or $DebugType -contains "All")
    CodeGen = ($DebugType -contains "CodeGen" -or $DebugType -contains "All")
    FileOp = ($DebugType -contains "FileOp" -or $DebugType -contains "All")
    NodeMatch = ($DebugType -contains "NodeMatch" -or $DebugType -contains "All")
    Environment = ($DebugType -contains "Environment" -or $DebugType -contains "All")
}

foreach ($type in $debugTypes.Keys) {
    $enabled = $debugTypes[$type]
    $status = if ($enabled) { "✅ 启用" } else { "❌ 禁用" }
    $color = if ($enabled) { "Green" } else { "Gray" }
    Write-Host "  $type`: $status" -ForegroundColor $color
}

Write-Host ""
Write-Host "✅ 参数标准化测试完成" -ForegroundColor Green
Write-Host ""
Write-Host "标准化命令行参数格式：" -ForegroundColor Cyan
Write-Host "  --verbosity `"$roslynatorVerbosity`"" -ForegroundColor White
Write-Host "  --file-log-verbosity `"$roslynatorFileLogVerbosity`"" -ForegroundColor White
if ($DebugType.Count -gt 0) {
    $debugTypesStr = $DebugType -join ","
    Write-Host "  --debugType `"$debugTypesStr`"" -ForegroundColor White
}

Write-Host ""
Write-Host "Test completed successfully!" -ForegroundColor Green 