#Requires -Version 5.1

<#
.SYNOPSIS
    A script to run the Roslyn-based comment analyzer.
    Supports detection, fixing, and verification of documentation comments.
.DESCRIPTION
    This script provides three modes of operation:
    - detect: Analyzes the code and logs issues to a JSON-based log file.
    - fix:    Analyzes and applies automatic fixes.
    
    Performance optimization: Use -ConsoleLogLevel and -FileLogLevel parameters to control 
    verbosity and improve analysis speed. Default settings provide optimal performance.
    
    Debug control: Use -Debug parameter to enable specific debug information when troubleshooting.
    Normal operation only shows success/failure results and warnings.
.PARAMETER SolutionPath
    The path to the solution (.sln) or project (.csproj) file to analyze.
.PARAMETER Mode
    The mode of operation. Can be 'detect', 'fix'.
.PARAMETER MsbuildPath
    Optional path to the MSBuild.exe directory. If not provided, it will be auto-detected.
.PARAMETER LogFile
    Optional path for the output log file. JobID prefix will be automatically added. Applies to 'detect' and 'fix' modes.
.PARAMETER ScriptPaths
    Optional array of specific file paths to analyze, overriding the project-wide analysis.
.PARAMETER ForceRestore
    If specified, forces NuGet package restoration even if packages already exist.
.PARAMETER ExportTempProject
    If specified, the temporary .csproj file created during analysis will not be deleted. Useful for debugging.
.PARAMETER MultiEnvironment
    If specified, performs analysis in multiple compilation environments to avoid conditional compilation issues.
    This helps detect annotation problems that might be hidden by #if/#endif directives.
    Only works with -ScriptPaths parameter.
.PARAMETER Verbosity
    Console log verbosity level. Valid values: quiet, minimal, normal, detailed, diagnostic.
    Default is 'minimal' for better performance.
.PARAMETER FileLogVerbosity  
    File log verbosity level. Valid values: quiet, minimal, normal, detailed, diagnostic.
    Default is 'normal' for balanced detail and performance.
.PARAMETER DebugType
    Enable debug information for troubleshooting. Can specify multiple debug types.
    Valid values: 'Analyzer', 'Fixer', 'Workflow', 'Parser', 'CodeGen', 'FileOp', 'NodeMatch', 'Environment', 'All'.
    Normal operation only shows success/failure results. Use debug only when troubleshooting.
.EXAMPLE
    # Normal operation - only shows success/failure
    .\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode detect
    
    # Enable debug for analyzer issues
    .\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode detect -DebugType Analyzer
    
    # Enable multiple debug types with custom verbosity
    .\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode fix -DebugType Analyzer,Fixer -Verbosity detailed -FileLogVerbosity diagnostic
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SolutionPath,

    [Parameter(Mandatory=$true)]
    [ValidateSet("detect", "fix")]
    [string]$Mode,

    [Parameter(Mandatory=$false)]
    [string]$MsbuildPath,

    [Parameter(Mandatory=$false)]
    [string]$LogFile,

    [Parameter(Mandatory=$false)]
    [string[]]$ScriptPaths,

    [Parameter(Mandatory=$false)]
    [switch]$ForceRestore,

    [Parameter(Mandatory=$false)]
    [switch]$ExportTempProject,

    [Parameter(Mandatory=$false)]
    [switch]$MultiEnvironment,

    [Parameter(Mandatory=$false)]
    [ValidateSet("quiet", "minimal", "normal", "detailed", "diagnostic")]
    [string]$Verbosity = "minimal",

    [Parameter(Mandatory=$false)]
    [ValidateSet("quiet", "minimal", "normal", "detailed", "diagnostic")]
    [string]$FileLogVerbosity = "normal",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Analyzer", "Fixer", "Workflow", "Parser", "CodeGen", "FileOp", "NodeMatch", "Environment", "Trace", "All")]
    [string[]]$DebugType = @()
)

# CommentAnalyzer.ps1 - Unity C# 项目注释分析器
# 版本: 3.0
# 最后更新: 2025-07-08

# ============================================
# 环境清理 - 防止PowerShell会话缓存导致的重复输出问题
# ============================================

# 清理所有相关函数定义
$functionsToClean = @(
    "Write-DebugInfo",
    "Write-UserInfo", 
    "Get-LatestMsBuildPath",
    "New-TemporaryCsproj",
    "Initialize-Globals",
    "Initialize-Environment",
    "Invoke-RoslynatorAnalysis",
    "Convert-ToRoslynatorVerbosity", 
    "Parse-RoslynatorLog",
    "Invoke-Analyzer",
    "Invoke-CommentAnalyzer",
    "Invoke-MultiEnvironmentAnalysis",
    "Merge-MultiEnvironmentResults"
)

foreach ($funcName in $functionsToClean) {
    if (Get-Command $funcName -ErrorAction SilentlyContinue) {
        Remove-Item "Function:$funcName" -ErrorAction SilentlyContinue
        Write-Verbose "Cleaned function: $funcName"
    }
}

# 清理所有相关全局变量
$variablesToClean = @(
    "JobID",
    "Paths", 
    "DebugTypes",
    "MsbuildPath"
)

foreach ($varName in $variablesToClean) {
    Remove-Variable -Name $varName -Scope Global -ErrorAction SilentlyContinue
    Write-Verbose "Cleaned global variable: $varName"
}

# 强制垃圾回收，清理会话状态
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Verbose "Environment cleanup completed - session state reset"

# ============================================

# --- DEBUG CONTROL GLOBALS ---
$Global:DebugTypes = @{
    Analyzer = ($DebugType -contains "Analyzer" -or $DebugType -contains "All")
    Fixer = ($DebugType -contains "Fixer" -or $DebugType -contains "All")
    Workflow = ($DebugType -contains "Workflow" -or $DebugType -contains "All")
    Parser = ($DebugType -contains "Parser" -or $DebugType -contains "All")
    CodeGen = ($DebugType -contains "CodeGen" -or $DebugType -contains "All")
    FileOp = ($DebugType -contains "FileOp" -or $DebugType -contains "All")
    NodeMatch = ($DebugType -contains "NodeMatch" -or $DebugType -contains "All")
    Environment = ($DebugType -contains "Environment" -or $DebugType -contains "All")
    Trace = ($DebugType -contains "Trace" -or $DebugType -contains "All")
}

