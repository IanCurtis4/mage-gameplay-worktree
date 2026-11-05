# F10 Q5 — supervision of complete preparation proofs

Date: 2026-11-05  
Worktree: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`  
HEAD before/after test runs: `11c8c14e293081d9014adea22b8e4da8eeafdcc0`  
Engine: Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`  
Fixture: `.godot/verification/e07_f1/fixture_project`

The frozen sequence ran on the same fixture with `-SkipImport`, except for the already completed preparation-proof import/bake and official `verify` selection. No source, test, runner, or expectation was changed during supervision. Final completion receipts record 2,233 source inputs; official verification used the four listed IDs; the final release manifest records 2,227 source/fixture input pairs with zero hash differences. All three generated proof files are byte-identical in source and fixture. Logs from the final test and release stages had no `SCRIPT ERROR`, `Parse Error`, `ERROR`, or timeout matches.

## Frozen completion stages

| Evidence folder | Result | Exit / timeout / abort | `runs.json` SHA256 |
|---|---:|---|---|
| `.godot/preparation_proofs/final_Batch` | 36/36 | 0 / false / false | `86D44F6AE2309D9D6BA8DE5D19DE7F4A3DB06E35A4DFD3C1476CE8C8FA117B5B` |
| `.godot/preparation_proofs/final_HeightGridNavigation` | 16/16 | 0 / false / false | `550680197BE4B250F1D134B80A3F58342FFE2EC96F45E607BA781A3025771AFD` |
| `.godot/preparation_proofs/final_PopulationPlanner` | 22/22 | 0 / false / false | `6E1CCC05391C01EC041E9E1C6F2E6D0BABA98D45C2AEF4FFAB97FE1476B82FE8` |
| `.godot/preparation_proofs/final_CandidateBatch` | 18/18 | 0 / false / false | `5B2F273EECF7BA14E8C029C36EBB18E60FC5018E51814AEC00BF1BE0467690E1` |
| `.godot/preparation_proofs/final_ForestPlay` | 20/20 | 0 / false / false | `13AF285A413D21DF873B9AC32C6770A70294949CC4ED750515A316F061AA479A` |

Batch direct case: 19.111 ms, two states, 1,158,436 B peak storage. Fragmented detour: 170.49 ms, 23 connections, 170 edge tests, 174 expansions, 165 states, 2,625,208 B peak storage.

HeightGridNavigation marker: batch 135.8 ms, cold 86.4 ms, warm 31.6 ms, 11 points. PopulationPlanner's 22 checks include stage-name memo reuse with fresh worlds/slot bindings, outward-only admission, and cancellation/negative-result checks.

ForestPlay's long synchronous far-route stress query passed `first_far_route_crosses_supports`: distance 10,620.967, 102,174.623 ms, 0→35 lattices, 14 proof hits, 0 fallback searches. This is the test's synchronous first-far-route/preparation path, not the asynchronous gameplay click. The subsequent walk measurements are warm, after that route initialized lattices: 213 frames, mean 18.8 ms, worst 81.7 ms. I do not interpret the 102-second route duration as a performance saving. Other ForestPlay timings: enter 64,620 ms; entry terminal frame and longest preparation frame 26,085 ms; travel 35,090 ms; suspend 10,612 ms; resume 34,878 ms. Snapshot raw bytes 4,958,640; checkpoint 568,788 B (base64 568,232 B); profile 575,688 B; first field 62 slots. `forest_first.png` SHA256 `26CB3367EE00C3AD828823CF900E656C0F085E4E57FE17998B54C12065135E51`.

## Preparation proof import, tests, bake, and phase

The final proof test receipt `.godot/preparation_proofs/proof_tests2` passed 23/23; exit 0, no timeout/abort, HEAD unchanged, 2,230 inputs. `runs.json` SHA256: `1CC172A679F83A8D4D416C901F5FDBC368872D11D5A2BB6D783703DEB37DB447`. Checks include subset/order/duplicate/root coverage, fresh world revisions, budget/cancellation, fallback for unrecorded destinations, geometry/profile/route mismatch rejection, corruption refusal, one-way controls, and unchanged stage/occupancy.

A preliminary run in `proof_tests1` preceded the short-file framing/decoder correction and was not a pass. Sol corrected the decoder; the second run above passed without changing expectations. Preparation-proof import `.godot/preparation_proofs/import1` exited 0 and passed; its `manifest.json` SHA256 is `524E108B8E988150AD3759471460D877A47196341B56255BF73FEB62DDD4B255`.

The explicit bake `.godot/preparation_proofs/bake` returned `ok=true` for three proof files, total 1,892,680 B:

| Package / file | Bytes | SHA256 in final release manifest |
|---|---:|---|
| `forest_terraces.d9d52701a7a4.navproof` | 976,772 | `28624D7D0EEA93D7E23A811C65080048AC92B53759B30CAD889AB7FCF4E70159` |
| `forest_valleys.2faa15085074.navproof` | 849,200 | `17ACAEB78B3CD8523F8B6F1B95EB8F8916A946A86F50899020E61DAB25522E0F` |
| `forest_lair.c19cad53def8.navproof` | 66,708 | `E12B70BC533BD2126954C16AA125635CFF5FB9E752E9C0009D6A01EB604E0B0A` |

The release manifest confirms these same hashes in source and fixture. Bake `engine.log` SHA256: `EE825F6F872CCFE4260C24CDADD37B9F4BF618ED1D99083D6B2E73A8F3C55D1C`; `output.log` SHA256: `39727FC012D3646D7093CD52E4E2AD9A2A4F34C365C26C206041808A7476FC7C`.

