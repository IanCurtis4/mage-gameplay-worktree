param(
    [Parameter(Mandatory)][string]$GodotPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [switch]$SkipImport,
    [string]$ResumeSession="",
    [ValidateSet('Geometry','Objects','ObjectsNative','Mesh','Relief','Ports','Batch','Materials','MaterialsNative','Scale','Cliff','CliffNative','BiomeProps','BiomePropsNative','Borders','BordersNative','Shadows','ShadowsNative','CanvasOrder','Library','LibraryNative','Viewport','ViewportNative','RuntimeView','GameplayNative','GameplayWindow','GameplayControls','GameplayEditorNative','GameplayCli','FieldsNative','Organic','NavigationLazy','NavigationDense','NavigationContext','Rounded','RoundedNative','SnapshotDensity','RoundedResume','SurfacePick','Authoring','AuthoringNative','Content','ContentNative','CompositionAX','CompositionAXNative','MapBiome','MapBiomeNative','EncounterAuthoring','EncounterAuthoringNative','PopulationReachability')][string]$Stage='Geometry'
)
$ErrorActionPreference='Stop'
$f9Root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if([IO.Path]::GetFullPath((git -C $f9Root rev-parse --show-toplevel)) -ne [IO.Path]::GetFullPath($f9Root)){throw 'Use the source checkout runner.'}
$f9Evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if(Test-Path -LiteralPath $f9Evidence){throw 'Use an absent evidence directory.'}
[void](New-Item -ItemType Directory -Force -Path $f9Evidence)
$f9Fixture=Join-Path $f9Root '.godot/verification/e07_f1/fixture_project'
if(-not $SkipImport){
    & (Join-Path $f9Root 'tools/map_editor_candidate/run.ps1') -GodotPath $GodotPath -EvidenceDirectory (Join-Path $f9Evidence 'import') -ReuseFixture $f9Fixture -Stage Import
}else{
    if(-not (Test-Path -LiteralPath (Join-Path $f9Fixture '.godot/global_script_class_cache.cfg'))){throw 'Import the shared fixture first.'}
    foreach($f9Relative in @('scripts/core/expedition/spatial/world_geometry.gd','scripts/core/expedition/generation/fixture_geometry.gd','scripts/map_authoring/composition/map_compiler.gd','tests/map_editor_f9_geometry_test.gd')){
        Copy-Item -LiteralPath (Join-Path $f9Root $f9Relative) -Destination (Join-Path $f9Fixture $f9Relative) -Force
    }
}
$f9Head=git -C $f9Root rev-parse HEAD
$f9Inputs=@()
foreach($f9Directory in @('scripts','scenes','data','assets','resources','content','addons/ragrpg_map_editor','tests','tools')){
    foreach($f9File in Get-ChildItem -LiteralPath (Join-Path $f9Root $f9Directory) -Recurse -File){
        $f9Relative=[IO.Path]::GetRelativePath($f9Root,$f9File.FullName).Replace('\','/')
        if($f9File.Name.EndsWith('.import') -and -not $f9Relative.StartsWith('assets/art/map_authoring/props/')){continue}
        $f9Inputs+=@{path=$f9Relative;sha256=(Get-FileHash -LiteralPath $f9File.FullName).Hash}
    }
}
$f9Info=[Diagnostics.ProcessStartInfo]::new()
$f9Info.FileName=(Resolve-Path -LiteralPath $GodotPath).Path
$f9Info.UseShellExecute=$false; $f9Info.CreateNoWindow=$true; $f9Info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$f9Info.RedirectStandardOutput=$true; $f9Info.RedirectStandardError=$true
$f9Info.Environment['APPDATA']=Join-Path $f9Fixture '.godot/discardable_profile'
$f9Info.Environment['LOCALAPPDATA']=$f9Info.Environment['APPDATA']
$f9Info.Environment['F9_EVIDENCE']=$f9Evidence
if($Stage -eq 'RoundedResume'){
    if([string]::IsNullOrEmpty($ResumeSession) -or -not (Test-Path -LiteralPath $ResumeSession -PathType Leaf)){throw 'Provide the existing disposable gameplay session.'}
    $f9Info.Environment['F9_RESUME_SESSION']=[IO.Path]::GetFullPath($ResumeSession)
}
$f9Script=if($Stage -eq 'Geometry'){'res://tests/map_editor_f9_geometry_test.gd'}else{'res://tests/map_editor_objects_test.gd'}
$f9Marker=if($Stage -eq 'Geometry'){'F9_GEOMETRY_RESULT'}else{'F9_OBJECTS_RESULT'}
if($Stage -eq 'NavigationContext'){$f9Script='res://tests/map_editor_navigation_context_test.gd';$f9Marker='F9_CONTEXT_RESULT'}
if($Stage -eq 'NavigationDense'){$f9Script='res://tests/map_editor_navigation_dense_test.gd';$f9Marker='F9_DENSE_RESULT'}
if($Stage -eq 'NavigationLazy'){$f9Script='res://tests/map_editor_navigation_lazy_test.gd';$f9Marker='F9_LAZY_RESULT'}
if($Stage -eq 'PopulationReachability'){$f9Script='res://tests/map_editor_population_reachability_test.gd';$f9Marker='F9_POPULATION_REACHABILITY_RESULT'}
if($Stage -eq 'EncounterAuthoring'){$f9Script='res://tests/map_editor_encounter_authoring_test.gd';$f9Marker='F9_ENCOUNTER_RESULT'}
if($Stage -eq 'MapBiome'){$f9Script='res://tests/map_editor_map_biome_test.gd';$f9Marker='F9_MAP_BIOME_RESULT'}
if($Stage -eq 'CompositionAX'){$f9Script='res://tests/map_editor_ax_composition_test.gd';$f9Marker='F9_AX_COMPOSITION_RESULT'}
if($Stage -eq 'Content'){$f9Script='res://tests/map_editor_ax_content_test.gd';$f9Marker='F9_AX_CONTENT_RESULT'}
if($Stage -eq 'Authoring'){$f9Script='res://tests/map_editor_ax_authoring_test.gd';$f9Marker='F9_AX_AUTHORING_RESULT'}
if($Stage -eq 'SurfacePick'){$f9Script='res://tests/map_editor_surface_pick_test.gd';$f9Marker='F9_PICK_RESULT'}
if($Stage -eq 'SnapshotDensity'){$f9Script='res://tests/map_editor_snapshot_density_test.gd';$f9Marker='F9_SNAPSHOT_DENSITY_RESULT'}
if($Stage -eq 'Rounded'){$f9Script='res://tests/map_editor_rounded_hill_test.gd';$f9Marker='F9_ROUNDED_RESULT'}
if($Stage -eq 'Organic'){$f9Script='res://tests/map_editor_organic_test.gd';$f9Marker='F9_ORGANIC_RESULT'}
if($Stage -eq 'Mesh'){$f9Script='res://tests/map_editor_mesh_test.gd';$f9Marker='F9_MESH_RESULT'}
if($Stage -eq 'Relief'){$f9Script='res://tests/map_editor_relief_test.gd';$f9Marker='F9_RELIEF_RESULT'}
if($Stage -eq 'Ports'){$f9Script='res://tests/map_editor_port_fragments_test.gd';$f9Marker='F9_PORT_RESULT'}
if($Stage -eq 'Batch'){$f9Script='res://tests/map_editor_navigation_batch_test.gd';$f9Marker='F9_BATCH_RESULT'}
if($Stage -eq 'Materials'){$f9Script='res://tests/map_editor_materials_test.gd';$f9Marker='F9_MATERIAL_RESULT'}
if($Stage -eq 'Library'){$f9Script='res://tests/map_editor_library_test.gd';$f9Marker='F9_LIBRARY_RESULT'}
if($Stage -eq 'Viewport'){$f9Script='res://tests/map_editor_viewport_test.gd';$f9Marker='F9_VIEWPORT_RESULT'}
if($Stage -eq 'RuntimeView'){$f9Script='res://tests/map_editor_gameplay_test.gd';$f9Marker='F9_RUNTIME_VIEW_RESULT'}
if($Stage -eq 'GameplayControls'){$f9Script='res://tests/map_editor_gameplay_controls_test.gd';$f9Marker='F9_CONTROLS_RESULT'}
if($Stage -eq 'GameplayCli'){$f9Script='res://tests/map_editor_gameplay_cli_test.gd';$f9Marker='F9_GAMEPLAY_CLI_RESULT'}
if($Stage -eq 'GameplayWindow'){$f9Script='res://tests/map_editor_gameplay_launch_test.gd';$f9Marker='F9_WINDOW_RESULT'}
if($Stage -eq 'CanvasOrder'){$f9Script='res://tests/map_editor_canvas_order_test.gd';$f9Marker='F9_ORDER_RESULT'}
if($Stage -eq 'Shadows'){$f9Script='res://tests/map_editor_shadows_test.gd';$f9Marker='F9_SHADOW_RESULT'}
if($Stage -eq 'Borders'){$f9Script='res://tests/map_editor_borders_test.gd';$f9Marker='F9_BORDER_RESULT'}
if($Stage -eq 'BiomeProps'){$f9Script='res://tests/map_editor_biome_props_test.gd';$f9Marker='F9_BIOME_PROPS_RESULT'}
if($Stage -eq 'Cliff'){$f9Script='res://tests/map_editor_cliff_test.gd';$f9Marker='F9_CLIFF_RESULT'}
if($Stage -eq 'Scale'){$f9Script='res://tests/map_editor_terrain_scale_test.gd';$f9Marker='M2_SCALE_RESULT'}
$f9Arguments=@('--path',$f9Fixture,'--headless','--log-file',(Join-Path $f9Evidence 'geometry.engine.log'),'--script',$f9Script)
if($Stage -in @('GameplayNative','FieldsNative','RoundedNative','RoundedResume','AuthoringNative','ContentNative','CompositionAXNative','MapBiomeNative','EncounterAuthoringNative')){
    $f9Marker=if($Stage -eq 'EncounterAuthoringNative'){'F9_ENCOUNTER_UI_RESULT'}elseif($Stage -eq 'MapBiomeNative'){'F9_MAP_BIOME_UI_RESULT'}elseif($Stage -eq 'CompositionAXNative'){'F9_AX_COMPOSITION_UI_RESULT'}elseif($Stage -eq 'ContentNative'){'F9_AX_CONTENT_UI_RESULT'}elseif($Stage -eq 'AuthoringNative'){'F9_AX_AUTHORING_UI_RESULT'}elseif($Stage -eq 'RoundedResume'){'F9_ROUNDED_RESUME_RESULT'}elseif($Stage -eq 'RoundedNative'){'F9_ROUNDED_UI_RESULT'}elseif($Stage -eq 'FieldsNative'){'F9_FIELDS_UI_RESULT'}else{'F9_GAMEPLAY_RESULT'}
    $f9GraphicsScript=if($Stage -eq 'EncounterAuthoringNative'){'res://tests/map_editor_encounter_authoring_ui_test.gd'}elseif($Stage -eq 'MapBiomeNative'){'res://tests/map_editor_map_biome_ui_test.gd'}elseif($Stage -eq 'CompositionAXNative'){'res://tests/map_editor_ax_composition_ui_test.gd'}elseif($Stage -eq 'ContentNative'){'res://tests/map_editor_ax_content_ui_test.gd'}elseif($Stage -eq 'AuthoringNative'){'res://tests/map_editor_ax_authoring_ui_test.gd'}elseif($Stage -eq 'RoundedResume'){'res://tests/map_editor_rounded_hill_resume_test.gd'}elseif($Stage -eq 'RoundedNative'){'res://tests/map_editor_rounded_hill_ui_test.gd'}elseif($Stage -eq 'FieldsNative'){'res://tests/map_editor_fields_ui_test.gd'}else{'res://tests/map_editor_gameplay_ui_test.gd'}
    $f9Arguments=@('--path',$f9Fixture,'--rendering-method','gl_compatibility','--log-file',(Join-Path $f9Evidence 'geometry.engine.log'),'--script',$f9GraphicsScript)
}
$f9RestoreProject=$null
if($Stage -in @('ObjectsNative','MaterialsNative','CliffNative','BiomePropsNative','BordersNative','ShadowsNative','LibraryNative','ViewportNative','GameplayEditorNative')){
    $f9Marker=if($Stage -eq 'GameplayEditorNative'){'F9_GAMEPLAY_EDITOR_RESULT'}elseif($Stage -eq 'ViewportNative'){'F9_VIEWPORT_UI_RESULT'}elseif($Stage -eq 'LibraryNative'){'F9_LIBRARY_UI_RESULT'}elseif($Stage -eq 'ShadowsNative'){'F9_SHADOW_UI_RESULT'}elseif($Stage -eq 'BordersNative'){'F9_BORDER_UI_RESULT'}elseif($Stage -eq 'BiomePropsNative'){'F9_BIOME_PROPS_UI_RESULT'}elseif($Stage -eq 'CliffNative'){'F9_CLIFF_UI_RESULT'}elseif($Stage -eq 'MaterialsNative'){'F9_MATERIAL_UI_RESULT'}else{'F9_OBJECTS_UI_RESULT'}
    $f9DriverName=if($Stage -eq 'GameplayEditorNative'){'f9_gameplay_editor_driver'}elseif($Stage -eq 'ViewportNative'){'f9_viewport_driver'}elseif($Stage -eq 'LibraryNative'){'f9_library_driver'}elseif($Stage -eq 'ShadowsNative'){'f9_shadows_driver'}elseif($Stage -eq 'BordersNative'){'f9_borders_driver'}elseif($Stage -eq 'BiomePropsNative'){'f9_biome_props_driver'}elseif($Stage -eq 'CliffNative'){'f9_cliff_driver'}elseif($Stage -eq 'MaterialsNative'){'f9_materials_driver'}else{'f9_objects_driver'}
    $f9DriverScript=if($Stage -eq 'GameplayEditorNative'){'tests/map_editor_gameplay_editor_ui_test.gd'}elseif($Stage -eq 'ViewportNative'){'tests/map_editor_viewport_ui_test.gd'}elseif($Stage -eq 'LibraryNative'){'tests/map_editor_library_ui_test.gd'}elseif($Stage -eq 'ShadowsNative'){'tests/map_editor_shadows_ui_test.gd'}elseif($Stage -eq 'BordersNative'){'tests/map_editor_borders_ui_test.gd'}elseif($Stage -eq 'BiomePropsNative'){'tests/map_editor_biome_props_ui_test.gd'}elseif($Stage -eq 'CliffNative'){'tests/map_editor_cliff_ui_test.gd'}elseif($Stage -eq 'MaterialsNative'){'tests/map_editor_materials_ui_test.gd'}else{'tests/map_editor_objects_ui_test.gd'}
    $f9Driver=Join-Path $f9Fixture ('addons/'+$f9DriverName); [void](New-Item -ItemType Directory -Force -Path $f9Driver)
    Copy-Item -LiteralPath (Join-Path $f9Root $f9DriverScript) -Destination (Join-Path $f9Driver 'plugin.gd') -Force
    '[plugin]','name="Fixture objetos F9"','description="Teste isolado"','author="RagRPG"','version="1"','script="plugin.gd"' | Set-Content -LiteralPath (Join-Path $f9Driver 'plugin.cfg') -Encoding utf8
    $f9RestoreProject=[IO.File]::ReadAllText((Join-Path $f9Fixture 'project.godot'))
    [IO.File]::WriteAllText((Join-Path $f9Fixture 'project.godot'),$f9RestoreProject+"`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/ragrpg_map_editor/plugin.cfg`",`"res://addons/"+$f9DriverName+"/plugin.cfg`")")
    $f9Arguments=@('--path',$f9Fixture,'--editor','--rendering-method','gl_compatibility','--log-file',(Join-Path $f9Evidence 'geometry.engine.log'))
}
foreach($f9Arg in $f9Arguments){$f9Info.ArgumentList.Add($f9Arg)}
$f9Process=[Diagnostics.Process]::new(); $f9Process.StartInfo=$f9Info
$f9Started=[DateTime]::UtcNow.ToString('o'); [void]$f9Process.Start()
$f9Out=$f9Process.StandardOutput.ReadToEndAsync(); $f9Err=$f9Process.StandardError.ReadToEndAsync()
$f9Watch=[Diagnostics.Stopwatch]::StartNew();$f9Timeout=$false;$f9Aborted=$false
while(-not $f9Process.WaitForExit(500)){
    if($f9Watch.ElapsedMilliseconds -gt 300000){$f9Timeout=$true;break}
    try{
        $f9Live=Get-Content -LiteralPath (Join-Path $f9Evidence 'geometry.engine.log') -Raw -ErrorAction SilentlyContinue
        if($f9Live -match 'SCRIPT ERROR:|Parse Error:|ERROR:'){$f9Aborted=$true;break}
    }catch [IO.IOException]{}
}
if($f9Timeout -or $f9Aborted){$f9Process.Kill($true);$f9Process.WaitForExit()}
$f9Text=$f9Out.GetAwaiter().GetResult()+$f9Err.GetAwaiter().GetResult()
if($null -ne $f9RestoreProject){[IO.File]::WriteAllText((Join-Path $f9Fixture 'project.godot'),$f9RestoreProject)}
[IO.File]::WriteAllText((Join-Path $f9Evidence 'geometry.output.log'),$f9Text)
$f9EngineText=Get-Content -LiteralPath (Join-Path $f9Evidence 'geometry.engine.log') -Raw
$f9Match=[regex]::Match($f9Text,'(?m)^'+$f9Marker+' (.+)$')
$f9Result=if($f9Match.Success){ConvertFrom-Json $f9Match.Groups[1].Value}else{$null}
$f9Pass=-not $f9Timeout -and -not $f9Aborted -and $f9Process.ExitCode -eq 0 -and $null -ne $f9Result -and $f9Result.ok -and $f9Result.count -gt 0 -and @($f9Result.checks).Count -eq $f9Result.count -and @($f9Result.checks | Where-Object {-not $_.ok}).Count -eq 0 -and $f9Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:' -and $f9EngineText -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
$f9Expected=@{PopulationReachability=27;Geometry=46;Objects=53;ObjectsNative=25;Mesh=34;Relief=58;Ports=92;Batch=36;Materials=35;MaterialsNative=20;Scale=46;Cliff=61;CliffNative=17;BiomeProps=30;BiomePropsNative=23;Borders=93;BordersNative=32;Shadows=28;ShadowsNative=90;CanvasOrder=43;Library=50;LibraryNative=53;Viewport=20;ViewportNative=52;RuntimeView=12;GameplayNative=52;GameplayWindow=33;GameplayControls=29;GameplayEditorNative=22;GameplayCli=18;FieldsNative=73;Organic=15;NavigationLazy=24;NavigationDense=5;NavigationContext=11;Rounded=19;RoundedNative=20;SnapshotDensity=33;RoundedResume=13;SurfacePick=24;Authoring=30;AuthoringNative=15;Content=28;ContentNative=30;CompositionAX=31;CompositionAXNative=13;MapBiome=15;MapBiomeNative=13;EncounterAuthoring=27;EncounterAuthoringNative=25}
$f9Pass=$f9Pass -and $f9Result.count -eq $f9Expected[$Stage]
$f9PreviewExit=$null
if($Stage -eq 'GameplayCli'){
    $f9Pids=@()
    foreach($f9Log in Get-ChildItem -LiteralPath $f9Evidence -Filter 'cli_*.output.log'){
        $f9CliMatch=[regex]::Match([IO.File]::ReadAllText($f9Log.FullName),'(?m)^F9_GAMEPLAY_CLI_RESULT (.+)$')
        if($f9CliMatch.Success){
            $f9Cli=ConvertFrom-Json $f9CliMatch.Groups[1].Value
            if($f9Cli.ok -and $null -ne $f9Cli.process_id){$f9Pids+=([int]$f9Cli.process_id)}
        }
    }
    $f9ExitWatch=[Diagnostics.Stopwatch]::StartNew()
    do{
        $f9Alive=@($f9Pids | Where-Object {Get-Process -Id $_ -ErrorAction SilentlyContinue})
        if($f9Alive.Count -eq 0){break}
        Start-Sleep -Milliseconds 200
    }while($f9ExitWatch.ElapsedMilliseconds -lt 15000)
    $f9PreviewExit=@{pids=$f9Pids;remaining=$f9Alive;all_closed=($f9Pids.Count -gt 0 -and $f9Alive.Count -eq 0)}
    $f9Pass=$f9Pass -and $f9PreviewExit.all_closed
}
foreach($f9Input in $f9Inputs){
    $f9Source=Join-Path $f9Root $f9Input.path; $f9Copy=Join-Path $f9Fixture $f9Input.path
    if((Get-FileHash -LiteralPath $f9Source).Hash -ne $f9Input.sha256 -or (Get-FileHash -LiteralPath $f9Copy).Hash -ne $f9Input.sha256){$f9Pass=$false}
}
$f9Manifest=@{resume_session=$ResumeSession;resume_session_sha256=$(if($Stage -eq 'RoundedResume'){(Get-FileHash -LiteralPath $ResumeSession).Hash}else{$null});preview_process_exit=$f9PreviewExit;stage=$Stage;head_before=$f9Head;head_after=(git -C $f9Root rev-parse HEAD);engine=(Resolve-Path -LiteralPath $GodotPath).Path;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;fixture=$f9Fixture;inputs=$f9Inputs;started_utc=$f9Started;finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$f9Process.ExitCode;timed_out=$f9Timeout;aborted=$f9Aborted;ok=$f9Pass;result=$f9Result}
[IO.File]::WriteAllText((Join-Path $f9Evidence 'runs.json'),(ConvertTo-Json -InputObject $f9Manifest -Depth 30))
$f9Process.Dispose()
Write-Output ('F9 '+$Stage+': '+$f9Pass)
Write-Output $f9Text
if(-not $f9Pass){throw ('F9 '+$Stage+' failed; logs preserved.')}