function Write-DebugInfo {
    <#
    .SYNOPSIS
    输出带有类型标注的debug信息
    
    .DESCRIPTION
    只有在对应的debug类型被启用时才输出信息，用于问题排查
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Analyzer", "Fixer", "Workflow", "Parser", "CodeGen", "FileOp", "NodeMatch", "Environment", "Trace")]
        [string]$DebugType,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Information", "Warning", "Error")]
        [string]$Level = "Information"
    )
    
    if ($Global:DebugTypes[$DebugType]) {
        $color = switch ($Level) {
            "Information" { "Cyan" }
            "Warning" { "Yellow" }
            "Error" { "Red" }
            default { "Cyan" }
        }
        
        $prefix = "[DEBUG-$DebugType]"
        # 只使用 Write-Host 输出，避免重复输出问题
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

function Write-UserInfo {
    <#
    .SYNOPSIS
    输出面向用户的信息（非debug）
    
    .DESCRIPTION
    正常操作信息，总是显示，包括成功/失败状态和警告
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Information", "Warning", "Error", "Success")]
        [string]$Level = "Information"
    )
    
    # 只在启用Trace debug类型时输出调用栈调试信息
    if ($Global:DebugTypes.Trace) {
        $caller = (Get-PSCallStack)[1]
        $debugPrefix = "[TRACE-${Level}] From: $($caller.FunctionName):$($caller.ScriptLineNumber)"
        Write-Host "$debugPrefix" -ForegroundColor Cyan
    }
    
    $color = switch ($Level) {
        "Information" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Success" { "Green" }
        default { "White" }
    }
    
    $prefix = switch ($Level) {
        "Information" { "[INFO]" }
        "Warning" { "[WARNING]" }
        "Error" { "[ERROR]" }
        "Success" { "[SUCCESS]" }
        default { "[INFO]" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# --- HELPER FUNCTIONS ---

function Get-LatestMsBuildPath {
    $vsWhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWhere) {
        $vsInstallations = & $vsWhere -products * -requires Microsoft.Component.MSBuild -property installationPath
        $preferredInstance = $vsInstallations | Where-Object { $_ -like '*BuildTools*' } | Select-Object -First 1
        if (!$preferredInstance) {
            $preferredInstance = $vsInstallations | Select-Object -First 1
        }
        
        if ($preferredInstance) {
            $msbuildPath = Join-Path $preferredInstance "MSBuild\Current\Bin"
            if (Test-Path (Join-Path $msbuildPath "MSBuild.exe")) {
                return $msbuildPath
            }
        }
    }
    throw "Could not find MSBuild.exe. Please ensure Visual Studio or Build Tools are installed."
}

function New-TemporaryCsproj {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceCsproj,
        
        [Parameter(Mandatory = $true)]
        [string[]]$TargetFiles,
        
        [Parameter(Mandatory = $true)]
        [string]$JobID,
        
        [Parameter(Mandatory = $false)]
        [string]$DefineConstants = ""
    )

    $tempDir = $Global:Paths.Temp
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir | Out-Null
    }
    $tempProjectName = "TempProject_{0}.csproj" -f (Get-Date -Format "yyyyMMddHHmmss")
    $tempProjectPath = Join-Path $tempDir $tempProjectName

    Write-DebugInfo "Creating temporary project at: $tempProjectPath" -DebugType "Workflow"

    # Load original project as XML
    [xml]$originalProjectXml = Get-Content -Path $SourceCsproj

    # Create new project XML
    $newProjectXml = [xml]"<Project Sdk=`"Microsoft.NET.Sdk`"></Project>"

    # Copy all PropertyGroup nodes from original to new
    $originalProjectXml.Project.PropertyGroup | ForEach-Object {
        $newNode = $newProjectXml.ImportNode($_, $true)
        $newProjectXml.Project.AppendChild($newNode) | Out-Null
    }

    # Copy all Reference ItemGroup nodes from original to new
    $originalProjectXml.Project.ItemGroup | Where-Object { $_.Reference } | ForEach-Object {
        $newNode = $newProjectXml.ImportNode($_, $true)
        $newProjectXml.Project.AppendChild($newNode) | Out-Null
    }

    # Add Compile item group for specified files
    $itemGroup = $newProjectXml.CreateElement("ItemGroup")
    $TargetFiles | ForEach-Object {
        $compileNode = $newProjectXml.CreateElement("Compile")
        # Convert to absolute path to avoid path resolution issues
        $filePath = if ([System.IO.Path]::IsPathRooted($_)) { 
            $_ 
        } else { 
            [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $_))
        }
        Write-DebugInfo "Adding file to temp project: $filePath" -DebugType "FileOp"
        $compileNode.SetAttribute("Include", $filePath)
        $itemGroup.AppendChild($compileNode) | Out-Null
    }
    $newProjectXml.Project.AppendChild($itemGroup) | Out-Null

    # If provided, add DefineConstants to the project file
    if (-not [string]::IsNullOrWhiteSpace($DefineConstants)) {
        Write-Verbose "Adding DefineConstants: $DefineConstants"
        
        # Find or create the PropertyGroup and add DefineConstants
        $propertyGroup = $newProjectXml.Project.PropertyGroup | Select-Object -First 1
        if ($propertyGroup) {
            $defineElement = $newProjectXml.CreateElement("DefineConstants")
            $defineElement.InnerText = $DefineConstants
            $propertyGroup.AppendChild($defineElement) | Out-Null
        }
    }

    # Save the new project file
    $newProjectXml.Save($tempProjectPath)

    return $tempProjectPath
}

function Initialize-Globals {
    Write-DebugInfo "Initialize-Globals called from: $((Get-PSCallStack)[1].FunctionName):$((Get-PSCallStack)[1].ScriptLineNumber)" -DebugType "Workflow"
    
    $scriptDir = $PSScriptRoot
    $logDir = Join-Path $scriptDir "Logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }

    $Global:JobID = "{0:yyyyMMdd-HHmmss}-{1}" -f (Get-Date), $PID
    Write-DebugInfo "Generated JobID: $Global:JobID" -DebugType "Workflow"

    # Handle custom log file paths with JobID prefix
    $detectLogPath = if ($LogFile) {
        $customDir = Split-Path -Path $LogFile -Parent
        $customName = Split-Path -Path $LogFile -Leaf
        if ($customDir) {
            if (-not (Test-Path $customDir)) {
                New-Item -ItemType Directory -Path $customDir -Force | Out-Null
            }
            Join-Path $customDir "$($Global:JobID)_$customName"
        } else {
            Join-Path $logDir "$($Global:JobID)_$customName"
        }
    } else {
        Join-Path $logDir "$($Global:JobID)_CommentAnalazy_detect.log"
    }

    $fixLogPath = if ($LogFile) {
        $detectLogPath -replace "\.log$", "_fix.log"
    } else {
        Join-Path $logDir "$($Global:JobID)_CommentAnalazy_fix.log"
    }

    $Global:Paths = @{
        Root = $scriptDir
        Temp = Join-Path $scriptDir "Temp"
        Logs = @{
            Detect = $detectLogPath
            Fix = $fixLogPath
        }
        Tools = @{
            Roslynator = Join-Path $scriptDir ".nuget/packages/roslynator.commandline/0.10.1/tools/net48/Roslynator.exe"
            Analyzer = Join-Path $scriptDir "ProjectCommentAnalyzer/ProjectCommentAnalyzer/bin/Debug/netstandard2.0/ProjectCommentAnalyzer.dll"
        }
    }

    if ($MsbuildPath -and (Test-Path (Join-Path $MsbuildPath "MSBuild.exe"))) {
        $global:MsbuildPath = $MsbuildPath
    } else {
        $global:MsbuildPath = Get-LatestMsBuildPath
    }
    
    Write-DebugInfo "Initialize-Globals completed" -DebugType "Workflow"
}

function Initialize-Environment {
    Write-DebugInfo "Initializing environment and checking dependencies..." -DebugType "Workflow"
    Write-DebugInfo "Found MSBuild at: $Global:MsbuildPath" -DebugType "Workflow"

    # NuGet and Roslynator CLI verification and restoration
    $roslynatorPath = $Global:Paths.Tools.Roslynator
    $nuGetDir = Join-Path $Global:Paths.Root ".nuget"
    $nugetPath = Join-Path $nuGetDir "nuget.exe"
    
    if (-not (Test-Path $nuGetDir)) {
        New-Item -ItemType Directory -Path $nuGetDir | Out-Null
    }

    if (-not (Test-Path $roslynatorPath) -or $ForceRestore) {
        if ($ForceRestore) {
            Write-UserInfo "Force restore requested. Restoring NuGet packages..." -Level "Information"
        } else {
            Write-UserInfo "Roslynator CLI not found. Attempting to restore NuGet packages..." -Level "Information"
        }

        if (-not (Test-Path $nugetPath)) {
            Write-DebugInfo "nuget.exe not found. Downloading it..." -DebugType "Workflow"
            $nugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
            try {
                Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetPath
                Write-DebugInfo "nuget.exe downloaded successfully." -DebugType "Workflow"
            } catch {
                throw "Failed to download nuget.exe. Please download it manually from $nugetUrl and place it at $nugetPath"
            }
        }

        $packagesConfig = Join-Path $Global:Paths.Root "packages.config"
        if (-not (Test-Path $packagesConfig)) {
            throw "packages.config not found at $packagesConfig"
        }
        
        Write-DebugInfo "Restoring NuGet packages from packages.config..." -DebugType "Workflow"
        $restoreArgs = "restore `"$packagesConfig`" -PackagesDirectory `"$($nuGetDir)/packages`""
        $process = Start-Process -FilePath $nugetPath -ArgumentList $restoreArgs -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "NuGet package restore failed with exit code $($process.ExitCode)."
        }
        Write-UserInfo "NuGet packages restored successfully." -Level "Success"

        if (-not (Test-Path $roslynatorPath)) {
            throw "Roslynator.exe still not found after NuGet restore. Please check path: $roslynatorPath"
        }
    }

    if (-not (Test-Path $Global:Paths.Tools.Analyzer)) {
        throw "Analyzer DLL not found at $($Global:Paths.Tools.Analyzer). Please build the ProjectCommentAnalyzer project first."
    }
    Write-DebugInfo "Dependencies are satisfied." -DebugType "Workflow"
}

