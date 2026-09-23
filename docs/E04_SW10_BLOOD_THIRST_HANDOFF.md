# E04-SW10 — Sede de Sangue

Base: `45187b4`. Passiva de equipagem manual R0–R3. Converte exclusivamente
VIT alocada (não VIT inicial ou de equipamento) em ATQ corpo a corpo por fonte
flat identificada, sem consumir VIT. O bônus continua útil contra boss sem
adds. Cura por abate atribuído ao `source_id` do jogador: 2%, 3% ou 4% do HP
máximo nos ranks 1–3, limitada ao máximo. Não cura sem passiva equipada.

`RunController` observa a aplicação canônica de dano em cada inimigo e
credita `killed` uma vez por ID do alvo. Golpes múltiplos e DoT não repetem
a cura; dano secundário com autoria do jogador pode creditar um abate distinto.
O conjunto de IDs é limpo no novo encontro. Sem fórmula em UI/ator para o
bônus de ataque: `BuildSnapshot` fornece VIT investida ao catálogo e
`StatCalculator` compõe o stat.

`tests/e04_swordsman_blood_thirst_rank_integration_test.gd` passou com 25
checks de ranks, fonte, VIT preservada, boss/ATQ sem adds, cura, DoT e
idempotência. `tools/verify.ps1` completo passou no Godot 4.7.2. Cura e
balanceamento aguardam playtest. Sem master/playtest.
