param(
    [ValidateSet('import','native','export','cost')][string]$Stage='native',
    [string]$EvidenceName='final',
    [string]$CandidatePack=''
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $taskRoot '.godot/verification/e07_f1/fixture_project'
$outputRoot=Join-Path $taskRoot ('.godot/verification/p4_directional/'+$Stage+'_'+$EvidenceName)
if(Test-Path -LiteralPath $outputRoot){throw 'Choose a new evidence name; attempts are immutable.'}
[void](New-Item -ItemType Directory -Path $outputRoot -Force)
$engine=Join-Path (Split-Path -Parent $taskRoot) 'godot/Godot_v4.7.2-stable_win64.exe'
$manifestPath=Join-Path $fixture 'source_hashes.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
foreach($rel in $manifest.Keys){
    foreach($targetRoot in @($taskRoot,$fixture)){
        $path=Join-Path $targetRoot $rel
        if(-not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest[$rel]){throw "Fixture mismatch: $rel"}
    }
}
foreach($rel in @('tools/e08_directional_probe.gd','tools/e08_directional_cost_probe.gd','tools/validate_e08_directional.ps1')){
    if(-not $manifest.ContainsKey($rel)){throw "Bootstrap/synchronize the new source first: $rel"}
}
function Invoke-Engine([string]$Label,[string[]]$EngineArguments,[int]$Limit=120){
    $target=Join-Path $outputRoot $Label
    [void](New-Item -ItemType Directory -Path $target -Force)
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$engine;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.Environment['APPDATA']=Join-Path $target 'appdata'
    $info.Environment['LOCALAPPDATA']=Join-Path $target 'localappdata'
    foreach($arg in $EngineArguments){$info.ArgumentList.Add($arg.Replace('{output}',$target))}
    $probeHash=$null
    $scriptIndex=[Array]::IndexOf($EngineArguments,'--script')
    if($scriptIndex -ge 0){
        $probePath=$EngineArguments[$scriptIndex+1]
        if($probePath.StartsWith('res://')){$probePath=Join-Path $fixture $probePath.Substring(6)}
        $probeHash=(Get-FileHash -LiteralPath $probePath -Algorithm SHA256).Hash
    }
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info
    $started=[DateTime]::UtcNow
    [void]$process.Start()
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    $timedOut=-not $process.WaitForExit($Limit*1000)
    if($timedOut){$process.Kill($true);$process.WaitForExit()}
    $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$code=$process.ExitCode;$process.Dispose()
    [IO.File]::WriteAllText((Join-Path $target 'stdout.log'),$out)
    [IO.File]::WriteAllText((Join-Path $target 'stderr.log'),$err)
    $failed=$timedOut -or $code -ne 0 -or (($out+$err) -match 'SCRIPT ERROR:|Parse Error:|ERROR:')
    [ordered]@{label=$Label;arguments=$EngineArguments;external_or_fixture_probe_sha256=$probeHash;started_utc=$started.ToString('o');elapsed_seconds=([DateTime]::UtcNow-$started).TotalSeconds;exit_code=$code;timed_out=$timedOut;failed=$failed;engine_sha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash;source_manifest_sha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash;runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $target 'execution.json') -Encoding utf8
    Write-Output "$Label exit=$code timeout=$timedOut failed=$failed"
    if($failed){Write-Output ($out+$err);throw "Directional validation failed: $Label"}
}
if($Stage -eq 'import'){
    Invoke-Engine 'import' @('--headless','--path',$fixture,'--editor','--import','--quit') 180
}
if($Stage -eq 'native'){
    Invoke-Engine 'native' @('--path',$fixture,'--script','res://tools/e08_directional_probe.gd','--','{output}')
}
if($Stage -eq 'export'){
    $pack=Join-Path $outputRoot 'directional_validation.pck'
    $preset=[IO.File]::ReadAllText((Join-Path $taskRoot 'export_presets.cfg'))
    # Include synthetic JSON in this harness only. Production filter contains
    # only the directional catalog path, not test fixture manifests.
    $preset=$preset.Replace('assets/art/animations/directional/*/presentation.json"','assets/art/animations/directional/*/presentation.json,tests/fixtures/e08_directional/*.json,tests/fixtures/e08_directional/*/*.json"')
    [IO.File]::WriteAllText((Join-Path $fixture 'export_presets.cfg'),$preset)
    [IO.File]::WriteAllText((Join-Path $outputRoot 'tested_export_presets.cfg'),$preset)
    Invoke-Engine 'export' @('--headless','--path',$fixture,'--editor','--export-pack','Windows Desktop',$pack) 180
    Invoke-Engine 'packed_unit' @('--headless','--main-pack',$pack,'--script','res://tests/e08_directional_animation_test.gd')
    Invoke-Engine 'packed_integration' @('--headless','--main-pack',$pack,'--script','res://tests/e08_directional_integration_test.gd')
    Get-FileHash -LiteralPath $pack -Algorithm SHA256 | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'pack_hash.json') -Encoding utf8
}
if($Stage -eq 'cost'){
    $probe=Join-Path $fixture 'tools/e08_directional_cost_probe.gd'
    $baseline=Join-Path (Split-Path -Parent $taskRoot) 'playtest_e08/pilot_ad09b99d/RagRPG-E08-Piloto1.pck'
    if((Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'd91bc71373ec370e744b61032b7aed036f4895620241027b29c0b505c81246e2'){throw 'Accepted pilot PCK hash mismatch.'}
    if([string]::IsNullOrWhiteSpace($CandidatePack)){throw 'CandidatePack is required for packed-to-packed comparison.'}
    $newPack=(Resolve-Path -LiteralPath $CandidatePack).Path
    Get-FileHash -LiteralPath $baseline,$newPack -Algorithm SHA256 | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'pack_hashes.json') -Encoding utf8
    Invoke-Engine 'baseline_v1' @('--main-pack',$baseline,'--script',$probe,'--','{output}','legacy')
    Invoke-Engine 'new_v1' @('--main-pack',$newPack,'--script',$probe,'--','{output}','legacy')
    Invoke-Engine 'new_v2_synthetic' @('--main-pack',$newPack,'--script',$probe,'--','{output}','directional')
    Invoke-Engine 'baseline_unarmed' @('--main-pack',$baseline,'--script',$probe,'--','{output}','unarmed_legacy')
    Invoke-Engine 'new_unarmed_v1' @('--main-pack',$newPack,'--script',$probe,'--','{output}','unarmed_legacy')
    Invoke-Engine 'new_unarmed_v2_synthetic' @('--main-pack',$newPack,'--script',$probe,'--','{output}','unarmed_directional')
}
