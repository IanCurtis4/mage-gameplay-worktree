param([Parameter(Mandatory)][string]$GodotPath,[Parameter(Mandatory)][string]$EvidenceDirectory,[switch]$Native,[string]$ReuseFixture = '',[switch]$UIOnly)
$ErrorActionPreference = 'Stop'
# Checkpoint42: every test compiles for real; the editor cache is opt-in.
$env:RAGRPG_COMPILE_CACHE='0'
$m4Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$m4Evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
if (Test-Path -LiteralPath $m4Evidence) { throw 'Use an absent evidence directory.' }
[void](New-Item -ItemType Directory -Force -Path $m4Evidence)
$m4Fixture = if ($ReuseFixture) { [IO.Path]::GetFullPath($ReuseFixture) } else { Join-Path $m4Evidence 'fixture' }
if (-not $ReuseFixture) {
    [void](New-Item -ItemType Directory -Force -Path $m4Fixture)
    foreach ($m4Dir in @('scripts','scenes','assets','data','resources','content','addons','tests','tools')) {
        $m4Path = Join-Path $m4Root $m4Dir
        if (Test-Path -LiteralPath $m4Path) { Copy-Item -LiteralPath $m4Path -Destination $m4Fixture -Recurse }
    }
}
# Refresh only task-owned/editor sources, preserving the imported fixture cache.
foreach ($m4Dir in @('scripts/map_authoring','addons/ragrpg_map_editor')) {
    Copy-Item -LiteralPath (Join-Path $m4Root $m4Dir) -Destination (Split-Path -Parent (Join-Path $m4Fixture $m4Dir)) -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $m4Root 'tools') -Destination $m4Fixture -Recurse -Force
