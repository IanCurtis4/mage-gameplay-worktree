# E04-S0-D1 — Investida como consumidora de rank

Base: `e071fff`. Escopo: somente `dash`; passiva do Espadachim não iniciada.

## Entrega

- `ClassCatalog` materializa a tabela R1–R5 de
  [E04_S0D_DASH_DESIGN.md](E04_S0D_DASH_DESIGN.md): SP e alcance fixos, recarga
  decrescente e nenhum efeito adicional.
- `PlayerActor` exige um rank válido e usa a definição capturada para custo,
  recarga e alcance. O destino continua limitado pela mesma navegação e colisão.
- Dispatch, HUD e mira consomem o handler e os valores da mesma definição; a
  duração atual da movimentação permanece fixa.

## Evidência e limite

`tests/e04_dash_rank_integration_test.gd` cobre tabela, R1/R5, débito, recarga,
snapshot, rank inválido, destino, dispatch, HUD e preview. Import headless e
`tools/verify.ps1` passaram: 25 suítes, 1.082 checks; a suíte nova responde por
28 checks.

Próximo pacote planejado: a passiva do Espadachim, em commit separado, porque
ela atravessa a fronteira de modificadores e não compartilha o handler ativo.
