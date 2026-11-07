param(
    [ValidateSet('sync','import','native','export','cost','motion','author','unit')][string]$Stage='native',
    [ValidateSet('elementalist','mage','swordsman')][string]$Kind='elementalist',
    [string]$EvidenceName='final',
    [switch]$Default
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $taskRoot '.godot/verification/e07_f1/fixture_project'
$outputRoot=Join-Path $taskRoot ('.godot/verification/p4_units/'+$Kind+'/'+$Stage+'_'+$EvidenceName)
if(Test-Path -LiteralPath $outputRoot){throw 'Choose a new evidence name; attempts are immutable.'}
[void](New-Item -ItemType Directory -Path $outputRoot -Force)
$engine=Join-Path (Split-Path -Parent $taskRoot) 'godot/Godot_v4.7.2-stable_win64.exe'
if((Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'){throw 'Unexpected standard engine'}
$manifestPath=Join-Path $fixture 'source_hashes.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
if($Stage -eq 'sync'){
    $ownership=Get-Content -LiteralPath (Join-Path $taskRoot 'docs/epics/e08_p4_units_sol_files.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $unitContract=$ownership.units.PSObject.Properties[$Kind].Value.ownership_file
    $unitOwnership=Get-Content -LiteralPath (Join-Path $taskRoot $unitContract) -Raw -Encoding UTF8 | ConvertFrom-Json
    $allowed=@($ownership.files)
    foreach($unit in $ownership.units.PSObject.Properties){
        $transferred=Get-Content -LiteralPath (Join-Path $taskRoot $unit.Value.ownership_file) -Raw -Encoding UTF8 | ConvertFrom-Json
        $allowed+=@($transferred.files)
    }
    $allowed=@($allowed | Select-Object -Unique)
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
        if(-not ($rel.StartsWith('assets/') -or $rel.StartsWith('tools/') -or $rel.StartsWith('tests/')) -or $rel.EndsWith('.import')){continue}
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
    [ordered]@{label=$Label;unit_kind=$Kind;require_default=[bool]$Default;arguments=$EngineArguments;actual_script_sha256=$scriptHash;started_utc=$started.ToString('o');elapsed_seconds=([DateTime]::UtcNow-$started).TotalSeconds;exit_code=$code;timed_out=$timedOut;failed=$failed;engine_sha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash;source_manifest_sha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash;runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;probe_sha256=(Get-FileHash -LiteralPath (Join-Path $taskRoot 'tools/e08_directional_unit_probe.gd') -Algorithm SHA256).Hash} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $target 'execution.json') -Encoding UTF8
    Write-Output "$Label exit=$code timeout=$timedOut failed=$failed"
    if($failed){Write-Output ($out+$err);throw "Art validation failed: $Label"}
}
if($Stage -eq 'sync'){Write-Output "Synchronized $($changed.Count) owned inputs; $($manifest.Count) sources verified."}
$defaultArgument=@()
if($Default){$defaultArgument=@('--default')}
if($Stage -eq 'import'){Invoke-Engine 'import' @('--headless','--path',$fixture,'--editor','--import','--quit') 180}
if($Stage -eq 'author'){
    $image=Join-Path $taskRoot ('assets/art/e08_characters/directional/'+$Kind+'/body.png')
    Invoke-Engine 'author' @('--path',$fixture,'--script','res://tools/e08_directional_unit_probe.gd','--','{output}','author',$image)
}
if($Stage -eq 'unit'){Invoke-Engine 'unit' (@('--headless','--path',$fixture,'--script','res://tests/e08_directional_units_test.gd','--',$Kind)+$defaultArgument)}
if($Stage -eq 'native'){Invoke-Engine 'native' (@('--path',$fixture,'--script','res://tools/e08_directional_unit_probe.gd','--','{output}','native',$Kind)+$defaultArgument)}
if($Stage -eq 'motion'){Invoke-Engine 'motion' (@('--path',$fixture,'--script','res://tools/e08_directional_unit_probe.gd','--','{output}','motion',$Kind)+$defaultArgument)}
if($Stage -eq 'cost'){
    if(Test-Path -LiteralPath (Join-Path $fixture ('assets/art/animations/directional/'+$Kind+'/presentation.json'))){throw 'Compare staged content before default activation; preserve the V1 control.'}
    foreach($mode in @('cost_legacy','cost_content')){Invoke-Engine $mode @('--path',$fixture,'--script','res://tools/e08_directional_unit_probe.gd','--','{output}',$mode,$Kind)}
}
if($Stage -eq 'export'){
    $pack=Join-Path $outputRoot 'art_unit_validation.pck'
    $preset=[IO.File]::ReadAllText((Join-Path $taskRoot 'export_presets.cfg'))
    $preset=$preset.Replace('assets/art/animations/directional/*/presentation.json"','assets/art/animations/directional/*/presentation.json,assets/art/e08_characters/directional/*/presentation.json,tests/fixtures/e08_directional/*.json,tests/fixtures/e08_directional/*/*.json"')
    [IO.File]::WriteAllText((Join-Path $fixture 'export_presets.cfg'),$preset)
    [IO.File]::WriteAllText((Join-Path $outputRoot 'tested_export_presets.cfg'),$preset)
    Invoke-Engine 'export' @('--headless','--path',$fixture,'--editor','--export-pack','Windows Desktop',$pack) 180
    Invoke-Engine 'packed_units' @('--headless','--main-pack',$pack,'--script','res://tests/e08_directional_units_test.gd')
    Invoke-Engine 'packed_spiritualist' @('--headless','--main-pack',$pack,'--script','res://tests/e08_directional_content_test.gd')
    Invoke-Engine 'packed_producer' @('--headless','--main-pack',$pack,'--script','res://tests/e08_directional_animation_test.gd')
    [ordered]@{sha256=(Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $pack).Length} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'pack_hash.json') -Encoding UTF8
}
