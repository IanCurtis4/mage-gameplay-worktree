param([Parameter(Mandatory)][string]$GodotPath,[Parameter(Mandatory)][string]$EvidenceDirectory,[switch]$Native,[string]$ReuseFixture='',[switch]$UIOnly)
$ErrorActionPreference='Stop'
# Checkpoint42: every test compiles for real; the editor cache is opt-in.
$env:RAGRPG_COMPILE_CACHE='0'
$m5Root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$m5GitRoot=git -C $m5Root rev-parse --show-toplevel
if($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($m5GitRoot) -ne [IO.Path]::GetFullPath($m5Root)){throw 'Invoke this runner only from the source checkout; a fixture runner would create a nested copy.'}
$m5Evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if(Test-Path -LiteralPath $m5Evidence){throw 'Use an absent evidence directory.'}
[void](New-Item -ItemType Directory -Force -Path $m5Evidence)
$m5Fixture=if($ReuseFixture){[IO.Path]::GetFullPath($ReuseFixture)}else{Join-Path $m5Root '.godot/m5_fixture'}
[void](New-Item -ItemType Directory -Force -Path $m5Fixture)
foreach($m5Dir in @('scripts','scenes','assets','data','resources','content','addons','tests','tools')){
    foreach($m5File in Get-ChildItem -LiteralPath (Join-Path $m5Root $m5Dir) -Recurse -File){
        $m5Target=Join-Path $m5Fixture ([IO.Path]::GetRelativePath($m5Root,$m5File.FullName))
        if(Test-Path -LiteralPath $m5Target){
            if($m5File.Name.EndsWith('.import')){continue}
            if((Get-FileHash -LiteralPath $m5File.FullName).Hash -eq (Get-FileHash -LiteralPath $m5Target).Hash){continue}
        }
        [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $m5Target))
        Copy-Item -LiteralPath $m5File.FullName -Destination $m5Target -Force
    }
}
$m5Project=(Get-Content -LiteralPath (Join-Path $m5Root 'project.godot') -Raw).Replace('version_control/autoload_on_startup=true','version_control/autoload_on_startup=false')
[IO.File]::WriteAllText((Join-Path $m5Fixture 'project.godot'),$m5Project)
$m5Profile=Join-Path $m5Fixture '.godot/discardable_profile'
[void](New-Item -ItemType Directory -Force -Path $m5Profile)
$m5Head=git -C $m5Root rev-parse HEAD
if(Test-Path -LiteralPath (Join-Path $m5Fixture 'addons/m5_driver/plugin.gd')){Copy-Item -LiteralPath (Join-Path $m5Root 'tests/map_editor_patrol_ui_test.gd') -Destination (Join-Path $m5Fixture 'addons/m5_driver/plugin.gd') -Force}
$m5Runs=[Collections.Generic.List[object]]::new()
function Invoke-M5([string]$Name,[string[]]$Arguments,[string]$Marker=''){
    $m5Info=[Diagnostics.ProcessStartInfo]::new()
    $m5Info.FileName=(Resolve-Path -LiteralPath $GodotPath).Path
    $m5Info.UseShellExecute=$false; $m5Info.CreateNoWindow=$true; $m5Info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $m5Info.RedirectStandardOutput=$true; $m5Info.RedirectStandardError=$true
    $m5Info.Environment['APPDATA']=$m5Profile; $m5Info.Environment['LOCALAPPDATA']=$m5Profile
    $m5Info.Environment['M5_EVIDENCE']=$m5Evidence
    foreach($m5Arg in @('--path',$m5Fixture,'--log-file',(Join-Path $m5Evidence ($Name+'.engine.log')))+$Arguments){$m5Info.ArgumentList.Add($m5Arg)}
    $m5Process=[Diagnostics.Process]::new(); $m5Process.StartInfo=$m5Info
    $m5Start=[DateTime]::UtcNow.ToString('o'); [void]$m5Process.Start()
    $m5Out=$m5Process.StandardOutput.ReadToEndAsync(); $m5Err=$m5Process.StandardError.ReadToEndAsync()
    $m5Watch=[Diagnostics.Stopwatch]::StartNew(); $m5Timeout=$false; $m5Aborted=$false
    while(-not $m5Process.WaitForExit(500)){
        if($m5Watch.ElapsedMilliseconds -gt 300000){$m5Timeout=$true; break}
        try{
            $m5Live=Get-Content -LiteralPath (Join-Path $m5Evidence ($Name+'.engine.log')) -Raw -ErrorAction SilentlyContinue
            if($m5Live -match 'SCRIPT ERROR:|Parse Error:|ERROR:'){$m5Aborted=$true; break}
        }catch [IO.IOException]{}
    }
    if($m5Timeout -or $m5Aborted){$m5Process.Kill($true); $m5Process.WaitForExit()}
    $m5Text=$m5Out.GetAwaiter().GetResult()+$m5Err.GetAwaiter().GetResult()
    $m5Log=Join-Path $m5Evidence ($Name+'.output.log'); [IO.File]::WriteAllText($m5Log,$m5Text)
    $m5Payload=$null
    $m5EngineText=Get-Content -LiteralPath (Join-Path $m5Evidence ($Name+'.engine.log')) -Raw
    $m5Pass= -not $m5Timeout -and -not $m5Aborted -and $m5Process.ExitCode -eq 0 -and $m5Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    $m5Pass=$m5Pass -and $m5EngineText -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    if($Marker){
        $m5Match=[regex]::Match($m5Text,'(?m)^'+$Marker+' (.+)$')
        if($m5Match.Success){$m5Payload=ConvertFrom-Json $m5Match.Groups[1].Value}
        $m5Pass=$m5Pass -and $null -ne $m5Payload -and $m5Payload.ok -and $m5Payload.count -gt 0 -and @($m5Payload.checks|Where-Object {-not $_.ok}).Count -eq 0
        $m5Expected=@{patrol=58;restart_prepare=33;restart_resume=21;native_ui=19}
        if($m5Expected.ContainsKey($Name)){$m5Pass=$m5Pass -and $m5Payload.count -eq $m5Expected[$Name] -and @($m5Payload.checks).Count -eq $m5Expected[$Name]}
    }
    $m5Runs.Add(@{name=$Name;ok=$m5Pass;arguments=$Arguments;started_utc=$m5Start;finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$m5Process.ExitCode;timed_out=$m5Timeout;aborted=$m5Aborted;output_sha256=(Get-FileHash -LiteralPath $m5Log).Hash;result=$m5Payload})
    [IO.File]::WriteAllText((Join-Path $m5Evidence 'runs.json'),(ConvertTo-Json -InputObject @($m5Runs.ToArray()) -Depth 30))
    $m5Process.Dispose(); Write-Output ($Name+': '+$m5Pass)
    if(-not $m5Pass){Write-Output $m5Text; throw ('M5 failed: '+$Name)}
}
Invoke-M5 'import' @('--headless','--editor','--import','--quit')
if(-not $UIOnly){
Invoke-M5 'patrol' @('--headless','--script','res://tests/map_editor_patrol_test.gd') 'M5_RESULT'
foreach($m5Mode in @('prepare','resume')){Invoke-M5 ('restart_'+$m5Mode) @('--headless','--script','res://tests/map_editor_patrol_restart_test.gd','--',$m5Mode) 'M5_RESTART_RESULT'}
foreach($m5Label in @('a','b')){Invoke-M5 ('cli_'+$m5Label) @('--headless','--script','res://scripts/map_authoring/patrol/headless.gd','--',(Join-Path $m5Fixture '.godot/m5_samples/patrols.json'))}
$m5HashA=[regex]::Match((Get-Content -LiteralPath (Join-Path $m5Evidence 'cli_a.output.log') -Raw),'MAP_PATROL_RESULT (.+)').Groups[1].Value|ConvertFrom-Json
$m5HashB=[regex]::Match((Get-Content -LiteralPath (Join-Path $m5Evidence 'cli_b.output.log') -Raw),'MAP_PATROL_RESULT (.+)').Groups[1].Value|ConvertFrom-Json
if(-not $m5HashA.ok -or -not $m5HashB.ok -or $m5HashA.output_hash -ne $m5Runs[1].result.package_hash -or $m5HashB.output_hash -ne $m5HashA.output_hash){throw 'CLI completion/hash mismatch.'}
}
if($Native -or $UIOnly){
    $m5Driver=Join-Path $m5Fixture 'addons/m5_driver'; [void](New-Item -ItemType Directory -Force -Path $m5Driver)
    Copy-Item -LiteralPath (Join-Path $m5Root 'tests/map_editor_patrol_ui_test.gd') -Destination (Join-Path $m5Driver 'plugin.gd') -Force
    '[plugin]','name="Fixture F5"','description="Teste isolado"','author="RagRPG"','version="1"','script="plugin.gd"'|Set-Content -LiteralPath (Join-Path $m5Driver 'plugin.cfg') -Encoding utf8
    Add-Content -LiteralPath (Join-Path $m5Fixture 'project.godot') -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/m5_driver/plugin.cfg`")" -Encoding utf8
    Invoke-M5 'native_ui' @('--editor','--rendering-method','gl_compatibility') 'M5_UI_RESULT'
}
$m5Inputs=@()
foreach($m5Dir in @('scripts','resources','content','data','assets','addons/ragrpg_map_editor','tests','tools')){
    foreach($m5File in Get-ChildItem -LiteralPath (Join-Path $m5Root $m5Dir) -Recurse -File){
        if($m5File.Name.EndsWith('.import')){continue}
        $m5Relative=[IO.Path]::GetRelativePath($m5Root,$m5File.FullName).Replace('\','/')
        $m5SourceHash=(Get-FileHash -LiteralPath $m5File.FullName).Hash
        $m5FixtureHash=(Get-FileHash -LiteralPath (Join-Path $m5Fixture $m5Relative)).Hash
        if($m5SourceHash -ne $m5FixtureHash){throw ('Source/fixture mismatch: '+$m5Relative)}
        $m5Inputs+=@{path=$m5Relative;sha256=$m5SourceHash;fixture_sha256=$m5FixtureHash}
    }
}
@{head_before=$m5Head;head_after=(git -C $m5Root rev-parse HEAD);engine=(Resolve-Path -LiteralPath $GodotPath).Path;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;fixture=$m5Fixture;project_source_sha256=(Get-FileHash -LiteralPath (Join-Path $m5Root 'project.godot')).Hash;project_fixture_sha256=(Get-FileHash -LiteralPath (Join-Path $m5Fixture 'project.godot')).Hash;declared_project_deltas=@('VCS startup disabled','UI driver only when Native');inputs=$m5Inputs;runs=$m5Runs.ToArray()}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $m5Evidence 'manifest.json') -Encoding utf8
Write-Output 'M5_ALL_PASS'
