# F10 Q5 remaining — Luna supervision receipt

Date: 2026-11-05  
Worktree: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`  
Engine: Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`  
Fixture: `.godot/verification/e07_f1/fixture_project`

The worktree was confirmed to be the specified checkout and no Godot or candidate processes were active before the run. Inputs were frozen. No source, test, runner, or expectation was edited by Luna.

## Step 1 — official directed verify selection

Evidence: `.godot/q5_remaining/verify_first`  
Selection: `e07_f4_resume_staging_test` and `e07_f7_presentation_test`, F1 fixture, editor import skipped, 300-second per-check timeout, disposable `APPDATA` and `LOCALAPPDATA` under the fixture profile. Both processes passed and exited 0 without timeout or abort:

- F4 resume staging: 91 checks, 0 failures.
- F7 presentation: 26 checks, 0 failures.

No `SCRIPT ERROR`, `Parse Error`, `ERROR`, or timeout patterns were found. The F7 test did emit two Control anchor-size warnings at test lines 55 and 58; the parent has retained these for test/UI correction. `checks.jsonl` SHA256 `E5564F6ECF03B4D6A25FE0E2C779DFF982BF69B82326459F26A40E3BB8329EA6`; `plan.json` SHA256 `3F2EBFC0D4EFB5143A9F23A0F42CE0150D81BD10E4F9344D82407E828250A7F4`. Plan HEAD: `954341d5721ea6959fb89b1458ce17242e3ce6f6`; engine hash as above.

## Step 2 — stopped at FarNavigation

Evidence: `.godot/q5_remaining/FarNavigation`  
The first requested completion stage failed to parse, so the sequence stopped immediately. Runner output: `F9 FarNavigation: False`. The engine reported at `tests/map_editor_far_navigation_test.gd:150`: `Cannot infer the type of "warm" variable because the value doesn't have a set type.` It then failed to load the script with a parse error. No test checks ran (`result_count=0`). This was a process failure, not a timed out run: exit 1, `timed_out=false`, `aborted=false`.

`runs.json` SHA256: `AC3C17E6FBF14E3A7DC75EC89581AD1AABD6BAB6A7EE89F71607BD384293600A`  
`geometry.engine.log` SHA256: `89164F77521BCCCE75E1DEE134A21CF68F2C9D6BE1D5A760B89C42EBF4187813`  
`geometry.output.log` SHA256: `F1B23D71307C1DA59BEB32012ACAAD26C06A306969EEDE6C5563D7B653C3C085`

The run recorded HEAD `954341d5721ea6959fb89b1458ce17242e3ce6f6` before and after, 2,237 inputs, and the standard engine SHA above. After the process exited, a process check found no Godot or candidate process active.

## Stop point

`SnapshotDensity`, `NavigationLazy`, `NavigationAstar`, `NavigationAsync`, `NavigationContext`, `NavigationDense`, `HeightGridNavigation`, `Batch`, `PopulationPlanner`, `CandidateBatch`, `PreparationProofs`, the second full verify selection, and M8 Release were not run. The engine and fixture are returned to Sol for the parse error and F7 presentation warnings. This is execution supervision, not an independent semantic audit.

## Continuation after FarNavigation harness correction

The earlier `FarNavigation2` receipt had all 25 conditions true and process exit 0, but runner `ok=false` because its expected count was 28. The runner cardinality expectation was corrected to 25; this harness mismatch is preserved separately and is not classified as a failed navigation condition. `FarNavigation2/runs.json` SHA256: `F53274754956C6A422395DAE7361183765FFE37C78F8ED9EE7BA0C790857E6F7`.

With the corrected expectation, `FarNavigation3` passed 25/25; exit 0, no timeout/abort/error, HEAD unchanged, 2,237 inputs. `runs.json` SHA256: `28F24BC48D73C67628495E738A705F20A1C53AD4D580B669270A5B52B9C6F976`. The preceding parse-error receipt remains at `.godot/q5_remaining/FarNavigation` (exit 1, no checks) and is retained as history.

