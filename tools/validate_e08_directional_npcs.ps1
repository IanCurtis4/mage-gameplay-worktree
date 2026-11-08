param(
    [ValidateSet('sync','import','native','export','cost','motion','unit','legacy','rig','player','compose','inspect','cost_all','world','mosaic','pilot')][string]$Stage='native',
    [string]$EvidenceName='final',
    [string]$Kind='warrior',
    [ValidateSet('cost_control','cost_content')][string]$CostMode='cost_content',
    [switch]$Default,
    [string[]]$Kinds=@()
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $taskRoot '.godot/verification/e07_f1/fixture_project'
$outputRoot=Join-Path $taskRoot ('.godot/verification/p4_final/'+$Stage+'_'+$EvidenceName)
if(Test-Path -LiteralPath $outputRoot){throw 'Choose a new evidence name; attempts are immutable.'}
[void](New-Item -ItemType Directory -Path $outputRoot -Force)
$engine=Join-Path (Split-Path -Parent $taskRoot) 'godot/Godot_v4.7.2-stable_win64.exe'
if((Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'){throw 'Unexpected standard engine'}
$manifestPath=Join-Path $fixture 'source_hashes.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
if($Stage -eq 'sync'){
    $ownership=Get-Content -LiteralPath (Join-Path $taskRoot 'docs/epics/e08_p4_final_integration_files.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $allowed=@($ownership.files)+@($ownership.read_only_inputs)
    $changed=@()
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $outputRoot 'previous_source_hashes.json')
    foreach($rel in $manifest.Keys){
        $oldFixture=Join-Path $fixture $rel
        if(-not (Test-Path -LiteralPath $oldFixture) -or (Get-FileHash -LiteralPath $oldFixture -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest[$rel]){throw "Previous fixture drift: $rel"}
        $current=Join-Path $taskRoot $rel
        if(-not (Test-Path -LiteralPath $current)){throw "Missing previous input: $rel"}
        $newHash=(Get-FileHash -LiteralPath $current -Algorithm SHA256).Hash.ToLowerInvariant()
        if($newHash -ne $manifest[$rel]){
            if($rel -notin $allowed){throw "Changed input outside art ownership: $rel"}
            $changed+=@{path=$rel;before_sha256=$manifest[$rel];after_sha256=$newHash}
        }
    }
    foreach($rel in $allowed){
        if(-not ($rel.StartsWith('assets/') -or $rel.StartsWith('tools/') -or $rel.StartsWith('tests/') -or $rel.StartsWith('scripts/')) -or $rel.EndsWith('.import')){continue}
        if($rel.StartsWith('assets/') -and $rel -notin @($ownership.read_only_inputs) -and [IO.Path]::GetFileName($rel) -notin @('body.png','npc_body.png','weaponless.png','bare_head.png','presentation.json','calibration.json','provenance.json','source_recipe.json')){continue}
        $current=Join-Path $taskRoot $rel
        if((Test-Path -LiteralPath $current) -and -not $manifest.ContainsKey($rel)){
            $changed+=@{path=$rel;before_sha256=$null;after_sha256=(Get-FileHash -LiteralPath $current -Algorithm SHA256).Hash.ToLowerInvariant()}
        }
    }
    foreach($entry in $changed){
        $target=Join-Path $fixture $entry.path
        if($null -ne $entry.before_sha256){
            $previous=Join-Path $outputRoot ('previous/'+$entry.path)
            [void](New-Item -ItemType Directory -Path (Split-Path -Parent $previous) -Force)
            Copy-Item -LiteralPath $target -Destination $previous
        }
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force)
        Copy-Item -LiteralPath (Join-Path $taskRoot $entry.path) -Destination $target
        $manifest[$entry.path]=$entry.after_sha256
    }
    $importChanges=@()
    foreach($rel in @($ownership.fixture_import_overrides)){
        $originalImport=Join-Path $taskRoot $rel
        if(-not (Test-Path -LiteralPath $originalImport)){continue}
        $fixtureImport=Join-Path $fixture $rel
        $after=(Get-FileHash -LiteralPath $originalImport -Algorithm SHA256).Hash.ToLowerInvariant()
        $before=if(Test-Path -LiteralPath $fixtureImport){(Get-FileHash -LiteralPath $fixtureImport -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null}
        if($after -ne $before){
            if($null -ne $before){
                $previous=Join-Path $outputRoot ('previous_import/'+$rel)
                [void](New-Item -ItemType Directory -Path (Split-Path -Parent $previous) -Force)
                Copy-Item -LiteralPath $fixtureImport -Destination $previous
            }
            Copy-Item -LiteralPath $originalImport -Destination $fixtureImport
            $importChanges+=@{path=$rel;before_sha256=$before;after_sha256=$after}
        }
    }
    $importChanges | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot 'import_delta.json') -Encoding UTF8
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $changed | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outputRoot 'delta.json') -Encoding UTF8
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $outputRoot 'source_hashes.json')
}
foreach($rel in $manifest.Keys){
    foreach($targetRoot in @($taskRoot,$fixture)){
        $source=Join-Path $targetRoot $rel
        if(-not (Test-Path -LiteralPath $source) -or (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest[$rel]){throw "Source/fixture mismatch: $rel"}
    }
}
$activeOwnership=Get-Content -LiteralPath (Join-Path $taskRoot 'docs/epics/e08_p4_final_integration_files.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach($rel in @($activeOwnership.fixture_import_overrides)){
    $originalImport=Join-Path $taskRoot $rel
    if(Test-Path -LiteralPath $originalImport){
        $fixtureImport=Join-Path $fixture $rel
        if(-not (Test-Path -LiteralPath $fixtureImport) -or (Get-FileHash -LiteralPath $originalImport -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $fixtureImport -Algorithm SHA256).Hash){throw "Owned import metadata drift: $rel"}
    }
}
$original=[IO.File]::ReadAllText((Join-Path $taskRoot 'project.godot'))
if($original.Replace('version_control/autoload_on_startup=true','version_control/autoload_on_startup=false') -cne [IO.File]::ReadAllText((Join-Path $fixture 'project.godot'))){throw 'Unexpected fixture project delta'}
function Invoke-Engine([string]$Label,[string[]]$EngineArguments,[int]$Limit=120){
    $target=Join-Path $outputRoot $Label
    [void](New-Item -ItemType Directory -Path $target -Force)
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$engine;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.Environment['APPDATA']=Join-Path $target 'appdata';$info.Environment['LOCALAPPDATA']=Join-Path $target 'localappdata'
    foreach($arg in $EngineArguments){$info.ArgumentList.Add($arg.Replace('{output}',$target))}
    $scriptHash=$null
    $scriptIndex=[Array]::IndexOf($EngineArguments,'--script')
    if($scriptIndex -ge 0){
        $scriptPath=$EngineArguments[$scriptIndex+1]
        if($scriptPath.StartsWith('res://')){$scriptPath=Join-Path $fixture $scriptPath.Substring(6)}
        $scriptHash=(Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info;$started=[DateTime]::UtcNow
    [void]$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    $timedOut=-not $process.WaitForExit($Limit*1000)
    if($timedOut){$process.Kill($true);$process.WaitForExit()}
    $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$code=$process.ExitCode;$process.Dispose()
    [IO.File]::WriteAllText((Join-Path $target 'stdout.log'),$out);[IO.File]::WriteAllText((Join-Path $target 'stderr.log'),$err)
    $failed=$timedOut -or $code -ne 0 -or (($out+$err) -match 'SCRIPT ERROR:|Parse Error:|ERROR:')
    [ordered]@{label=$Label;unit_kind=$Kind;require_default=([bool]$Default -or $Stage -in @('world','mosaic'));arguments=$EngineArguments;actual_script_sha256=$scriptHash;started_utc=$started.ToString('o');elapsed_seconds=([DateTime]::UtcNow-$started).TotalSeconds;exit_code=$code;timed_out=$timedOut;failed=$failed;engine_sha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash;source_manifest_sha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash;runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;probe_sha256=$(if(Test-Path -LiteralPath (Join-Path $taskRoot 'tools/e08_directional_npc_probe.gd')){(Get-FileHash -LiteralPath (Join-Path $taskRoot 'tools/e08_directional_npc_probe.gd') -Algorithm SHA256).Hash}else{$null})} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $target 'execution.json') -Encoding UTF8
    Write-Output "$Label exit=$code timeout=$timedOut failed=$failed"
    if($failed){Write-Output (($out+$err).Substring(0,[Math]::Min(3000,($out+$err).Length)));throw "Art validation failed: $Label"}
}
if($Stage -eq 'sync'){Write-Output "Synchronized $($changed.Count) owned inputs; $($manifest.Count) sources verified."}
if($Stage -eq 'import'){Invoke-Engine 'import' @('--headless','--path',$fixture,'--editor','--import','--quit') 180}
if($Stage -eq 'inspect'){Invoke-Engine 'inspect' @('--headless','--path',$fixture,'--script','res://tools/prepare_e08_npc_archer_body.gd','--','{output}','inspect')}
if($Stage -eq 'compose'){Invoke-Engine 'compose' @('--path',$fixture,'--script','res://tools/prepare_e08_npc_archer_body.gd','--','{output}') 180}
if($Stage -eq 'legacy'){Invoke-Engine 'legacy' @('--headless','--path',$fixture,'--script','res://tools/e08_legacy_rig_reference.gd','--','{output}')}
if($Stage -eq 'rig'){Invoke-Engine 'rig' @('--headless','--path',$fixture,'--script','res://tests/e08_directional_rig_compatibility_test.gd')}
if($Stage -eq 'unit'){$argsForTest=@('--headless','--path',$fixture,'--script','res://tests/e08_directional_npcs_test.gd');if(-not $Default){$argsForTest+=@('--','--stage')};Invoke-Engine 'unit' $argsForTest}
if($Stage -eq 'player'){$argsForTest=@('--headless','--path',$fixture,'--script','res://tests/e08_directional_units_test.gd','--',$Kind);if($Default){$argsForTest+='--default'};Invoke-Engine 'player' $argsForTest}
if($Stage -in @('native','motion','cost')){
 $mode=if($Stage -eq 'cost'){$CostMode}else{$Stage}
 $arguments=@('--path',$fixture,'--script','res://tools/e08_directional_npc_probe.gd','--','{output}',$mode,$Kind)
 if($Default){$arguments+='--default'}
 Invoke-Engine $Stage $arguments
}

if($Stage -eq 'cost_all'){
 Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $outputRoot 'source_hashes.json')
 Copy-Item -LiteralPath (Join-Path $taskRoot 'tools/e08_directional_npc_probe.gd') -Destination (Join-Path $outputRoot 'tested_probe.gd')
 Copy-Item -LiteralPath (Join-Path $taskRoot 'tools/e08_directional_unit_probe.gd') -Destination (Join-Path $outputRoot 'tested_unit_probe.gd')
 $targets=if($Kinds.Count){$Kinds}else{@('swordsman','mage','archer','defender','berserker','elementalist','spiritualist','sentinel','hunter','geometer','warrior','gel','beast_master','animal_companion','e08_forest_wolf','e08_forest_boar','npc_archer')}
 foreach($kindName in $targets){
  $Kind=$kindName
  $pair=@{}
  foreach($mode in @('cost_control','cost_content')){
   Invoke-Engine ($Kind+'_'+$mode) @('--path',$fixture,'--script','res://tools/e08_directional_npc_probe.gd','--','{output}',$mode,$Kind)
   $data=Get-Content -LiteralPath (Join-Path $outputRoot ($Kind+'_'+$mode+'/result.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
   $metrics=@{}
   foreach($state in @($true,$false)){
    $windows=@($data.windows | Where-Object moving -eq $state)
    $values=@{}
    foreach($metric in @('median_ms','p95_ms','cpu_median_ms','cpu_p95_ms')){
     $ordered=@($windows | ForEach-Object { [double]($_.$metric) } | Sort-Object)
     $values[$metric]=$ordered[1]
    }
    $metrics[$(if($state){'moving'}else{'idle'})]=$values
   }
   $metrics['retained_static_bytes']=[double]$data.static_after_clear-[double]$data.static_before
   $pair[$mode]=$metrics
  }
  $deltas=@{}
  foreach($state in @('moving','idle')){
   $deltas[$state]=@{}
   foreach($metric in @('median_ms','p95_ms','cpu_median_ms','cpu_p95_ms')){
    $deltas[$state][$metric]=100.0*($pair.cost_content[$state][$metric]/$pair.cost_control[$state][$metric]-1.0)
   }
  }
  $record=@{kind=$Kind;pair=$pair;delta_percent=$deltas;retained_delta_bytes=$pair.cost_content.retained_static_bytes-$pair.cost_control.retained_static_bytes}
  $record | ConvertTo-Json -Depth 8 -Compress | Add-Content -LiteralPath (Join-Path $outputRoot 'summary.jsonl') -Encoding UTF8
  Write-Output ("SUMMARY {0} movingCPU {1:F3}->{2:F3}ms idleCPU {3:F3}->{4:F3}ms framep95 {5:F2}%/{6:F2}% retained {7}B" -f $Kind,$pair.cost_control.moving.cpu_median_ms,$pair.cost_content.moving.cpu_median_ms,$pair.cost_control.idle.cpu_median_ms,$pair.cost_content.idle.cpu_median_ms,$deltas.moving.p95_ms,$deltas.idle.p95_ms,$record.retained_delta_bytes)
 }
 foreach($rel in $manifest.Keys){
  foreach($targetRoot in @($taskRoot,$fixture)){
   if((Get-FileHash -LiteralPath (Join-Path $targetRoot $rel) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest[$rel]){throw "Frozen cost input drift: $rel"}
  }
 }
 Write-Output 'Completed frozen matched cost batch; all source/fixture hashes still exact.'
}

if($Stage -in @('world','mosaic')){
 Invoke-Engine $Stage @('--path',$fixture,'--script','res://tools/e08_directional_npc_probe.gd','--','{output}',$Stage,'warrior','--default') 180
}
if($Stage -eq 'pilot'){
 Invoke-Engine 'lair' @('--path',$fixture,'--script','res://tools/e08_pilot_probe.gd','--','{output}','lair') 180
}

if($Stage -eq 'export'){
 $pack=Join-Path $outputRoot 'p4_final_validation.pck'
 $preset=[IO.File]::ReadAllText((Join-Path $taskRoot 'export_presets.cfg'))
 $preset=$preset.Replace('assets/art/animations/directional/*/presentation.json"','assets/art/animations/directional/*/presentation.json,assets/art/e08_characters/directional/*/*.json,assets/art/e08_enemies/directional/*/*.json,tests/fixtures/e08_directional/*.json,tests/fixtures/e08_directional/*/*.json,tests/fixtures/e08_equipment_art/*.json,assets/art/e08_head_fit/*/*.json,assets/art/e08_equipment_redesign/*.json"')
 [IO.File]::WriteAllText((Join-Path $fixture 'export_presets.cfg'),$preset)
 [IO.File]::WriteAllText((Join-Path $outputRoot 'tested_export_presets.cfg'),$preset)
 Invoke-Engine 'export' @('--headless','--path',$fixture,'--editor','--export-pack','Windows Desktop',$pack) 180
 foreach($test in @('e08_directional_npcs_test','e08_directional_rig_compatibility_test','e08_directional_units_test','e08_equipment_art_test','e08_directional_content_test','e08_directional_animation_test','e08_characters_test')){
  Invoke-Engine ('packed_'+$test) @('--headless','--main-pack',$pack,'--script',('res://tests/'+$test+'.gd')) 180
 }
 [ordered]@{sha256=(Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $pack).Length} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'pack_hash.json') -Encoding UTF8
}
