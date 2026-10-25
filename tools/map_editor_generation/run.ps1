param([Parameter(Mandatory)][string]$GodotPath,[Parameter(Mandatory)][string]$EvidenceDirectory,[switch]$Native,[string]$ReuseFixture='',[switch]$UIOnly)
$ErrorActionPreference='Stop'
$m6Root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$m6GitRoot=git -C $m6Root rev-parse --show-toplevel
if($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($m6GitRoot) -ne [IO.Path]::GetFullPath($m6Root)){throw 'Invoke this runner only from the source checkout; a fixture runner would create a nested copy.'}
$m6Evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if(Test-Path -LiteralPath $m6Evidence){throw 'Use an absent evidence directory.'}
[void](New-Item -ItemType Directory -Force -Path $m6Evidence)
$m6Fixture=if($ReuseFixture){[IO.Path]::GetFullPath($ReuseFixture)}else{Join-Path $m6Root '.godot/verification/e07_f1/fixture_project'}
[void](New-Item -ItemType Directory -Force -Path $m6Fixture)
foreach($m6Dir in @('scripts','scenes','assets','data','resources','content','addons','tests','tools')){
    foreach($m6File in Get-ChildItem -LiteralPath (Join-Path $m6Root $m6Dir) -Recurse -File){
        $m6Target=Join-Path $m6Fixture ([IO.Path]::GetRelativePath($m6Root,$m6File.FullName))
        if(Test-Path -LiteralPath $m6Target){
            if($m6File.Name.EndsWith('.import')){continue}
            if((Get-FileHash -LiteralPath $m6File.FullName).Hash -eq (Get-FileHash -LiteralPath $m6Target).Hash){continue}
        }
        [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $m6Target))
        Copy-Item -LiteralPath $m6File.FullName -Destination $m6Target -Force
    }
}
$m6Project=(Get-Content -LiteralPath (Join-Path $m6Root 'project.godot') -Raw).Replace('version_control/autoload_on_startup=true','version_control/autoload_on_startup=false')
[IO.File]::WriteAllText((Join-Path $m6Fixture 'project.godot'),$m6Project)
$m6Profile=Join-Path $m6Fixture '.godot/discardable_profile'
[void](New-Item -ItemType Directory -Force -Path $m6Profile)
$m6Head=git -C $m6Root rev-parse HEAD
if(Test-Path -LiteralPath (Join-Path $m6Fixture 'addons/m6_driver/plugin.gd')){Copy-Item -LiteralPath (Join-Path $m6Root 'tests/map_editor_generation_ui_test.gd') -Destination (Join-Path $m6Fixture 'addons/m6_driver/plugin.gd') -Force}
$m6Runs=[Collections.Generic.List[object]]::new()
function Invoke-M6([string]$Name,[string[]]$Arguments,[string]$Marker=''){
    $m6Info=[Diagnostics.ProcessStartInfo]::new()
    $m6Info.FileName=(Resolve-Path -LiteralPath $GodotPath).Path
    $m6Info.UseShellExecute=$false; $m6Info.CreateNoWindow=$true; $m6Info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $m6Info.RedirectStandardOutput=$true; $m6Info.RedirectStandardError=$true
    $m6Info.Environment['APPDATA']=$m6Profile; $m6Info.Environment['LOCALAPPDATA']=$m6Profile
    $m6Info.Environment['M6_EVIDENCE']=$m6Evidence
    foreach($m6Arg in @('--path',$m6Fixture,'--log-file',(Join-Path $m6Evidence ($Name+'.engine.log')))+$Arguments){$m6Info.ArgumentList.Add($m6Arg)}
    $m6Process=[Diagnostics.Process]::new(); $m6Process.StartInfo=$m6Info
    $m6Start=[DateTime]::UtcNow.ToString('o'); [void]$m6Process.Start()
    $m6Out=$m6Process.StandardOutput.ReadToEndAsync(); $m6Err=$m6Process.StandardError.ReadToEndAsync()
    $m6Watch=[Diagnostics.Stopwatch]::StartNew(); $m6Timeout=$false; $m6Aborted=$false
    while(-not $m6Process.WaitForExit(500)){
        if($m6Watch.ElapsedMilliseconds -gt 300000){$m6Timeout=$true; break}
        try{
            $m6Live=Get-Content -LiteralPath (Join-Path $m6Evidence ($Name+'.engine.log')) -Raw -ErrorAction SilentlyContinue
            if($m6Live -match 'SCRIPT ERROR:|Parse Error:|ERROR:'){$m6Aborted=$true; break}
        }catch [IO.IOException]{}
    }
    if($m6Timeout -or $m6Aborted){$m6Process.Kill($true); $m6Process.WaitForExit()}
    $m6Text=$m6Out.GetAwaiter().GetResult()+$m6Err.GetAwaiter().GetResult()
    $m6Log=Join-Path $m6Evidence ($Name+'.output.log'); [IO.File]::WriteAllText($m6Log,$m6Text)
    $m6Payload=$null
    $m6EngineText=Get-Content -LiteralPath (Join-Path $m6Evidence ($Name+'.engine.log')) -Raw
    $m6Pass= -not $m6Timeout -and -not $m6Aborted -and $m6Process.ExitCode -eq 0 -and $m6Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    $m6Pass=$m6Pass -and $m6EngineText -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    if($Marker){
        $m6Match=[regex]::Match($m6Text,'(?m)^'+$Marker+' (.+)$')
        if($m6Match.Success){$m6Payload=ConvertFrom-Json $m6Match.Groups[1].Value}
        $m6Pass=$m6Pass -and $null -ne $m6Payload -and $m6Payload.ok -and $m6Payload.count -gt 0 -and @($m6Payload.checks|Where-Object {-not $_.ok}).Count -eq 0
        $m6Expected=@{generation=89;native_ui=28}
        if($m6Expected.ContainsKey($Name)){$m6Pass=$m6Pass -and $m6Payload.count -eq $m6Expected[$Name] -and @($m6Payload.checks).Count -eq $m6Expected[$Name]}
    }
    $m6Runs.Add(@{name=$Name;ok=$m6Pass;arguments=$Arguments;started_utc=$m6Start;finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$m6Process.ExitCode;timed_out=$m6Timeout;aborted=$m6Aborted;output_sha256=(Get-FileHash -LiteralPath $m6Log).Hash;result=$m6Payload})
    [IO.File]::WriteAllText((Join-Path $m6Evidence 'runs.json'),(ConvertTo-Json -InputObject @($m6Runs.ToArray()) -Depth 30))
    $m6Process.Dispose(); Write-Output ($Name+': '+$m6Pass)
    if(-not $m6Pass){Write-Output $m6Text; throw ('M6 failed: '+$Name)}
}
Invoke-M6 'import' @('--headless','--editor','--import','--quit')
if(-not $UIOnly){
Invoke-M6 'generation' @('--headless','--script','res://tests/map_editor_generation_test.gd') 'M6_RESULT'
foreach($m6Label in @('a','b')){Invoke-M6 ('cli_'+$m6Label) @('--headless','--script','res://scripts/map_authoring/generation/headless.gd','--',(Join-Path $m6Fixture '.godot/m6_samples/generation.json'),'--experimental-wfc')}
$m6HashA=[regex]::Match((Get-Content -LiteralPath (Join-Path $m6Evidence 'cli_a.output.log') -Raw),'MAP_GENERATION_RESULT (.+)').Groups[1].Value|ConvertFrom-Json
$m6HashB=[regex]::Match((Get-Content -LiteralPath (Join-Path $m6Evidence 'cli_b.output.log') -Raw),'MAP_GENERATION_RESULT (.+)').Groups[1].Value|ConvertFrom-Json
if(-not $m6HashA.ok -or -not $m6HashB.ok -or $m6HashA.output_hash -ne $m6Runs[1].result.package_hash -or $m6HashB.output_hash -ne $m6HashA.output_hash){throw 'CLI completion/hash mismatch.'}
}
if($Native -or $UIOnly){
    $m6Driver=Join-Path $m6Fixture 'addons/m6_driver'; [void](New-Item -ItemType Directory -Force -Path $m6Driver)
    Copy-Item -LiteralPath (Join-Path $m6Root 'tests/map_editor_generation_ui_test.gd') -Destination (Join-Path $m6Driver 'plugin.gd') -Force
    '[plugin]','name="Fixture F6"','description="Teste isolado"','author="RagRPG"','version="1"','script="plugin.gd"'|Set-Content -LiteralPath (Join-Path $m6Driver 'plugin.cfg') -Encoding utf8
    Add-Content -LiteralPath (Join-Path $m6Fixture 'project.godot') -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/m6_driver/plugin.cfg`")" -Encoding utf8
    Invoke-M6 'native_ui' @('--editor','--rendering-method','gl_compatibility') 'M6_UI_RESULT'
}
$m6Inputs=@()
foreach($m6Dir in @('scripts','resources','content','data','assets','addons/ragrpg_map_editor','tests','tools')){
    foreach($m6File in Get-ChildItem -LiteralPath (Join-Path $m6Root $m6Dir) -Recurse -File){
        if($m6File.Name.EndsWith('.import')){continue}
        $m6Relative=[IO.Path]::GetRelativePath($m6Root,$m6File.FullName).Replace('\','/')
        $m6SourceHash=(Get-FileHash -LiteralPath $m6File.FullName).Hash
        $m6FixtureHash=(Get-FileHash -LiteralPath (Join-Path $m6Fixture $m6Relative)).Hash
        if($m6SourceHash -ne $m6FixtureHash){throw ('Source/fixture mismatch: '+$m6Relative)}
        $m6Inputs+=@{path=$m6Relative;sha256=$m6SourceHash;fixture_sha256=$m6FixtureHash}
    }
}
@{head_before=$m6Head;head_after=(git -C $m6Root rev-parse HEAD);engine=(Resolve-Path -LiteralPath $GodotPath).Path;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;fixture=$m6Fixture;project_source_sha256=(Get-FileHash -LiteralPath (Join-Path $m6Root 'project.godot')).Hash;project_fixture_sha256=(Get-FileHash -LiteralPath (Join-Path $m6Fixture 'project.godot')).Hash;declared_project_deltas=@('VCS startup disabled','UI driver only when Native');inputs=$m6Inputs;runs=$m6Runs.ToArray()}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $m6Evidence 'manifest.json') -Encoding utf8
Write-Output 'M6_ALL_PASS'

# Prepare the same fixture for the official read-only checks. Preserve native
# project hashes above, then remove only the declared fixture-driver config.
[IO.File]::WriteAllText((Join-Path $m6Fixture 'project.godot'),$m6Project)
$m6Primary=@{}
foreach($m6Input in $m6Inputs){$m6Primary[$m6Input.path]=$m6Input.sha256.ToLowerInvariant()}
[IO.File]::WriteAllText((Join-Path $m6Fixture 'source_hashes.json'),(ConvertTo-Json -InputObject $m6Primary -Depth 5))
[IO.File]::WriteAllText((Join-Path $m6Fixture 'source_root.txt'),$m6Root)
