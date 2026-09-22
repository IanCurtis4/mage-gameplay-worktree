# E04-S0-D8 — Regeneração de SP como consumidora de rank

Base: `038e21c`. Escopo: somente `mage_mana_regeneration`.

## Entrega

- `ClassCatalog` materializa a passiva R1–R3 e converte o handler fechado em uma
  fonte canônica de `sp_regen` para o `StatCalculator`.
- `BuildSnapshot` consulta genericamente passivas equipadas e seus ranks, removendo
  a magnitude fixa do Mago sem alterar o contrato já entregue da Resistência.
- R1 preserva +50%; R2/R3 aplicam +75%/+100%. Rank inválido ou passiva não equipada
  não aplica bônus; o ator continua regenerando pelo breakdown, sem fórmula paralela.

## Evidência e limite

`tests/e04_mage_sp_regeneration_rank_integration_test.gd` cobre catálogo, cópia,
R1–R3, composição aditiva, equipagem, rank inválido, preview/runtime, pausa, morte
e limite de SP máximo. Import headless e `tools/verify.ps1` passaram: 32 suítes,
1.309 checks; a suíte nova responde por 26 checks.

Este pacote encerra as skills do kit piloto atual do Mago. O próximo recorte de
S0-D pertence ao Arqueiro e requer liberação separada.
