# E04-AR-B5 — handoff da Mira Estendida

Base: `e1fdb0f`. Escopo: somente `extended_aim`, self-target e buff de alcance.

## Entrega

- `ClassCatalog` materializa R1–R5 com duração crescente e bônus fixo de +120;
  `ProfileCatalog` conhece a quarta ativa sem liberar a classe.
- `PlayerActor` mantém timer pausável e não acumulável, amplia autoataque e as
  três ofensivas entregues e limpa o estado em morte/configuração.
- `Targeting.SELF` executa imediatamente por tecla ou botão sem depender do mouse;
  HUD, preview e controller expõem o estado e capturam o alcance vigente.

## Evidência e limite

`tests/e04_archer_extended_aim_rank_integration_test.gd` cobre tabela, R1/R5,
snapshot, custo, recarga, rank inválido, aplicação seletiva do alcance, pausa,
expiração, morte, renovação, input self, HUD, preview e projéteis capturados.
Resultado final de import headless e `tools/verify.ps1`: 37 suítes, 1.504
checks; a suíte nova responde por 49 checks.

Próximo pacote: runtime compartilhado de armadilhas, somente após liberação
separada.