Copy-Item -LiteralPath (Join-Path $m4Root 'assets/art/map_authoring') -Destination (Join-Path $m4Fixture 'assets/art') -Recurse -Force
foreach ($m4File in @('map_editor_population_test.gd','map_editor_population_ui_test.gd','map_editor_document_test.gd')) {
    $m4Path = Join-Path $m4Root ('tests/'+$m4File)
    if (Test-Path -LiteralPath $m4Path) { Copy-Item -LiteralPath $m4Path -Destination (Join-Path $m4Fixture 'tests') -Force }
}
$m4Config = (Get-Content -LiteralPath (Join-Path $m4Root 'project.godot') -Raw).Replace('version_control/autoload_on_startup=true','version_control/autoload_on_startup=false')
[IO.File]::WriteAllText((Join-Path $m4Fixture 'project.godot'), $m4Config)
$m4Isolation = Join-Path $m4Fixture '.godot/profile'
[void](New-Item -ItemType Directory -Force -Path $m4Isolation)
$m4HeadBefore = git -C $m4Root rev-parse HEAD
$m4Runs = [Collections.Generic.List[object]]::new()
function Invoke-M4([string]$Name,[string[]]$Arguments,[string]$Marker = '',[int]$Count = 0) {
    $m4Info = [Diagnostics.ProcessStartInfo]::new()
    $m4Info.FileName = (Resolve-Path -LiteralPath $GodotPath).Path
    $m4Info.UseShellExecute = $false
    $m4Info.CreateNoWindow = $true
    $m4Info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $m4Info.RedirectStandardOutput = $true
    $m4Info.RedirectStandardError = $true
    $m4Info.Environment['APPDATA'] = $m4Isolation
    $m4Info.Environment['LOCALAPPDATA'] = $m4Isolation
    $m4Info.Environment['M4_CAPTURE'] = Join-Path $m4Evidence 'terrain.png'
    foreach ($m4Arg in @('--path',$m4Fixture,'--log-file',(Join-Path $m4Evidence ($Name+'.engine.log'))) + $Arguments) { $m4Info.ArgumentList.Add($m4Arg) }
    $m4Process = [Diagnostics.Process]::new(); $m4Process.StartInfo=$m4Info
    $m4Started = [DateTime]::UtcNow.ToString('o')
    [void]$m4Process.Start()
    $m4Out = $m4Process.StandardOutput.ReadToEndAsync(); $m4Err = $m4Process.StandardError.ReadToEndAsync()
    $m4TimeoutMs = if ($Name -in @('population','native_ui')) { 180000 } else { 60000 }
    $m4Watch = [Diagnostics.Stopwatch]::StartNew()
    $m4Timeout = $false
    $m4Aborted = $false
    while (-not $m4Process.WaitForExit(500)) {
        if ($m4Watch.ElapsedMilliseconds -gt $m4TimeoutMs) { $m4Timeout=$true; break }
        $m4EngineLog = Join-Path $m4Evidence ($Name+'.engine.log')
        try {
            $m4LiveText = Get-Content -LiteralPath $m4EngineLog -Raw -ErrorAction SilentlyContinue
            if ($m4LiveText -match 'SCRIPT ERROR:|Parse Error:|ERROR:') { $m4Aborted=$true; break }
        } catch [IO.IOException] { } # The writer may hold the file briefly; stdout is checked at completion.
    }
    if ($m4Timeout -or $m4Aborted) { $m4Process.Kill($true); $m4Process.WaitForExit() }
    $m4Text=$m4Out.GetAwaiter().GetResult()+$m4Err.GetAwaiter().GetResult()
    $m4Log=Join-Path $m4Evidence ($Name+'.output.log'); [IO.File]::WriteAllText($m4Log,$m4Text)
    $m4Payload=$null
    $m4Pass= -not $m4Timeout -and -not $m4Aborted -and $m4Process.ExitCode -eq 0 -and $m4Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    if ($Marker) {
        $m4Match=[regex]::Match($m4Text,'(?m)^'+$Marker+' (.+)$')
        if ($m4Match.Success) { $m4Payload=ConvertFrom-Json $m4Match.Groups[1].Value }
        $m4Pass=$m4Pass -and $null -ne $m4Payload -and $m4Payload.ok
        if ($Count -gt 0) { $m4Pass=$m4Pass -and $m4Payload.count -eq $Count }
        if ($m4Payload.checks) { $m4Pass=$m4Pass -and @($m4Payload.checks | Where-Object {-not $_.ok}).Count -eq 0 }
    }
    $m4Runs.Add(@{name=$Name;ok=$m4Pass;started_utc=$m4Started;finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$m4Process.ExitCode;timed_out=$m4Timeout;aborted_on_error=$m4Aborted;timeout_ms=$m4TimeoutMs;arguments=$Arguments;output_sha256=(Get-FileHash -LiteralPath $m4Log).Hash;result=$m4Payload})
    [IO.File]::WriteAllText((Join-Path $m4Evidence 'runs.json'),(ConvertTo-Json -InputObject @($m4Runs.ToArray()) -Depth 20))
    $m4Process.Dispose()
    Write-Output ($Name+': '+$m4Pass)
    if (-not $m4Pass) { Write-Output $m4Text; throw ('M4 failed: '+$Name) }
}
Invoke-M4 'import' @('--headless','--editor','--import','--quit')
if (-not $UIOnly) {
Invoke-M4 'population' @('--headless','--script','res://tests/map_editor_population_test.gd') 'M4_RESULT' 91
Invoke-M4 'cli_a' @('--headless','--script','res://scripts/map_authoring/population/headless.gd','--',$m4Runs[1].result.source_path) 'MAP_POPULATION_RESULT'
Invoke-M4 'cli_b' @('--headless','--script','res://scripts/map_authoring/population/headless.gd','--',$m4Runs[1].result.source_path) 'MAP_POPULATION_RESULT'
if ($m4Runs[1].result.package_hash -ne $m4Runs[2].result.output_hash -or $m4Runs[2].result.output_hash -ne $m4Runs[3].result.output_hash) { throw 'Independent process mismatch.' }
Invoke-M4 'document_regression' @('--headless','--script','res://tests/map_editor_document_test.gd') 'M1_RESULT' 70
}
if ($Native -or $UIOnly) {
    $m4Driver=Join-Path $m4Fixture 'addons/m4_driver'
    [void](New-Item -ItemType Directory -Force -Path $m4Driver)
    Copy-Item -LiteralPath (Join-Path $m4Root 'tests/map_editor_population_ui_test.gd') -Destination (Join-Path $m4Driver 'plugin.gd') -Force
    '[plugin]', 'name="Fixture F4"', 'description="Teste isolado"', 'author="RagRPG"', 'version="1"', 'script="plugin.gd"' | Set-Content -LiteralPath (Join-Path $m4Driver 'plugin.cfg') -Encoding utf8
    Add-Content -LiteralPath (Join-Path $m4Fixture 'project.godot') -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/m4_driver/plugin.cfg`")" -Encoding utf8
    Invoke-M4 'native_ui' @('--editor','--rendering-method','gl_compatibility') 'M4_UI_RESULT' 29
}
$m4Inputs=@()
foreach ($m4Dir in @('scripts','resources','content','data','addons/ragrpg_map_editor','assets','tests/map_editor_population_test.gd','tests/map_editor_population_ui_test.gd','tests/map_editor_document_test.gd','tools/map_editor_population/run.ps1')) {
    $m4Path=Join-Path $m4Root $m4Dir
    if (-not (Test-Path -LiteralPath $m4Path)) { continue }
    foreach ($m4File in @(Get-ChildItem -LiteralPath $m4Path -Recurse -File)) {
        if ($m4File.Name.EndsWith('.import')) { continue }
        $m4Relative = [IO.Path]::GetRelativePath($m4Root,$m4File.FullName).Replace('\','/')
        $m4SourceHash = (Get-FileHash -LiteralPath $m4File.FullName).Hash
        $m4FixtureHash = (Get-FileHash -LiteralPath (Join-Path $m4Fixture $m4Relative)).Hash
        if ($m4SourceHash -ne $m4FixtureHash) { throw ('Source/fixture mismatch: '+$m4Relative) }
        $m4Inputs+=@{path=$m4Relative;sha256=$m4SourceHash;fixture_sha256=$m4FixtureHash}
    }
}
@{selection=$(if ($UIOnly) {"ui_only"} else {"population_cli_document_native"});project_source_sha256=(Get-FileHash -LiteralPath (Join-Path $m4Root "project.godot")).Hash;project_fixture_sha256=(Get-FileHash -LiteralPath (Join-Path $m4Fixture "project.godot")).Hash;declared_project_deltas=@("VCS startup disabled", "Native fixture driver enabled when selected");head_before=$m4HeadBefore;head_after=(git -C $m4Root rev-parse HEAD);engine=(Resolve-Path -LiteralPath $GodotPath).Path;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;inputs=$m4Inputs;runs=$m4Runs.ToArray()} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $m4Evidence 'manifest.json') -Encoding utf8
Write-Output 'M4_ALL_PASS'
