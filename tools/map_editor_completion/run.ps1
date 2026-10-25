param(
    [Parameter(Mandatory)][string]$GodotPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [switch]$SkipImport,
    [ValidateSet('Geometry')][string]$Stage='Geometry'
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
$f9Inputs=@(Get-ChildItem -LiteralPath (Join-Path $f9Root 'scripts/core/expedition'),(Join-Path $f9Root 'scripts/map_authoring'),(Join-Path $f9Root 'tests') -Recurse -File | ForEach-Object { @{path=[IO.Path]::GetRelativePath($f9Root,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash} })
$f9Info=[Diagnostics.ProcessStartInfo]::new()
$f9Info.FileName=(Resolve-Path -LiteralPath $GodotPath).Path
$f9Info.UseShellExecute=$false; $f9Info.CreateNoWindow=$true; $f9Info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$f9Info.RedirectStandardOutput=$true; $f9Info.RedirectStandardError=$true
$f9Info.Environment['APPDATA']=Join-Path $f9Fixture '.godot/discardable_profile'
$f9Info.Environment['LOCALAPPDATA']=$f9Info.Environment['APPDATA']
foreach($f9Arg in @('--path',$f9Fixture,'--headless','--log-file',(Join-Path $f9Evidence 'geometry.engine.log'),'--script','res://tests/map_editor_f9_geometry_test.gd')){$f9Info.ArgumentList.Add($f9Arg)}
$f9Process=[Diagnostics.Process]::new(); $f9Process.StartInfo=$f9Info
$f9Started=[DateTime]::UtcNow.ToString('o'); [void]$f9Process.Start()
$f9Out=$f9Process.StandardOutput.ReadToEndAsync(); $f9Err=$f9Process.StandardError.ReadToEndAsync()
$f9Timeout=-not $f9Process.WaitForExit(300000)
if($f9Timeout){$f9Process.Kill($true);$f9Process.WaitForExit()}
$f9Text=$f9Out.GetAwaiter().GetResult()+$f9Err.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $f9Evidence 'geometry.output.log'),$f9Text)
$f9EngineText=Get-Content -LiteralPath (Join-Path $f9Evidence 'geometry.engine.log') -Raw
$f9Match=[regex]::Match($f9Text,'(?m)^F9_GEOMETRY_RESULT (.+)$')
$f9Result=if($f9Match.Success){ConvertFrom-Json $f9Match.Groups[1].Value}else{$null}
$f9Pass=-not $f9Timeout -and $f9Process.ExitCode -eq 0 -and $null -ne $f9Result -and $f9Result.ok -and $f9Result.count -eq 46 -and @($f9Result.checks).Count -eq 46 -and @($f9Result.checks | Where-Object {-not $_.ok}).Count -eq 0 -and $f9Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:' -and $f9EngineText -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
foreach($f9Input in $f9Inputs){
    $f9Source=Join-Path $f9Root $f9Input.path; $f9Copy=Join-Path $f9Fixture $f9Input.path
    if((Get-FileHash -LiteralPath $f9Source).Hash -ne $f9Input.sha256 -or (Get-FileHash -LiteralPath $f9Copy).Hash -ne $f9Input.sha256){$f9Pass=$false}
}
$f9Manifest=@{head_before=$f9Head;head_after=(git -C $f9Root rev-parse HEAD);engine=(Resolve-Path -LiteralPath $GodotPath).Path;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;fixture=$f9Fixture;inputs=$f9Inputs;started_utc=$f9Started;finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$f9Process.ExitCode;timed_out=$f9Timeout;ok=$f9Pass;result=$f9Result}
[IO.File]::WriteAllText((Join-Path $f9Evidence 'runs.json'),(ConvertTo-Json -InputObject $f9Manifest -Depth 30))
$f9Process.Dispose()
Write-Output ('F9 geometry: '+$f9Pass)
Write-Output $f9Text
if(-not $f9Pass){throw 'F9 geometry failed; logs preserved.'}
