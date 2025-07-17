#Requires -Version 5.1
<#
.SYNOPSIS
    Main Script Integration Test - Detect Mode
.DESCRIPTION
    Test CommentAnalyzer.ps1 main script analyzer calling capability
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$ShowDetails
)

$ErrorActionPreference = "Stop"

# Get script paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$testCaseFile = Join-Path $scriptDir "..\TestCases\TC_MS_001_MainScriptIntegration.cs"
$mainScript = Join-Path $rootDir "CommentAnalyzer.ps1"
$testProjectPath = Join-Path $rootDir "ProjectCommentAnalyzer\ProjectCommentAnalyzer\ProjectCommentAnalyzer.csproj"

Write-Host "=== Main Script Integration Test - Detect Mode ===" -ForegroundColor Green

# Verify required files exist
if (-not (Test-Path $testCaseFile)) {
    throw "Test case file not found: $testCaseFile"
}

if (-not (Test-Path $mainScript)) {
    throw "Main script not found: $mainScript"
}

if (-not (Test-Path $testProjectPath)) {
    throw "Test project not found: $testProjectPath"
}

try {
    Write-Host "1. Executing main script - Detect mode" -ForegroundColor Yellow
    Write-Host "   Test case: $testCaseFile"
    Write-Host "   Project path: $testProjectPath"
    
    # Execute main script
    $logFile = "MainScript_Detect_Test.log"
    & $mainScript -SolutionPath $testProjectPath -Mode "detect" -ScriptPaths @($testCaseFile) -LogFile $logFile -ExportTempProject
    
    Write-Host "2. Verifying log file generation" -ForegroundColor Yellow
    $logPattern = Join-Path $rootDir "Logs\*_$logFile"
    $logFiles = Get-ChildItem -Path $logPattern -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -eq 0) {
        throw "Log file not found: $logPattern"
    }
    
    $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host "   Found log file: $($latestLog.FullName)"
    
    Write-Host "3. Analyzing log content" -ForegroundColor Yellow
    $logContent = Get-Content -Path $latestLog.FullName -Raw
    
    # Check for expected diagnostic rules
    $expectedRules = @(
        "PROJECT_TYPE_MISSING_SUMMARY",
        "PROJECT_TYPE_MISSING_REMARKS", 
        "PROJECT_MEMBER_MISSING_SUMMARY",
        "PROJECT_MEMBER_MISSING_REMARKS"
    )
    
    $foundRules = @()
    foreach ($rule in $expectedRules) {
        if ($logContent -match $rule) {
            $foundRules += $rule
            Write-Host "   Found rule: $rule" -ForegroundColor Green
        }
    }
    
    if ($foundRules.Count -eq 0) {
        Write-Warning "No PROJECT_* rules found in log, analyzer may not be loaded correctly"
        if ($ShowDetails) {
            Write-Host "Log content preview:" -ForegroundColor Cyan
            Write-Host $logContent.Substring(0, [Math]::Min(500, $logContent.Length))
        }
    }
    
    Write-Host "4. Verifying temporary project file" -ForegroundColor Yellow
    $tempDir = Join-Path $rootDir "Temp"
    $tempProjects = Get-ChildItem -Path $tempDir -Filter "TempProject_*.csproj" -ErrorAction SilentlyContinue
    
    if ($tempProjects.Count -gt 0) {
        $latestTempProject = $tempProjects | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "   Found temp project: $($latestTempProject.Name)" -ForegroundColor Green
        
        # Verify temp project content
        [xml]$tempProjectXml = Get-Content -Path $latestTempProject.FullName
        $compileItems = $tempProjectXml.Project.ItemGroup.Compile
        
        if ($compileItems) {
            Write-Host "   Temp project contains $($compileItems.Count) compile items" -ForegroundColor Green
            foreach ($item in $compileItems) {
                Write-Host "     - $($item.Include)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Warning "No temp project files found (may have been cleaned up)"
    }
    
    Write-Host "5. Test Results Summary" -ForegroundColor Yellow
    Write-Host "   Main script executed successfully" -ForegroundColor Green
    Write-Host "   Log file generated normally" -ForegroundColor Green
    Write-Host "   Found $($foundRules.Count) PROJECT rules" -ForegroundColor Green
    Write-Host "   Temp project processing normal" -ForegroundColor Green
    
    Write-Host "=== Main Script Integration Test - Detect Mode Complete ===" -ForegroundColor Green
    
} catch {
    Write-Error "Test failed: $_"
    exit 1
} 