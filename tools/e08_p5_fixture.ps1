param(
    [Parameter(Mandatory=$true)][ValidateSet('sync','import','verify','probe')][string]$Stage,
    [Parameter(Mandatory=$true)][string]$Package,
    [Parameter(Mandatory=$true)][string]$EvidenceName,
    [string[]]$Test=@(),
    [string]$Script='',
    [string[]]$ScriptArgs=@(),
    [switch]$Headless,
    [int]$LockWaitMinutes=60,
    [ValidateRange(60,1800)][int]$TimeoutSeconds=300
)
## E08 P5 shared-fixture wrapper. One writer/runner at a time (atomic directory
## lock), process CWD pinned to the worktree, APPDATA/LOCALAPPDATA isolated,
## immutable evidence names, ownership from docs/epics/e08_p5_files.json.
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
[Environment]::CurrentDirectory=$taskRoot
Set-Location -LiteralPath $taskRoot
$fixture=Join-Path $taskRoot '.godot/verification/e07_f1/fixture_project'
$p5Root=Join-Path $taskRoot '.godot/verification/p5'
[void](New-Item -ItemType Directory -Force -Path $p5Root)
$outputRoot=Join-Path $p5Root ($Package+'_'+$Stage+'_'+$EvidenceName)
if(Test-Path -LiteralPath $outputRoot){throw "Evidence name already used: $outputRoot"}
$engine=Join-Path (Split-Path -Parent $taskRoot) 'godot/Godot_v4.7.2-stable_win64.exe'
if((Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'){throw 'Unexpected standard engine'}
$ownership=Get-Content -LiteralPath (Join-Path $taskRoot 'docs/epics/e08_p5_files.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if(-not ($ownership.packages.PSObject.Properties.Name -contains $Package)){throw "Unknown package $Package"}
$lock=Join-Path $p5Root 'fixture.lock'
$deadline=[DateTime]::UtcNow.AddMinutes($LockWaitMinutes)
while($true){
    try{[void](New-Item -ItemType Directory -Path $lock -ErrorAction Stop);break}catch{
        if([DateTime]::UtcNow -gt $deadline){throw "Fixture lock busy: $lock ($(Get-Content -LiteralPath (Join-Path $lock 'owner.txt') -ErrorAction SilentlyContinue))"}
        Start-Sleep -Seconds 10
    }
}
try{
    Set-Content -LiteralPath (Join-Path $lock 'owner.txt') -Value "$Package $Stage $EvidenceName $([DateTime]::UtcNow.ToString('o'))"
    [void](New-Item -ItemType Directory -Force -Path $outputRoot)
    $manifestPath=Join-Path $fixture 'source_hashes.json'
    $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    if($Stage -eq 'sync'){
        # Any package may sync: changes of every package are owned somewhere; files
        # outside all P5 lists (or read-only inputs) are refused.
        $allowed=@()
        foreach($p in $ownership.packages.PSObject.Properties){$allowed+=@($p.Value.files)}
        $allowed+=@($ownership.coordinator_files)
        $readOnly=@($ownership.read_only_inputs)
        $changed=@()
        Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $outputRoot 'previous_source_hashes.json')
        foreach($rel in @($manifest.Keys)){
            $old=Join-Path $fixture $rel
            if(-not (Test-Path -LiteralPath $old) -or (Get-FileHash -LiteralPath $old -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest[$rel]){throw "Previous fixture drift: $rel"}
            $current=Join-Path $taskRoot $rel
            if(-not (Test-Path -LiteralPath $current)){throw "Missing previous input: $rel"}
            $hash=(Get-FileHash -LiteralPath $current -Algorithm SHA256).Hash.ToLowerInvariant()
            if($hash -ne $manifest[$rel]){
                if($rel -notin $allowed -or $rel -in $readOnly){throw "Changed input outside P5 ownership: $rel"}
                $changed+=@{path=$rel;before_sha256=$manifest[$rel];after_sha256=$hash}
            }
        }
        foreach($rel in $allowed){
            if($rel.EndsWith('/') -or $rel.StartsWith('docs/')){continue}
            $current=Join-Path $taskRoot $rel
            if((Test-Path -LiteralPath $current -PathType Leaf) -and -not $manifest.ContainsKey($rel)){
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
        Write-Output "Synchronized $($changed.Count) inputs; $($manifest.Count) sources tracked."
    }
    foreach($rel in $manifest.Keys){
        foreach($root in @($taskRoot,$fixture)){
            $source=Join-Path $root $rel
            if(-not (Test-Path -LiteralPath $source) -or (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest[$rel]){throw "Source/fixture mismatch (run -Stage sync first): $rel"}
        }
    }
    function Invoke-Engine([string]$Label,[string[]]$EngineArguments,[int]$Limit=300){
        $target=Join-Path $outputRoot $Label
        [void](New-Item -ItemType Directory -Path $target -Force)
        $info=[Diagnostics.ProcessStartInfo]::new()
        $info.FileName=$engine;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WorkingDirectory=$taskRoot
        $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
        $info.Environment['APPDATA']=Join-Path $target 'appdata';$info.Environment['LOCALAPPDATA']=Join-Path $target 'localappdata'
        foreach($arg in $EngineArguments){$info.ArgumentList.Add($arg.Replace('{output}',$target))}
        $process=[Diagnostics.Process]::new();$process.StartInfo=$info;$started=[DateTime]::UtcNow
        [void]$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        $timedOut=-not $process.WaitForExit($Limit*1000)
        if($timedOut){$process.Kill($true);$process.WaitForExit()}
        $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$code=$process.ExitCode;$process.Dispose()
        [IO.File]::WriteAllText((Join-Path $target 'stdout.log'),$out);[IO.File]::WriteAllText((Join-Path $target 'stderr.log'),$err)
        $failed=$timedOut -or $code -ne 0 -or (($out+$err) -match 'SCRIPT ERROR:|Parse Error:|ERROR:')
        [ordered]@{label=$Label;package=$Package;arguments=$EngineArguments;started_utc=$started.ToString('o');elapsed_seconds=([DateTime]::UtcNow-$started).TotalSeconds;exit_code=$code;timed_out=$timedOut;failed=$failed;engine_sha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash;source_manifest_sha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $target 'execution.json') -Encoding UTF8
        Write-Output "$Label exit=$code timeout=$timedOut failed=$failed"
        if($failed){Write-Output (($out+$err).Substring(0,[Math]::Min(4000,($out+$err).Length)));throw "Engine step failed: $Label"}
    }
    if($Stage -eq 'import'){Invoke-Engine 'import' @('--headless','--path',$fixture,'--editor','--import','--quit') $TimeoutSeconds}
    if($Stage -eq 'probe'){
        if(-not $Script.StartsWith('res://')){throw 'Probe script must be res:// inside the fixture'}
        $arguments=@();if($Headless){$arguments+='--headless'}
        $arguments+=@('--path',$fixture,'--script',$Script,'--','{output}')+$ScriptArgs
        Invoke-Engine 'probe' $arguments $TimeoutSeconds
    }
    if($Stage -eq 'verify'){
        if($Test.Count -eq 0){throw 'verify requires -Test'}
        & (Join-Path $taskRoot 'tools/verify.ps1') -GodotPath $engine -F1Fixture -SkipEditorImport -VerificationDirectory $outputRoot -Test $Test
        if($LASTEXITCODE){throw "verify failed ($LASTEXITCODE)"}
    }
}finally{
    Remove-Item -LiteralPath $lock -Recurse -Force -ErrorAction SilentlyContinue
}
