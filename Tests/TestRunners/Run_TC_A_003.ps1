<#
.SYNOPSIS
    Test case for analyzer rule: PROJECT_TYPE_MISSING_REMARKS_TAG (TC_A_003)
.DESCRIPTION
    This script runs the CommentAnalyzer on a specific test case file and verifies
    that the analyzer correctly identifies a <remarks> tag that is missing the
    required structured sub-tags.
#>

# --- Test Configuration ---
$TestName = "TC_A_003: Remarks Missing Structured Tags"
$RuleIdToFind = "PROJECT_TYPE_MISSING_REMARKS_TAG"
$ExpectedDetections = 10 # There are 10 required sub-tags to check for.

# --- Helper Functions ---
function Get-LatestMsBuildPath {
    $vsWherePath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\\Installer\\vswhere.exe"
    if (-not (Test-Path $vsWherePath)) {
        throw "vswhere.exe not found at $vsWherePath. Cannot auto-detect MSBuild path."
    }
    # Find all instances that have the MSBuild component.
    $vsInstallations = & $vsWherePath -products * -requires Microsoft.Component.MSBuild -property installationPath
    # Prefer BuildTools, then Enterprise, then Community.
    $preferredInstance = $vsInstallations | Where-Object { $_ -like '*BuildTools*' } | Select-Object -First 1
    if (-not $preferredInstance) { $preferredInstance = $vsInstallations | Where-Object { $_ -like '*Enterprise*' } | Select-Object -First 1 }
    if (-not $preferredInstance) { $preferredInstance = $vsInstallations | Where-Object { $_ -like '*Community*' } | Select-Object -First 1 }
    if (-not $preferredInstance) { $preferredInstance = $vsInstallations | Select-Object -First 1 }

    if ($preferredInstance) {
        $msbuildPath = Join-Path $preferredInstance "MSBuild\\Current\\Bin"
        if (Test-Path (Join-Path $msbuildPath "MSBuild.exe")) {
            return $msbuildPath
        }
    }
    throw "Could not find a valid MSBuild instance."
}

# --- Path Setup ---
# Get the directory of the currently running script.
$ScriptDirectory = (Split-Path -Parent $MyInvocation.MyCommand.Definition)

# Search upwards for the project root, marked by the 'ProjectSettings' directory.
$currentDir = $ScriptDirectory
$RepoRoot = $null
while ($currentDir -and ($currentDir -ne (Split-Path $currentDir -Parent))) {
    if (Test-Path (Join-Path $currentDir "ProjectSettings")) {
        $RepoRoot = $currentDir
        break
    }
    $currentDir = (Split-Path $currentDir -Parent)
}

if (-not $RepoRoot) {
    throw "FATAL: Could not determine repository root."
}

# Define component paths directly
$AnalyzerScriptPath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/CommentAnalyzer.ps1"
$TestCasePath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/Tests/TestCases/TC_A_003_RemarksMissingTag.cs"
$CsprojPath = Join-Path $RepoRoot "Dropleton.csproj"
$AnalyzerCsprojPath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/ProjectCommentAnalyzer/ProjectCommentAnalyzer/ProjectCommentAnalyzer.csproj"
$AnalyzerDllPath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/ProjectCommentAnalyzer/ProjectCommentAnalyzer/bin/Release/netstandard2.0/ProjectCommentAnalyzer.dll"
# Manually define the path to Roslynator.exe
$RoslynatorPath = Join-Path $RepoRoot "CustomPackages/CommentAnalyzer/.nuget/packages/roslynator.commandline/0.10.1/tools/net48/Roslynator.exe"
# Dynamically find MSBuild path
$MsbuildPath = Get-LatestMsBuildPath