The remaining completion stages passed sequentially. Every runner returned `ok=true`, exit 0, `timed_out=false`, `aborted=false`; scans found no `SCRIPT ERROR`, `Parse Error`, `ERROR`, or timeout patterns.

| Evidence folder | Result | `runs.json` SHA256 |
|---|---:|---|
| `.godot/q5_remaining/SnapshotDensity` | 34/34 | `1C49A6327B1A1E700EE6FA77B757C954C4A667615A681A6EECD77807FE48005E` |
| `.godot/q5_remaining/NavigationLazy` | 24/24 | `6B1AFBE5878D79E0D93C60C2CE7DB736EBA881D6178B238AE0769E9949DA8C58` |
| `.godot/q5_remaining/NavigationAstar` | 18/18 | `A8CA3AA52C139EF04FFEBB4B43957BCAC6BBF1FE00BA2EEF334A759ABF939CC9` |
| `.godot/q5_remaining/NavigationAsync` | 18/18 | `2414D533D916C45109A34AC48C43BF6978D0562C407237D05D7C40C8E15208BE` |
| `.godot/q5_remaining/NavigationContext` | 11/11 | `3319C83B7A41E316DBE5C6CB7AA22FB1269ADD28372522CB98B2F871733F380C` |
| `.godot/q5_remaining/NavigationDense` | 5/5 | `BD8CD71015038621CCD80F3C8D2FEF92E67EBD7143F14272CF4DBEBF31D90115` |
| `.godot/q5_remaining/HeightGridNavigation` | 16/16 | `E02320AA5152E858B940C9A895B526121A28640743983A96362E8C348EF6828F` |
| `.godot/q5_remaining/Batch` | 36/36 | `227E84F7E2900EBE966270D88F5118C5771D99294B50B8EA74EE25A5A9B65552` |
| `.godot/q5_remaining/PopulationPlanner` | 22/22 | `77F6257B9C4576DB2359B64097CEA3655B9739FCCAF6608642142742BF0D04FF` |
| `.godot/q5_remaining/CandidateBatch` | 18/18 | `0C60DC966DA4788C89E5D70FE278079CB8D53354B829CAC115964BE924581195` |
| `.godot/q5_remaining/PreparationProofs` | 23/23 | `C9F60D76166FC18D944062AC55035431F4ECC330A3D7AFA74F847DA436C075D9` |

HeightGridNavigation timing was batch 160.4 ms, cold 100.8 ms, warm 48.8 ms for 11 points. Async metrics reported organic call 7,098 µs / compute 1,872,712 µs and port call 3,645 µs / compute 117,692 µs; the main loop remained responsive. NavigationDense reported 2,617,496 µs for target Z=4.0 and a direct target Z=95.0 path in 30,487 µs. Batch direct case was 15.558 ms; detour 182.101 ms, 23 connections, 170 edge tests, 174 expansions, 165 states, 2,625,208 B peak storage.

## Full official verify selection

`verify.ps1 -List` selected exactly 26 of 301 IDs: seven F4, three F7, ten F5, five F3, and F1 geometry. It ran with the F1 fixture, editor import skipped, 300-second per-check timeout, and disposable `APPDATA`/`LOCALAPPDATA`. All 26 processes recorded exit 0, `failed=false`, `timed_out=false`, `aborted=false`; no `SCRIPT ERROR`, `Parse Error`, `ERROR`, or timeout pattern appeared. Per-test counts from output logs:

- F4: alt isolation 16; controller 11; restart 3; durable 28; fault 53; compatibility 16; resume staging 91.
- F7: presentation 26; flow 23 assertions; actions 28.
- F5: population 40; campaign 28; recovery 33; fault 20; completion 39; quest 21; death kits 191; reward 6; waves 37; build 32.
- F3: snapshot 52; continuation 2,743 across 30 scenarios; action matrix 2,004 across 21 scenarios; lifecycle 90; mob state 372 across four scenarios.
- F1 geometry: 33.

