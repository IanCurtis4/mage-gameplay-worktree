param([Parameter(Mandatory)][string]$GodotPath,[Parameter(Mandatory)][string]$EvidenceDirectory,[switch]$Native,[string]$ReuseFixture = '')
$ErrorActionPreference = 'Stop'
$m3Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$m3Evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
if (Test-Path -LiteralPath $m3Evidence) { throw 'Use an absent evidence directory.' }
[void](New-Item -ItemType Directory -Force -Path $m3Evidence)
$m3Fixture = if ($ReuseFixture) { [IO.Path]::GetFullPath($ReuseFixture) } else { Join-Path $m3Evidence 'fixture' }
if (-not $ReuseFixture) {
    [void](New-Item -ItemType Directory -Force -Path $m3Fixture)
    foreach ($m3Dir in @('scripts','scenes','assets','data','resources','content','addons','tests','tools')) {
        $m3Path = Join-Path $m3Root $m3Dir
        if (Test-Path -LiteralPath $m3Path) { Copy-Item -LiteralPath $m3Path -Destination $m3Fixture -Recurse }
    }
}
# Refresh only task-owned/editor sources, preserving the imported fixture cache.
foreach ($m3Dir in @('scripts/map_authoring','addons/ragrpg_map_editor')) {
    Copy-Item -LiteralPath (Join-Path $m3Root $m3Dir) -Destination (Split-Path -Parent (Join-Path $m3Fixture $m3Dir)) -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $m3Root 'tools') -Destination $m3Fixture -Recurse -Force
