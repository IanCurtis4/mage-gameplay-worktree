# F9 Terra source consumer probe 02 — Luna

Frozen HEAD: `0acc94ef6530d560eb1695de699b40b53dd8cdb2`; Import09 `editor_import` had already passed (1/299). Godot 4.7.2 standard ran headless in the same full F1 fixture with its disposable `APPDATA` and `LOCALAPPDATA`. Exit 0; no Script/Parse/engine ERROR was reported.

## Source load and terrain compilation

Both original Terra files were byte-identical to their clean replay artifacts, loaded validly through `SourceStore`, and compiled to the same semantic and terrain-package hashes as Terra's clean reopen evidence.

| Source | Input SHA-256 | Source hash | Terrain package hash | Load / compile |
|---|---|---|---|---:|
| `sanctuary_woods_clearing.source.json` | `65a26754c437695d7e7d60e93980c187371fddeec4fb71f78323104dbb55ced5` | `93a5d99c3110ec054fca292b3efe3778b4d4745003f35390ade9c3d6d307ba38` | `aa762ada7df22b49c8ece77f95c9104791e8fc8138adecbdadd545651838bc12` | 26.571 / 228.647 ms |
| `sanctuary_woods_overpass.source.json` | `d0071096addfefcefad1f1df849c3977064a741b4ed1446ffaf50a3f25a95d7e` | `d0d0f5ba826a167facc6f703ef0e85d97ba74b1dcb75270de834f294c02ed94a` | `dd2da0720ecc3757d42378e5be0e97865fba979d637517f1513bf666ee490a88` | 13.341 / 97.390 ms |

## Composition and body-preparation consumer

The isolated one-piece composition is retained as a negative: it correctly returned `opening_unlinked` for `terrain/a_east` at `(1280, 0, 640)`. The linked composition then used the two untouched sources, hashes above, instance `clearing` at `[0,0,0]`, instance `overpass` at `[1280,0,0]`, both with rotation `0`, and link `woods_seam` from `clearing/a_east` to `overpass/b_west_gate`.

`Maps.compile` passed, and the package source hash matched the ephemeral map document hash `84bc976cf8d44c237806656aa461cd6097426a999c56f2193d319f834272e2ae`. Candidate creation and `Candidate.prepare` passed. The prepare path used the canonical preview traversal profile with radius `20`, height `32`; its all-surfaces connectivity gate completed successfully. The compiler and prepare timings are separate: map compile 15,518.450 ms (navigation subphase 14,714.929 ms), candidate creation 787.834 ms, and candidate preparation 18,914.186 ms (navigation subphase 17,323.562 ms). Detailed counters and memory metrics are preserved in the structured result.

This proves consumer compilation and body-access preparation only. It does not prove App/gameplay launch, walking, general playability, or FPS. The linked map and candidate were ephemeral test values and were not persisted as product data.

## Evidence

- [Invocation, argv, profile, input hashes, and complete structured result](source_consumer.invocation.json)
- [Godot stdout with per-source hashes, checks, and phase timings](source_consumer.stdout.log)
- [Engine log](source_consumer.engine.log)
- [Temporary probe script copied as text](f9_terra_source_consumer_test_02.gd.txt)
- [Earlier isolated-opening diagnostic (expected negative)](../source_consumer_report.md)
