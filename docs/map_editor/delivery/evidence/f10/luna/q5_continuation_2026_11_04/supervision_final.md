# F10 Q5 continuation — final supervision receipt

Date: 2026-11-05  
Worktree: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`  
Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`  
Fixture: `.godot/verification/e07_f1/fixture_project`

All final tests below ran before the local code commit, with HEAD `d49dc1603ca6ab0e380054c45b0adcaecb3a10ab` recorded before and after the runs. The parent reports the tested inputs remained unchanged when commit `d54526502f536f695bd5982d50f5c4ef93441efe` was created; no post-commit rerun was performed. The final import manifest records 2,218 source/fixture entries with zero hash differences. The release manifest independently records the same 2,218 entries with zero differences. Both manifests record the same HEAD and engine hash.

Manifest hashes: final import `A1052BAC5D16CFF8AEFFF33605101AF489C6CFAE81370194631AB64ED069E4C3`; release `1D66D633F1C1A7E87E1AA113CDA6A0BA115F8F55A71DED76580CD2AA3A8FE263`. The final import manifest gives matching source/fixture hashes for `world_connectivity_batch.gd` (`F563D220CA879543739C8DCB5492DB908F3F6A3C91AE9F95FB0D6D5CDAE86C70`), `world_height_grid.gd` (`0908D2090D85291EC3A37C9AB0B8ADF38AF55AF4F206B0607D340AE5C0F9941C`), `population_planner.gd` (`12483DDC684F937D6AB4A0C322640016B3BD0411DA1D86697166D2F98F6E9627`), and `map_editor_phase_release_test.gd` (`5908D98DE5350283E3EBDF589BE607EFC839FD2980ABE7F84CE22034C87BFFBD`). Completion runner receipts contain 2,224 source input records; their script hashes match the final manifest for the tested native stages.

## Final validation

Each stage ran sequentially on the one existing fixture. The log scan found no `SCRIPT ERROR`, `Parse Error`, `ERROR`, or timeout patterns.

| Evidence folder | Result | Exit / timeout | `runs.json` SHA256 |
|---|---:|---|---|
| `.godot/q5_continue/validated_HeightGridNavigation` | 16/16 | 0 / false | `A6C4C6C992510AEF0C4464265BE88729C46B58D26C8DB6C11F0C4A1D38B7B253` |
| `.godot/q5_continue/validated_Q5UsabilityNative` | 12/12 | 0 / false | `8620DFBEF78E8E9F5F87E987C7142D4E727FF15A0B0E97E724C97C8A15311E03` |
| `.godot/q5_continue/official_geometry_population` — F1 geometry | 33 checks, 0 failures | 0 / false | `checks.jsonl`: `893473CF51CBED376B7B03B3E9953443D4CEAF6FC5116BD883D0ACD476F047FA` |
| `.godot/q5_continue/official_geometry_population` — F5 population | 40 checks, 0 failures | 0 / false | same `checks.jsonl` above |
| `.godot/q5_continue/release_after` — release | 6/6 | 0 / false | included in aggregate below |
| `.godot/q5_continue/release_after` — Bosque | 8/8 | 0 / false | included in aggregate below |
| `.godot/q5_continue/release_after` — Forest | 14/14 | 0 / false | included in aggregate below |

For F7 presentation, the earlier receipt `.godot/q5_continue/presentation_followup` records 19 checks, zero failures, exit 0, and no timeout. The parent verified that the F7 presentation files and the F7 presentation test remain byte-identical, so this evidence is reused and was not rerun. This does not claim the whole broader input set is unchanged; the navigation test and runner differ. `checks.jsonl` SHA256 `A1BE2045BB3F17C27FDE62F67869904735AD132C12B7264AB0ACF30702B0427E`; `plan.json` SHA256 `8CDF20ECEF0BCA42FF1FF3814D4FD5CE962BB573AEC4766A08937D2F9E287AA0`.

`validated_HeightGridNavigation` reported `F10_GRID_NAV_TIMING`: batch 160.2 ms, cold 96.4 ms, warm 32.3 ms for 11 points. `validated_Q5UsabilityNative` reported a 1440×1000 window, UX canvas 569×323 and AX canvas 575×304; all 12 checks passed. Its screenshot `q5_editor_usability.png` SHA256 is `5CE1BF5BCFC8B8812053E2B3A1CDBD8F12CDBB573D539198B10B3225A53E72B5`.

