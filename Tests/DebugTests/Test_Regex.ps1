#!/usr/bin/env pwsh

# 测试消息
$testMessage = "[Workflow-DEBUG] test message"

# 测试不同的正则表达式
$patterns = @(
    "\[.*-DEBUG\]",
    "\[Workflow-DEBUG\]",
    "Workflow-DEBUG",
    "\[.*DEBUG.*\]"
)

Write-Host "Testing message: $testMessage"
Write-Host ""

foreach ($pattern in $patterns) {
    $result = $testMessage -match $pattern
    Write-Host "Pattern: $pattern -> Result: $result"
}

Write-Host ""
Write-Host "Testing actual output parse:"

$sampleOutput = @(
    "[Workflow-DEBUG] Dependencies are satisfied.",
    "[Workflow-DEBUG] Specific scripts provided. Creating a temporary project...",
    "Analysis completed. 0 diagnostics found.",
    "✅ No issues found - code analysis passed!"
)

foreach ($line in $sampleOutput) {
    $isDebug = $line -match "\[.*-DEBUG\]"
    $isUser = $line -match "Analysis completed|found|passed"
    Write-Host "Line: $line"
    Write-Host "  -> IsDebug: $isDebug, IsUser: $isUser"
} 