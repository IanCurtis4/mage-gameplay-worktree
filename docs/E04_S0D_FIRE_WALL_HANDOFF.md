# E04-S0-D4 — Parede de Fogo como consumidora de rank

Base: `e40d27b`. Escopo: somente `fire_wall`.

## Entrega

- `ClassCatalog` materializa R1–R5 com dano por tick linear e custo côncavo;
  preparo, recarga, alcance e geometria do efeito permanecem fixos.
- `PlayerActor` exige rank válido e captura poder, SP, cast e cooldown. O dispatch
  usa `Handler.FIRE_WALL`.
- `FireWall` não consulta mais o alcance legado: o controller entrega o alcance
  capturado do snapshot. Duração, pilares e stream único de burn não mudam.

## Evidência e limite

`tests/e04_fire_wall_rank_integration_test.gd` cobre tabela, R1/R5, emissão,
débito, preparo, recarga, snapshot, rank inválido, HUD, mira, dispatch, posição
e burn persistente. Import headless e `tools/verify.ps1` passaram: 28 suítes,
1.176 checks; a suíte nova responde por 36 checks.

Próximo pacote planejado: Lança de Fogo, somente após liberação separada.
