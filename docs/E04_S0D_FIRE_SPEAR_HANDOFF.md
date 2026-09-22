# E04-S0-D5 — Lança de Fogo como consumidora de rank

Base: `bbaeca9`. Escopo: somente `fire_spear`.

## Entrega

- `ClassCatalog` materializa R1–R5 com dano linear e custo côncavo; cast, cooldown,
  alcance, velocidade, targeting e bônus contra queimadura permanecem fixos.
- `RunState.projectile_count` deixa de converter rank da Lança de Fogo em quantidade:
  base 1, mais um por stack do augment específico. Lança de Gelo não muda.
- Dispatch e projétil consomem o handler e os valores capturados do snapshot.

## Evidência e limite

`tests/e04_fire_spear_rank_integration_test.gd` cobre tabela, R1/R5, dano, SP,
cast, cooldown, alcance, velocidade, snapshot, rank inválido, quantidade/augment,
HUD, alvo, dispatch e projéteis homing. Import headless e `tools/verify.ps1`
passaram: 29 suítes, 1.215 checks; a suíte nova responde por 39 checks.

Próximo pacote planejado: Lança de Gelo, somente após liberação separada.
