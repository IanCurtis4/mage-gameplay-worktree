# E04-S0-C — Corte como consumidor de rank

Base: `ea61e68`. Escopo: somente `slash`; S0-D não iniciado.

## Entrega

- `ClassCatalog` materializa a tabela R1–R5 aprovada em
  [E04_S0C_DESIGN.md](E04_S0C_DESIGN.md), sem calcular a curva no runtime.
- `PlayerActor` captura do snapshot uma cópia validada da definição efetiva.
  Dano, SP, bloqueio, cooldown, cast e alcance do Corte leem essa cópia; emissões
  conservam o valor capturado. Rank ausente/inválido não recua para R1.
- O dispatch do Corte usa seu `handler_id`. HUD e mira exibem rank/custo e usam
  a mesma definição para disponibilidade e geometria. Skills restantes mantêm
  os campos legados e não receberam tabelas.

## Evidência e limite

`tests/e04_slash_rank_integration_test.gd` cobre a tabela, R1/R5, dano emitido,
débito e insuficiência de SP, isolamento do snapshot, rank inválido, HUD e mira.
Import headless e `tools/verify.ps1` passaram: 23 suítes, 1.035 checks.

Próximo pacote planejado: S0-D, somente após liberação; não inferir tabelas
das demais skills a partir do Corte.
