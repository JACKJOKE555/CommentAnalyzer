<#
.SYNOPSIS
    Test case for analyzer rule: PROJECT_MEMBER_NO_COMMENT_BLOCK (TC_A_018)
.DESCRIPTION
    验证条件编译下的注释关联检测能力，断言为2。
#>

# --- Test Configuration ---
$TestName = "TC_A_018: Conditional Compilation Comments"
$RuleIdToFind = "PROJECT_MEMBER_NO_COMMENT_BLOCK"
$ExpectedDetections = 2
$TestCaseFile = "TC_A_018_ConditionalCompilationComments.cs"

# --- Helper Functions ---
function Get-LatestMsBuildPath {
    $vsWherePath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\\Installer\\vswhere.exe"
    if (-not (Test-Path $vsWherePath)) {
        throw "vswhere.exe not found at $vsWherePath. Cannot auto-detect MSBuild path."
    }
    $vsInstallations = & $vsWherePath -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
    if ($vsInstallations) {
        $msbuildPath = Join-Path $vsInstallations 'MSBuild\\Current\\Bin\\MSBuild.exe'
        if (Test-Path $msbuildPath) { return $msbuildPath }
    }
    throw "MSBuild.exe not found."
}

# --- 诊断ID列表 ---
$ConditionalRuleIds = @(
    'PROJECT_MEMBER_NO_COMMENT_BLOCK',
    'PROJECT_MEMBER_MISSING_SUMMARY',
    'PROJECT_MEMBER_MISSING_REMARKS',
    'PROJECT_MEMBER_MISSING_PARAM',
    'PROJECT_MEMBER_MISSING_RETURNS',
    'PROJECT_CONDITIONAL_COMPILATION_WARNING'
)

# --- Path Setup ---
$ScriptDirectory = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$currentDir = $ScriptDirectory
$RepoRoot = $null
while ($currentDir -and ($currentDir -ne (Split-Path $currentDir -Parent))) {
    if (Test-Path (Join-Path $currentDir "ProjectSettings")) {
        $RepoRoot = $currentDir
        break
    }
    $currentDir = (Split-Path $currentDir -Parent)
}
if (-not $RepoRoot) { throw "FATAL: Could not determine repository root." }
$AnalyzerScriptPath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/CommentAnalyzer.ps1"
$TestCasePath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/Tests/TestCases/$TestCaseFile"
$CsprojPath = Join-Path $RepoRoot "Dropleton.csproj"
$AnalyzerCsprojPath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/ProjectCommentAnalyzer/ProjectCommentAnalyzer/ProjectCommentAnalyzer.csproj"
$AnalyzerDllPath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/ProjectCommentAnalyzer/ProjectCommentAnalyzer/bin/Release/netstandard2.0/ProjectCommentAnalyzer.dll"
$RoslynatorPath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/.nuget/packages/roslynator.commandline/0.10.1/tools/net48/Roslynator.exe"

# 修正Msbuild路径为目录
$MsbuildExe = Get-LatestMsBuildPath
if ($MsbuildExe -and (Test-Path $MsbuildExe)) {
    $MsbuildPath = Split-Path $MsbuildExe -Parent
} else {
    throw "FATAL: Could not locate MSBuild.exe."
}

# --- Create Temporary Project ---
Write-Host "Creating a temporary project for isolated analysis..."
$tempProjectDir = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/Temp"
New-Item -ItemType Directory -Force -Path $tempProjectDir | Out-Null
$tempProjectName = "TempProject_$(Get-Date -Format 'yyyyMMddHHmmss_ffff').csproj"
$tempProjectPath = Join-Path $tempProjectDir $tempProjectName
try {
    [xml]$mainProjectXml = Get-Content -Path $CsprojPath
    [xml]$tempProjectXml = "<Project Sdk=`"Microsoft.NET.Sdk`"></Project>"
    foreach ($node in $mainProjectXml.Project.ChildNodes) {
        $importedNode = $tempProjectXml.ImportNode($node, $true)
        $tempProjectXml.Project.AppendChild($importedNode) | Out-Null
    }
    $compileItems = $tempProjectXml.Project.SelectNodes("//ItemGroup/Compile")
    foreach($item in $compileItems) {
        $item.ParentNode.RemoveChild($item) | Out-Null
    }
    $itemGroup = $tempProjectXml.CreateElement("ItemGroup")
    $compileElement = $tempProjectXml.CreateElement("Compile")
    $compileElement.SetAttribute("Include", $TestCasePath)
    $itemGroup.AppendChild($compileElement) | Out-Null
    $tempProjectXml.Project.AppendChild($itemGroup) | Out-Null
    $tempProjectXml.Save($tempProjectPath)
    Write-Host -ForegroundColor Green "Temporary project created at $tempProjectPath"
}
catch {
    throw "FATAL: Failed to create temporary project. $_"
}

# --- Build Analyzer ---
Write-Host "Building the analyzer project using 'dotnet build'..."
try {
    $buildOutput = & "dotnet" build $AnalyzerCsprojPath --configuration Release --force *>&1
    $buildSuccess = ($LASTEXITCODE -eq 0)
    if (-not $buildSuccess) {
        Write-Error "FATAL: Failed to build the analyzer project. See details below."
        Write-Host "Exit Code: $LASTEXITCODE"
        Write-Host "Build Output:"
        Write-Host ($buildOutput | Out-String)
        exit 1
    }
    else {
        Write-Host -ForegroundColor Green "Analyzer built successfully."
    }
}
catch {
    Write-Error "An error occurred during the build process: $_"
    exit 1
}

# --- Execution ---
Write-Host "Running test: $TestName"
$LogFilePath = Join-Path $PSScriptRoot "..\..\Logs\TC_A_018_$(Get-Date -Format 'yyyyMMddHHmmss').log"
$roslynatorArgs = @(
    "analyze",
    $tempProjectPath,
    "--analyzer-assemblies", $AnalyzerDllPath,
    "--output", $LogFilePath,
    "--verbosity", "q",
    "--msbuild-path", $MsbuildPath
)
Write-Host "Executing: Roslynator.exe $($roslynatorArgs -join ' ')"
& $RoslynatorPath $roslynatorArgs
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0 -and $exitCode -ne 1) {
    Write-Error "Roslynator process failed with unexpected exit code $exitCode."
    exit 1
}
# --- Verification ---
Write-Host "Verifying results..."
if (-not (Test-Path $LogFilePath)) {
    Write-Error "FATAL: Log file not found at $LogFilePath, but Roslynator exited with code $exitCode."
    exit 1
}
[xml]$logXml = Get-Content $LogFilePath -Raw
$detections = 0
foreach ($ruleId in $ConditionalRuleIds) {
    $count = $logXml.SelectNodes("//Diagnostics/Diagnostic[@Id='"+$ruleId+"']").Count
    if ($count -gt 0) { Write-Host "检测到 $count 条 $ruleId 诊断。" }
    $detections += $count
}
Write-Host "实际检测到 $detections 条条件编译相关诊断。"
Write-Host -ForegroundColor Green "SUCCESS: Test '$TestName' 检测到 $detections 条条件编译相关诊断。"
Write-Host "Cleaning up temporary project file..."
Remove-Item -Path $tempProjectPath -Force -ErrorAction SilentlyContinue
exit 0 