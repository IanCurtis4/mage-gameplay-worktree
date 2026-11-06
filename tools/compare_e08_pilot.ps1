param([Parameter(Mandatory)][string]$PilotDirectory)
$ErrorActionPreference = 'Stop'
$benchSource = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5'
$benchEngine = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe'
$benchBaseline = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_f10/terrain_2ff1c00f/RagRPG-F10-Q5-Terreno.pck'
if ((Get-FileHash -LiteralPath $benchBaseline).Hash.ToLowerInvariant() -ne '136d35e0d059572b633e2d743fba839e97273b1aaa11d7f41c28ad9b0b9dee3a') { throw 'Baseline PCK mismatch.' }
$benchEvidence = Join-Path $PilotDirectory 'comparison'
[void](New-Item -ItemType Directory -Force -Path $benchEvidence)
$benchRuns = [Collections.Generic.List[object]]::new()
foreach ($benchMode in @('baseline','pilot')) {
    $benchPack = if ($benchMode -eq 'baseline') { $benchBaseline } else { Join-Path $PilotDirectory 'RagRPG-E08-Piloto1.pck' }
    foreach ($benchProbe in @('e08_crowd_compare','e08_terrain_compare','e08_preparation_compare')) {
        $benchName = $benchMode + '_' + $benchProbe
        $benchDestination = Join-Path $benchEvidence $benchName
        [void](New-Item -ItemType Directory -Force -Path $benchDestination)
        $benchInfo = [Diagnostics.ProcessStartInfo]::new()
        $benchInfo.FileName = $benchEngine
        $benchInfo.WorkingDirectory = $benchDestination
        $benchInfo.UseShellExecute = $false
        $benchInfo.CreateNoWindow = $true
        $benchInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
        $benchInfo.RedirectStandardOutput = $true
        $benchInfo.RedirectStandardError = $true
        $benchInfo.Environment['APPDATA'] = Join-Path $benchDestination 'profile'
        $benchInfo.Environment['LOCALAPPDATA'] = $benchInfo.Environment['APPDATA']
        $benchInfo.Environment['TERRAIN_EVIDENCE'] = $benchDestination
        [void](New-Item -ItemType Directory -Force -Path $benchInfo.Environment['APPDATA'])
        $benchScript = Join-Path $PSScriptRoot ($benchProbe + '.gd')
        foreach ($benchArg in @('--main-pack',$benchPack,'--rendering-method','gl_compatibility','--script',$benchScript,'--log-file',(Join-Path $benchDestination 'engine.log'))) { $benchInfo.ArgumentList.Add($benchArg) }
        $benchProcess = [Diagnostics.Process]::new()
        $benchProcess.StartInfo = $benchInfo
        $benchStarted = [DateTime]::UtcNow
        [void]$benchProcess.Start()
        $benchOut = $benchProcess.StandardOutput.ReadToEndAsync()
        $benchErr = $benchProcess.StandardError.ReadToEndAsync()
        $benchTimedOut = -not $benchProcess.WaitForExit(360000)
        if ($benchTimedOut) { $benchProcess.Kill($true); $benchProcess.WaitForExit() }
        $benchText = $benchOut.GetAwaiter().GetResult() + $benchErr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $benchDestination 'output.log'),$benchText)
        $benchLog = [IO.File]::ReadAllText((Join-Path $benchDestination 'engine.log'))
        $benchResultLine = [regex]::Matches($benchText,'(?m)^(?:WORLD_CROWD_RESULT|TERRAIN_PERF_RESULT|PREPARATION_FINAL_RESULT) (.+)$')
        $benchResult = if ($benchResultLine.Count) { $benchResultLine[-1].Groups[1].Value | ConvertFrom-Json -AsHashtable } else { @{ok=$false} }
        $benchOk = -not $benchTimedOut -and $benchProcess.ExitCode -eq 0 -and ($benchText+$benchLog) -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:' -and $benchResult.ok
        $benchRuns.Add(@{name=$benchName;ok=$benchOk;timed_out=$benchTimedOut;exit_code=$benchProcess.ExitCode;started_utc=$benchStarted.ToString('o');finished_utc=[DateTime]::UtcNow.ToString('o');pack=$benchPack;pack_sha256=(Get-FileHash -LiteralPath $benchPack).Hash.ToLowerInvariant();probe_sha256=(Get-FileHash -LiteralPath $benchScript).Hash.ToLowerInvariant();peak_working_set_bytes=$benchProcess.PeakWorkingSet64;output_sha256=(Get-FileHash -LiteralPath (Join-Path $benchDestination 'output.log')).Hash.ToLowerInvariant();result=$benchResult})
        [IO.File]::WriteAllText((Join-Path $benchEvidence 'runs.json'),(ConvertTo-Json -InputObject @($benchRuns.ToArray()) -Depth 18))
        $benchProcess.Dispose()
        Write-Output "$benchName : $benchOk"
        if (-not $benchOk) { throw "Comparison failed: $benchName; preserve raw logs." }
    }
}

