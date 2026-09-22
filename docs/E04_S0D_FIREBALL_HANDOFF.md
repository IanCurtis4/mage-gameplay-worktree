# E04-S0-D3 — Bola de Fogo como consumidora de rank

Base: `84a7ccf`. Escopo: somente `fireball`.

## Entrega

- `ClassCatalog` materializa R1–R5 com dano linear e custo côncavo; alcance,
  velocidade, preparo, recarga, targeting e crítico legado são preservados.
- `PlayerActor` exige rank válido e usa a cópia capturada para poder, SP, cast,
  cooldown, alcance e velocidade. O dispatch usa `Handler.FIREBALL`.
- O projétil criado pelo controller recebe alcance/velocidade do mesmo snapshot;
  a regra de crítico contra queimadura e a colisão existente não mudam.

## Evidência e limite

`tests/e04_fireball_rank_integration_test.gd` cobre tabela, R1/R5, emissão,
captura de dano, débito, preparo, recarga, snapshot, rank inválido, HUD, mira,
dispatch e configuração do projétil. Import headless e `tools/verify.ps1` passaram:
27 suítes, 1.140 checks; a suíte nova responde por 35 checks.

Próximo pacote planejado: Parede de Fogo, somente após liberação separada.