The release runner completed `M8_SELECTED_PASS`. `runs.json` SHA256 `765B08508989C21C0D4FA3964485A8F079E475BF6B6BB11AA4EC3AB3C6F8A323`; `manifest.json` SHA256 `1D66D633F1C1A7E87E1AA113CDA6A0BA115F8F55A71DED76580CD2AA3A8FE263`; `release_manifest.json` SHA256 `E3800ACAF012D862B4D22E46230160F50DD8B67F9EB1A3ECD3761D4CC3FC08F5`. All five release processes (import, export, release, Bosque, Forest) exited 0, were not timed out or aborted, and returned `ok=true`. No error patterns appeared in logs.

Sampled peak working set: import 914,288,640 B; export 1,031,364,608 B; release 624,005,120 B; Bosque 875,442,176 B; Forest 1,092,640,768 B. Forest timings: entry 171,066.538 ms, suspend 7,018.8 ms, resume 26,569.841 ms. Package hashes: release `b6ffc4b62c6dfc7583351bc8adc24d707b42e0282c8502ac635a829e1355f024`; Bosque `41a8e11a6c70fdc9c87cec67a2c9f8fc8fb7af5ecfdc1690ba532472c0e52587`. Screenshots `release.png`, `release_sanctuary_woods.png`, and `release_forest.png` are present in the evidence folder; the forest screenshot SHA256 is `2D8A076372D00057C890654655A073C0AD2D020A003531E366B30CE27E110CFA`.

## Historical baselines and discarded trials

The earlier `package_before` profile passed 1/1 with load 118,770.58 ms and package hash `d9d52701a7a40124969d94f1770ef9f3cc3d0f609691afc02ebae48ccdf665ce`. Its runtime script hashes match the final manifest; only test/runner and import-sidecar input sets differ. This is retained as a profile baseline, not as new test coverage.

The `package_after` profile measured load 121,270.716 ms. Its `world_connectivity_batch.gd` hash was `77D32A4ACD881CB11332732C54D15EB244D9C1A96228D644AA722395231E9DD6` (changed from final); its `world_height_grid.gd` hash matched final at `0908D2090D85291EC3A37C9AB0B8ADF38AF55AF4F206B0607D340AE5C0F9941C`. Before `projection_PackageProfile`, Sol restored `world_connectivity_batch.gd`; its hash `F563D220CA879543739C8DCB5492DB908F3F6A3C91AE9F95FB0D6D5CDAE86C70` matches final. That projection changed only `world_height_grid.gd` to hash `BA58852D2EC186C4B586A5E071070C714A90F44D874EF9516A33466D2497C819`, instead of the final `0908D2090D85291EC3A37C9AB0B8ADF38AF55AF4F206B0607D340AE5C0F9941C`; it measured 127,551.302 ms. Neither trial improved on the 118,770.58 ms `package_before` baseline, so neither is claimed as a performance gain. `projection_HeightGrid` (17/17) and `projection_HeightGridNavigation` (16/16) also ran under the changed height-grid source and are discarded for final-source validation. Earlier `final_Batch` (36/36), `final_PopulationPlanner` (22/22), `final_CandidateBatch` (18/18), and `final_HeightGridNavigation` (16/16) ran with a changed `world_connectivity_batch.gd`; they are not counted as final-source validation. No repeated-run counts are added together as coverage.

The earlier `preparation_before` ForestPhase run passed 9/9 and reported manifest hash `12271a4e44f456e7e2993bcd4d81a405717ab2463be0697a969964bac5916707`, total preparation 178,986 ms. Its input set differs from final in three runtime scripts (`patrol_compiler.gd`, `terrain_panel.gd`, `workflow_bar.gd`), so it is historical only and is not used as a final performance comparison. There was no final-source ForestPhase rerun in the last root batch.

All final stages completed and engine/fixture ownership was returned. This receipt supervises process completion, test counts, logs, and hashes; it is not an independent semantic audit.