# --- Pre-flight Checks ---
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
    # Load the main project file as XML
    [xml]$mainProjectXml = Get-Content -Path $CsprojPath

    # Create a new XML document for the temp project
    [xml]$tempProjectXml = "<Project Sdk=`"Microsoft.NET.Sdk`"></Project>"
    
    # Copy all top-level elements (like PropertyGroup, ItemGroup for analyzers) from the main project
    foreach ($node in $mainProjectXml.Project.ChildNodes) {
        $importedNode = $tempProjectXml.ImportNode($node, $true)
        $tempProjectXml.Project.AppendChild($importedNode) | Out-Null
    }

    # Remove all existing Compile items
    $compileItems = $tempProjectXml.Project.SelectNodes("//ItemGroup/Compile")
    foreach($item in $compileItems) {
        $item.ParentNode.RemoveChild($item) | Out-Null
    }

    # Add an ItemGroup with a Compile item for our test case file
    $itemGroup = $tempProjectXml.CreateElement("ItemGroup")
    $compileElement = $tempProjectXml.CreateElement("Compile")
    $compileElement.SetAttribute("Include", $TestCasePath)
    $itemGroup.AppendChild($compileElement) | Out-Null
    $tempProjectXml.Project.AppendChild($itemGroup) | Out-Null

    # Save the temporary project file
    $tempProjectXml.Save($tempProjectPath)
    Write-Host -ForegroundColor Green "Temporary project created at $tempProjectPath"
}
catch {
    throw "FATAL: Failed to create temporary project. $_"
}

# --- Build Analyzer ---
Write-Host "Building the analyzer project using 'dotnet build'..."
try {
    # Using 'dotnet build' is more robust for SDK-style projects.
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
$LogFilePath = Join-Path $PSScriptRoot "..\\..\\Logs\\TC_A_003_$(Get-Date -Format 'yyyyMMddHHmmss').log"

# Define arguments for Roslynator.exe. Let PowerShell handle quoting.
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

# Roslynator exits with 0 if no issues found, 1 if issues are found. Both are valid success cases for execution.
if ($exitCode -ne 0 -and $exitCode -ne 1) {
    Write-Error "Roslynator process failed with unexpected exit code $exitCode."
    exit 1
}

# --- Verification ---
Write-Host "Verifying results..."
if (-not (Test-Path $LogFilePath)) {
    # If exit code was 0 (no issues), the log file might not be created.
    if ($exitCode -eq 0 -and $ExpectedDetections -gt 0) {
        Write-Error "FAILURE: Test '$TestName' failed. Roslynator found no issues, but expected $ExpectedDetections."
    } elseif ($exitCode -eq 0 -and $ExpectedDetections -eq 0) {
         Write-Host -ForegroundColor Green "SUCCESS: Test '$TestName' passed. Found 0 detections as expected."
         exit 0
    } else {
        Write-Error "FATAL: Log file not found at $LogFilePath, but Roslynator exited with code $exitCode."
    }
    exit 1
}

[xml]$logXml = Get-Content $LogFilePath -Raw
# The XPath query must be specific to the <Diagnostics> block to avoid counting the <Summary> node.
$diagnostics = $logXml.SelectNodes("//Diagnostics/Diagnostic[@Id='$RuleIdToFind']")
$detections = $diagnostics.Count

if ($detections -eq $ExpectedDetections) {
    Write-Host -ForegroundColor Green "SUCCESS: Test '$TestName' passed. Found $detections detections as expected."
} else {
    Write-Error "FAILURE: Test '$TestName' failed. Expected $ExpectedDetections detections for rule '$RuleIdToFind', but found $detections."
    Write-Host "Log file located at: $LogFilePath"
    # Do not exit with 1 here, to allow cleanup
}

# --- Cleanup ---
# Only clean up if the test was successful to allow for post-mortem debugging.
if ($detections -eq $ExpectedDetections) {
    Write-Host "Cleaning up temporary project file..."
    Remove-Item -Path $tempProjectPath -Force -ErrorAction SilentlyContinue
}

# Final exit code determination
if ($detections -eq $ExpectedDetections) {
    exit 0
} else {
    exit 1
} 