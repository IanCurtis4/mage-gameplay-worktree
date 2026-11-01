param(
    [Parameter(Mandatory)][string]$GodotPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [switch]$Native
)
$ErrorActionPreference = 'Stop'
# Checkpoint42: every test compiles for real; the editor cache is opt-in.
$env:RAGRPG_COMPILE_CACHE='0'
$m1Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$m1Evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
# Checkpoint41: the fixture now carries the whole runtime; keep it out of the
# evidence directory (ignored .godot), evidence keeps only logs and receipts.
$m1Fixture = Join-Path $m1Root ('.godot/verification/m1/' + (Split-Path -Leaf $m1Evidence))
if (Test-Path -LiteralPath $m1Fixture) { throw 'Use a new evidence directory for every attempt.' }
[void](New-Item -ItemType Directory -Force -Path (Join-Path $m1Fixture 'scripts'))
[void](New-Item -ItemType Directory -Force -Path (Join-Path $m1Fixture 'addons/m1_driver'))
[void](New-Item -ItemType Directory -Force -Path (Join-Path $m1Fixture 'tests'))
# Checkpoint41: map_authoring now preloads shared runtime (geometry, expedition
# view, catalogs); the isolated fixture takes the whole runtime, not only the editor.
Remove-Item -LiteralPath (Join-Path $m1Fixture 'scripts') -Recurse -Force
foreach ($m1Dir in @('scripts', 'data', 'assets', 'resources', 'content', 'scenes')) {
    if (Test-Path -LiteralPath (Join-Path $m1Root $m1Dir)) { Copy-Item -LiteralPath (Join-Path $m1Root $m1Dir) -Destination $m1Fixture -Recurse }
}
Copy-Item -LiteralPath (Join-Path $m1Root 'addons/ragrpg_map_editor') -Destination (Join-Path $m1Fixture 'addons') -Recurse
Copy-Item -LiteralPath (Join-Path $m1Root 'tests/map_editor_document_test.gd') -Destination (Join-Path $m1Fixture 'tests')
Copy-Item -LiteralPath (Join-Path $m1Root 'tests/map_editor_document_ui_test.gd') -Destination (Join-Path $m1Fixture 'addons/m1_driver/plugin.gd')
@'
config_version=5
[application]
config/name="Editor de mapas — validação F1"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $m1Fixture 'project.godot') -Encoding utf8
@'
[plugin]
name="Supervisor de fixture M1"
description="Somente teste isolado"
author="RagRPG"
version="1"
script="plugin.gd"
'@ | Set-Content -LiteralPath (Join-Path $m1Fixture 'addons/m1_driver/plugin.cfg') -Encoding utf8
$m1Isolation = Join-Path $m1Fixture '.godot/profile'
[void](New-Item -ItemType Directory -Force -Path $m1Isolation)
$m1Runs = [Collections.Generic.List[object]]::new()
function Invoke-M1([string]$Name, [string[]]$Arguments, [string]$Marker, [int]$ExpectedChecks = 0, [switch]$Interrupt) {
    $m1Info = [Diagnostics.ProcessStartInfo]::new()
    $m1Info.FileName = (Resolve-Path -LiteralPath $GodotPath).Path
    $m1Info.UseShellExecute = $false
    $m1Info.CreateNoWindow = $true
    $m1Info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $m1Info.RedirectStandardOutput = $true
    $m1Info.RedirectStandardError = $true
    $m1Info.Environment['APPDATA'] = $m1Isolation
    $m1Info.Environment['LOCALAPPDATA'] = $m1Isolation
    if ($Name -eq 'native_ui') { $m1Info.Environment['M1_CAPTURE'] = Join-Path $m1Evidence 'shell.png' }
    foreach ($m1Arg in @('--path', $m1Fixture, '--log-file', (Join-Path $m1Evidence ($Name + '.engine.log'))) + $Arguments) { $m1Info.ArgumentList.Add($m1Arg) }
    $m1Process = [Diagnostics.Process]::new()
    $m1Process.StartInfo = $m1Info
    $m1Started = [DateTime]::UtcNow.ToString('o')
    [void]$m1Process.Start()
    $m1Out = $m1Process.StandardOutput.ReadToEndAsync()
    $m1Err = $m1Process.StandardError.ReadToEndAsync()
    $m1Terminated = $false
    if ($Interrupt) {
        $m1Watch = [Diagnostics.Stopwatch]::StartNew()
        $m1ReadySignal = Join-Path $m1Fixture '.godot/interruption.ready'
        while ($m1Watch.Elapsed.TotalSeconds -lt 30 -and -not $m1Process.HasExited) {
            if (Test-Path -LiteralPath $m1ReadySignal) {
                $m1Process.Kill($true)
                $m1Terminated = $true
                break
            }
            Start-Sleep -Milliseconds 50
        }
    }
    $m1Timeout = -not $m1Process.WaitForExit(60000)
    if ($m1Timeout) { $m1Process.Kill($true); $m1Process.WaitForExit() }
    $m1Text = $m1Out.GetAwaiter().GetResult() + $m1Err.GetAwaiter().GetResult()
    $m1Log = Join-Path $m1Evidence ($Name + '.output.log')
    [IO.File]::WriteAllText($m1Log, $m1Text)
    $m1Payload = $null
    $m1Pass = -not $m1Timeout -and (($m1Process.ExitCode -eq 0 -and -not $Interrupt) -or ($Interrupt -and $m1Terminated)) -and $m1Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    if ($Marker) {
        $m1Match = [regex]::Match($m1Text, '(?m)^' + $Marker + ' (.+)$')
        if ($m1Match.Success) { $m1Payload = ConvertFrom-Json $m1Match.Groups[1].Value }
        $m1Pass = $m1Pass -and $null -ne $m1Payload -and $m1Payload.ok
        if ($ExpectedChecks -gt 0) { $m1Pass = $m1Pass -and $m1Payload.count -eq $ExpectedChecks -and @($m1Payload.checks | Where-Object { -not $_.ok }).Count -eq 0 }
    }
    $m1Runs.Add(@{ name=$Name; ok=$m1Pass; deliberately_terminated=$m1Terminated; started_utc=$m1Started; finished_utc=[DateTime]::UtcNow.ToString('o'); exit_code=$m1Process.ExitCode; timed_out=$m1Timeout; arguments=$Arguments; output_sha256=(Get-FileHash -LiteralPath $m1Log -Algorithm SHA256).Hash; result=$m1Payload })
    [IO.File]::WriteAllText((Join-Path $m1Evidence 'runs.json'), (ConvertTo-Json -InputObject @($m1Runs.ToArray()) -Depth 15))
    $m1Process.Dispose()
    Write-Output ($Name + ': ' + $m1Pass)
    if (-not $m1Pass) { Write-Output $m1Text; throw ('M1 failed: ' + $Name) }
}
Invoke-M1 'import' @('--headless', '--editor', '--import', '--quit') ''
Invoke-M1 'document' @('--headless', '--script', 'res://tests/map_editor_document_test.gd') 'M1_RESULT' 70
Invoke-M1 'cli_create' @('--headless', '--script', 'res://scripts/map_authoring/io/headless.gd', '--', 'create', (Join-Path $m1Fixture '.godot/cli.json'), 'cli_piece') 'MAP_SOURCE_RESULT'
Invoke-M1 'cli_validate' @('--headless', '--script', 'res://scripts/map_authoring/io/headless.gd', '--', 'validate', (Join-Path $m1Fixture '.godot/cli.json')) 'MAP_SOURCE_RESULT'
Invoke-M1 'cli_copy' @('--headless', '--script', 'res://scripts/map_authoring/io/headless.gd', '--', 'copy', (Join-Path $m1Fixture '.godot/cli.json'), (Join-Path $m1Fixture '.godot/cli_copy.json'), 'absent') 'MAP_SOURCE_RESULT'
if ($m1Runs[2].result.output_hash -ne $m1Runs[3].result.output_hash -or $m1Runs[2].result.output_hash -ne $m1Runs[4].result.output_hash) { throw 'CLI semantic hash mismatch.' }
Invoke-M1 'interruption' @('--headless', '--script', 'res://tests/map_editor_document_test.gd', '--', '--interruption') 'M1_INTERRUPTION_READY' -Interrupt
Invoke-M1 'restart_recover' @('--headless', '--script', 'res://scripts/map_authoring/io/headless.gd', '--', 'recover', (Join-Path $m1Fixture '.godot/interruption.json'), 'autosave', (Join-Path $m1Fixture '.godot/recovered.json')) 'MAP_SOURCE_RESULT'
Invoke-M1 'restart_pending' @('--headless', '--script', 'res://scripts/map_authoring/io/headless.gd', '--', 'recover', (Join-Path $m1Fixture '.godot/interruption.json'), 'pending', (Join-Path $m1Fixture '.godot/recovered_pending.json')) 'MAP_SOURCE_RESULT'
if ($m1Runs[5].result.output_hash -ne $m1Runs[6].result.output_hash -or $m1Runs[5].result.output_hash -ne $m1Runs[7].result.output_hash) { throw 'Restart recovery semantic hash mismatch.' }
Add-Content -LiteralPath (Join-Path $m1Fixture 'project.godot') -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/m1_driver/plugin.cfg`")" -Encoding utf8
if ($Native) { Invoke-M1 'native_ui' @('--editor', '--rendering-method', 'gl_compatibility') 'M1_UI_RESULT' 41 }
else { Invoke-M1 'headless_ui' @('--headless', '--editor') 'M1_UI_RESULT' 40 }
$m1Sources = @()
foreach ($m1Relative in @('scripts/map_authoring', 'addons/ragrpg_map_editor', 'tests/map_editor_document_test.gd', 'tests/map_editor_document_ui_test.gd', 'tools/map_editor_document/run.ps1')) {
    $m1Path = Join-Path $m1Root $m1Relative
    foreach ($m1File in @(Get-ChildItem -LiteralPath $m1Path -Recurse -File)) {
        $m1Sources += @{ path=[IO.Path]::GetRelativePath($m1Root, $m1File.FullName).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $m1File.FullName -Algorithm SHA256).Hash }
    }
}
@{ engine=(Resolve-Path -LiteralPath $GodotPath).Path; engine_sha256=(Get-FileHash -LiteralPath $GodotPath -Algorithm SHA256).Hash; sources=$m1Sources; runs=$m1Runs.ToArray() } | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $m1Evidence 'manifest.json') -Encoding utf8
Write-Output 'M1_ALL_PASS'