The plan records HEAD `954341d5721ea6959fb89b1458ce17242e3ce6f6`, engine hash above, 26 selected steps, and runner SHA256 `7B99350BF37544BB1CF02A977097904BD7DDA2519EF7FDA8CBB1D57DEA7D5410`. `checks.jsonl` SHA256 `A4A93DB21B0C7D449DEB0EC6FC0DC69806CD23C1A63C55AE922D958B80713071`; `plan.json` SHA256 `F1E4F307D79E33867644FBEF7CB9DDA7FC0046BA0AE344903A99FE2207BEEF95`. No Godot/candidate process remained after the selection.

## Isolated seam probe and follow-up test correction

After the 26-ID selection, the requested isolated `e07_f1_presentation_test` run in `.godot/q5_remaining/verify_seam_before` reproduced the known expectation mismatch: 37 checks, one failure, exit 1, no timeout. The old assertion expected a coincident continuous seam to be refused, but the actual F9 surface-picking contract returns the deterministic root owner at `(300, 0, 150)` with an empty error code. This isolated probe is distinct from and does not invalidate the passing 26-ID selection.

`checks.jsonl` SHA256 `AEFE6185B51C86DA75AF257734672E393290532A5D0BD740E495D63E513488A6`; `plan.json` SHA256 `D1FF9461F80B314D8B7EA0F8D1D77667DFC5B358AEE85CECF933179B6DDA0897`; output log SHA256 `0492767E5A3214171B167D864A0E3889B6B96E7041EB9D0496C40FFC81DECE1F`; engine log SHA256 `29546BAE4C71920AC885C30BB40B878AF255D166C385312A067E0322CFD378E6`.

After all processes exited, Sol updated only `tests/e07_f1_presentation_test.gd` to require deterministic root ownership at that point and add a copied fixture with links disabled that must be refused at the same radius. The synchronized source and fixture test file now both hash to `190896B007F56C3029A53E2E4C22283624DAA998CF769B42E94E49A3E55201F8` (10,046 bytes); the UID files also match (`F9317EE6A19639604618EEBDCB74920D3D9E48439FD057A4531F154C53ED9BCB`). Sol reports the updated test has 39 checks. It was not rerun by Luna after this edit. No runtime file changed after `verify_full`; the earlier 26-ID selection did not include this isolated presentation test.

The subsequent seam correction and final stages are recorded below. The earlier statement that no ForestPlay was run applies to the first attempt only. Release was not run in the final continuation because the owner paused the batch before export while evaluating navigation latency.

## Final continuation — seam, far-route control, and gameplay/interface

After the full 26-ID verify selection, Sol changed only `tests/e07_f1_presentation_test.gd` and synchronized it to the existing fixture. The runtime remained unchanged. The corrected isolated F1 presentation test passed 39/39 in `.godot/q5_remaining/verify_seam_after` (exit 0, no timeout/abort); `checks.jsonl` SHA256 `A699BEE5DD660FE3D4C7CD4A34D62B27BE2552909B6DD7B2129A02998D63F868`, `plan.json` SHA256 `5DDCB82933756487EA7C1340E108465C6FD8D09D3E07D3370AB42158121B44A5`, output SHA256 `69F688370370F9985CCB61AC420F739CE3C7CEC813D86A5F5C7026EAE5639429`. The isolated SurfacePick stage also passed 24/24, exit 0, no timeout/abort; `runs.json` SHA256 `EDF12BBA6E92202B88DB39298B417D6AD6DE17C271B77AAE3DCE2D9BCCC604B4`. These are receipts supplied by the parent, not reruns by Luna. Thus the 26-ID full selection remains valid for its inputs; the updated F1 presentation test has its own passing receipt.

### Fresh-process far-route comparison