function Invoke-RoslynatorAnalysis {
    <#
    .SYNOPSIS
    执行单个环境的Roslynator分析
    
    .DESCRIPTION
    为多环境分析提供的简化接口，返回结构化的分析结果
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        
        [Parameter(Mandatory = $false)]
        [string]$Environment = "Default",
        
        [Parameter(Mandatory = $false)]
        [string]$ConsoleLogLevel = "minimal",
        
        [Parameter(Mandatory = $false)]
        [string]$FileLogLevel = "normal"
    )
    
    try {
        # 确保日志目录存在
        $logDir = Split-Path -Path $LogFile -Parent
        if (!(Test-Path $logDir)) { 
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null 
        }
        if (Test-Path $LogFile) { 
            Clear-Content $LogFile 
        }

        Write-DebugInfo "[$Environment] Executing Roslynator analysis: $ProjectPath" -DebugType "Analyzer"
        $workingDir = Split-Path -Path $ProjectPath -Parent

        # 构建Roslynator参数
        $arguments = @(
            "analyze",
            "`"$ProjectPath`"",
            "-a",
            "`"$($Global:Paths.Tools.Analyzer)`"",
            "--file-log",
            "`"$LogFile`"",
            "--file-log-verbosity",
            $FileLogVerbosity,
            "--verbosity",
            $Verbosity,
            "--msbuild-path",
            "`"$($Global:MsbuildPath)`""
        )

        $process = Start-Process -FilePath $Global:Paths.Tools.Roslynator -ArgumentList $arguments -NoNewWindow -PassThru -Wait -WorkingDirectory $workingDir
        
        # 等待日志文件生成
        $timeoutSeconds = 10
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-Path $LogFile) -and $stopwatch.Elapsed.TotalSeconds -lt $timeoutSeconds) {
            Start-Sleep -Milliseconds 100
        }
        $stopwatch.Stop()

        if (Test-Path $LogFile) {
            # 解析日志文件，提取问题信息
            $issues = Parse-RoslynatorLog -LogFile $LogFile
            
            return @{
                Success = $true
                IssueCount = $issues.Count
                Issues = $issues
                LogFile = $LogFile
                Environment = $Environment
            }
        } else {
            return @{
                Success = $false
                Error = "日志文件未生成: $LogFile"
                IssueCount = 0
                Issues = @()
            }
        }
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            IssueCount = 0
            Issues = @()
        }
    }
}

