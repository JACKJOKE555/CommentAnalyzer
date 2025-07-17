# 测试脚本：验证TC_F_003_TypeMissingRemarks修复功能
param(
    [switch]$Debug
)

$testFile = ".\Tests\FixerTestCases\TC_F_003_TypeMissingRemarks.cs"
$backupFile = "$testFile.backup"

Write-Host "=== TC_F_003_TypeMissingRemarks Fix Test ==="

# 1. 备份原文件
Write-Host "1. 备份原文件..."
Copy-Item $testFile $backupFile -Force

# 2. 检查原文件内容
Write-Host "2. 原文件内容："
Get-Content $testFile
Write-Host ""

# 3. 运行detect模式
Write-Host "3. 运行detect模式..."
$detectResult = & .\CommentAnalyzer.ps1 -SolutionPath $testFile -Mode detect
Write-Host "检测结果: $detectResult"

# 4. 尝试手动运行XmlDocRoslynTool
Write-Host "4. 尝试手动运行XmlDocRoslynTool..."
$tempProject = ".\Temp\TempProject_test.csproj"
$analyzerPath = ".\ProjectCommentAnalyzer\ProjectCommentAnalyzer\bin\Debug\netstandard2.0\ProjectCommentAnalyzer.dll"
$msbuildPath = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin"
$xmlLogPath = ".\Logs\test_fix.xml"

if ($Debug) {
    Write-Host "Debug模式，显示详细信息..."
    & .\XmlDocRoslynTool\bin\Debug\net8.0\XmlDocRoslynTool.exe --projectPath=$tempProject --analyzerPath=$analyzerPath --files=$testFile --msbuildPath=$msbuildPath --xmlLogPath=$xmlLogPath --debugType="NodeMatch,Fixer"
} else {
    Write-Host "运行基本修复..."
    & .\XmlDocRoslynTool\bin\Debug\net8.0\XmlDocRoslynTool.exe --projectPath=$tempProject --analyzerPath=$analyzerPath --files=$testFile --msbuildPath=$msbuildPath --xmlLogPath=$xmlLogPath
}

# 5. 检查修复后的文件内容
Write-Host "5. 修复后文件内容："
Get-Content $testFile
Write-Host ""

# 6. 恢复原文件
Write-Host "6. 恢复原文件..."
Copy-Item $backupFile $testFile -Force
Remove-Item $backupFile -Force

Write-Host "=== 测试完成 ===" 