Copy-Item -LiteralPath (Join-Path $m3Root 'assets/art/map_authoring') -Destination (Join-Path $m3Fixture 'assets/art') -Recurse -Force
foreach ($m3File in @('map_editor_composition_test.gd','map_editor_composition_ui_test.gd','map_editor_document_test.gd')) {
    $m3Path = Join-Path $m3Root ('tests/'+$m3File)
    if (Test-Path -LiteralPath $m3Path) { Copy-Item -LiteralPath $m3Path -Destination (Join-Path $m3Fixture 'tests') -Force }
}
$m3Config = (Get-Content -LiteralPath (Join-Path $m3Root 'project.godot') -Raw).Replace('version_control/autoload_on_startup=true','version_control/autoload_on_startup=false')
[IO.File]::WriteAllText((Join-Path $m3Fixture 'project.godot'), $m3Config)
$m3Isolation = Join-Path $m3Fixture '.godot/profile'
[void](New-Item -ItemType Directory -Force -Path $m3Isolation)
$m3Runs = [Collections.Generic.List[object]]::new()
function Invoke-M3([string]$Name,[string[]]$Arguments,[string]$Marker = '',[int]$Count = 0) {
    $m3Info = [Diagnostics.ProcessStartInfo]::new()
    $m3Info.FileName = (Resolve-Path -LiteralPath $GodotPath).Path
    $m3Info.UseShellExecute = $false
    $m3Info.CreateNoWindow = $true
    $m3Info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $m3Info.RedirectStandardOutput = $true
    $m3Info.RedirectStandardError = $true
    $m3Info.Environment['APPDATA'] = $m3Isolation
    $m3Info.Environment['LOCALAPPDATA'] = $m3Isolation
    $m3Info.Environment['M3_CAPTURE'] = Join-Path $m3Evidence 'terrain.png'
    foreach ($m3Arg in @('--path',$m3Fixture,'--log-file',(Join-Path $m3Evidence ($Name+'.engine.log'))) + $Arguments) { $m3Info.ArgumentList.Add($m3Arg) }
    $m3Process = [Diagnostics.Process]::new(); $m3Process.StartInfo=$m3Info
    $m3Started = [DateTime]::UtcNow.ToString('o')
    [void]$m3Process.Start()
    $m3Out = $m3Process.StandardOutput.ReadToEndAsync(); $m3Err = $m3Process.StandardError.ReadToEndAsync()
    $m3TimeoutMs = if ($Name -eq 'terrain_scale') { 180000 } else { 60000 }
    $m3Timeout = -not $m3Process.WaitForExit($m3TimeoutMs)
    if ($m3Timeout) { $m3Process.Kill($true); $m3Process.WaitForExit() }
    $m3Text=$m3Out.GetAwaiter().GetResult()+$m3Err.GetAwaiter().GetResult()
    $m3Log=Join-Path $m3Evidence ($Name+'.output.log'); [IO.File]::WriteAllText($m3Log,$m3Text)
    $m3Payload=$null
    $m3Pass= -not $m3Timeout -and $m3Process.ExitCode -eq 0 -and $m3Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    if ($Marker) {
        $m3Match=[regex]::Match($m3Text,'(?m)^'+$Marker+' (.+)$')
        if ($m3Match.Success) { $m3Payload=ConvertFrom-Json $m3Match.Groups[1].Value }
        $m3Pass=$m3Pass -and $null -ne $m3Payload -and $m3Payload.ok
        if ($Count -gt 0) { $m3Pass=$m3Pass -and $m3Payload.count -eq $Count }
        if ($m3Payload.checks) { $m3Pass=$m3Pass -and @($m3Payload.checks | Where-Object {-not $_.ok}).Count -eq 0 }
    }
    $m3Runs.Add(@{name=$Name;ok=$m3Pass;started_utc=$m3Started;finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$m3Process.ExitCode;timed_out=$m3Timeout;timeout_ms=$m3TimeoutMs;arguments=$Arguments;output_sha256=(Get-FileHash -LiteralPath $m3Log).Hash;result=$m3Payload})
    [IO.File]::WriteAllText((Join-Path $m3Evidence 'runs.json'),(ConvertTo-Json -InputObject @($m3Runs.ToArray()) -Depth 20))
    $m3Process.Dispose()
    Write-Output ($Name+': '+$m3Pass)
    if (-not $m3Pass) { Write-Output $m3Text; throw ('M3 failed: '+$Name) }
}
Invoke-M3 'import' @('--headless','--editor','--import','--quit')
Invoke-M3 'composition' @('--headless','--script','res://tests/map_editor_composition_test.gd') 'M3_RESULT' 63
Invoke-M3 'cli_a' @('--headless','--script','res://scripts/map_authoring/composition/headless.gd','--',$m3Runs[1].result.source_path) 'MAP_COMPOSITION_RESULT'
Invoke-M3 'cli_b' @('--headless','--script','res://scripts/map_authoring/composition/headless.gd','--',$m3Runs[1].result.source_path) 'MAP_COMPOSITION_RESULT'
if ($m3Runs[1].result.package_hash -ne $m3Runs[2].result.output_hash -or $m3Runs[2].result.output_hash -ne $m3Runs[3].result.output_hash) { throw 'Independent process mismatch.' }
Invoke-M3 'document_regression' @('--headless','--script','res://tests/map_editor_document_test.gd') 'M1_RESULT' 70
if ($Native) {
    $m3Driver=Join-Path $m3Fixture 'addons/m3_driver'
    [void](New-Item -ItemType Directory -Force -Path $m3Driver)
    Copy-Item -LiteralPath (Join-Path $m3Root 'tests/map_editor_composition_ui_test.gd') -Destination (Join-Path $m3Driver 'plugin.gd') -Force
    '[plugin]', 'name="Fixture F3"', 'description="Teste isolado"', 'author="RagRPG"', 'version="1"', 'script="plugin.gd"' | Set-Content -LiteralPath (Join-Path $m3Driver 'plugin.cfg') -Encoding utf8
    Add-Content -LiteralPath (Join-Path $m3Fixture 'project.godot') -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/m3_driver/plugin.cfg`")" -Encoding utf8
    Invoke-M3 'native_ui' @('--editor','--rendering-method','gl_compatibility') 'M3_UI_RESULT' 22
}
$m3Inputs=@()
foreach ($m3Dir in @('scripts/map_authoring','scripts/core/expedition','scripts/world/expedition_geometry_view.gd','addons/ragrpg_map_editor','assets/art/map_authoring','tests/map_editor_composition_test.gd','tests/map_editor_composition_ui_test.gd','tests/map_editor_document_test.gd','tools/map_editor_composition/run.ps1')) {
    $m3Path=Join-Path $m3Root $m3Dir
    if (-not (Test-Path -LiteralPath $m3Path)) { continue }
    foreach ($m3File in @(Get-ChildItem -LiteralPath $m3Path -Recurse -File)) {
        $m3Relative = [IO.Path]::GetRelativePath($m3Root,$m3File.FullName).Replace('\','/')
        $m3SourceHash = (Get-FileHash -LiteralPath $m3File.FullName).Hash
        $m3FixtureHash = (Get-FileHash -LiteralPath (Join-Path $m3Fixture $m3Relative)).Hash
        if ($m3SourceHash -ne $m3FixtureHash) { throw ('Source/fixture mismatch: '+$m3Relative) }
        $m3Inputs+=@{path=$m3Relative;sha256=$m3SourceHash;fixture_sha256=$m3FixtureHash}
    }
}
@{head=(git -C $m3Root rev-parse HEAD);engine=(Resolve-Path -LiteralPath $GodotPath).Path;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;inputs=$m3Inputs;runs=$m3Runs.ToArray()} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $m3Evidence 'manifest.json') -Encoding utf8
Write-Output 'M3_ALL_PASS'
