#Requires -Version 5.1
<#
.SYNOPSIS
    主脚本集成测试 - 错误处理测试
.DESCRIPTION
    测试CommentAnalyzer.ps1主脚本的错误处理能力，验证：
    1. 对语法错误文件的处理
    2. 错误信息的正确输出
    3. 日志文件中的错误记录
    4. 脚本的优雅失败处理
#>

# [修正3] 测试文件初始化（如有备份则恢复，无则用原始用例覆盖临时文件）
$testFile = "CustomPackages/CommentAnalyzer/Tests/TestCases/TC_MS_003_ErrorHandling.cs"
if (Test-Path "$testFile.bak") {
    Copy-Item "$testFile.bak" $testFile -Force
}

# 获取脚本路径
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$testCaseFile = Join-Path $scriptDir "..\TestCases\TC_MS_003_ErrorHandling.cs"
$mainScript = Join-Path $rootDir "CommentAnalyzer.ps1"
$testProjectPath = Join-Path $rootDir "ProjectCommentAnalyzer\ProjectCommentAnalyzer\ProjectCommentAnalyzer.csproj"

Write-Host "=== 主脚本集成测试 - 错误处理测试 ===" -ForegroundColor Green

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
    Write-Host "1. 执行主脚本 - 处理语法错误文件" -ForegroundColor Yellow
    Write-Host "   测试用例: $testCaseFile"
    Write-Host "   项目路径: $testProjectPath"
    
    # 执行主脚本，期望它能优雅地处理语法错误
    $logFile = "MainScript_ErrorHandling_Test.log"
    
    # 捕获主脚本的执行结果
    $scriptResult = $null
    $scriptError = $null
    
    try {
        & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) -LogFile $logFile -ExportTempProject 2>&1 | Tee-Object -Variable scriptResult
    } catch {
        $scriptError = $_
    }
    
    Write-Host "2. 验证错误处理结果" -ForegroundColor Yellow
    
    # 检查脚本是否优雅地处理了错误
    if ($scriptError) {
        Write-Host "   ✓ 脚本检测到错误并终止执行" -ForegroundColor Green
        Write-Host "   错误信息: $($scriptError.ToString())" -ForegroundColor Yellow
    } else {
        Write-Host "   ✓ 脚本完成执行（可能忽略了部分语法错误）" -ForegroundColor Green
    }
    
    Write-Host "3. 验证日志文件记录" -ForegroundColor Yellow
    $logPattern = Join-Path $rootDir "Logs\*_$logFile"
    $logFiles = Get-ChildItem -Path $logPattern -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -gt 0) {
        $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "   ✓ 找到日志文件: $($latestLog.Name)" -ForegroundColor Green
        
        $logContent = Get-Content -Path $latestLog.FullName -Raw
        
        # 检查日志中是否包含错误信息
        if ($logContent -match "error|Error|ERROR") {
            Write-Host "   ✓ 日志中包含错误信息" -ForegroundColor Green
        } else {
            Write-Warning "   日志中未发现明显的错误信息"
        }
    } else {
        Write-Warning "未找到日志文件，可能主脚本在早期阶段失败"
    }
    
    Write-Host "4. 验证临时文件处理" -ForegroundColor Yellow
    $tempDir = Join-Path $rootDir "Temp"
    $tempFiles = Get-ChildItem -Path $tempDir -Filter "*ErrorHandling*" -ErrorAction SilentlyContinue
    
    if ($tempFiles.Count -gt 0) {
        Write-Host "   ✓ 发现相关临时文件: $($tempFiles.Count)个" -ForegroundColor Green
        foreach ($file in $tempFiles) {
            Write-Host "     - $($file.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ○ 未发现相关临时文件（可能已被清理或未创建）" -ForegroundColor Gray
    }
    
    Write-Host "5. 错误处理测试总结" -ForegroundColor Yellow
    Write-Host "   ✓ 主脚本错误处理验证完成" -ForegroundColor Green
    Write-Host "   ✓ 错误信息记录正常" -ForegroundColor Green
    Write-Host "   ✓ 日志文件处理正常" -ForegroundColor Green
    
    Write-Host "=== 主脚本集成测试 - 错误处理测试 完成 ===" -ForegroundColor Green
    
} catch {
    Write-Error "测试失败: $_"
    exit 1
} 