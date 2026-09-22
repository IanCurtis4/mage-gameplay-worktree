# E04-S0-D2 — Resistência como consumidora de rank

Base: `0504b9f`. Escopo: somente `swordsman_resistance`.

## Entrega

- `ClassCatalog` materializa a passiva R1–R3 e despacha seu handler fechado para
  uma fonte canônica de `physical_defense`.
- `BuildSnapshot` remove a magnitude fixa: consulta o rank equipado e entrega a
  fonte ao `StatCalculator`, usado igualmente por preview e ator.
- R1 preserva +50%; R2/R3 aplicam +75%/+100%. Rank inválido ou passiva não equipada
  não aplica bônus. Dano mágico e demais stats não mudam.

## Evidência e limite

`tests/e04_swordsman_resistance_rank_integration_test.gd` cobre catálogo, cópia
imutável, R1–R3, composição aditiva, equipagem, rank inválido, preview/runtime e
mitigação física sem efeito mágico. Import headless e `tools/verify.ps1` passaram:
26 suítes, 1.105 checks; a suíte nova responde por 23 checks.

Este pacote encerra as três skills do kit piloto atual do Espadachim. O próximo
recorte de S0-D pertence ao Mago e requer liberação separada.
