param(
 [ValidateSet('Prepare','Resume','Export','Smoke')][string]$Action,
 [string]$GodotPath = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe',
 [string]$OutputDirectory,
 [string]$Seed = '42',
 [switch]$Release,
 [switch]$Headless,
 [switch]$IncludePolicyJson
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path $projectRoot '.godot/verification/e07_f1/fixture_project'
$evidenceRoot = Join-Path $projectRoot '.godot/verification/e07_f8'
if (-not $OutputDirectory) { throw 'Explicit isolated OutputDirectory is required.' }
$probeOutput = [IO.Path]::GetFullPath($OutputDirectory)
[void][IO.Directory]::CreateDirectory($probeOutput)
[void][IO.Directory]::CreateDirectory((Join-Path $probeOutput 'appdata'))
[void][IO.Directory]::CreateDirectory((Join-Path $probeOutput 'localappdata'))
$releaseRoot = Join-Path $evidenceRoot 'release'
$releaseExe = Join-Path $releaseRoot 'RagRPG-E07.exe'
$engineArgs = [System.Collections.Generic.List[string]]::new()
$label = ($Action.ToLowerInvariant() + $(if ($Release) { '_release' } else { '_source' }))
$executable = if ($Release) { $releaseExe } else { $GodotPath }
if ($Action -eq 'Export') {
 [void][IO.Directory]::CreateDirectory($releaseRoot)
 $preset = [IO.File]::ReadAllText((Join-Path $projectRoot 'export_presets.cfg'))
 $template = 'C:/Users/João Pedro/AppData/Roaming/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe'
 if (-not (Test-Path -LiteralPath $template)) { throw 'Verified Windows release template missing.' }
 $preset = $preset.Replace('custom_template/release=""', ('custom_template/release="' + $template + '"'))
 if ($IncludePolicyJson) { $preset = $preset.Replace('include_filter=""', 'include_filter="data/expedition/policies/*.json,scripts/core/expedition/snapshot/runtime_manifest.json"') }
 [IO.File]::WriteAllText((Join-Path $fixtureRoot 'export_presets.cfg'), $preset)
 @('--headless','--path',$fixtureRoot,'--export-release','Windows Desktop',$releaseExe) | ForEach-Object { $engineArgs.Add($_) }
} else {
 if ($Headless) { $engineArgs.Add('--headless') }
 if (-not $Release) { $engineArgs.Add('--path'); $engineArgs.Add($fixtureRoot) }
 if ($Action -ne 'Smoke') { $engineArgs.Add('res://tools/e07_f8_candidate_probe.tscn') }
 if ($Action -eq 'Smoke') { $engineArgs.Add('--quit-after'); $engineArgs.Add('8') }
}
$engineArgs.Add('--log-file'); $engineArgs.Add((Join-Path $probeOutput ($label + '.engine.log')))
if ($Action -in @('Prepare','Resume')) {
 $engineArgs.Add('--'); $engineArgs.Add('--f8-mode=' + $Action.ToLowerInvariant())
 $engineArgs.Add('--f8-output=' + $probeOutput); $engineArgs.Add('--f8-seed=' + $Seed)
}
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $executable
$info.WorkingDirectory = if ($Release) { $releaseRoot } else { $fixtureRoot }
$info.UseShellExecute = $false; $info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
$info.Environment['APPDATA'] = Join-Path $probeOutput 'appdata'
$info.Environment['LOCALAPPDATA'] = Join-Path $probeOutput 'localappdata'
foreach ($arg in $engineArgs) { $info.ArgumentList.Add($arg) }
$process = [Diagnostics.Process]::new(); $process.StartInfo = $info
$plan = @{ created_utc=[DateTime]::UtcNow.ToString('o'); executable=$executable; executable_sha256=(Get-FileHash -LiteralPath $executable).Hash; arguments=@($engineArgs); working_directory=$info.WorkingDirectory; profile_environment=@{APPDATA=$info.Environment['APPDATA'];LOCALAPPDATA=$info.Environment['LOCALAPPDATA']}; policy_json_included=[bool]$IncludePolicyJson }
$plan | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeOutput ($label + '.plan.json')) -Encoding utf8
[void]$process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync(); $stderrTask = $process.StandardError.ReadToEndAsync()
$timedOut = -not $process.WaitForExit(300000)
if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
$text = $stdoutTask.GetAwaiter().GetResult() + $stderrTask.GetAwaiter().GetResult()
$code = $process.ExitCode; $process.Dispose()
$logPath = Join-Path $probeOutput ($label + '.output.log')
Set-Content -LiteralPath $logPath -Value $text -Encoding utf8
$failed = $timedOut -or $code -ne 0 -or $text -match 'SCRIPT ERROR:|Parse Error:|ERROR:'
if ($Action -in @('Prepare','Resume')) { $failed = $failed -or $text -notmatch ('E07 F8 CANDIDATE ' + $Action.ToLowerInvariant() + ': PASS') }
$result = @{ exit_code=$code; timed_out=$timedOut; failed=[bool]$failed; output_sha256=(Get-FileHash -LiteralPath $logPath).Hash; output_path=$logPath }
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $probeOutput ($label + '.result.json')) -Encoding utf8
Write-Output $text
if ($failed) { throw ('F8 ' + $Action + ' failed; preserved ' + $logPath) }
