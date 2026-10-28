# F9 Terra source consumer probe — Luna

Frozen HEAD: `0acc94ef6530d560eb1695de699b40b53dd8cdb2` (Import09 PASS). Godot 4.7.2 standard ran headless against the shared `e07_f1/fixture_project` with disposable `APPDATA`/`LOCALAPPDATA`.

## Result

Stopped at the first source after `MapCompiler.compile` rejected the requested single-piece test composition. No source, profile, runtime, expected value, or candidate was modified or persisted.

- `Store.load_source` accepted `sanctuary_woods_clearing.source.json`. Byte SHA-256 `65a26754c437695d7e7d60e93980c187371fddeec4fb71f78323104dbb55ced5` and semantic source hash `93a5d99c3110ec054fca292b3efe3778b4d4745003f35390ade9c3d6d307ba38` match Terra's clean replay.
- `TerrainCompiler.compile` passed with package hash `aa762ada7df22b49c8ece77f95c9104791e8fc8138adecbdadd545651838bc12`, matching Terra's clean replay.
- The temporary `MapDocument.empty` composition used one piece and one instance named `terrain` at `[0,0,0]`, rotation `0`, with no extra source edits or links. `Maps.compile` failed `opening_unlinked`, entity `terrain/a_east`, location `(1280, 0, 640)`. Candidate creation and preparation were not reached.
- The canonical preview body profile resolved as radius `20`, height `32`. No accessibility, walking, gameplay, or FPS conclusion is available from this failed map compilation.
- Runtime exit code was `1`; the log contains the structured diagnostic and no Script/Parse/engine `ERROR` lines.

The untouched second input `sanctuary_woods_overpass.source.json` has byte SHA-256 `d0071096addfefcefad1f1df849c3977064a741b4ed1446ffaf50a3f25a95d7e`; it was not loaded because execution stopped on the clearing failure.

## Evidence

- [Invocation, environment, file hashes, and structured result](source_consumer.invocation.json)
- [Godot output](source_consumer.stdout.log)
- [Engine log](source_consumer.engine.log)
- [Temporary probe source copy](f9_terra_source_consumer_test.gd.txt)
- [Import check](checks.jsonl)