function Convert-ToRoslynatorVerbosity {
    <#
    .SYNOPSIS
    转换标准日志级别到 Roslynator CLI 格式
    
    .DESCRIPTION
    Roslynator CLI 接受的日志级别格式：
    - quiet (q)
    - minimal (m) 
    - normal (n)
    - detailed (d)
    - diagnostic (diag)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Verbosity
    )
    
    switch ($Verbosity.ToLower()) {
        "quiet" { return "quiet" }
        "minimal" { return "minimal" }
        "normal" { return "normal" }
        "detailed" { return "detailed" }
        "diagnostic" { return "diagnostic" }
        default { 
            Write-DebugInfo "Unknown verbosity level: $Verbosity, using 'normal'" -DebugType "Workflow"
            return "normal" 
        }
    }
}

function Parse-RoslynatorLog {
    <#
    .SYNOPSIS
    解析Roslynator日志文件，提取PROJECT_*开头的自定义诊断问题信息
    
    .DESCRIPTION
    此函数专门用于解析和统计PROJECT_开头的自定义诊断规则，过滤掉内置的CS诊断。
    确保只统计项目特定的注释规范检查结果。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    $issues = @()
    
    if (Test-Path $LogFile) {
        $content = Get-Content $LogFile -Encoding UTF8
        
        foreach ($line in $content) {
            # 解析诊断行格式，支持两种格式：
            # 格式1: D:\path\to\file.cs(123,45): warning PROJECT_MEMBER_NO_COMMENT_BLOCK: Missing comment block
            # 格式2:   D:\path\to\file.cs(123,45): warning PROJECT_MEMBER_NO_COMMENT_BLOCK: Missing comment block
            
            # 更灵活的匹配，支持行首可能有空格
            if ($line -match '^\s*([A-Za-z]:.+\.cs)\((\d+),\d+\):\s+(warning|error|info)\s+(PROJECT_[^:]+):\s*(.*)$') {
                $issues += @{
                    FilePath = $matches[1].Trim()
                    Line = [int]$matches[2]
                    Rule = $matches[4].Trim()
                    Message = $matches[5].Trim()
                }
            }
        }
    }
    
    Write-DebugInfo "Parse-RoslynatorLog: Parsed $($issues.Count) PROJECT_* diagnostics from $LogFile" -DebugType "Parser"
    return $issues
}

function Invoke-Analyzer {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("analyze")]
        [string]$AnalyzeMode,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetProject,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )
    
    Write-DebugInfo "Invoke-Analyzer called from: $((Get-PSCallStack)[1].FunctionName):$((Get-PSCallStack)[1].ScriptLineNumber)" -DebugType "Analyzer"
    Write-DebugInfo "Parameters: Mode=$AnalyzeMode, Project=$TargetProject" -DebugType "Analyzer"

    $logDir = Split-Path -Path $OutputFile -Parent
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    if (Test-Path $OutputFile) { Clear-Content $OutputFile }

    # 转换日志级别到 Roslynator 格式
    $roslynatorVerbosity = Convert-ToRoslynatorVerbosity $Verbosity
    $roslynatorFileLogVerbosity = Convert-ToRoslynatorVerbosity $FileLogVerbosity
    
    Write-DebugInfo "Running Roslynator ($AnalyzeMode)..." -DebugType "Analyzer"
    Write-DebugInfo "Verbosity: $Verbosity -> $roslynatorVerbosity, FileLogVerbosity: $FileLogVerbosity -> $roslynatorFileLogVerbosity" -DebugType "Analyzer"
    $workingDir = Split-Path -Path $TargetProject -Parent

    # Manually construct the argument array for clarity and correctness
    $arguments = @(
        $AnalyzeMode,
        "`"$TargetProject`"",
        "-a",
        "`"$($Global:Paths.Tools.Analyzer)`"",
        "--file-log",
        "`"$OutputFile`"",
        "--file-log-verbosity",
        $roslynatorFileLogVerbosity,
        "--verbosity",
        $roslynatorVerbosity,
        "--msbuild-path",
        "`"$($Global:MsbuildPath)`""
    )
    
    Write-DebugInfo "Roslynator arguments: $($arguments -join ' ')" -DebugType "Analyzer"

    $process = Start-Process -FilePath $Global:Paths.Tools.Roslynator -ArgumentList $arguments -NoNewWindow -PassThru -Wait -WorkingDirectory $workingDir
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 1) {
        Write-Warning "Roslynator process exited with code $($process.ExitCode)."
    }

    # Wait for the log file to be created to avoid race conditions
    $timeoutSeconds = 10
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path $OutputFile) -and $stopwatch.Elapsed.TotalSeconds -lt $timeoutSeconds) {
        Start-Sleep -Milliseconds 100
    }
    $stopwatch.Stop()

    if (Test-Path $OutputFile) {
        Write-DebugInfo "Detection complete. See log: $OutputFile" -DebugType "Analyzer"
    } else {
        Write-UserInfo "Analyzer did not produce a log file at $OutputFile" -Level "Warning"
    }

    Write-DebugInfo "Invoke-Analyzer completed" -DebugType "Analyzer"
}