ForestPhase `.godot/preparation_proofs/phase1` passed 9/9, exit 0, no timeout/abort, 2,233 inputs. It prepared the three packages in 43,774 ms with the same composed manifest hash as the preceding manifest: `12271a4e44f456e7e2993bcd4d81a405717ab2463be0697a969964bac5916707` (1,534,752 B), recorded 14 proof hits and 0 fallback searches. Per-package prepare times: terraces 23,177.104 ms; valleys 18,107.549 ms; lair 2,379.640 ms. `runs.json` SHA256: `9C38AD93F7C723EA74D99B43C52C472F87A2DE1310B7350E372A0005AB59AE1D`.

## Official regression selection

`verify.ps1 -List` confirmed these IDs: F4 compatibility (index 249), F7 flow (256), F5 population (258), and F1 geometry (273). The selection ran with the existing F1 fixture, editor import skipped, 300-second timeout, and disposable `APPDATA`/`LOCALAPPDATA`. All four processes exited 0, `failed=false`, and `timed_out=false`: F4 compatibility 16 checks; F7 flow 23 assertions; F5 population 40 checks; F1 geometry 33 checks. `checks.jsonl` SHA256: `C5E3437E9E5EBAA568C1B10D438FDF6753D898A39CD88D896A4312C8C0B0E0D8`; `plan.json` SHA256: `09FD6209B805607C54B80CA175CB5D19EEE3CF2800AD44C1AFE016443E48DC29`. No error patterns appeared in logs.

## Clean M8 release

The release runner completed `M8_SELECTED_PASS`. Manifest `.godot/preparation_proofs/release/manifest.json` SHA256 `B37F6C6B43890F642EFD1499E44E74750996973A37C3DF0A577C335E3D3BC72A`; `runs.json` SHA256 `B13CDAF4746E146CB35DB7AC08FC3557BDB59E2BD0E6982D659C780DF6EFB4BA`; `release_manifest.json` SHA256 `BA3DE40A1A78342E1C568F15B45338DBC8C49DF20F558EB47E481DC1231AEF2F`. Manifest records HEAD unchanged, the standard engine hash above, the same fixture path, 2,227 source/fixture input pairs with zero differences, and all three `.navproof` file hashes listed above.

Release process checks: release 6/6, Bosque 8/8, Forest 14/14. Import/export/release/Bosque/Forest all returned `ok=true`, exit 0, `timed_out=false`, `aborted=false`. Sampled peak working set: import 906,608,640 B; export 1,026,048,000 B; release 619,843,584 B; Bosque 877,477,888 B; Forest 1,082,245,120 B. Forest timings: entry 63,799.485 ms; suspend 7,745.575 ms; resume 26,260.661 ms. Package hashes: release `b6ffc4b62c6dfc7583351bc8adc24d707b42e0282c8502ac635a829e1355f024`; Bosque `41a8e11a6c70fdc9c87cec67a2c9f8fc8fb7af5ecfdc1690ba532472c0e52587`. Captures `release.png`, `release_sanctuary_woods.png`, and `release_forest.png` are present; `release_forest.png` SHA256 `0B76F062DC04E0659D3BD694240E9C178CAC34CC35A67374465124F1CB37527E`.

No merge, master update, push, or human product acceptance is implied. Q5 remains open for its remaining obligations. This is process/test evidence supervision, not an independent semantic audit.

## Appendix — private limit and warm-route controls

The parent ran these read-only diagnostic controls after the release batch. They do not change the product run, earlier test counts, or source state.

- `.godot/preparation_proofs/controls/limits.json` reports `ok=true`, `cycle_rejected=true`, and `oversized_rejected=true`. The process exited 0 in 6,320.674 ms, sampled peak RSS 370,601,984 B, with no log error. Hashes: `limits.json` `E17BE3CA809ACF0F0B4EF2A993687D3589F3507757421489622EEB3AF9959CE5`; `limits_process.json` `85D16A61BB402444CE9EE418C1055E77CCE87B950BD8A5CDC68829880539F357`; `limits.log` `FFD5A0B760B7FA6CE1B4001C025AC1E64079081B36E6DF90F2F105A8013C2F3A`.
- Corrected warm control `.godot/preparation_proofs/controls/warm.json` returned `ok=true`, distance 10,620.966796875, 100 grids, and 0→100 lattices. `_ensure_support_index` prewarm took 2,315.23 ms; the same far route then took 116,186 ms, with one proof hit and zero searches. Process exit 0; elapsed 132,087.2461 ms; sampled peak RSS 476,782,592 B; no log error. Hashes: `warm.json` `3D7A3249F3F38C8B96ED919C4CF79994D1D445BD6FFE4FAE389C5BECFF43E9CB`; `warm_process.json` `043515D482FFAB2D7E886828D87D0473D87D441DFE09429CE095B210FA27020C`; `warm.log` `C6FD163300F3416E4ADC2BD7A852812191D0F98306D4B1953677C73ECAEF628A`. The control shows that 100-lattice prewarm did not remove the expensive far-route query. It is a distinct diagnostic sample and does not establish a regression against the ForestPlay measurement or attribute the full route duration to proof preparation.
- An earlier warm probe in `.godot/preparation_proofs/controls/prewarm_probe_error` omitted `_ensure_support_index`; it logged 100 `SCRIPT ERROR` lines accessing `grids`. That probe is explicitly discarded and is not evidence. Its helper/log/JSON hashes are respectively `244A84CD49EA9D90535A01B35C86334E09D8426432A0764B03140902968F594C`, `EE9EA55E80913E8C958A560AC501662FF3CD72851BB28C169B64E677FCCCC7BA`, and `BFB197FF81246AC727DA2EB038DFBC8A555FDBFA8945954360326966D6CE20B3`.

No engine was started for this appendix; it records only the existing control receipts.
