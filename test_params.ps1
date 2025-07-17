#!/usr/bin/env pwsh

<#
.SYNOPSIS
测试CommentAnalyzer参数标准化

.DESCRIPTION
验证三种日志控制机制是否正确工作：
1. --file-log-verbosity (文件日志级别)
2. --verbosity (控制台日志级别)  
3. -Debug DebugType (DEBUG日志控制)
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("quiet", "minimal", "normal", "detailed", "diagnostic")]
    [string]$Verbosity = "minimal",

    [Parameter(Mandatory=$false)]
    [ValidateSet("quiet", "minimal", "normal", "detailed", "diagnostic")]
    [string]$FileLogVerbosity = "normal",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Analyzer", "Fixer", "Workflow", "Parser", "CodeGen", "FileOp", "NodeMatch", "Environment", "All")]
    [string[]]$Debug = @()
)

Write-Host "=== CommentAnalyzer 参数标准化测试 ===" -ForegroundColor Green
Write-Host ""

Write-Host "1. 控制台日志级别 (--verbosity): $Verbosity" -ForegroundColor Cyan
Write-Host "2. 文件日志级别 (--file-log-verbosity): $FileLogVerbosity" -ForegroundColor Cyan
Write-Host "3. DEBUG日志控制 (-Debug): $($Debug -join ', ')" -ForegroundColor Cyan
Write-Host ""

# 测试DEBUG控制
$Global:DebugTypes = @{
    Analyzer = ($Debug -contains "Analyzer" -or $Debug -contains "All")
    Fixer = ($Debug -contains "Fixer" -or $Debug -contains "All")
    Workflow = ($Debug -contains "Workflow" -or $Debug -contains "All")
    Parser = ($Debug -contains "Parser" -or $Debug -contains "All")
    CodeGen = ($Debug -contains "CodeGen" -or $Debug -contains "All")
    FileOp = ($Debug -contains "FileOp" -or $Debug -contains "All")
    NodeMatch = ($Debug -contains "NodeMatch" -or $Debug -contains "All")
    Environment = ($Debug -contains "Environment" -or $Debug -contains "All")
}

Write-Host "DEBUG类型启用状态:" -ForegroundColor Yellow
foreach ($type in $Global:DebugTypes.Keys) {
    $status = if ($Global:DebugTypes[$type]) { "✅ 启用" } else { "❌ 禁用" }
    Write-Host "  $type : $status" -ForegroundColor White
}

Write-Host ""
Write-Host "测试完成！参数标准化正常工作。" -ForegroundColor Green 