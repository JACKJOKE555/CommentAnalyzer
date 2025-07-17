# RunWithAutoComplete.ps1
# 封装脚本：自动在命令执行后添加完成标记，帮助AI识别命令结束

param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath,
    
    [string]$Arguments = "",
    
    [int]$DelaySeconds = 1,
    
    [int]$OutputLines = 8
)

function Write-CompletionMarker {
    param([string]$Message = "COMMAND COMPLETED")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output ""
    Write-Output "=== $Message - $timestamp ==="
    
    # 添加多行空输出确保AI能识别命令结束
    for ($i = 1; $i -le $OutputLines; $i++) {
        Write-Output ""
    }
}

try {
    Write-Output "开始执行: $ScriptPath $Arguments"
    
    # 执行目标脚本
    if ($Arguments) {
        & $ScriptPath $Arguments
    } else {
        & $ScriptPath
    }
    
    # 记录退出码
    $exitCode = $LASTEXITCODE
    
    # 添加延迟确保所有输出完成
    Start-Sleep -Seconds $DelaySeconds
    
    # 写入完成标记
    if ($exitCode -eq 0) {
        Write-CompletionMarker "SCRIPT COMPLETED SUCCESSFULLY"
    } else {
        Write-CompletionMarker "SCRIPT COMPLETED WITH ERROR (Exit Code: $exitCode)"
    }
    
} catch {
    Write-Output "执行过程中发生错误: $($_.Exception.Message)"
    Write-CompletionMarker "SCRIPT FAILED WITH EXCEPTION"
}

Write-Output "RunWithAutoComplete.ps1 执行完毕" 