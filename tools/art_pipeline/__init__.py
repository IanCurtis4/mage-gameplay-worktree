"""RagRPG generator-neutral art pipeline (E09 T2, contract C5).

Library modules, each also runnable as a script:

    validate_sheet      validate one source sheet or a set of views (JSON report)
    validate_batch      validate a staging batch laid out like assets/art/e08_codex_*
    remove_background   flat-colour background removal with recorded parameters
    normalize_scale     equalise the idle body height between views (no smoothing)
    provenance          ragrpg_art_provenance_v2 schema and a reader for the v1 records
    selection           selection.json writer/reader used by the packagers
    archive             hash-checked copy to the durable archive plus a versioned index
    record_generation   CLI that any generator script calls to append a v2 record

Everything except validate_*, remove_background and normalize_scale uses only the standard
library. The image tools need Pillow and numpy, the same dependencies as tools/prepare_e08_*.py.
"""
VERSION = "1.0.0"
