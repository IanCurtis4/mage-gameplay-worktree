param([string]$EvidenceName='attempt1')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $taskRoot '.godot/verification/e07_f1/fixture_project'
$outputDirectory=Join-Path $taskRoot ('.godot/verification/p4_sol/'+$EvidenceName)
if(Test-Path -LiteralPath $outputDirectory){throw 'Choose a new evidence name; do not overwrite attempts.'}
[void](New-Item -ItemType Directory -Path $outputDirectory -Force)
$engine=Join-Path (Split-Path -Parent $taskRoot) 'godot/Godot_v4.7.2-stable_win64.exe'
$info=[System.Diagnostics.ProcessStartInfo]::new()
$info.FileName=$engine
$info.UseShellExecute=$false
$info.CreateNoWindow=$true
$info.RedirectStandardOutput=$true
$info.RedirectStandardError=$true
$info.Environment['APPDATA']=Join-Path $outputDirectory 'appdata'
$info.Environment['LOCALAPPDATA']=Join-Path $outputDirectory 'localappdata'
foreach($arg in @('--path',$fixture,'--script','res://tools/e08_p4_ui_probe.gd','--',$outputDirectory)){$info.ArgumentList.Add($arg)}
$started=[DateTime]::UtcNow
$p=[System.Diagnostics.Process]::new(); $p.StartInfo=$info
[void]$p.Start()
$stdout=$p.StandardOutput.ReadToEndAsync(); $stderr=$p.StandardError.ReadToEndAsync()
$timeout=-not $p.WaitForExit(180000)
if($timeout){$p.Kill($true); $p.WaitForExit()}
$out=$stdout.GetAwaiter().GetResult(); $err=$stderr.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $outputDirectory 'stdout.log'),$out)
[IO.File]::WriteAllText((Join-Path $outputDirectory 'stderr.log'),$err)
$exitCode=$p.ExitCode; $p.Dispose()
$failed=$timeout -or $exitCode -ne 0 -or (($out+$err) -match 'SCRIPT ERROR:|Parse Error:|ERROR:')
[ordered]@{started_utc=$started.ToString('o');elapsed_seconds=([DateTime]::UtcNow-$started).TotalSeconds;exit_code=$exitCode;timed_out=$timeout;failed=$failed;engine_sha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash;probe_sha256=(Get-FileHash -LiteralPath (Join-Path $fixture 'tools/e08_p4_ui_probe.gd') -Algorithm SHA256).Hash;runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;source_manifest_sha256=(Get-FileHash -LiteralPath (Join-Path $fixture 'source_hashes.json') -Algorithm SHA256).Hash} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirectory 'execution.json') -Encoding utf8
Write-Output $out
Write-Output $err
if($failed){throw "P4 Sol probe failed: exit=$exitCode timeout=$timeout"}
