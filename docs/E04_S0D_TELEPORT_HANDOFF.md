# E04-S0-D7 — Teleporte como consumidor de rank

Base: `b7a5096`. Escopo: somente `teleport`.

## Entrega

- `ClassCatalog` materializa R1–R5 com custo e alcance fixos e recarga decrescente.
- `PlayerActor` limita o destino pelo alcance capturado do snapshot e rejeita rank
  inválido sem fallback; travessia intermediária e validação do destino permanecem.
- O dispatch usa o handler `TELEPORT`; HUD, mira e execução consomem a mesma
  definição de rank. O Teleporte continua instantâneo e sem dano ou efeitos.

## Evidência e limite

`tests/e04_teleport_rank_integration_test.gd` cobre tabela, R1/R5, SP, recarga,
alcance, snapshot, rank inválido, destino livre/bloqueado, travessia de obstáculo,
limpeza do movimento, HUD, mira e dispatch. Import headless e `tools/verify.ps1`
passaram: 31 suítes, 1.283 checks; a suíte nova responde por 29 checks.

Próximo pacote planejado: passiva de regeneração de SP do Mago, somente após
liberação separada.
