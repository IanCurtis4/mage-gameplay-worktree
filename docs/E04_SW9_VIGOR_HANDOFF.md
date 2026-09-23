# E04-SW9 — Vigor

Base: `889b470`. Passiva R0–R3, equipagem manual nos dois slots passivos.
`ClassCatalog.passive_modifier_source` identifica a fonte e aumenta o stat
derivado `hp_regen` em +50%, +80% ou +110% nos ranks 1–3. O ator lê somente
o `StatBreakdown`; a regra existente regenera HP exclusivamente fora de
encontro, enquanto vivo e sem pausa. Sem cura imediata ao equipar/recalcular.

`tests/e04_swordsman_vigor_rank_integration_test.gd` passou com 26 checks
de catálogo, fonte, R0/inválido, snapshot, pausa e cura fora de combate.
`tools/verify.ps1` completo passou no Godot 4.7.2. Balanceamento requer
playtest. Sem master/playtest.
