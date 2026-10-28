# F9 AX authoring validation — Luna

## Results

| Stage | Frozen HEAD | Result | Evidence |
|---|---|---:|---|
| Headless `Authoring` | `da0e620829983c5948371cec9c36a983afa76613` | PASS 30/30 | [model_03](model_03/geometry.output.log), [manifest](model_03/runs.json) |
| Native `AuthoringNative` | `beb8dc740bede1fb8c5e48a4389417f5cc535eaa` | PASS 12/12 | [native_02](native_02/geometry.output.log), [manifest](native_02/runs.json) |
| AX CLI, headless | `beb8dc740bede1fb8c5e48a4389417f5cc535eaa` | PASS, 10/10 actions | [request](cli/positive_headless_02.request.json), [result](cli/positive_headless_02.result.json) |
| AX CLI, native window | `beb8dc740bede1fb8c5e48a4389417f5cc535eaa` | PASS, 10/10 actions | [request](cli/positive_native_02.request.json), [result](cli/positive_native_02.result.json), [capture](cli/positive_native_02_capture.png) |
| AX CLI reopen in a new process | `beb8dc740bede1fb8c5e48a4389417f5cc535eaa` | PASS, 2/2 actions | [request](cli/reopen_02.request.json), [result](cli/reopen_02.result.json) |
| `tools/verify.ps1` `editor_import` | F1 fixture | PASS, 1 selected check | [checks](verify_editor_import_02/checks.jsonl), [engine log](verify_editor_import_02/001.engine.log), [output](verify_editor_import_02/001.output.log) |

This paragraph and the following input hash table describe the earlier CLI freeze at `beb8dc740bede1fb8c5e48a4389417f5cc535eaa`; they are historical evidence only. The final native, CLI, and import runs are separately recorded under the `17516a20` section below, with the authoritative complete inputs and source-to-fixture checks in [native_04/runs.json](native_04/runs.json).

Both positive CLI recipes created two adjacent 5×5 grids, applied a brush stroke, undid and redid it, added a connector, compiled, and saved the source. The headless run, native replay, and separate-process reopen all returned source hash `87abe8373a53fbf7c53c15c6dae2e0e6022336ce1df6995ea6494696aa89c99a` and compiled package hash `169c09d144ef58f1cda13fe66faeebfcdff0819ff7822b115b4482bc5fc1875b`. The native replay saved to a different external path. The `editor_import` check selected 1 of 299 available steps and used the fixture’s disposable `APPDATA` and `LOCALAPPDATA` profile.

The CLI failure probes behaved as specified:

- An unknown root field returned `arguments_invalid`, exit 1, zero completed actions, and no editor snapshot. The client rejected the request before mounting the Shell.
- An unknown parameter stopped the batch after 2 of 3 actions. The third rename did not run, and the source retained the name `Before invalid action` with no layer added. See [request](cli/reject_action_stop_02.request.json) and [result](cli/reject_action_stop_02.result.json).
- A pre-existing result target returned `io_conflict`; its sentinel contents remained unchanged. See [invocation metadata](cli/reject_existing_result_02.invocation.json).

## Input and engine hashes — initial CLI freeze `beb8dc740bede1fb8c5e48a4389417f5cc535eaa`

The engine was Godot 4.7.2 standard at `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`, SHA-256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.

| Input | SHA-256 in the frozen source and fixture |
|---|---|
| `addons/ragrpg_map_editor/shell.gd` | `0616AB800576D537CAF66615141D95DCC7622CF07624990FF139095567BF1416` |
| `addons/ragrpg_map_editor/presentation.gd` | `D0AA6984699E065F0AA500CF839083909E68DDBC41D22E9EDF99E3D04A14AFA7` |
| `scripts/map_authoring/terrain/terrain_panel.gd` | `ED6AABE03E2DD6702489EA8B25841DE280889CBCD1F886B134AA84A09F1B19C8` |
| `scripts/map_authoring/terrain/terrain_operations.gd` | `1556601D49997CCEA32223A250C499314B817EA9F32CDB9BF6A0D1DD94393614` |
| `scripts/map_authoring/agent/ax_session.gd` | `D994F3169CA03F3337ED94119A53F79B716D44AAD5E84A2568D1D99B8387CD31` |
| `tests/map_editor_ax_authoring_test.gd` | `5DAA803D6B6EBB3B6503A06B2BA57B1DB897EEEDCAE08DBDE273114BA4F99329` |
| `tests/map_editor_ax_authoring_ui_test.gd` | `E0B7E25EF44DC6227A2BCBD1A437668870CB4181A30FFF1360315F99DB8CB523` |
| `tools/map_editor_completion/run.ps1` | `422D2644CCDB737ADDB225D614897A9113858825CF3A3C4AAC43E6F7964A79A3` |

