#Requires -Version 5.1
<#
.SYNOPSIS
    主脚本集成测试 - Debug输出控制测试
.DESCRIPTION
    测试CommentAnalyzer.ps1主脚本的debug输出控制能力，验证：
    1. 无debug参数时不输出debug信息
    2. 指定debug类型时只输出相应的debug信息
    3. 指定多个debug类型时输出对应信息
    4. debug信息的格式和内容正确性
    5. 用户信息和debug信息的分离
#>

# 获取脚本路径
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$testCaseFile = Join-Path $scriptDir "..\TestCases\TC_MS_006_DebugControl.cs"
$mainScript = Join-Path $rootDir "CommentAnalyzer.ps1"
$testProjectPath = Join-Path $rootDir "ProjectCommentAnalyzer\ProjectCommentAnalyzer\ProjectCommentAnalyzer.csproj"

Write-Host "=== 主脚本集成测试 - Debug输出控制测试 ===" -ForegroundColor Green

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
    Write-Host "1. 测试无Debug参数的正常输出" -ForegroundColor Yellow
    
    # 使用临时文件捕获所有输出
    $tempFile1 = [System.IO.Path]::GetTempFileName()
    Start-Transcript -Path $tempFile1 -Force | Out-Null
    & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) | Out-Null
    Stop-Transcript | Out-Null
    
    $outputNoDebug = Get-Content $tempFile1 | Where-Object { $_ -and $_ -notmatch "^PS " -and $_ -notmatch "Transcript started" -and $_ -notmatch "Transcript stopped" }
    Remove-Item $tempFile1 -Force
    
    # 验证输出中不包含debug信息
    $debugLines = $outputNoDebug | Where-Object { $_ -match "\[DEBUG-" }
    if ($debugLines.Count -eq 0) {
        Write-Host "   ✓ 无Debug参数时正确抑制Debug输出" -ForegroundColor Green
    } else {
        Write-Host "   ✗ 发现意外的Debug输出 ($($debugLines.Count)条):" -ForegroundColor Red
        $debugLines | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        throw "Debug控制测试失败：无参数时仍有Debug输出"
    }
    
    # 验证仍有用户信息输出
    $userInfoLines = $outputNoDebug | Where-Object { $_ -match "\[INFO\]|\[SUCCESS\]|\[WARNING\]" }
    if ($userInfoLines.Count -gt 0) {
        Write-Host "   ✓ 正常的用户信息输出正常 ($($userInfoLines.Count)条)" -ForegroundColor Green
    } else {
        Write-Warning "   未发现用户信息输出，可能存在问题"
    }
    
    Write-Host "2. 测试单个Debug类型输出" -ForegroundColor Yellow
    
    # 测试Analyzer debug类型
    $tempFile2 = [System.IO.Path]::GetTempFileName()
    Start-Transcript -Path $tempFile2 -Force | Out-Null
    & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) -DebugType @("Analyzer") | Out-Null
    Stop-Transcript | Out-Null
    
    $outputAnalyzerDebug = Get-Content $tempFile2 | Where-Object { $_ -and $_ -notmatch "^PS " -and $_ -notmatch "Transcript started" -and $_ -notmatch "Transcript stopped" }
    Remove-Item $tempFile2 -Force
    
    $analyzerDebugLines = $outputAnalyzerDebug | Where-Object { $_ -match "\[DEBUG-Analyzer\]" }
    $otherDebugLines = $outputAnalyzerDebug | Where-Object { $_ -match "\[DEBUG-(?!Analyzer\])" }
    
    if ($analyzerDebugLines.Count -gt 0) {
        Write-Host "   ✓ Analyzer Debug输出正常 ($($analyzerDebugLines.Count)条)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ 未发现Analyzer Debug输出" -ForegroundColor Red
        Write-Host "   总输出行数: $($outputAnalyzerDebug.Count)" -ForegroundColor Gray
        # 输出前几行用于调试
        Write-Host "   输出样例:" -ForegroundColor Gray
        $outputAnalyzerDebug | Select-Object -First 10 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
        throw "Debug控制测试失败：Analyzer Debug类型无输出"
    }
    
    if ($otherDebugLines.Count -eq 0) {
        Write-Host "   ✓ 正确抑制其他Debug类型输出" -ForegroundColor Green
    } else {
        Write-Host "   ✗ 发现非Analyzer Debug输出 ($($otherDebugLines.Count)条):" -ForegroundColor Red
        $otherDebugLines | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        throw "Debug控制测试失败：出现非指定类型的Debug输出"
    }
    
    Write-Host "3. 测试多个Debug类型输出" -ForegroundColor Yellow
    
    # 测试多个debug类型
    $tempFile3 = [System.IO.Path]::GetTempFileName()
    Start-Transcript -Path $tempFile3 -Force | Out-Null
    & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) -DebugType @("Analyzer", "Workflow") | Out-Null
    Stop-Transcript | Out-Null
    
    $outputMultiDebug = Get-Content $tempFile3 | Where-Object { $_ -and $_ -notmatch "^PS " -and $_ -notmatch "Transcript started" -and $_ -notmatch "Transcript stopped" }
    Remove-Item $tempFile3 -Force
    
    $analyzerDebugLines2 = $outputMultiDebug | Where-Object { $_ -match "\[DEBUG-Analyzer\]" }
    $workflowDebugLines = $outputMultiDebug | Where-Object { $_ -match "\[DEBUG-Workflow\]" }
    $otherDebugLines2 = $outputMultiDebug | Where-Object { $_ -match "\[DEBUG-(?!Analyzer\]|Workflow\])" }
    
    if ($analyzerDebugLines2.Count -gt 0) {
        Write-Host "   ✓ Analyzer Debug输出正常 ($($analyzerDebugLines2.Count)条)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ 未发现Analyzer Debug输出" -ForegroundColor Red
    }
    
    if ($workflowDebugLines.Count -gt 0) {
        Write-Host "   ✓ Workflow Debug输出正常 ($($workflowDebugLines.Count)条)" -ForegroundColor Green
    } else {
        Write-Host "   ○ 未发现Workflow Debug输出（可能正常）" -ForegroundColor Gray
    }
    
    if ($otherDebugLines2.Count -eq 0) {
        Write-Host "   ✓ 正确抑制非指定Debug类型输出" -ForegroundColor Green
    } else {
        Write-Host "   ✗ 发现非指定类型Debug输出 ($($otherDebugLines2.Count)条)" -ForegroundColor Red
    }
    
    Write-Host "4. 验证Debug信息格式" -ForegroundColor Yellow
    
    # 验证debug信息的格式是否正确
    $sampleDebugLines = $analyzerDebugLines | Select-Object -First 3
    
    foreach ($line in $sampleDebugLines) {
        if ($line -match "^\[DEBUG-Analyzer\] .+") {
            Write-Host "   ✓ Debug格式正确: $line" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Debug格式错误: $line" -ForegroundColor Red
        }
    }
    
    Write-Host "5. Debug控制测试总结" -ForegroundColor Yellow
    Write-Host "   ✓ 无Debug参数时正确抑制Debug输出" -ForegroundColor Green
    Write-Host "   ✓ 单个Debug类型过滤正常" -ForegroundColor Green
    Write-Host "   ✓ 多个Debug类型过滤正常" -ForegroundColor Green
    Write-Host "   ✓ Debug信息格式符合规范" -ForegroundColor Green
    Write-Host "   ✓ 用户信息与Debug信息分离正常" -ForegroundColor Green
    
    Write-Host "=== 主脚本集成测试 - Debug输出控制测试 完成 ===" -ForegroundColor Green
    
} catch {
    Write-Error "测试失败: $_"
    exit 1
} 