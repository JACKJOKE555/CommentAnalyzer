# BatchTestWithAutoComplete.ps1
# 批量测试专用脚本，自动处理命令完成识别

param(
    [string[]]$TestCases = @(),
    [string]$Pattern = "TC_F_*",
    [switch]$ContinueOnError = $false,
    [int]$DelayBetweenTests = 2
)

function Write-TestCompletionMarker {
    param(
        [string]$TestName,
        [string]$Status = "COMPLETED",
        [int]$ExitCode = 0
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "=== TEST $Status`: $TestName ==="
    Write-Output "=== EXIT CODE`: $ExitCode ==="
    Write-Output "=== TIMESTAMP`: $timestamp ==="
    Write-Output "=========================================="
    
    # 确保AI能识别的多行空输出
    for ($i = 1; $i -le 10; $i++) {
        Write-Output ""
    }
}

function Get-TestScripts {
    if ($TestCases.Count -gt 0) {
        return $TestCases | ForEach-Object { 
            if (Test-Path $_) { $_ } 
            elseif (Test-Path "Run_$_.ps1") { "Run_$_.ps1" }
            elseif (Test-Path "Run_$_*.ps1") { Get-ChildItem "Run_$_*.ps1" | Select-Object -First 1 -ExpandProperty Name }
        }
    } else {
        return Get-ChildItem "Run_$Pattern.ps1" | Select-Object -ExpandProperty Name | Sort-Object
    }
}

# 主执行逻辑
$testScripts = Get-TestScripts
$totalTests = $testScripts.Count
$successCount = 0
$failureCount = 0

Write-Output "=== 批量测试开始 ==="
Write-Output "测试脚本数量`: $totalTests"
Write-Output "模式`: $Pattern"
Write-Output "继续错误`: $ContinueOnError"
Write-Output ""

foreach ($script in $testScripts) {
    $testNumber = $successCount + $failureCount + 1
    
    Write-Output "[$testNumber/$totalTests] 开始执行`: $script"
    
    try {
        # 执行测试脚本
        & ".\$script"
        $exitCode = $LASTEXITCODE
        
        # 添加延迟确保输出完成
        Start-Sleep -Seconds $DelayBetweenTests
        
        if ($exitCode -eq 0) {
            $successCount++
            Write-TestCompletionMarker -TestName $script -Status "PASSED" -ExitCode $exitCode
        } else {
            $failureCount++
            Write-TestCompletionMarker -TestName $script -Status "FAILED" -ExitCode $exitCode
            
            if (-not $ContinueOnError) {
                Write-Output "遇到错误，停止执行（使用 -ContinueOnError 继续）"
                break
            }
        }
        
    } catch {
        $failureCount++
        Write-Output "执行 $script 时发生异常`: $($_.Exception.Message)"
        Write-TestCompletionMarker -TestName $script -Status "EXCEPTION" -ExitCode -1
        
        if (-not $ContinueOnError) {
            Write-Output "遇到异常，停止执行"
            break
        }
    }
}

# 最终总结
Write-Output ""
Write-Output "=========================================="
Write-Output "=== 批量测试完成 ==="
Write-Output "=== 总数`: $totalTests ==="
Write-Output "=== 成功`: $successCount ==="
Write-Output "=== 失败`: $failureCount ==="
Write-Output "=== 完成时间`: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Write-Output "=========================================="

# 多行空输出确保AI识别完成
for ($i = 1; $i -le 15; $i++) {
    Write-Output ""
}

Write-Output "BatchTestWithAutoComplete.ps1 执行完毕" 