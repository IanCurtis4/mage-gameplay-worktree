param([Parameter(Mandatory)][string]$GodotPath,[Parameter(Mandatory)][string]$EvidenceDirectory,[switch]$Native,[string]$ReuseFixture = '')
$ErrorActionPreference = 'Stop'
$m2Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$m2Evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
if (Test-Path -LiteralPath $m2Evidence) { throw 'Use an absent evidence directory.' }
[void](New-Item -ItemType Directory -Force -Path $m2Evidence)
$m2Fixture = if ($ReuseFixture) { [IO.Path]::GetFullPath($ReuseFixture) } else { Join-Path $m2Evidence 'fixture' }
if (-not $ReuseFixture) {
    [void](New-Item -ItemType Directory -Force -Path $m2Fixture)
    foreach ($m2Dir in @('scripts','scenes','assets','data','resources','content','addons','tests','tools')) {
        $m2Path = Join-Path $m2Root $m2Dir
        if (Test-Path -LiteralPath $m2Path) { Copy-Item -LiteralPath $m2Path -Destination $m2Fixture -Recurse }
    }
}
# Refresh only task-owned/editor sources, preserving the imported fixture cache.
foreach ($m2Dir in @('scripts/map_authoring','addons/ragrpg_map_editor')) {
    Copy-Item -LiteralPath (Join-Path $m2Root $m2Dir) -Destination (Split-Path -Parent (Join-Path $m2Fixture $m2Dir)) -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $m2Root 'tools') -Destination $m2Fixture -Recurse -Force
