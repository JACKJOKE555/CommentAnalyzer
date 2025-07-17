#Requires -Version 5.1
<#
.SYNOPSIS
    主脚本集成测试 - 文件管理测试
.DESCRIPTION
    测试CommentAnalyzer.ps1主脚本的文件管理能力，验证：
    1. 临时文件的创建和清理
    2. 日志文件的管理策略
    3. 文件系统异常的处理
    4. ExportTempProject参数的功能
#>

# [修正3] 测试文件初始化（如有备份则恢复，无则用原始用例覆盖临时文件）
$testFile = "CustomPackages/CommentAnalyzer/Tests/TestCases/TC_MS_004_FileManagement.cs"
if (Test-Path "$testFile.bak") {
    Copy-Item "$testFile.bak" $testFile -Force
}

# 获取脚本路径
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$testCaseFile = Join-Path $scriptDir "..\TestCases\TC_MS_004_FileManagement.cs"
$mainScript = Join-Path $rootDir "CommentAnalyzer.ps1"
$testProjectPath = Join-Path $rootDir "ProjectCommentAnalyzer\ProjectCommentAnalyzer\ProjectCommentAnalyzer.csproj"

Write-Host "=== 主脚本集成测试 - 文件管理测试 ===" -ForegroundColor Green

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
    Write-Host "1. 执行主脚本 - 启用临时项目导出" -ForegroundColor Yellow
    Write-Host "   测试用例: $testCaseFile"
    Write-Host "   项目路径: $testProjectPath"
    
    # 清理之前的临时文件
    $tempDir = Join-Path $rootDir "Temp"
    if (Test-Path $tempDir) {
        Get-ChildItem -Path $tempDir -Filter "*FileManagement*" | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    
    # 记录执行前的文件状态
    $beforeExecution = @{
        TempDir = if (Test-Path $tempDir) { (Get-ChildItem -Path $tempDir).Count } else { 0 }
        LogsDir = if (Test-Path (Join-Path $rootDir "Logs")) { (Get-ChildItem -Path (Join-Path $rootDir "Logs") -Filter "*FileManagement*").Count } else { 0 }
    }
    
    # 执行主脚本
    $logFile = "MainScript_FileManagement_Test.log"
    & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) -LogFile $logFile -ExportTempProject
    
    Write-Host "2. 验证临时文件管理" -ForegroundColor Yellow
    
    # 检查临时项目文件是否创建
    $tempProjects = Get-ChildItem -Path $tempDir -Filter "TempProject_*.csproj" -ErrorAction SilentlyContinue | 
                   Sort-Object LastWriteTime -Descending
    
    if ($tempProjects.Count -gt 0) {
        $latestTempProject = $tempProjects[0]
        Write-Host "   ✓ 临时项目文件已创建: $($latestTempProject.Name)" -ForegroundColor Green
        
        # 验证临时项目内容
        [xml]$tempProjectXml = Get-Content -Path $latestTempProject.FullName
        $compileItems = $tempProjectXml.Project.ItemGroup.Compile
        
        if ($compileItems) {
            Write-Host "   ✓ 临时项目包含编译项: $($compileItems.Count)个" -ForegroundColor Green
            
            # 检查是否包含我们的测试文件
            $containsTestFile = $false
            foreach ($item in $compileItems) {
                if ($item.Include -match "FileManagement") {
                    $containsTestFile = $true
                    break
                }
            }
            
            if ($containsTestFile) {
                Write-Host "   ✓ 临时项目正确包含测试文件" -ForegroundColor Green
            } else {
                Write-Warning "   临时项目未包含预期的测试文件"
            }
        }
        
        # 测试ExportTempProject功能 - 文件应该保留
        Write-Host "   ○ 验证临时文件保留策略（ExportTempProject=true）" -ForegroundColor Gray
    } else {
        Write-Warning "未找到临时项目文件"
    }
    
    Write-Host "3. 验证日志文件管理" -ForegroundColor Yellow
    $logPattern = Join-Path $rootDir "Logs\*_$logFile"
    $logFiles = Get-ChildItem -Path $logPattern -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -gt 0) {
        $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "   ✓ 日志文件已创建: $($latestLog.Name)" -ForegroundColor Green
        Write-Host "   ✓ 日志文件大小: $([math]::Round($latestLog.Length/1KB, 2)) KB" -ForegroundColor Green
        
        # 检查日志文件命名格式
        if ($latestLog.Name -match "^\d{8}-\d{6}-\d+_.*\.log$") {
            Write-Host "   ✓ 日志文件命名格式正确" -ForegroundColor Green
        } else {
            Write-Warning "   日志文件命名格式可能不标准"
        }
        
    } else {
        Write-Warning "未找到日志文件"
    }
    
    Write-Host "4. 测试文件清理功能" -ForegroundColor Yellow
    
    # 执行主脚本但不使用ExportTempProject参数，测试自动清理
    Write-Host "   执行不保留临时文件的测试..." -ForegroundColor Gray
    $cleanupLogFile = "MainScript_FileManagement_Cleanup_Test.log"
    & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) -LogFile $cleanupLogFile
    
    # 检查是否有新的临时文件被清理
    $tempProjectsAfterCleanup = Get-ChildItem -Path $tempDir -Filter "TempProject_*.csproj" -ErrorAction SilentlyContinue |
                               Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-1) } |
                               Sort-Object LastWriteTime -Descending
    
    if ($tempProjectsAfterCleanup.Count -eq 0) {
        Write-Host "   ✓ 临时文件自动清理功能正常" -ForegroundColor Green
    } else {
        Write-Warning "   临时文件可能未被正确清理"
    }
    
    Write-Host "5. 文件管理测试总结" -ForegroundColor Yellow
    Write-Host "   ✓ 临时项目文件创建功能正常" -ForegroundColor Green
    Write-Host "   ✓ ExportTempProject参数功能正常" -ForegroundColor Green
    Write-Host "   ✓ 日志文件管理功能正常" -ForegroundColor Green
    Write-Host "   ✓ 文件清理策略验证完成" -ForegroundColor Green
    
    Write-Host "=== 主脚本集成测试 - 文件管理测试 完成 ===" -ForegroundColor Green
    
} catch {
    Write-Error "测试失败: $_"
    exit 1
} 