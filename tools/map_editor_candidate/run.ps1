param([Parameter(Mandatory)][string]$GodotPath,[Parameter(Mandatory)][string]$EvidenceDirectory,[string]$ReuseFixture='',[ValidateSet('Import','Candidate','Core','Native','Release','All')][string]$Stage='All')
$ErrorActionPreference='Stop'
$m8Root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$m8GitRoot=git -C $m8Root rev-parse --show-toplevel
if($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($m8GitRoot) -ne [IO.Path]::GetFullPath($m8Root)){throw 'Invoke this runner only from the source checkout; a fixture runner would create a nested copy.'}
$m8Evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if(Test-Path -LiteralPath $m8Evidence){throw 'Use an absent evidence directory.'}
[void](New-Item -ItemType Directory -Force -Path $m8Evidence)
$m8Fixture=if($ReuseFixture){[IO.Path]::GetFullPath($ReuseFixture)}else{Join-Path $m8Root '.godot/verification/e07_f1/fixture_project'}
[void](New-Item -ItemType Directory -Force -Path $m8Fixture)
foreach($m8Dir in @('scripts','scenes','assets','data','resources','content','addons','tests','tools')){
    foreach($m8File in Get-ChildItem -LiteralPath (Join-Path $m8Root $m8Dir) -Recurse -File){
        $m8Target=Join-Path $m8Fixture ([IO.Path]::GetRelativePath($m8Root,$m8File.FullName))
        if(Test-Path -LiteralPath $m8Target){
            if($m8File.Name.EndsWith('.import')){continue}
            if((Get-FileHash -LiteralPath $m8File.FullName).Hash -eq (Get-FileHash -LiteralPath $m8Target).Hash){continue}
        }
        [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $m8Target))
        Copy-Item -LiteralPath $m8File.FullName -Destination $m8Target -Force
    }
}
$m8Project=(Get-Content -LiteralPath (Join-Path $m8Root 'project.godot') -Raw).Replace('version_control/autoload_on_startup=true','version_control/autoload_on_startup=false')
[IO.File]::WriteAllText((Join-Path $m8Fixture 'project.godot'),$m8Project)
$m8Profile=Join-Path $m8Fixture '.godot/discardable_profile'
[void](New-Item -ItemType Directory -Force -Path $m8Profile)
$m8Head=git -C $m8Root rev-parse HEAD
if(Test-Path -LiteralPath (Join-Path $m8Fixture 'addons/m8_driver/plugin.gd')){Copy-Item -LiteralPath (Join-Path $m8Root 'tests/map_editor_candidate_ui_test.gd') -Destination (Join-Path $m8Fixture 'addons/m8_driver/plugin.gd') -Force}
$m8Runs=[Collections.Generic.List[object]]::new()
function Invoke-M8([string]$Name,[string[]]$Arguments,[string]$Marker='',[int]$ExpectedExit=0,[string]$Executable='',[switch]$Standalone){
    $m8Info=[Diagnostics.ProcessStartInfo]::new()
    $m8Info.FileName=(Resolve-Path -LiteralPath $(if ($Executable) {$Executable} else {$GodotPath})).Path
    $m8Info.UseShellExecute=$false; $m8Info.CreateNoWindow=$true; $m8Info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $m8Info.RedirectStandardOutput=$true; $m8Info.RedirectStandardError=$true
    $m8Info.Environment['APPDATA']=$m8Profile; $m8Info.Environment['LOCALAPPDATA']=$m8Profile
    $m8Info.Environment['M8_EVIDENCE']=$m8Evidence
    $m8Prefix=if($Standalone){@()}else{@('--path',$m8Fixture)}
    foreach($m8Arg in $m8Prefix+@('--log-file',(Join-Path $m8Evidence ($Name+'.engine.log')))+$Arguments){$m8Info.ArgumentList.Add($m8Arg)}
    $m8Process=[Diagnostics.Process]::new(); $m8Process.StartInfo=$m8Info
    $m8Start=[DateTime]::UtcNow.ToString('o'); [void]$m8Process.Start()
    $m8Out=$m8Process.StandardOutput.ReadToEndAsync(); $m8Err=$m8Process.StandardError.ReadToEndAsync()
    $m8Watch=[Diagnostics.Stopwatch]::StartNew(); $m8Timeout=$false; $m8Aborted=$false
    while(-not $m8Process.WaitForExit(500)){
        if($m8Watch.ElapsedMilliseconds -gt 300000){$m8Timeout=$true; break}
        try{
            $m8Live=Get-Content -LiteralPath (Join-Path $m8Evidence ($Name+'.engine.log')) -Raw -ErrorAction SilentlyContinue
            if($m8Live -match 'SCRIPT ERROR:|Parse Error:|ERROR:'){$m8Aborted=$true; break}
        }catch [IO.IOException]{}
    }
    if($m8Timeout -or $m8Aborted){$m8Process.Kill($true); $m8Process.WaitForExit()}
    $m8Text=$m8Out.GetAwaiter().GetResult()+$m8Err.GetAwaiter().GetResult()
    $m8Log=Join-Path $m8Evidence ($Name+'.output.log'); [IO.File]::WriteAllText($m8Log,$m8Text)
    $m8Payload=$null
    $m8EngineText=Get-Content -LiteralPath (Join-Path $m8Evidence ($Name+'.engine.log')) -Raw
    $m8Pass= -not $m8Timeout -and -not $m8Aborted -and $m8Process.ExitCode -eq $ExpectedExit -and $m8Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    $m8Pass=$m8Pass -and $m8EngineText -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    if($Marker){
        $m8Match=[regex]::Match($m8Text,'(?m)^'+$Marker+' (.+)$')
        if($m8Match.Success){$m8Payload=ConvertFrom-Json $m8Match.Groups[1].Value}
        $m8Pass=$m8Pass -and $null -ne $m8Payload -and $m8Payload.ok -and $m8Payload.count -gt 0 -and @($m8Payload.checks|Where-Object {-not $_.ok}).Count -eq 0
        $m8Expected=@{candidate=52;document=70;terrain=102;composition=63;population=91;patrol=58;generation=89;exchange=113;native_ui=48;release=6}
        if($m8Expected.ContainsKey($Name)){$m8Pass=$m8Pass -and $m8Payload.count -eq $m8Expected[$Name] -and @($m8Payload.checks).Count -eq $m8Expected[$Name]}
    }
    $m8Runs.Add(@{name=$Name;ok=$m8Pass;arguments=$Arguments;started_utc=$m8Start;finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$m8Process.ExitCode;timed_out=$m8Timeout;aborted=$m8Aborted;output_sha256=(Get-FileHash -LiteralPath $m8Log).Hash;result=$m8Payload})
    [IO.File]::WriteAllText((Join-Path $m8Evidence 'runs.json'),(ConvertTo-Json -InputObject @($m8Runs.ToArray()) -Depth 30))
    $m8Process.Dispose(); Write-Output ($Name+': '+$m8Pass)
    if(-not $m8Pass){Write-Output $m8Text; throw ('M8 failed: '+$Name)}
}
Invoke-M8 'import' @('--headless','--editor','--import','--quit')
if($Stage -in @('Candidate','Core','All')) {
    Invoke-M8 'candidate' @('--headless','--script','res://tests/map_editor_candidate_test.gd') 'M8_RESULT'
    if($Stage -ne 'Candidate') { foreach($m8Suite in @('document','terrain','composition','population','patrol','generation','exchange')) {
        Invoke-M8 $m8Suite @('--headless','--script',('res://tests/map_editor_'+$m8Suite+'_test.gd')) ('M'+@{document=1;terrain=2;composition=3;population=4;patrol=5;generation=6;exchange=7}[$m8Suite]+'_RESULT')
    }
}
}
if($Stage -in @('Native','All')) {
    $m8Driver=Join-Path $m8Fixture 'addons/m8_driver'; [void](New-Item -ItemType Directory -Force -Path $m8Driver)
    Copy-Item -LiteralPath (Join-Path $m8Root 'tests/map_editor_candidate_ui_test.gd') -Destination (Join-Path $m8Driver 'plugin.gd') -Force
    '[plugin]','name="Fixture F8"','description="Teste isolado"','author="RagRPG"','version="1"','script="plugin.gd"'|Set-Content -LiteralPath (Join-Path $m8Driver 'plugin.cfg') -Encoding utf8
    Add-Content -LiteralPath (Join-Path $m8Fixture 'project.godot') -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/ragrpg_map_editor/plugin.cfg`",`"res://addons/m8_driver/plugin.cfg`")" -Encoding utf8
    Invoke-M8 'native_ui' @('--editor','--rendering-method','gl_compatibility') 'M8_UI_RESULT'
}
if($Stage -in @('Release','All')) {
    $m8ReleaseRoot=Join-Path $m8Root '.godot/m8_release'; [void](New-Item -ItemType Directory -Force -Path $m8ReleaseRoot)
    $m8Exe=Join-Path $m8ReleaseRoot 'RagRPG-Map-Candidate.exe'
    $m8Template='C:/Users/João Pedro/AppData/Roaming/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe'
    if(-not (Test-Path -LiteralPath $m8Template)){throw 'Windows release template missing.'}
    $m8Preset=(Get-Content -LiteralPath (Join-Path $m8Root 'export_presets.cfg') -Raw).Replace('custom_template/release=""',('custom_template/release="'+$m8Template+'"')).Replace('exclude_filter=""','exclude_filter="addons/godot-git-plugin/*"').Replace('include_filter=""','include_filter="data/map_authoring/*.json,data/map_authoring/*.rpp,data/expedition/policies/*.json,scripts/core/expedition/snapshot/runtime_manifest.json"')
    [IO.File]::WriteAllText((Join-Path $m8Fixture 'export_presets.cfg'),$m8Preset)
    $m8ReleaseProject=$m8Project.Replace('run/main_scene="res://scenes/character_menu.tscn"','run/main_scene="res://data/map_authoring/candidate_preview.tscn"')+"`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/ragrpg_map_editor/plugin.cfg`")"
    [IO.File]::WriteAllText((Join-Path $m8Fixture 'project.godot'),$m8ReleaseProject)
    Invoke-M8 'export_release' @('--headless','--export-release','Windows Desktop',$m8Exe)
    Invoke-M8 'release' @('--','--m8-probe') 'M8_RELEASE_RESULT' 0 $m8Exe -Standalone
    @{template=$m8Template;template_sha256=(Get-FileHash -LiteralPath $m8Template).Hash;exe_sha256=(Get-FileHash -LiteralPath $m8Exe).Hash;pck_sha256=(Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($m8Exe,'.pck'))).Hash;project_sha256=(Get-FileHash -LiteralPath (Join-Path $m8Fixture 'project.godot')).Hash;preset_sha256=(Get-FileHash -LiteralPath (Join-Path $m8Fixture 'export_presets.cfg')).Hash}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $m8Evidence 'release_manifest.json') -Encoding utf8
}
$m8Inputs=@()
foreach($m8Dir in @('scripts','scenes','resources','content','data','assets','addons/ragrpg_map_editor','tests','tools')) {
    foreach($m8File in Get-ChildItem -LiteralPath (Join-Path $m8Root $m8Dir) -Recurse -File) {
        if($m8File.Name.EndsWith('.import')){continue}
        $m8Relative=[IO.Path]::GetRelativePath($m8Root,$m8File.FullName).Replace('\','/')
        $m8SourceHash=(Get-FileHash -LiteralPath $m8File.FullName).Hash
        $m8FixtureHash=(Get-FileHash -LiteralPath (Join-Path $m8Fixture $m8Relative)).Hash
        if($m8SourceHash -ne $m8FixtureHash){throw ('Source/fixture mismatch: '+$m8Relative)}
        $m8Inputs+=@{path=$m8Relative;sha256=$m8SourceHash;fixture_sha256=$m8FixtureHash}
    }
}
@{head_before=$m8Head;head_after=(git -C $m8Root rev-parse HEAD);engine=(Resolve-Path -LiteralPath $GodotPath).Path;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;fixture=$m8Fixture;project_source_sha256=(Get-FileHash -LiteralPath (Join-Path $m8Root 'project.godot')).Hash;project_fixture_sha256=(Get-FileHash -LiteralPath (Join-Path $m8Fixture 'project.godot')).Hash;declared_project_deltas=@('VCS startup disabled','Native: map editor and UI driver enabled','Release: candidate main scene and map editor enabled; isolated export preset');inputs=$m8Inputs;runs=$m8Runs.ToArray()}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $m8Evidence 'manifest.json') -Encoding utf8
Write-Output 'M8_SELECTED_PASS'
[IO.File]::WriteAllText((Join-Path $m8Fixture 'project.godot'),$m8Project)
$m8Primary=@{}
foreach($m8Input in $m8Inputs){$m8Primary[$m8Input.path]=$m8Input.sha256.ToLowerInvariant()}
[IO.File]::WriteAllText((Join-Path $m8Fixture 'source_hashes.json'),(ConvertTo-Json -InputObject $m8Primary -Depth 5))
[IO.File]::WriteAllText((Join-Path $m8Fixture 'source_root.txt'),$m8Root)