Copy-Item -LiteralPath (Join-Path $m2Root 'assets/art/map_authoring') -Destination (Join-Path $m2Fixture 'assets/art') -Recurse -Force
foreach ($m2File in @('map_editor_terrain_scale_test.gd','map_editor_terrain_test.gd','map_editor_terrain_ui_test.gd','map_editor_document_test.gd','map_editor_document_ui_test.gd')) {
    $m2Path = Join-Path $m2Root ('tests/'+$m2File)
    if (Test-Path -LiteralPath $m2Path) { Copy-Item -LiteralPath $m2Path -Destination (Join-Path $m2Fixture 'tests') -Force }
}
$m2Config = (Get-Content -LiteralPath (Join-Path $m2Root 'project.godot') -Raw).Replace('version_control/autoload_on_startup=true','version_control/autoload_on_startup=false')
[IO.File]::WriteAllText((Join-Path $m2Fixture 'project.godot'), $m2Config)
$m2Isolation = Join-Path $m2Fixture '.godot/profile'
[void](New-Item -ItemType Directory -Force -Path $m2Isolation)
$m2Runs = [Collections.Generic.List[object]]::new()
function Invoke-M2([string]$Name,[string[]]$Arguments,[string]$Marker = '',[int]$Count = 0) {
    $m2Info = [Diagnostics.ProcessStartInfo]::new()
    $m2Info.FileName = (Resolve-Path -LiteralPath $GodotPath).Path
    $m2Info.UseShellExecute = $false
    $m2Info.CreateNoWindow = $true
    $m2Info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $m2Info.RedirectStandardOutput = $true
    $m2Info.RedirectStandardError = $true
    $m2Info.Environment['APPDATA'] = $m2Isolation
    $m2Info.Environment['LOCALAPPDATA'] = $m2Isolation
    $m2Info.Environment['M2_CAPTURE'] = Join-Path $m2Evidence 'terrain.png'
    foreach ($m2Arg in @('--path',$m2Fixture,'--log-file',(Join-Path $m2Evidence ($Name+'.engine.log'))) + $Arguments) { $m2Info.ArgumentList.Add($m2Arg) }
    $m2Process = [Diagnostics.Process]::new(); $m2Process.StartInfo=$m2Info
    $m2Started = [DateTime]::UtcNow.ToString('o')
    [void]$m2Process.Start()
    $m2Out = $m2Process.StandardOutput.ReadToEndAsync(); $m2Err = $m2Process.StandardError.ReadToEndAsync()
    $m2TimeoutMs = if ($Name -eq 'terrain_scale') { 180000 } else { 60000 }
    $m2Timeout = -not $m2Process.WaitForExit($m2TimeoutMs)
    if ($m2Timeout) { $m2Process.Kill($true); $m2Process.WaitForExit() }
    $m2Text=$m2Out.GetAwaiter().GetResult()+$m2Err.GetAwaiter().GetResult()
    $m2Log=Join-Path $m2Evidence ($Name+'.output.log'); [IO.File]::WriteAllText($m2Log,$m2Text)
    $m2Payload=$null
    $m2Pass= -not $m2Timeout -and $m2Process.ExitCode -eq 0 -and $m2Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    if ($Marker) {
        $m2Match=[regex]::Match($m2Text,'(?m)^'+$Marker+' (.+)$')
        if ($m2Match.Success) { $m2Payload=ConvertFrom-Json $m2Match.Groups[1].Value }
        $m2Pass=$m2Pass -and $null -ne $m2Payload -and $m2Payload.ok
        if ($Count -gt 0) { $m2Pass=$m2Pass -and $m2Payload.count -eq $Count }
        if ($m2Payload.checks) { $m2Pass=$m2Pass -and @($m2Payload.checks | Where-Object {-not $_.ok}).Count -eq 0 }
    }
    $m2Runs.Add(@{name=$Name;ok=$m2Pass;started_utc=$m2Started;finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$m2Process.ExitCode;timed_out=$m2Timeout;timeout_ms=$m2TimeoutMs;arguments=$Arguments;output_sha256=(Get-FileHash -LiteralPath $m2Log).Hash;result=$m2Payload})
    [IO.File]::WriteAllText((Join-Path $m2Evidence 'runs.json'),(ConvertTo-Json -InputObject @($m2Runs.ToArray()) -Depth 20))
    $m2Process.Dispose()
    Write-Output ($Name+': '+$m2Pass)
    if (-not $m2Pass) { Write-Output $m2Text; throw ('M2 failed: '+$Name) }
}
Invoke-M2 'import' @('--headless','--editor','--import','--quit')
Invoke-M2 'terrain' @('--headless','--script','res://tests/map_editor_terrain_test.gd') 'M2_RESULT' 102
Invoke-M2 'cli_a' @('--headless','--script','res://scripts/map_authoring/compiler/headless.gd','--',$m2Runs[1].result.source_path) 'MAP_TERRAIN_RESULT'
Invoke-M2 'cli_b' @('--headless','--script','res://scripts/map_authoring/compiler/headless.gd','--',$m2Runs[1].result.source_path) 'MAP_TERRAIN_RESULT'
if ($m2Runs[1].result.package_hash -ne $m2Runs[2].result.output_hash -or $m2Runs[2].result.output_hash -ne $m2Runs[3].result.output_hash) { throw 'Independent process compilation mismatch.' }
Invoke-M2 'terrain_scale' @('--headless','--script','res://tests/map_editor_terrain_scale_test.gd') 'M2_SCALE_RESULT' 46
$m2Scale = $m2Runs[$m2Runs.Count-1].result
Invoke-M2 'large_cli_a' @('--headless','--script','res://scripts/map_authoring/compiler/headless.gd','--',$m2Scale.source_path) 'MAP_TERRAIN_RESULT'
Invoke-M2 'large_cli_b' @('--headless','--script','res://scripts/map_authoring/compiler/headless.gd','--',$m2Scale.source_path) 'MAP_TERRAIN_RESULT'
if ($m2Runs[$m2Runs.Count-1].result.output_hash -ne $m2Scale.package_hash -or $m2Runs[$m2Runs.Count-2].result.output_hash -ne $m2Scale.package_hash) { throw 'Large GUI/headless package hash mismatch.' }
# A fresh destination for document IO regression, then remove no source data.
Invoke-M2 'document_regression' @('--headless','--script','res://tests/map_editor_document_test.gd') 'M1_RESULT' 70
if ($Native) {
    $m2Driver=Join-Path $m2Fixture 'addons/m2_driver'
    [void](New-Item -ItemType Directory -Force -Path $m2Driver)
    Copy-Item -LiteralPath (Join-Path $m2Root 'tests/map_editor_terrain_ui_test.gd') -Destination (Join-Path $m2Driver 'plugin.gd') -Force
    '[plugin]', 'name="Fixture F2"', 'description="Teste isolado"', 'author="RagRPG"', 'version="1"', 'script="plugin.gd"' | Set-Content -LiteralPath (Join-Path $m2Driver 'plugin.cfg') -Encoding utf8
    Add-Content -LiteralPath (Join-Path $m2Fixture 'project.godot') -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/m2_driver/plugin.cfg`")" -Encoding utf8
    Invoke-M2 'native_ui' @('--editor','--rendering-method','gl_compatibility') 'M2_UI_RESULT' 45
}
$m2Inputs=@()
foreach ($m2Dir in @('scripts/map_authoring','addons/ragrpg_map_editor','assets/art/map_authoring','tests/map_editor_terrain_scale_test.gd','tests/map_editor_terrain_test.gd','tests/map_editor_terrain_ui_test.gd','tests/map_editor_document_test.gd','tests/map_editor_document_ui_test.gd','tools/map_editor_terrain/run.ps1')) {
    $m2Path=Join-Path $m2Root $m2Dir
    if (-not (Test-Path -LiteralPath $m2Path)) { continue }
    foreach ($m2File in @(Get-ChildItem -LiteralPath $m2Path -Recurse -File)) {
        $m2Relative = [IO.Path]::GetRelativePath($m2Root,$m2File.FullName).Replace('\','/')
        $m2SourceHash = (Get-FileHash -LiteralPath $m2File.FullName).Hash
        $m2FixtureHash = (Get-FileHash -LiteralPath (Join-Path $m2Fixture $m2Relative)).Hash
        if ($m2SourceHash -ne $m2FixtureHash) { throw ('Source/fixture mismatch: '+$m2Relative) }
        $m2Inputs+=@{path=$m2Relative;sha256=$m2SourceHash;fixture_sha256=$m2FixtureHash}
    }
}
Copy-Item -LiteralPath (Join-Path $m2Fixture '.godot/terrain_measurements.json') -Destination $m2Evidence
Copy-Item -LiteralPath (Join-Path $m2Fixture '.godot/terrain_scale_measurements.json') -Destination $m2Evidence
@{engine=(Resolve-Path -LiteralPath $GodotPath).Path;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;inputs=$m2Inputs;runs=$m2Runs.ToArray()} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $m2Evidence 'manifest.json') -Encoding utf8
Write-Output 'M2_ALL_PASS'