Full request/result/log/capture hashes and process arguments are indexed in [the CLI manifest](cli/manifest.json). Runner manifests include the complete frozen input list and source-to-fixture hash checks.

## Preserved failures and corrections

Earlier failed evidence remains in place and is not counted as a pass:

- `model/` records the first parse failure before dynamic return values were explicitly typed.
- `model_02/` records a valid cardinal normal payload that the producer incorrectly rejected: Array membership treated integer and float vector components as unequal. Sol corrected the numeric comparison in the producer; no test expectation changed.
- `native/` records the mistaken expectation that a disconnected distant grid would compile. Sol confirmed `route_unreachable` is correct; the native proof now keeps that as a negative and uses connected geometry for positive compilation.
- `cli/positive_headless.request.json` and its result preserve the first malformed recipe: PowerShell flattened the nested stroke points to `[64,64]`, so the service correctly returned `arguments_invalid`. The corrected `_02` request serializes `[[64,64]]` and passes.
- `cli/reject_unknown_root.invocation.json` preserves an initial helper argument-construction error where PowerShell split each `--ax-*=` option from its path. The corrected `_02` process arguments are recorded separately and the negative passes.
- `cli/verify_editor_import.log` records a Verify invocation that omitted the required `-GodotPath` and did not start Godot. `verify_editor_import_02/` records the corrected command and pass.

## Historical visual limitation (superseded)

At the earlier `beb8dc7` freeze, the 12 native assertions passed but the capture `native_02/ax_gui_shared_authorship.png` showed initially visible Context and Exchange windows covering the terrain editor; the native CLI capture had the same obstruction. This visual limitation was addressed and superseded by the final 15/15 native capture and native CLI capture recorded below.

The Verify editor scan emitted a warning that it ignored a nested `project.godot` at `res://tools/map_editor_probe/hosting`; the selected `editor_import` check still exited 0. No other gameplay, snapshot, or unrelated suite was repeated here.

## Final AX presentation rerun — 2026-10-28

The current bounded UI/CLI segment completed at frozen HEAD `17516a20f959fabdecf0af76777824d379d98f42`, with source and fixture inputs synchronized by Import08. The earlier native capture failure from `native_03` remains preserved: its capture predicates failed because the project scaled the requested 1600×1000 host to 1600×900 and the scroll view exposed only a 1300×300 canvas. The test host and fixture capture setup were adjusted to 1:1 content scale and to reveal a 440-pixel canvas for evidence; the production canvas minimum and all 15 assertions stayed unchanged.

| Stage | Result | Evidence |
|---|---:|---|
| Native AX authoring | PASS 15/15 | [native_04 log and capture](native_04/geometry.output.log), [capture image](native_04/ax_gui_shared_authorship.png), [runner manifest](native_04/runs.json) |
| Native AX CLI replay | PASS 10/10 actions | [CLI result](cli/native_04/positive_native_04.result.json), [invocation metadata](cli/native_04/positive_native_04.invocation.json), [capture](cli/native_04/positive_native_04_capture.png), [summary](cli/native_04/summary.json) |
| `tools/verify.ps1` `editor_import` | PASS, 1 selected check | [check manifest](verify_editor_import_04/checks.jsonl), [engine log](verify_editor_import_04/001.engine.log), [output](verify_editor_import_04/001.output.log) |

The native AX capture reports a 1600×1000 image matching the physical window, a visible 1300×440 canvas, 22 meshes, 54 sampled colors, and no visible auxiliary windows. The reviewed image shows the authored ramp/bridge terrain unobscured. The CLI replay retained source hash `87abe8373a53fbf7c53c15c6dae2e0e6022336ce1df6995ea6494696aa89c99a`, compiled package hash `169c09d144ef58f1cda13fe66faeebfcdff0819ff7822b115b4482bc5fc1875b`, and saved-file SHA-256 `9F327DC24BAD60AB0323DA8BF0638BF4899E0BD042A7588D6AE0125B77AEE39C`, matching the earlier successful recipe. Its capture also shows the terrain without auxiliary-window overlays.

A first CLI retry (`cli/native_03/`) and a first Verify invocation are retained as harness mistakes, not product failures: PowerShell unrolled `--ax-*=` plus path into separate arguments; Verify also combined `-SkipEditorImport` with a selection for `editor_import`, so it selected no checks. The corrected Python argv-list CLI replay and Verify invocation without `-SkipEditorImport` passed. No gameplay, snapshot, or unrelated checks were repeated in this segment.

This closes only the AX-authoring presentation validation segment. It does not constitute overall F9 acceptance or product approval.
