param([Parameter(Mandatory = $true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$projectPath = Split-Path -Parent $PSScriptRoot

function Invoke-GodotCheck([string[]]$EngineArguments) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $enginePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $EngineArguments) { $startInfo.ArgumentList.Add($argument) }
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

Invoke-GodotCheck @('--headless', '--path', $projectPath, '--editor', '--import', '--quit')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/foundation_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--quit-after', '5')
Write-Host 'All foundation checks passed.'
