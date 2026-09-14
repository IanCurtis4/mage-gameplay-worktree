param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [switch]$SkipEditorImport
)
$ErrorActionPreference = 'Stop'
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$projectPath = Split-Path -Parent $PSScriptRoot
$verificationPath = Join-Path $projectPath '.godot/verification'
[void](New-Item -ItemType Directory -Force -Path $verificationPath)
$logPath = Join-Path $verificationPath 'godot.log'

function Invoke-GodotCheck([string[]]$EngineArguments) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $enginePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @('--log-file', $logPath) + $EngineArguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) {
        $process.Kill($true)
        throw 'Godot verification timed out after 60 seconds.'
    }
    $checkOutput = $stdoutTask.GetAwaiter().GetResult() + $stderrTask.GetAwaiter().GetResult()
    $checkExitCode = $process.ExitCode
    $process.Dispose()
    Write-Host $checkOutput
    if ($checkExitCode -ne 0 -or ($checkOutput -match 'SCRIPT ERROR:|Parse Error:|ERROR:')) {
        throw "Godot verification failed (exit $checkExitCode)."
    }
}

if ($SkipEditorImport) {
    Write-Host 'Editor import explicitly skipped; verify import in a clean worktree before using this option.'
} else {
    Invoke-GodotCheck @('--headless', '--path', $projectPath, '--editor', '--import', '--quit')
}
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/foundation_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/combat_animation_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/milestone_one_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/pursuit_momentum_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/battle_ui_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/arena_flow_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/ui_layout_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/mage_gameplay_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/persistent_state_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/profile_store_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/profile_facade_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/profile_run_facade_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e01_profile_diagnostic_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--quit-after', '5')
Write-Host 'All foundation and milestone-one checks passed.'
