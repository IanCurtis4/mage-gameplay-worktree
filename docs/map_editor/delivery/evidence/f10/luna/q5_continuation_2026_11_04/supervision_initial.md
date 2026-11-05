# F10 Q5 continuation — Luna evidence receipt

Date: 2026-11-04  
Worktree: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`  
HEAD before/after both runs: `d49dc1603ca6ab0e380054c45b0adcaecb3a10ab`  
Engine: Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`  
Fixture: `.godot/verification/e07_f1/fixture_project`

## Stage 1 — ForestPhase

Evidence: `.godot/q5_continue/preparation_before`  
Result: PASS, 9/9; exit 0, `timed_out=false`, `aborted=false`; no `SCRIPT ERROR`, `Parse Error`, `ERROR` or timeout in logs. The run recorded 2,222 source input hashes.

`F10_FOREST_PHASE_TIMING`: manifest hash `12271a4e44f456e7e2993bcd4d81a405717ab2463be0697a969964bac5916707`, 1,534,752 bytes; total preparation 178,986 ms.

- `forest_terraces`: 133,850.985 ms. `load_package` 115,016.114 ms; `surface_connectivity` 5,139.499 ms; `validate` 4,653.602 ms; `create_candidate` 3,548.052 ms; `population_build` 500.552 ms.
- `forest_valleys`: 36,855.155 ms. `load_package` 25,012.765 ms; `validate` 3,463.259 ms; `create_candidate` 3,332.759 ms; `surface_connectivity` 1,678.038 ms; `population_build` 736.542 ms.
- `forest_lair`: 8,172.732 ms. `load_package` 6,603.324 ms; `validate` 507.992 ms; `create_candidate` 509.350 ms; `surface_connectivity` 244.703 ms; `population_build` 66.539 ms.

`runs.json` SHA256: `93A5C77F8003D331CDBBF9D8D6326ED8FDB40C27D1F8C96C12AF667C6EF42D65`.

## Stage 2 — Q5UsabilityNative

Evidence: `.godot/q5_continue/usability_initial`  
Result: FAIL, 12 checks total, 11 passed; exit 1, `timed_out=false`, `aborted=false`. First and only failed check: `ux_visible_canvas_300px`. Marker `Q5_USABILITY_VISIBLE` reported window `(1440, 1000)`, UX canvas `569x286` and AX canvas `575x300`; the UX canvas was 14 px short of the 300 px requirement. No `SCRIPT ERROR`, `Parse Error`, `ERROR` or timeout pattern appeared in the logs. The receipt records 2,222 source input hashes.

`runs.json` SHA256: `1D74A70F5BEAB1D85EEAA8D6CC1329DF02AE015071514E7690BE52EF8E56DBF1`  
Screenshot `q5_editor_usability.png` SHA256: `7BE250BBF7F2742F3C8015170EE590268CD154DCEF73AB6B886B0F221F211AB0`  
`geometry.engine.log` SHA256: `731A4F53381ADF65CCF508AACCF87F2BC2FF4702BAE176FB1D7F0EB63EE0410A`  
`geometry.output.log` SHA256: `13299F3BFF726748E29B5E72C8948CCC5F4A6F9C2C595CA4AAE8E4DAD4905FB0`

## Stop point

Per the batch instruction, execution stopped at the first failed stage. The F7 presentation selection was not run. No source, test, runner, or expectation was edited by this supervision. Engine/fixture ownership is returned to Sol for the UI decision and any authorized follow-up.
