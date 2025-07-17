<#
.SYNOPSIS
    Test case for analyzer rule: PROJECT_CONDITIONAL_COMPILATION_WARNING (TC_A_020)
.DESCRIPTION
    验证简化条件编译检测告警能力，断言为1。
#>

# --- Test Configuration ---
$TestName = "TC_A_020: Simple Conditional Test"
$RuleIdToFind = "PROJECT_CONDITIONAL_COMPILATION_WARNING"
$ExpectedDetections = 1
$TestCaseFile = "TC_A_020_SimpleConditionalTest.cs"

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

# --- MSBuild Path ---
$MsbuildExe = Get-LatestMsBuildPath
$MsbuildPath = Split-Path $MsbuildExe -Parent
$MsbuildPath = $MsbuildPath.TrimEnd('\','"')
Write-Host "MSBuildPath: $MsbuildPath"

# --- Log Path ---
$LogDir = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/Logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$JobId = Get-Date -Format "yyyyMMddHHmmss"
$LogFilePath = Join-Path $LogDir "TC_A_020_${JobId}.log"

# --- Run Analyzer ---
Write-Host "Running analyzer for $TestCaseFile ..."
$exitCode = & $AnalyzerScriptPath `
    -SolutionPath $CsprojPath `
    -Mode detect `
    -ScriptPaths $TestCasePath `
    -MsbuildPath $MsbuildPath `
    -LogFile $LogFilePath
if ($exitCode -ne 0) {
    Write-Error "Analyzer exited with code $exitCode."
    exit $exitCode
}

# --- Verification ---
Write-Host "Verifying results..."
if (-not (Test-Path $LogFilePath)) {
    Write-Error "FATAL: Log file not found at $LogFilePath, but analyzer exited with code $exitCode."
    exit 1
}
[xml]$logXml = Get-Content $LogFilePath -Raw
$detections = ($logXml.SelectNodes("//diagnostic[starts-with(@id, '$RuleIdToFind')]") | Measure-Object).Count
Write-Host ("[PASS] $($TestName): Detected $($detections) as expected.")
if ($detections -eq $ExpectedDetections) {
    Write-Host ("[PASS] $($TestName): Detected $($detections) as expected.")
    exit 0
} else {
    Write-Error ("[FAIL] $($TestName): Expected $($ExpectedDetections), but found $($detections).")
    exit 1
} 