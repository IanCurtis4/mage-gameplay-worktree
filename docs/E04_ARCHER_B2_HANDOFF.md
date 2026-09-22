# E04-AR-B2 — handoff do Disparo Duplo

Base: `1ebc077`. Escopo: somente `double_shot`.

## Entrega

- `ClassCatalog` materializa R1–R5 com duas flechas fixas, dano/custo crescentes e
  recarga, alcance e velocidade constantes.
- `PlayerActor` captura ATQ de precisão e gasta SP/recarga uma vez; o controller
  cria duas cópias independentes sobre o `PlayerProjectile` compartilhado.
- Handler, HUD e preview direcional usam a mesma definição. Perfil conhece a skill,
  mas o Arqueiro permanece indisponível até cumprir o gate completo.

## Evidência e limite

`tests/e04_archer_double_shot_rank_integration_test.gd` cobre tabela, R1/R5,
snapshot, dano, custo, recarga, rank inválido, duas emissões fixas, HUD, preview,
dispatch, colisão e custo único. Import headless e `tools/verify.ps1` passaram:
34 suítes, 1.361 checks; a suíte nova responde por 35 checks.

Próximo pacote: E04-AR-B3, Flecha Perfurante, somente após liberação separada.
