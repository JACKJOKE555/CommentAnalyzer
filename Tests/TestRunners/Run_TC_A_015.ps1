<#
.SYNOPSIS
    Test case for analyzer rule: PROJECT_DELEGATE_* (TC_A_015)
.DESCRIPTION
    验证委托类型的注释检测能力，断言为6。
#>

# --- Test Configuration ---
$TestName = "TC_A_015: Delegate Support"
$RuleIdToFind = "PROJECT_DELEGATE_"
$ExpectedDetections = 11
$TestCaseFile = "TC_A_015_DelegateSupport.cs"
$LogFile = "CustomPackages/CommentAnalyzer/Logs/TC_A_015_test.log"
Write-Host "[TC_A_015] 日志输出路径: $LogFile"

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
if (-not (Test-Path $AnalyzerScriptPath)) { throw "FATAL: Analyzer script not found at $AnalyzerScriptPath" }
if (-not (Test-Path $TestCasePath)) { throw "FATAL: Test case file not found at $TestCasePath" }
if (-not (Test-Path $CsprojPath)) { throw "FATAL: Main project file not found at $CsprojPath" }
if (-not (Test-Path $AnalyzerCsprojPath)) { throw "FATAL: Analyzer project file not found at $AnalyzerCsprojPath" }
if (-not (Test-Path $RoslynatorPath)) { throw "FATAL: Roslynator.exe not found at $RoslynatorPath" }

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
$LogFilePath = Join-Path $PSScriptRoot "..\..\Logs\TC_A_015_$(Get-Date -Format 'yyyyMMddHHmmss').log"
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
# --- 诊断ID列表 ---
$DelegateRelatedRuleIds = @(
    'PROJECT_TYPE_NO_COMMENT_BLOCK',
    'PROJECT_TYPE_MISSING_SUMMARY',
    'PROJECT_TYPE_MISSING_REMARKS',
    'PROJECT_MEMBER_MISSING_TYPEPARAM',
    'PROJECT_MEMBER_MISSING_PARAM',
    'PROJECT_MEMBER_MISSING_RETURNS'
)
foreach ($ruleId in $DelegateRelatedRuleIds) {
    $count = $logXml.SelectNodes("//Diagnostics/Diagnostic[@Id='"+$ruleId+"']").Count
    if ($count -gt 0) { Write-Host "检测到 $count 条 $ruleId 诊断。" }
    $detections += $count
}
Write-Host "实际检测到 $detections 条委托相关诊断。"
if ($detections -eq $ExpectedDetections) {
    Write-Host -ForegroundColor Green "SUCCESS: Test '$TestName' passed. Found $detections detections as expected."
} else {
    Write-Error "FAILURE: Test '$TestName' failed. Expected $ExpectedDetections detections for delegate-related rules, but found $detections."
    Write-Host "Log file located at: $LogFilePath"
}
if ($detections -eq $ExpectedDetections) {
    Write-Host "Cleaning up temporary project file..."
    Remove-Item -Path $tempProjectPath -Force -ErrorAction SilentlyContinue
}
if ($detections -eq $ExpectedDetections) { exit 0 } else { exit 1 } 