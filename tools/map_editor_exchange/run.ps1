param([Parameter(Mandatory)][string]$GodotPath,[Parameter(Mandatory)][string]$EvidenceDirectory,[switch]$Native,[string]$ReuseFixture='',[switch]$UIOnly)
$ErrorActionPreference='Stop'
$m7Root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$m7GitRoot=git -C $m7Root rev-parse --show-toplevel
if($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($m7GitRoot) -ne [IO.Path]::GetFullPath($m7Root)){throw 'Invoke this runner only from the source checkout; a fixture runner would create a nested copy.'}
$m7Evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if(Test-Path -LiteralPath $m7Evidence){throw 'Use an absent evidence directory.'}
[void](New-Item -ItemType Directory -Force -Path $m7Evidence)
$m7Fixture=if($ReuseFixture){[IO.Path]::GetFullPath($ReuseFixture)}else{Join-Path $m7Root '.godot/verification/e07_f1/fixture_project'}
[void](New-Item -ItemType Directory -Force -Path $m7Fixture)
foreach($m7Dir in @('scripts','scenes','assets','data','resources','content','addons','tests','tools')){
    foreach($m7File in Get-ChildItem -LiteralPath (Join-Path $m7Root $m7Dir) -Recurse -File){
        $m7Target=Join-Path $m7Fixture ([IO.Path]::GetRelativePath($m7Root,$m7File.FullName))
        if(Test-Path -LiteralPath $m7Target){
            if($m7File.Name.EndsWith('.import')){continue}
            if((Get-FileHash -LiteralPath $m7File.FullName).Hash -eq (Get-FileHash -LiteralPath $m7Target).Hash){continue}
        }
        [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $m7Target))
        Copy-Item -LiteralPath $m7File.FullName -Destination $m7Target -Force
    }
}
$m7Project=(Get-Content -LiteralPath (Join-Path $m7Root 'project.godot') -Raw).Replace('version_control/autoload_on_startup=true','version_control/autoload_on_startup=false')
[IO.File]::WriteAllText((Join-Path $m7Fixture 'project.godot'),$m7Project)
$m7Profile=Join-Path $m7Fixture '.godot/discardable_profile'
[void](New-Item -ItemType Directory -Force -Path $m7Profile)
$m7Head=git -C $m7Root rev-parse HEAD
if(Test-Path -LiteralPath (Join-Path $m7Fixture 'addons/m7_driver/plugin.gd')){Copy-Item -LiteralPath (Join-Path $m7Root 'tests/map_editor_exchange_ui_test.gd') -Destination (Join-Path $m7Fixture 'addons/m7_driver/plugin.gd') -Force}
$m7Runs=[Collections.Generic.List[object]]::new()
function Invoke-M7([string]$Name,[string[]]$Arguments,[string]$Marker=''){
    $m7Info=[Diagnostics.ProcessStartInfo]::new()
    $m7Info.FileName=(Resolve-Path -LiteralPath $GodotPath).Path
    $m7Info.UseShellExecute=$false; $m7Info.CreateNoWindow=$true; $m7Info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $m7Info.RedirectStandardOutput=$true; $m7Info.RedirectStandardError=$true
    $m7Info.Environment['APPDATA']=$m7Profile; $m7Info.Environment['LOCALAPPDATA']=$m7Profile
    $m7Info.Environment['M7_EVIDENCE']=$m7Evidence
    foreach($m7Arg in @('--path',$m7Fixture,'--log-file',(Join-Path $m7Evidence ($Name+'.engine.log')))+$Arguments){$m7Info.ArgumentList.Add($m7Arg)}
    $m7Process=[Diagnostics.Process]::new(); $m7Process.StartInfo=$m7Info
    $m7Start=[DateTime]::UtcNow.ToString('o'); [void]$m7Process.Start()
    $m7Out=$m7Process.StandardOutput.ReadToEndAsync(); $m7Err=$m7Process.StandardError.ReadToEndAsync()
    $m7Watch=[Diagnostics.Stopwatch]::StartNew(); $m7Timeout=$false; $m7Aborted=$false
    while(-not $m7Process.WaitForExit(500)){
        if($m7Watch.ElapsedMilliseconds -gt 300000){$m7Timeout=$true; break}
        try{
            $m7Live=Get-Content -LiteralPath (Join-Path $m7Evidence ($Name+'.engine.log')) -Raw -ErrorAction SilentlyContinue
            if($m7Live -match 'SCRIPT ERROR:|Parse Error:|ERROR:'){$m7Aborted=$true; break}
        }catch [IO.IOException]{}
    }
    if($m7Timeout -or $m7Aborted){$m7Process.Kill($true); $m7Process.WaitForExit()}
    $m7Text=$m7Out.GetAwaiter().GetResult()+$m7Err.GetAwaiter().GetResult()
    $m7Log=Join-Path $m7Evidence ($Name+'.output.log'); [IO.File]::WriteAllText($m7Log,$m7Text)
    $m7Payload=$null
    $m7EngineText=Get-Content -LiteralPath (Join-Path $m7Evidence ($Name+'.engine.log')) -Raw
    $m7Pass= -not $m7Timeout -and -not $m7Aborted -and $m7Process.ExitCode -eq 0 -and $m7Text -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    $m7Pass=$m7Pass -and $m7EngineText -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    if($Marker){
        $m7Match=[regex]::Match($m7Text,'(?m)^'+$Marker+' (.+)$')
        if($m7Match.Success){$m7Payload=ConvertFrom-Json $m7Match.Groups[1].Value}
        $m7Pass=$m7Pass -and $null -ne $m7Payload -and $m7Payload.ok -and $m7Payload.count -gt 0 -and @($m7Payload.checks|Where-Object {-not $_.ok}).Count -eq 0
        $m7Expected=@{exchange=113;native_ui=36}
        if($m7Expected.ContainsKey($Name)){$m7Pass=$m7Pass -and $m7Payload.count -eq $m7Expected[$Name] -and @($m7Payload.checks).Count -eq $m7Expected[$Name]}
    }
    $m7Runs.Add(@{name=$Name;ok=$m7Pass;arguments=$Arguments;started_utc=$m7Start;finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$m7Process.ExitCode;timed_out=$m7Timeout;aborted=$m7Aborted;output_sha256=(Get-FileHash -LiteralPath $m7Log).Hash;result=$m7Payload})
    [IO.File]::WriteAllText((Join-Path $m7Evidence 'runs.json'),(ConvertTo-Json -InputObject @($m7Runs.ToArray()) -Depth 30))
    $m7Process.Dispose(); Write-Output ($Name+': '+$m7Pass)
    if(-not $m7Pass){Write-Output $m7Text; throw ('M7 failed: '+$Name)}
}
Invoke-M7 'import' @('--headless','--editor','--import','--quit')
if(-not $UIOnly){
Invoke-M7 'exchange' @('--headless','--script','res://tests/map_editor_exchange_test.gd') 'M7_RESULT'
foreach($m7Label in @('a','b')){Invoke-M7 ('cli_'+$m7Label) @('--headless','--script','res://scripts/map_authoring/exchange/headless.gd','--','review',(Join-Path $m7Fixture '.godot/m7_samples/map.rpx'),(Join-Path $m7Fixture '.godot/m7_samples/map_proposal.rpx'),(Join-Path $m7Fixture '.godot/m7_samples/map.json'))}
$m7HashA=[regex]::Match((Get-Content -LiteralPath (Join-Path $m7Evidence 'cli_a.output.log') -Raw),'MAP_EXCHANGE_RESULT (.+)').Groups[1].Value|ConvertFrom-Json
$m7HashB=[regex]::Match((Get-Content -LiteralPath (Join-Path $m7Evidence 'cli_b.output.log') -Raw),'MAP_EXCHANGE_RESULT (.+)').Groups[1].Value|ConvertFrom-Json
if(-not $m7HashA.ok -or -not $m7HashB.ok -or $m7HashA.output_hash -ne $m7Runs[1].result.package_hash -or $m7HashB.output_hash -ne $m7HashA.output_hash){throw 'CLI completion/hash mismatch.'}
}
if($Native -or $UIOnly){
    $m7Driver=Join-Path $m7Fixture 'addons/m7_driver'; [void](New-Item -ItemType Directory -Force -Path $m7Driver)
    Copy-Item -LiteralPath (Join-Path $m7Root 'tests/map_editor_exchange_ui_test.gd') -Destination (Join-Path $m7Driver 'plugin.gd') -Force
    '[plugin]','name="Fixture F6"','description="Teste isolado"','author="RagRPG"','version="1"','script="plugin.gd"'|Set-Content -LiteralPath (Join-Path $m7Driver 'plugin.cfg') -Encoding utf8
    Add-Content -LiteralPath (Join-Path $m7Fixture 'project.godot') -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/m7_driver/plugin.cfg`")" -Encoding utf8
    Invoke-M7 'native_ui' @('--editor','--rendering-method','gl_compatibility') 'M7_UI_RESULT'
}
$m7Inputs=@()
foreach($m7Dir in @('scripts','scenes','resources','content','data','assets','addons/ragrpg_map_editor','tests','tools')){
    foreach($m7File in Get-ChildItem -LiteralPath (Join-Path $m7Root $m7Dir) -Recurse -File){
        if($m7File.Name.EndsWith('.import')){continue}
        $m7Relative=[IO.Path]::GetRelativePath($m7Root,$m7File.FullName).Replace('\','/')
        $m7SourceHash=(Get-FileHash -LiteralPath $m7File.FullName).Hash
        $m7FixtureHash=(Get-FileHash -LiteralPath (Join-Path $m7Fixture $m7Relative)).Hash
        if($m7SourceHash -ne $m7FixtureHash){throw ('Source/fixture mismatch: '+$m7Relative)}
        $m7Inputs+=@{path=$m7Relative;sha256=$m7SourceHash;fixture_sha256=$m7FixtureHash}
    }
}
@{head_before=$m7Head;head_after=(git -C $m7Root rev-parse HEAD);engine=(Resolve-Path -LiteralPath $GodotPath).Path;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;fixture=$m7Fixture;project_source_sha256=(Get-FileHash -LiteralPath (Join-Path $m7Root 'project.godot')).Hash;project_fixture_sha256=(Get-FileHash -LiteralPath (Join-Path $m7Fixture 'project.godot')).Hash;declared_project_deltas=@('VCS startup disabled','UI driver only when Native');inputs=$m7Inputs;runs=$m7Runs.ToArray()}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $m7Evidence 'manifest.json') -Encoding utf8
Write-Output 'M7_ALL_PASS'

# Prepare the same fixture for the official read-only checks. Preserve native
# project hashes above, then remove only the declared fixture-driver config.
[IO.File]::WriteAllText((Join-Path $m7Fixture 'project.godot'),$m7Project)
$m7Primary=@{}
foreach($m7Input in $m7Inputs){$m7Primary[$m7Input.path]=$m7Input.sha256.ToLowerInvariant()}
[IO.File]::WriteAllText((Join-Path $m7Fixture 'source_hashes.json'),(ConvertTo-Json -InputObject $m7Primary -Depth 5))
[IO.File]::WriteAllText((Join-Path $m7Fixture 'source_root.txt'),$m7Root)
