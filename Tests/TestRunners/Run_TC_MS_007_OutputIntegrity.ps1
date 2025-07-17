#Requires -Version 5.1
<#
.SYNOPSIS
    主脚本集成测试 - 输出完整性测试
.DESCRIPTION
    测试CommentAnalyzer.ps1主脚本的输出完整性，验证：
    1. 无重复输出问题
    2. 每条消息只出现一次
    3. debug信息和用户信息的输出一致性
    4. detect和fix模式的输出完整性
    5. 大量诊断情况下的输出稳定性
#>

# 获取脚本路径
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$testCaseFile = Join-Path $scriptDir "..\TestCases\TC_MS_007_OutputIntegrity.cs"
$mainScript = Join-Path $rootDir "CommentAnalyzer.ps1"
$testProjectPath = Join-Path $rootDir "ProjectCommentAnalyzer\ProjectCommentAnalyzer\ProjectCommentAnalyzer.csproj"

Write-Host "=== 主脚本集成测试 - 输出完整性测试 ===" -ForegroundColor Green

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

# 辅助函数：检查重复输出
function Test-OutputDuplication {
    param(
        [string[]]$OutputLines,
        [string]$TestName
    )
    
    $duplicateCount = 0
    $lineGroups = $OutputLines | Group-Object
    
    foreach ($group in $lineGroups) {
        if ($group.Count -gt 1) {
            $duplicateCount += $group.Count - 1
            Write-Host "   ⚠ 发现重复输出 ($($group.Count)次): $($group.Name)" -ForegroundColor Yellow
        }
    }
    
    if ($duplicateCount -eq 0) {
        Write-Host "   ✓ $TestName 无重复输出" -ForegroundColor Green
        return $true
    } else {
        Write-Host "   ✗ $TestName 发现 $duplicateCount 条重复输出" -ForegroundColor Red
        return $false
    }
}

# 辅助函数：分析输出模式
function Analyze-OutputPattern {
    param(
        [string[]]$OutputLines,
        [string]$TestName
    )
    
    $debugLines = $OutputLines | Where-Object { $_ -match "\[DEBUG-" }
    $infoLines = $OutputLines | Where-Object { $_ -match "\[INFO\]" }
    $successLines = $OutputLines | Where-Object { $_ -match "\[SUCCESS\]" }
    $warningLines = $OutputLines | Where-Object { $_ -match "\[WARNING\]" }
    
    Write-Host "   分析 $TestName 输出模式:" -ForegroundColor Cyan
    Write-Host "     - Debug消息: $($debugLines.Count)条" -ForegroundColor Gray
    Write-Host "     - Info消息: $($infoLines.Count)条" -ForegroundColor Gray
    Write-Host "     - Success消息: $($successLines.Count)条" -ForegroundColor Gray
    Write-Host "     - Warning消息: $($warningLines.Count)条" -ForegroundColor Gray
    Write-Host "     - 总输出行数: $($OutputLines.Count)条" -ForegroundColor Gray
}