The corrected private comparison ran `reference` then `current` in separate fresh engine processes, using the existing fixture. Both returned `ok=true`, exit 0, `timed_out=false`, `aborted=false`; result fields and route matched exactly (`same_full_result=true`, distance `10620.966796875`, route 9,968 bytes, route SHA256 `B758F63B7A36B7BCBEB3E35F03794D6E949DEA87454F6486AF7B52C2878044B6`). Reference took 115,743 ms wall / 103,806.713 ms measured; current took 106,475 ms wall / 94,410.710 ms measured. Current built 454 grid fields versus 1,752 in reference and had 36,009 straight-grid rejections versus zero. This is a single paired probe, not a general performance guarantee; the distant synchronous route still took about 94.4 seconds. Both runs used engine SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`, source HEAD `954341d5721ea6959fb89b1458ce17242e3ce6f6`, and source-hashes SHA256 `1D5BA8FAD56221AFE5809A80FD78DFA967ADEA04729BE44D9D01410F1264B319`.

`.godot/q5_remaining/far_compare2/runs.json` SHA256: `506B221E36FC9311551ACA6A70928351B2CC2EC4D676A06569BACEC39915AEA0`. Reference/current JSON SHA256s: `8E2398FFC0AB9B5081954DBEFBABF9E8F444830B4DA840E13BF4EA84EB086310` / `7207721732FE5CEEE4B9322E653F78B76DFBF8D46FDB94F97EA8208586684FD1`; output-log SHA256s: `D8E671B0E233AB6B65787A9D67250F8C3D9B751746325059E067DB9B8CDD0D0E` / `2CC06363897F566AF59049560475F0E34BB83D7B2C2930586F2F9AD63E525DF2`; the route file hash above is shared. Error-pattern scan was empty and no engine/candidate process remained. The earlier `.godot/q5_remaining/far_compare` helper parse error is preserved, not overwritten; it used the untyped probe and did not produce a route result.

### Completion stages

All three stages were run sequentially with `-SkipImport` on the same fixture. Each runner reported `ok=true`, exit 0, no timeout/abort; scans found no `SCRIPT ERROR`, `Parse Error`, `ERROR`, or timeout. Each recorded 2,237 inputs, stable HEAD before/after `954341d5721ea6959fb89b1458ce17242e3ce6f6`, and the standard engine SHA above.

| Evidence folder | Checks | Stage result | `runs.json` SHA256 | Engine log SHA256 |
|---|---:|---|---|---|
| `.godot/q5_remaining/ForestPhase` | 9/9 | PASS | `FA7B5E186C514E217BBB00BBBFCE71F5E0FDE6A8062D17F6BD27CE97D9DA0F91` | `D891A6BD902CAC9FF4EEA8440FBC0C7ED591126362BFDDDF505BA24DFD1D1460` |
| `.godot/q5_remaining/ForestPlay` | 20/20 | PASS | `44B7AEFD8ABA39BBF63D30A43329AA0C9565667D84E6779DA3C6501E80F40D6C` | `91070A4BCBD0618CCFEAD8C7D05D12DF25278AA9A755CF4C707E75C449D24254` |
| `.godot/q5_remaining/GameInterface` | 9/9 | PASS | `E89EEF89C576E79F03EA7D240C60D5BA040789851F2648A8708175B3FE1E80AC` | `E069267CD52BB50AA471E6ED243C1B9F0BB96B83AB4464255362E294BB96774D` |

ForestPhase used the expected authored manifest hash `12271a4e44f456e7e2993bcd4d81a405717ab2463be0697a969964bac5916707` (1,534,752 bytes); preparation took 37,465.0 ms, with 14 proof hits and zero searches. Per-map preparation was 18,682.671 ms for `forest_terraces`, 16,342.878 ms for `forest_valleys`, and 2,349.8 ms for `forest_lair`.

ForestPlay reported the cold far-route measurement again: 94,892.831 ms, distance 10,620.9668, 0→35 lattices, 14 proof hits / 0 searches. Gameplay timing: entry 66,235 ms; terminal entry frame and longest preparation frame 27,025.3 ms; resume 22,437 ms; suspend 10,577 ms; travel 33,939 ms. Walking recorded 206 frames, 19.4 ms mean / 94.7 ms worst. Checkpoint size was 568,752 bytes and profile size 575,652 bytes. The entry and route timings remain significant latency observations.

The parent paused before M8 Release to investigate a possible further exact navigation optimization and avoid a duplicate export. Therefore Release was not run and no release result is claimed. After GameInterface completed, no Godot/candidate process remained; engine and fixture ownership were returned to the parent. This receipt records execution and evidence; it is not an independent semantic audit.

## Frozen final-input rerun — core, navigation, and UI gates

The parent transferred the engine and fixture for a final rerun. The standard engine SHA remained `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`; the checkout HEAD before and after all stages remained `954341d5721ea6959fb89b1458ce17242e3ce6f6`. Completion evidence records 2,239 input file hashes per stage. The fixture `source_hashes.json` has SHA256 `FD970C265C3B000251B3E0B3BCC2B7A696D6B6702CF9D529C608FCC7A4DCCD6E` and 2,233 entries; Luna compared every manifest entry against both the checkout and the fixture and found zero missing or mismatched files. The identical runtime hashes recorded by both the final GridAttachments and FarNavigation runs include:

- `scripts/core/expedition/spatial/world_geometry.gd`: `2AA99990CB4CFD74357EBFCEC62177F48F11F8694D5583E238B559742EF0404B`
- `scripts/core/expedition/spatial/world_height_grid.gd`: `91CC9B591743B9974AD81A92809CB45FF543BDB32DE2C94B8453A94A4EF6772B`
- `scripts/core/expedition/spatial/world_support_patch.gd`: `33411167EC754C2993B56458E7D5AED6CED7BFF9DC2B19D5B49E85C79CF00D8A`
- `tests/map_editor_far_navigation_test.gd`: `9719E1C2F936BC66FA5CA0504106DD2155A9E6EBDDF07880CF56EBEE9670EC5A`

The initial verify invocation omitted the runner's required `-GodotPath` and failed before creating evidence or starting an engine. The corrected invocation used `-VerificationDirectory` (the parameter name in `tools/verify.ps1`), F1 fixture mode, editor import skipped, 300-second check timeouts, and `APPDATA`/`LOCALAPPDATA` set to the fixture's disposable profile. The runner's plan and logs confirmed the absolute fixture path under this worktree. The 11 selected IDs passed with exit 0, `failed=false`, `timed_out=false`, and `aborted=false`; log scans were empty for `SCRIPT ERROR`, `Parse Error`, `ERROR`, and timeout. Counts from output: E06 gameplay AI 76; F4 resume staging 91 and compatibility 16; F3 snapshot 52 and continuation 2,743; F5 recovery 33 and fault 20; F7 flow 23 assertions and presentation 26; F1 geometry 33 and presentation 39. The runner replaced the default `.godot/verification/plan.json` and `checks.jsonl`; Luna preserved exact copies of that plan, manifest, and only the 22 selected engine/output logs in `.godot/q5_remaining/verify_final`. The copied bytes retain their original file hashes and their manifest paths point at the original worktree verification files. Plan SHA256 `D71E75CB10F4AC97DC74B76514CB68A2A09CC34FC09368022B1950FBFC2E319E`; checks SHA256 `84F62E218852D8B7743EC6DD0D59B009A00CE83726EFF09B878AE75C090A85F9`; runner SHA256 `7B99350BF37544BB1CF02A977097904BD7DDA2519EF7FDA8CBB1D57DEA7D5410`.

All 18 final completion stages below passed sequentially with `-SkipImport`, exit 0, `timed_out=false`, `aborted=false`, no error patterns, stable HEAD, and 2,239 hashed inputs each. Exact `runs.json` SHA256 values:

| Evidence folder | Checks | `runs.json` SHA256 |
|---|---:|---|
| `.godot/q5_remaining/final_GridAttachments` | 439/439 | `3A6A8A7AF70B11AF147886A86A23666FC4E244A97D7850FAB549AFAE33191D4B` |
| `.godot/q5_remaining/final_FarNavigation` | 33/33 | `227D2A1487B58C4BF4C36D56D9DDC7C6C7654AB364AB2EC414BF176B745AECEA` |
| `.godot/q5_remaining/final_HeightGrid` | 14/14 | `D2E3558525BFDB72816F2FC877C5B69D0FA915BB0855274D603F86EB666783FC` |
| `.godot/q5_remaining/final_HeightGridNavigation` | 16/16 | `5A434AB6F93D7986F67DD626425BCD1FB33F2FF68C1BB7473F28E0E7906C1DAB` |
| `.godot/q5_remaining/final_Batch` | 36/36 | `11ACC4DB6CCE79BBA078B479081BA24A76083AADB3A4F30103F8718CA825B2CC` |
| `.godot/q5_remaining/final_NavigationLazy` | 24/24 | `F2E1CB2316B2549F50F3A120A3050AEB63ADA0BA5C618CBFCA5C8485DA18736B` |
| `.godot/q5_remaining/final_NavigationAstar` | 18/18 | `B963BE175A0A83867BA09B8491689C1463341A124A8B3C6A018292458ADE5422` |
| `.godot/q5_remaining/final_NavigationAsync` | 18/18 | `B983E6B30D735397145C9086CD2A3BF400AD810AF2E92398EDBF12E96182F28E` |
| `.godot/q5_remaining/final_NavigationContext` | 11/11 | `A3285D9DFF713D25585A08EB6FD35EEE97E514524057681E18E6F6C391567244` |
| `.godot/q5_remaining/final_NavigationDense` | 5/5 | `7F540BEDFB9C34DC2E3BE0D6F6DC451B7726647C4E9F8947293F6A8820201939` |
| `.godot/q5_remaining/final_PopulationPlanner` | 22/22 | `6E10DBCFC4E84871EF9CC46A509917B5FC4A4207504AA3F13323211DC5DE597E` |
| `.godot/q5_remaining/final_CandidateBatch` | 18/18 | `7BA3897A8A0E95C495C52E984E3D5CE66051B78941A9EFB71D23F0AFBB7CDBF8` |
| `.godot/q5_remaining/final_PreparationProofs` | 23/23 | `933FFEF69CC79C5731D8912B1407596904529B261EA4FE11DC689BEAC6123429` |
| `.godot/q5_remaining/final_SnapshotDensity` | 34/34 | `98917428E7A646E5EE2E9DD37DA78312A72F3425F02C6D1A7D5B1E280D60EBA0` |
| `.godot/q5_remaining/final_PhasePresentation` | 10/10 | `F11DEB527649B857F558C2D82DA934BCB69463780D7EEC3BC6C230E8074F9096` |
| `.godot/q5_remaining/final_ForestPhase` | 9/9 | `D7706472D51B7345A8281B5A99836D8568C01192791A228AF7BAD27DE7098E98` |
| `.godot/q5_remaining/final_ForestPlay` | 20/20 | `C01A195CFA3EA6AF26EFDB3548A4537F617C1B456991A2886E3DC87DA6253226` |
| `.godot/q5_remaining/final_GameInterface` | 9/9 | `B647FD73336AD45DC1FA9ADA4E53A4E3C854DC73936245B02BECE67880AE3276` |

### Final-stage timing and copied controls

ForestPhase passed 9/9 with manifest hash `12271a4e44f456e7e2993bcd4d81a405717ab2463be0697a969964bac5916707` (1,534,752 bytes), 14 proof hits / zero searches, and 41,959 ms total preparation. Map times: `forest_terraces` 21,693.293 ms, `forest_valleys` 17,608.910 ms, `forest_lair` 2,564.728 ms. ForestPlay passed 20/20. Its cold distant route was 81,181.775 ms at distance 10,620.9668; gameplay entry 70,882 ms, terminal/longest preparation frame 28,186.9 ms, resume 25,339 ms, suspend 12,228 ms, travel 37,361 ms, and walking 181 frames at 22.1 ms mean / 113.3 ms worst. Checkpoint was 568,668 bytes and profile 575,568 bytes. GameInterface passed 9/9. All three used 2,239 inputs and the final manifest above; no log error/timeout patterns appeared.

Luna also inspected the preserved comparison/control receipts requested by the parent. The three far-route results had the same distance `10620.966796875` and canonical route SHA256 `B758F63B7A36B7BEBE3E35F03794D6E949DEA87454F6486AF7B52C2878044B6`; none had process errors or timeouts:

| Preserved control | Result | `runs.json` SHA256 | Source-hashes SHA256 | Classification |
|---|---|---|---|---|
| `.godot/q5_remaining/far_compare3` | 76,180.848 ms measured; same route | `7390991E8AED355E9BB6C87C8A1E537CB10D26DEFFA507738A53D07EC369E024` | `F3252CBA0FB8D036A3A5537739BBB1DF2DEB63BD59D79B8AD590D1AB2CAE36F5` | retained baseline for the contains/attachment/guard source |
| `.godot/q5_remaining/far_compare4` | 75,167.606 ms measured, no meaningful gain | `54993B4DAE52FDD34A0B6F1C60A63C42AFA6C049BA3D1DC563674499BEB0B898` | `329947552ACD639997985F164EB84ABB0F33774DDC25CA0479CBB234DAE976BE` | discarded overflow-point/scope variant |
| `.godot/q5_remaining/far_compare5` | 77,037.110 ms measured, no gain | `9004A1FCCD0785FC693AB9683F5FA4A16E864C5E8465252615AB20CB1E9505BF` | `6FC8CB690534DAEB7FD773A67C769173B6CA1A94CAD90184BE49C27FD46BA216` | discarded empty-mask-counter variant |

The parent-provided `GridAttachments3` receipt passed 439/439 (runs SHA256 `99A79E626D478F18294CDE1F8610806F6ED124FD71B98022B32CB35536926330`) and `FarNavigation6` passed 33/33 (runs SHA256 `80973F428F045D0C074CB36C235052C7128FE3E8D4029E4B718A6ED2A037D4E0`); both were exit 0 without error/timeout patterns, recorded HEAD `954341d...` and 2,239 inputs. The final reruns independently passed those same stages under the frozen manifest.

### Release hold

M8 Release was deliberately not started. Before export, the parent identified a valid title of up to 120 characters without spaces that could be clipped because the UI label's wrapping mode and measurement flags differ. Sol has exclusive control of the engine and the two UI inputs for that proof. Core/save/navigation and the 18 final completion stages remain frozen and validated; F7 presentation and GameInterface plus Release must be rechecked after the UI-only correction. No Godot/candidate process remained after GameInterface, and engine/fixture ownership was returned. This remains execution supervision, not an independent semantic audit.

## Final UI proof and Release candidate

The UI issue was reproduced and corrected by the parent/Sol before this M8 run. The title was a valid 120-character unbroken string. In `.godot/q5_remaining/portal_word_before`, F7 presentation returned 27 checks / 1 failure (exit 1, not timed out): the label measured 9 lines / 231 px while the button minimum was 58 px. `checks.jsonl` SHA256 `7DDCFB32436D8DC5A883802397FA285EE9F5F7285C250FFEAE8ACD9E335F0A81`; engine log SHA256 `6E4689A1ABEBB5C9043DDF5A3555034DA00048CE013551EA946EFA69C159BFF5`; output SHA256 `0D845EEB0BAFE664300241A107DB15D9CC364ED8E58D9BBBD57F786B6A542FA2`. Sol changed only `scripts/ui/expedition/expedition_status_panel.gd` to measure with the label's adaptive wrapping mode and real minimum height, plus `tests/e07_f7_presentation_test.gd` to retain the long-word oracle. In `.godot/q5_remaining/portal_word_after`, F7 passed 27/27 (exit 0, no timeout), with the same 9-line / 231 px label and a 243 px button. `checks.jsonl` SHA256 `002AFAA57770A56E006D4353A24B63BF82FA0EE5B21D2FB5A4DA588821E276DD`; `plan.json` SHA256 `F1FA10086C0A2237774EEF6E9A5648858E40740D15A2EB1B284263442365E2A5`; engine log SHA256 `3D6A7A454AD0DCC01D3B135162C2DCBA161123011EB87438C91CC9A0E3079AC1`; output SHA256 `E6DBD869650DF8AFF1E156D2300FBAAAC49A2D4251C4951B5C97E17592DA5F38`. The synchronized GameInterface receipt passed 9/9, exit 0, no timeout; `runs.json` SHA256 `3E49F8A1A129FCBF42C6AF7FC5F1B6C5A9D0D22B6F56A4CDB873A368E373F46B`.

Relative to the 2,239-input final FarNavigation record, an explicit hash comparison found exactly two changed input paths: `scripts/ui/expedition/expedition_status_panel.gd` (`9D484069CF5ABA9026CC98EBE832606A5C78357007765CC6AC50B957B4000527` → `E6477F964189B60C0EC60DC7F9811FF0E418178728806B75E2E8EE8D015B6852`) and `tests/e07_f7_presentation_test.gd` (`E53B0AF042F4F1117BFE3A7CA61BE9A6F363FBAFE1D1C2F1B88F3709C475FC02` → `9B806BFFCE62C36D4E6635AC63EDB2E2C625DC76146ABD7E3862AF379DE076B7`). These files are deliberately not claimed identical to the earlier 11-ID selection and 18-stage batch. Core/save/navigation inputs remained frozen and unchanged. The updated fixture manifest has 2,233 entries, SHA256 `993C713950E951CD584D998099FC04CE667B98FAB80420B132FC416748E27DB1`; all entries matched both source and fixture with zero mismatches.

With the UI proof complete and inputs frozen, M8 candidate Release ran sequentially against the existing F1 fixture in `.godot/q5_remaining/Release_final`. Import, export, Release, Bosque, and Forest rows all returned `ok=true`, exit 0, `timed_out=false`, and `aborted=false`; error scans across all logs were empty. Release checks passed 6/6; Bosque passed 8/8; Forest passed 14/14. The parent inspected `release_forest.png` and confirmed the portal was fully present. Forest release timings: entry 53,443.613 ms, resume 17,067.827 ms, suspend 6,636.961 ms.

Release process memory samples (peak working set): import 914,010,112 B; export 1,035,546,624 B; standalone Release 623,931,392 B; Bosque 879,800,320 B; Forest 1,028,395,008 B. The Release manifest recorded 2,233 inputs, stable HEAD `954341d5721ea6959fb89b1458ce17242e3ce6f6`, engine SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`, and fixture `.godot/verification/e07_f1/fixture_project`. All 2,233 release input hashes matched current source and fixture. The fixture `project.godot` was restored to the expected F1 configuration (VCS autoload disabled); its post-run hash `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517` matched the run manifest. `release_manifest.json` recorded the temporary candidate project hash separately as `0A90A7D060B43322035E741538DC181107D717BE09FC3194ADCDBCA0465400D9`.