# Main script logic wrapped in a function
function Invoke-CommentAnalyzer {
    Write-DebugInfo "Script execution started - PID: $PID, Time: $(Get-Date)" -DebugType "Workflow"
    Write-DebugInfo "Parameters: Mode=$Mode, SolutionPath=$SolutionPath" -DebugType "Workflow"
    
    # 参数验证增强 - 确保输入的有效性和安全性
    if (-not (Test-Path $SolutionPath)) {
        Write-Error "Solution/project path does not exist: $SolutionPath"
        exit 1
    }
    
    # 验证文件扩展名
    $validExtensions = @('.sln', '.csproj', '.cs')
    $fileExtension = [System.IO.Path]::GetExtension($SolutionPath).ToLower()
    if ($fileExtension -notin $validExtensions) {
        Write-Error "Unsupported file type: ${fileExtension}. Supported types: $($validExtensions -join ', ')"
        exit 1
    }
    
    # 验证ScriptPaths（如果提供）
    if ($ScriptPaths -and $ScriptPaths.Count -gt 0) {
        foreach ($scriptPath in $ScriptPaths) {
            if (-not (Test-Path $scriptPath)) {
                Write-Error "Script file does not exist: $scriptPath"
                exit 1
            }
            $scriptExtension = [System.IO.Path]::GetExtension($scriptPath).ToLower()
            if ($scriptExtension -ne '.cs') {
                Write-Error "Script file must be a C# file (.cs): $scriptPath"
                exit 1
            }
        }
        Write-DebugInfo "Validated $($ScriptPaths.Count) script file(s)" -DebugType "Workflow"
    }
    
    # 验证MsbuildPath（如果提供）
    if ($MsbuildPath -and -not (Test-Path (Join-Path $MsbuildPath "MSBuild.exe"))) {
        Write-Error "Invalid MSBuild path: $MsbuildPath"
        exit 1
    }
    
    $tempProjectPath = $null
    try {
        Initialize-Globals
        Initialize-Environment
        
        # 检查 SolutionPath 是 .cs 文件还是项目文件
        $solutionExtension = [System.IO.Path]::GetExtension($SolutionPath).ToLower()
        
        if ($solutionExtension -eq ".cs") {
            # 如果传递的是 .cs 文件，将其转换为单文件分析
            Write-DebugInfo "Single .cs file provided. Creating a temporary project for analysis..." -DebugType "Workflow"
            
            # 寻找一个基准项目文件来作为模板
            $baseProjectPath = $null
            $searchDir = Split-Path -Path $SolutionPath -Parent
            
            # 向上搜索项目文件
            while ($searchDir -and -not $baseProjectPath) {
                $csprojFiles = Get-ChildItem -Path $searchDir -Filter "*.csproj" -ErrorAction SilentlyContinue
                if ($csprojFiles.Count -gt 0) {
                    $baseProjectPath = $csprojFiles[0].FullName
                    break
                }
                $searchDir = Split-Path -Path $searchDir -Parent
            }
            
            # 如果找不到基准项目，创建一个简单的默认项目
            if (-not $baseProjectPath) {
                Write-DebugInfo "No base project found. Creating a minimal default project..." -DebugType "Workflow"
                $tempDir = $Global:Paths.Temp
                if (-not (Test-Path $tempDir)) {
                    New-Item -ItemType Directory -Path $tempDir | Out-Null
                }
                $defaultProjectPath = Join-Path $tempDir "DefaultBase.csproj"
                $defaultProjectContent = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
</Project>
'@
                $defaultProjectContent | Out-File -FilePath $defaultProjectPath -Encoding UTF8
                $baseProjectPath = $defaultProjectPath
            }
            
            Write-DebugInfo "Using base project: $baseProjectPath" -DebugType "Workflow"
            $tempProjectPath = New-TemporaryCsproj -SourceCsproj $baseProjectPath -TargetFiles @($SolutionPath) -JobID $Global:JobID
            $targetProject = $tempProjectPath
            $ScriptPaths = @($SolutionPath)  # 设置 ScriptPaths 以便后续逻辑正确处理
        }
        elseif ($ScriptPaths -and $ScriptPaths.Count -gt 0) {
            Write-DebugInfo "Specific scripts provided with project. Creating a temporary project..." -DebugType "Workflow"
            $tempProjectPath = New-TemporaryCsproj -SourceCsproj $SolutionPath -TargetFiles $ScriptPaths -JobID $Global:JobID
            $targetProject = $tempProjectPath
        } 
        else {
            Write-DebugInfo "Project/solution file provided. Analyzing the whole project/solution." -DebugType "Workflow"
            $targetProject = $SolutionPath
        }

        if ($Mode -eq "detect") {
            Write-UserInfo "--- Running in DETECT mode ---" -Level "Information"
            
            if ($MultiEnvironment -and $ScriptPaths -and $ScriptPaths.Count -gt 0) {
                Write-DebugInfo "Multi-environment analysis mode enabled - avoiding conditional compilation issues" -DebugType "Environment"
                $result = Invoke-MultiEnvironmentAnalysis -CsprojPath $SolutionPath -ScriptPaths $ScriptPaths -JobID $Global:JobID -LogDir (Split-Path $Global:Paths.Logs.Detect -Parent)
                
                if ($result.Success) {
                    Write-DebugInfo "Multi-environment analysis completed, merged log: $($result.MergedLogFile)" -DebugType "Environment"
                    Write-UserInfo "Multi-environment analysis completed. $($result.TotalIssues) PROJECT_* custom diagnostics found." -Level "Information"
                    
                    # 根据问题数量设置退出码
                    if ($result.TotalIssues -eq 0) {
                        Write-UserInfo "✅ No custom diagnostic issues found - code analysis passed!" -Level "Success"
                        exit 0
                    } else {
                        Write-UserInfo "⚠️  Found $($result.TotalIssues) PROJECT_* custom diagnostic issues across environments" -Level "Warning"
                        exit 1
                    }
                } else {
                    Write-UserInfo "Issues encountered during multi-environment analysis" -Level "Warning"
                    Write-UserInfo "Analysis completed with errors." -Level "Error"
                    exit 1
                }
            } else {
                Invoke-Analyzer -AnalyzeMode "analyze" -TargetProject $targetProject -OutputFile $Global:Paths.Logs.Detect
                
                # 解析日志文件并输出诊断统计信息
                $diagnostics = Parse-RoslynatorLog -LogFile $Global:Paths.Logs.Detect
                $diagnosticsCount = $diagnostics.Count
                
                Write-UserInfo "Analysis completed. $diagnosticsCount PROJECT_* custom diagnostics found." -Level "Information"
                if ($diagnosticsCount -eq 0) {
                    Write-UserInfo "✅ No custom diagnostic issues found - code analysis passed!" -Level "Success"
                    exit 0
                } else {
                    Write-UserInfo "⚠️  Found $diagnosticsCount PROJECT_* custom diagnostic issues:" -Level "Warning"
                    $diagnostics | Group-Object Rule | ForEach-Object {
                        Write-UserInfo "  - $($_.Name): $($_.Count) issues" -Level "Warning"
                    }
                    exit 1
                }
            }
        } 
        elseif ($Mode -eq "fix") {
            Write-UserInfo "--- Running in FIX mode ---" -Level "Information"
            $xmlDocToolExe = Join-Path $PSScriptRoot "XmlDocRoslynTool/bin/Debug/net8.0/XmlDocRoslynTool.exe"
            $projectPath = $targetProject
            $analyzerPath = $Global:Paths.Tools.Analyzer
            $msbuildPath = $global:MsbuildPath
            $xmlLogPath = $Global:Paths.Logs.Fix -replace ".log$", ".xml"

            if (-not (Test-Path $xmlDocToolExe)) {
                Write-Error "XmlDocRoslynTool.exe not found at $xmlDocToolExe. Please build the project first."
                return
            }

            $maxRounds = 10
            $round = 0
            $fixConverged = $false
            $lastDiagnosticsCount = -1  # 🔧 用于检测无限循环的变量
            $lastFileHashes = @{}
            $scriptFiles = @()
            if ($tempProjectPath) {
                $scriptFiles = $ScriptPaths | ForEach-Object {
                    if ([System.IO.Path]::IsPathRooted($_)) { $_ } else { [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $_)) }
                }
            } else {
                # 若分析整个项目，需遍历项目下所有.cs文件
                $scriptFiles = Get-ChildItem -Path (Split-Path $projectPath -Parent) -Recurse -Include *.cs | Select-Object -ExpandProperty FullName
            }
            # 初始化hash - 性能优化：并行处理多个文件
            Write-DebugInfo "Calculating initial file hashes for $($scriptFiles.Count) files..." -DebugType "Fixer"
            $lastFileHashes = @{}
            if ($scriptFiles.Count -gt 10) {
                # 对于大量文件，使用并行处理
                $jobs = @()
                foreach ($file in $scriptFiles) {
                    if (Test-Path $file) {
                        $jobs += Start-Job -ScriptBlock {
                            param($FilePath)
                            try {
                                $hash = (Get-FileHash $FilePath -Algorithm SHA256).Hash
                                return @{ Path = $FilePath; Hash = $hash; Success = $true }
                            } catch {
                                return @{ Path = $FilePath; Hash = $null; Success = $false; Error = $_.Exception.Message }
                            }
                        } -ArgumentList $file
                    }
                }
                
                # 等待所有job完成并收集结果
                $jobs | ForEach-Object {
                    $result = $_ | Wait-Job | Receive-Job
                    if ($result.Success) {
                        $lastFileHashes[$result.Path] = $result.Hash
                    } else {
                        Write-DebugInfo "Failed to hash file $($result.Path): $($result.Error)" -DebugType "Fixer" -Level "Warning"
                    }
                    Remove-Job $_
                }
            } else {
                # 对于少量文件，使用顺序处理
                foreach ($f in $scriptFiles) { 
                    if (Test-Path $f) { 
                        try {
                            $lastFileHashes[$f] = (Get-FileHash $f -Algorithm SHA256).Hash 
                        } catch {
                            Write-DebugInfo "Failed to hash file ${f}: $($_.Exception.Message)" -DebugType "Fixer" -Level "Warning"
                        }
                    } 
                }
            }
            Write-DebugInfo "File hash calculation completed for $($lastFileHashes.Count) files" -DebugType "Fixer"

            # 运行初始分析以获取修复前的诊断数量
            Write-DebugInfo "Starting initial analysis..." -DebugType "Fixer"
            $initialDetectLog = $Global:Paths.Logs.Detect -replace ".log$", "_initial.log"
            Invoke-Analyzer -AnalyzeMode "analyze" -TargetProject $projectPath -OutputFile $initialDetectLog
            $initialDiagnostics = Parse-RoslynatorLog -LogFile $initialDetectLog
            $initialDiagnosticsCount = $initialDiagnostics.Count
            Write-DebugInfo "Initial analysis completed. Count: $initialDiagnosticsCount" -DebugType "Fixer"
            Write-UserInfo "Initial analysis: $initialDiagnosticsCount PROJECT_* custom diagnostics found before fixing." -Level "Information"

            # 如果初始分析显示0个诊断，直接跳过修复循环
            if ($initialDiagnosticsCount -eq 0) {
                Write-UserInfo "[PASS] All diagnostics fixed" -Level "Success"
                
                # 生成简化的修复报告
                $reportData = @{
                    JobID = $Global:JobID
                    Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    Mode = "fix"
                    Summary = @{
                        IssuesBefore = 0
                        IssuesAfter = 0
                        RoundsExecuted = 0
                        FixConverged = $true
                        FilesProcessed = $scriptFiles.Count
                    }
                    Files = @($scriptFiles | ForEach-Object { 
                        @{
                            Path = $_
                            Modified = $false
                        }
                    })
                    FinalDiagnostics = @()
                }

                $reportFile = $Global:Paths.Logs.Fix -replace ".log$", "_report.json"
                $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
                Write-DebugInfo "Fix report generated: $reportFile" -DebugType "Fixer"
                Write-UserInfo "Fix completed. Issues before: 0, Issues after: 0" -Level "Information"
                Write-UserInfo "✅ All issues fixed successfully!" -Level "Success"
                exit 0
            }

            # 初始化第一轮的分析结果（复用初始分析结果）
            $diagnostics = $initialDiagnostics
            $diagnosticsCount = $initialDiagnosticsCount
            
            do {
                $round++
                Write-DebugInfo "=== Fix convergence round: $round ===" -DebugType "Fixer"
                $detectLog = $Global:Paths.Logs.Detect -replace ".log$", "_fix_round$round.log"
                $fixLog = $Global:Paths.Logs.Fix -replace ".log$", "_fix_round$round.log"
                
                # 1. 第一轮复用初始分析结果，后续轮次重新分析
                if ($round -gt 1) {
                    # 运行分析器
                    Invoke-Analyzer -AnalyzeMode "analyze" -TargetProject $projectPath -OutputFile $detectLog
                    $diagnostics = Parse-RoslynatorLog -LogFile $detectLog
                    $diagnosticsCount = $diagnostics.Count
                } else {
                    # 第一轮复用初始分析的日志文件
                    Copy-Item -Path $initialDetectLog -Destination $detectLog -Force
                    Write-DebugInfo "[Round $round] Reusing initial analysis results. Count: $diagnosticsCount" -DebugType "Fixer"
                }
                # 2. 记录修复前hash - 性能优化版本
                Write-DebugInfo "Recording file hashes before fix round $round..." -DebugType "Fixer"
                $fileHashesBefore = @{}
                foreach ($f in $scriptFiles) { 
                    if (Test-Path $f) { 
                        try {
                            $fileHashesBefore[$f] = (Get-FileHash $f -Algorithm SHA256).Hash 
                        } catch {
                            Write-DebugInfo "Failed to hash file ${f} before fix: $($_.Exception.Message)" -DebugType "Fixer" -Level "Warning"
                        }
                    } 
                }
                # 3. 运行修复器
                if ($tempProjectPath) {
                    $filesArg = $scriptFiles -join ";"
                    $args = @(
                        "--projectPath=$projectPath",
                        "--analyzerPath=$analyzerPath",
                        "--files=$filesArg",
                        "--msbuildPath=`"$msbuildPath`"",
                        "--xmlLogPath=$xmlLogPath"
                    )
                } else {
                    $args = @(
                        "--projectPath=$projectPath",
                        "--analyzerPath=$analyzerPath",
                        "--msbuildPath=`"$msbuildPath`"",
                        "--xmlLogPath=$xmlLogPath"
                    )
                }
                
                # 传递日志控制参数到修复器
                $args += "--verbosity=`"$Verbosity`""
                $args += "--file-log-verbosity=`"$FileLogVerbosity`""
                
                # 传递debug参数到修复器
                if ($DebugType -and $DebugType.Count -gt 0) {
                    $debugTypesStr = $DebugType -join ","
                    $args += "--debugType=`"$debugTypesStr`""
                }
                Write-DebugInfo "[Round $round] Invoking XmlDocRoslynTool.exe with arguments: $($args -join ' ')" -DebugType "Fixer"
                $process = Start-Process -FilePath $xmlDocToolExe -ArgumentList $args -NoNewWindow -Wait -PassThru
                if ($process.ExitCode -ne 0) {
                    Write-Error "XmlDocRoslynTool.exe exited with code $($process.ExitCode)"
                    break
                }
                # 4. 再次分析
                Invoke-Analyzer -AnalyzeMode "analyze" -TargetProject $projectPath -OutputFile $detectLog
                $diagnostics = Parse-RoslynatorLog -LogFile $detectLog
                $diagnosticsCount = $diagnostics.Count
                # 5. 记录修复后hash
                $fileHashesAfter = @{}
                foreach ($f in $scriptFiles) { if (Test-Path $f) { $fileHashesAfter[$f] = (Get-FileHash $f).Hash } }
                # 6. 判断收敛
                $allUnchanged = $true
                foreach ($f in $scriptFiles) {
                    if ($fileHashesBefore[$f] -ne $fileHashesAfter[$f]) { $allUnchanged = $false; break }
                }
                
                # 🔧 增强收敛检测：添加诊断数量稳定性检查
                $diagnosticsStable = $false
                if ($round -gt 1 -and $diagnosticsCount -eq $lastDiagnosticsCount) {
                    $diagnosticsStable = $true
                    Write-DebugInfo "[Round $round] Diagnostics count stable at $diagnosticsCount - possible infinite loop detected" -DebugType "Fixer" -Level "Warning"
                }
                
                if ($diagnosticsCount -eq 0 -or $allUnchanged -or $diagnosticsStable) {
                    $fixConverged = $true
                    if ($diagnosticsCount -eq 0) {
                        Write-UserInfo "[PASS] All diagnostics fixed" -Level "Success"
                    } elseif ($allUnchanged -and $diagnosticsCount -gt 0) {
                        Write-UserInfo "[WARNING] Fix converged but some issues remain. Manual intervention required. Issues: $diagnosticsCount" -Level "Warning"
                    } elseif ($diagnosticsStable) {
                        Write-UserInfo "[WARNING] Fix stopped due to stable diagnostics count - possible infinite loop. Issues: $diagnosticsCount" -Level "Warning"
                    }
                    Write-DebugInfo "[Round $round] Fix converged. Diagnostics: $diagnosticsCount, Content changed: $(! $allUnchanged), Stable: $diagnosticsStable" -DebugType "Fixer"
                }
                
                # 记录上一轮的诊断数量
                $lastDiagnosticsCount = $diagnosticsCount
            } while (-not $fixConverged -and $round -lt $maxRounds)

            # 生成JSON修复报告
            $reportData = @{
                JobID = $Global:JobID
                Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                Mode = "fix"
                Summary = @{
                    IssuesBefore = $initialDiagnosticsCount
                    IssuesAfter = $diagnosticsCount
                    RoundsExecuted = $round
                    FixConverged = $fixConverged
                    FilesProcessed = $scriptFiles.Count
                }
                Files = @($scriptFiles | ForEach-Object { 
                    @{
                        Path = $_
                        Modified = ($fileHashesBefore[$_] -ne $fileHashesAfter[$_])
                    }
                })
                FinalDiagnostics = @($diagnostics | ForEach-Object {
                    @{
                        FilePath = $_.FilePath
                        Line = $_.Line
                        Rule = $_.Rule
                        Message = $_.Message
                    }
                })
            }

            $reportFile = $Global:Paths.Logs.Fix -replace ".log$", "_report.json"
            $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
            Write-DebugInfo "Fix report generated: $reportFile" -DebugType "Fixer"
            Write-UserInfo "Fix completed. PROJECT_* custom diagnostics before: $initialDiagnosticsCount, after: $diagnosticsCount" -Level "Information"
            
            # 根据修复结果设置退出码
            if ($diagnosticsCount -eq 0) {
                Write-UserInfo "✅ All PROJECT_* custom diagnostic issues fixed successfully!" -Level "Success"
                exit 0
            } else {
                Write-UserInfo "⚠️  $diagnosticsCount PROJECT_* custom diagnostic issues remain after fix" -Level "Warning"
                exit 1
            }
        }

        Write-DebugInfo "Script finished successfully." -DebugType "Workflow"
        exit 0

    } catch {
        Write-Error "An error occurred: $_"
        exit 1
    } finally {
        # Clean up temp project if it was created
        if ($tempProjectPath -and -not $ExportTempProject) {
            Write-DebugInfo "Cleaning up temporary project: $tempProjectPath" -DebugType "Workflow"
            Remove-Item -Path $tempProjectPath -Force
        }
    }
}

function Invoke-MultiEnvironmentAnalysis {
    <#
    .SYNOPSIS
    在多个编译环境下执行分析，避免条件编译影响
    
    .DESCRIPTION
    此函数解决条件编译环境下注释关联错误的问题。通过在不同的宏定义环境下
    多次运行分析，确保所有代码路径都被正确检测。
    
    .PARAMETER CsprojPath
    源项目文件路径
    
    .PARAMETER ScriptPaths  
    要分析的脚本文件路径
    
    .PARAMETER JobID
    作业唯一标识符
    
    .PARAMETER LogDir
    日志输出目录
    
    .EXAMPLE
    Invoke-MultiEnvironmentAnalysis -CsprojPath "Project.csproj" -ScriptPaths @("File1.cs", "File2.cs") -JobID "20250624-001" -LogDir ".\Logs"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$CsprojPath,
        
        [Parameter(Mandatory = $true)]
        [string[]]$ScriptPaths,
        
        [Parameter(Mandatory = $true)]
        [string]$JobID,
        
        [Parameter(Mandatory = $true)]
        [string]$LogDir
    )
    
            Write-DebugInfo "Starting multi-environment analysis to avoid conditional compilation issues..." -DebugType "Environment"
    
    # 定义不同的编译环境
    $environments = @(
        @{ 
            Name = "Default"
            Defines = ""
            Description = "Default compilation environment"
        },
        @{ 
            Name = "Addressables"
            Defines = "ADDRESSABLES"
            Description = "Addressables-enabled compilation environment"
        },
        @{ 
            Name = "Editor"
            Defines = "UNITY_EDITOR"
            Description = "Unity Editor compilation environment"
        },
        @{ 
            Name = "AddressablesEditor"
            Defines = "ADDRESSABLES;UNITY_EDITOR"
            Description = "Addressables + Editor编译环境"
        }
    )
    
    $allResults = @()
    $tempProjects = @()
    
    try {
        foreach ($env in $environments) {
            Write-DebugInfo "分析环境: $($env.Name) - $($env.Description)" -DebugType "Environment"
            
            # 为每个环境创建临时项目
            $envJobID = "${JobID}_$($env.Name)"
            $tempProject = New-TemporaryCsproj -SourceCsproj $CsprojPath -TargetFiles $ScriptPaths -JobID $envJobID -DefineConstants $env.Defines
            $tempProjects += $tempProject
            
            # 执行分析
            $logFile = Join-Path $LogDir "${envJobID}_CommentAnalazy_detect.log"
            $result = Invoke-RoslynatorAnalysis -ProjectPath $tempProject -LogFile $logFile -Environment $env.Name -ConsoleLogLevel $Verbosity -FileLogLevel $FileLogVerbosity
            
            if ($result.Success) {
                Write-DebugInfo "$($env.Name) environment analysis successful: $($result.IssueCount) issues" -DebugType "Environment"
                $allResults += @{
                    Environment = $env.Name
                    LogFile = $logFile
                    IssueCount = $result.IssueCount
                    Issues = $result.Issues
                }
            } else {
                Write-DebugInfo "$($env.Name) environment analysis failed: $($result.Error)" -DebugType "Environment" -Level "Error"
            }
        }
        
        # 合并分析结果
        Write-DebugInfo "Merging multi-environment analysis results..." -DebugType "Environment"
        $mergedResult = Merge-MultiEnvironmentResults -Results $allResults -JobID $JobID -LogDir $LogDir
        
        Write-DebugInfo "Multi-environment analysis completed!" -DebugType "Environment"
        Write-DebugInfo "Total environments: $($environments.Count)" -DebugType "Environment"
        Write-DebugInfo "Successful environments: $($allResults.Count)" -DebugType "Environment"
        Write-DebugInfo "Merged issue count: $($mergedResult.TotalIssues)" -DebugType "Environment"
        Write-DebugInfo "Merged log: $($mergedResult.MergedLogFile)" -DebugType "Environment"
        
        return $mergedResult
        
    } finally {
        # 清理临时项目文件
        foreach ($tempProject in $tempProjects) {
            if (Test-Path $tempProject) {
                Remove-Item $tempProject -Force -ErrorAction SilentlyContinue
                Write-Verbose "已清理临时项目: $tempProject"
            }
        }
    }
}

function Merge-MultiEnvironmentResults {
    <#
    .SYNOPSIS
    合并多个编译环境的分析结果
    
    .DESCRIPTION
    智能合并不同编译环境下的分析结果，去除重复问题，生成统一的报告
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results,
        
        [Parameter(Mandatory = $true)]
        [string]$JobID,
        
        [Parameter(Mandatory = $true)]
        [string]$LogDir
    )
    
    $mergedIssues = @{}
    $totalIssues = 0
    
    # 合并所有环境的问题
    foreach ($result in $Results) {
        Write-DebugInfo "Processing $($result.IssueCount) issues from $($result.Environment) environment..." -DebugType "Environment"
        
        foreach ($issue in $result.Issues) {
            # 使用文件路径+行号作为唯一键，避免重复问题
            $issueKey = "$($issue.FilePath):$($issue.Line)"
            
            if (-not $mergedIssues.ContainsKey($issueKey)) {
                $mergedIssues[$issueKey] = @{
                    FilePath = $issue.FilePath
                    Line = $issue.Line
                    Rule = $issue.Rule
                    Message = $issue.Message
                    Environments = @($result.Environment)
                }
                $totalIssues++
            } else {
                # 记录此问题在多个环境中都存在
                $mergedIssues[$issueKey].Environments += $result.Environment
            }
        }
    }
    
    # 生成合并后的日志文件
    $mergedLogFile = Join-Path $LogDir "${JobID}_CommentAnalazy_detect_merged.log"
    $mergedLogContent = @()
    
    $mergedLogContent += "# CommentAnalyzer 多编译环境分析合并报告"
    $mergedLogContent += "# 生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $mergedLogContent += "# 作业ID: $JobID"
    $mergedLogContent += "# 分析环境数: $($Results.Count)"
    $mergedLogContent += "# 合并后问题总数: $totalIssues"
    $mergedLogContent += ""
    
    # 按文件分组输出问题
    $issuesByFile = $mergedIssues.Values | Group-Object FilePath
    
    foreach ($fileGroup in $issuesByFile) {
        $mergedLogContent += "## 文件: $($fileGroup.Name)"
        $mergedLogContent += ""
        
        foreach ($issue in ($fileGroup.Group | Sort-Object Line)) {
            $envList = $issue.Environments -join ", "
            $mergedLogContent += "  行 $($issue.Line): [$($issue.Rule)] $($issue.Message)"
            $mergedLogContent += "    环境: $envList"
            $mergedLogContent += ""
        }
    }
    
    # 写入合并日志
    $mergedLogContent | Out-File -FilePath $mergedLogFile -Encoding UTF8
    
    return @{
        Success = $true
        TotalIssues = $totalIssues
        MergedLogFile = $mergedLogFile
        IssuesByFile = $issuesByFile
        EnvironmentResults = $Results
    }
}

# --- SCRIPT ENTRY POINT ---
Invoke-CommentAnalyzer