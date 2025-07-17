# 测试Parse-RoslynatorLog函数
$logFile = "D:\Unity\Project\Dropleton\CustomPackages\CommentAnalyzer\Logs\20250715-220547-32696_CommentAnalazy_detect.log"

# 加载Parse-RoslynatorLog函数
function Parse-RoslynatorLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    $issues = @()
    
    if (Test-Path $LogFile) {
        $content = Get-Content $LogFile -Encoding UTF8
        
        foreach ($line in $content) {
            Write-Host "检查行: $line" -ForegroundColor Yellow
            # 解析诊断行格式，例如：
            # D:\path\to\file.cs(123,45): warning PROJECT_MEMBER_NO_COMMENT_BLOCK: Missing comment block
            if ($line -match '^(.+?)\((\d+),\d+\):\s+\w+\s+([^:]+):\s*(.+)$') {
                Write-Host "匹配到诊断行!" -ForegroundColor Green
                $issues += @{
                    FilePath = $matches[1]
                    Line = [int]$matches[2]
                    Rule = $matches[3].Trim()
                    Message = $matches[4].Trim()
                }
            }
        }
    }
    
    return $issues
}

# 测试函数
$diagnostics = Parse-RoslynatorLog -LogFile $logFile
Write-Host "诊断数量: $($diagnostics.Count)" -ForegroundColor Cyan
$diagnostics | ForEach-Object {
    Write-Host "  规则: $($_.Rule), 行: $($_.Line), 文件: $($_.FilePath)" -ForegroundColor White
}
