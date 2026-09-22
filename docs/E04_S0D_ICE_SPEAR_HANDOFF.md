# E04-S0-D6 — Lança de Gelo como consumidora de rank

Base: `e95f976`. Escopo: somente `ice_spear`.

## Entrega

- `ClassCatalog` materializa R1–R5 com dano linear e custo côncavo; cast, cooldown,
  alcance, velocidade, targeting e slow permanecem fixos.
- `RunState.projectile_count` deixa de converter rank de ambas as lanças em
  quantidade: base 1, mais um por stack do augment específico.
- O handler compartilhado de lanças, HUD, mira e projétil usam valores capturados
  do snapshot; o slow continua aplicado somente após dano positivo.

## Evidência e limite

`tests/e04_ice_spear_rank_integration_test.gd` cobre tabela, R1/R5, dano, SP,
cast, cooldown, alcance, velocidade, snapshot, rank inválido, quantidade/augment,
HUD, alvo, dispatch, homing e slow. Import headless e `tools/verify.ps1`
passaram: 30 suítes, 1.254 checks; a suíte nova responde por 39 checks.

Próximo pacote planejado: Teleporte, somente após liberação separada.