| Release receipt | SHA256 |
|---|---|
| `.godot/q5_remaining/Release_final/runs.json` | `22668A0CC30432A1B6E724D233389B8EB07BD0FFAFCFF09CE1FE77AF70ECC1D4` |
| `.godot/q5_remaining/Release_final/manifest.json` | `B94C93E7766A3DC03C20FA0405791A3CC48B802402B9E76D9A82DEAAD8C029C3` |
| `.godot/q5_remaining/Release_final/release_manifest.json` | `2B85B397AB194CB27AD657BA6C8ADD75A29DD65B312668BA0656B301C0663DF9` |

The clean candidate artifacts remain available for Sol's archival/hash/cleanup step. `RagRPG-Map-Candidate.exe` is 109,127,680 B, SHA256 `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668`; `.pck` is 94,861,832 B, SHA256 `C59F7E5B88D366CF015CF8025A5E1C805D64FE34ACC658C9DD17682C74428B88`. The three release screenshots and hashes: `release.png` `EEFA3CE3F1F87D728B74D042F690D944A5A12373E5932C62153C6165CE687EE0`; `release_sanctuary_woods.png` `0CDD442A71D3166C63BF2C747B197737BCF22AEBABF2785BE0490BAFAD06810D`; `release_forest.png` `2F96A37917C8C0D365152EFFAE1E39569D1AE1229DDFDC73DC6A9AF301151338`. After M8 returned exit 0, no Godot/candidate process remained; engine/fixture are returned to the parent. No runtime, test, runner, or expectation was edited by Luna. This is execution supervision, not an independent semantic audit.