try {
    Write-Host "1. 测试Detect模式输出完整性" -ForegroundColor Yellow
    
    # 执行detect模式分析
    $outputDetect = & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) 2>&1
    
    $result1 = Test-OutputDuplication -OutputLines $outputDetect -TestName "Detect模式"
    Analyze-OutputPattern -OutputLines $outputDetect -TestName "Detect模式"
    
    Write-Host "2. 测试带Debug的Detect模式输出完整性" -ForegroundColor Yellow
    
    # 执行带debug的detect模式分析
    $outputDetectDebug = & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) -DebugType "Analyzer","Workflow" 2>&1
    
    $result2 = Test-OutputDuplication -OutputLines $outputDetectDebug -TestName "Detect模式(Debug)"
    Analyze-OutputPattern -OutputLines $outputDetectDebug -TestName "Detect模式(Debug)"
    
    Write-Host "3. 测试Fix模式输出完整性" -ForegroundColor Yellow
    
    # 执行fix模式分析
    $outputFix = & $mainScript -SolutionPath $testProjectPath -Mode "fix" -ScriptPaths @($testCaseFile) 2>&1
    
    $result3 = Test-OutputDuplication -OutputLines $outputFix -TestName "Fix模式"
    Analyze-OutputPattern -OutputLines $outputFix -TestName "Fix模式"
    
    Write-Host "4. 测试带Debug的Fix模式输出完整性" -ForegroundColor Yellow
    
    # 执行带debug的fix模式分析
    $outputFixDebug = & $mainScript -SolutionPath $testProjectPath -Mode "fix" -ScriptPaths @($testCaseFile) -DebugType "Fixer","Analyzer" 2>&1
    
    $result4 = Test-OutputDuplication -OutputLines $outputFixDebug -TestName "Fix模式(Debug)"
    Analyze-OutputPattern -OutputLines $outputFixDebug -TestName "Fix模式(Debug)"
    
    Write-Host "5. 验证特定消息的唯一性" -ForegroundColor Yellow
    
    # 检查关键消息是否只出现一次
    $keyMessages = @(
        "Running in DETECT mode",
        "Running in FIX mode",
        "Analysis completed",
        "Fix process completed"
    )
    
    $allOutput = $outputDetect + $outputDetectDebug + $outputFix + $outputFixDebug
    
    foreach ($message in $keyMessages) {
        $matchingLines = $allOutput | Where-Object { $_ -match [regex]::Escape($message) }
        $expectedCount = if ($message -match "DETECT") { 2 } elseif ($message -match "FIX") { 2 } else { 4 }
        
        if ($matchingLines.Count -eq $expectedCount) {
            Write-Host "   ✓ 关键消息 '$message' 出现次数正确 ($($matchingLines.Count)/$expectedCount)" -ForegroundColor Green
        } else {
            Write-Host "   ✗ 关键消息 '$message' 出现次数异常 ($($matchingLines.Count)/$expectedCount)" -ForegroundColor Red
        }
    }
    
    Write-Host "6. 验证Debug消息的正确性" -ForegroundColor Yellow
    
    # 验证debug消息不会重复
    $allDebugLines = ($outputDetectDebug + $outputFixDebug) | Where-Object { $_ -match "\[DEBUG-" }
    $debugDuplicates = $allDebugLines | Group-Object | Where-Object { $_.Count -gt 1 }
    
    if ($debugDuplicates.Count -eq 0) {
        Write-Host "   ✓ Debug消息无异常重复" -ForegroundColor Green
    } else {
        Write-Host "   ✗ 发现Debug消息重复:" -ForegroundColor Red
        foreach ($dup in $debugDuplicates) {
            Write-Host "     - '$($dup.Name)' 重复 $($dup.Count) 次" -ForegroundColor Red
        }
    }
    
    Write-Host "7. 压力测试 - 多次连续执行" -ForegroundColor Yellow
    
    # 连续执行多次，验证会话状态清理
    $consecutiveResults = @()
    for ($i = 1; $i -le 3; $i++) {
        Write-Host "   执行第 $i 次连续测试..." -ForegroundColor Gray
        $consecutiveOutput = & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) 2>&1
        $consecutiveResults += Test-OutputDuplication -OutputLines $consecutiveOutput -TestName "连续执行第${i}次"
    }
    
    $consecutiveSuccess = $consecutiveResults | Where-Object { $_ -eq $true }
    if ($consecutiveSuccess.Count -eq 3) {
        Write-Host "   ✓ 连续执行测试全部通过，会话状态清理正常" -ForegroundColor Green
    } else {
        Write-Host "   ✗ 连续执行测试发现问题，可能存在会话状态缓存" -ForegroundColor Red
    }
    
    Write-Host "8. 输出完整性测试总结" -ForegroundColor Yellow
    
    $allResults = @($result1, $result2, $result3, $result4) + $consecutiveResults
    $successCount = ($allResults | Where-Object { $_ -eq $true }).Count
    $totalCount = $allResults.Count
    
    if ($successCount -eq $totalCount) {
        Write-Host "   ✅ 所有输出完整性测试通过 ($successCount/$totalCount)" -ForegroundColor Green
        Write-Host "   ✓ 无重复输出问题" -ForegroundColor Green
        Write-Host "   ✓ 消息输出一致性良好" -ForegroundColor Green
        Write-Host "   ✓ 会话状态清理正常" -ForegroundColor Green
        Write-Host "   ✓ 大量诊断情况下输出稳定" -ForegroundColor Green
    } else {
        $failCount = $totalCount - $successCount
        Write-Host "   ❌ 输出完整性测试部分失败 ($failCount/$totalCount 失败)" -ForegroundColor Red
        throw "输出完整性测试失败"
    }
    
    Write-Host "=== 主脚本集成测试 - 输出完整性测试 完成 ===" -ForegroundColor Green
    
} catch {
    Write-Error "测试失败: $_"
    exit 1
} 