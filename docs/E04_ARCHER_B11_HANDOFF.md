# E04-AR-B11 — handoff da Precisão

Base: `b3df810`. Escopo: `archer_precision` R1–R3, HIT canônico e gate do
Arqueiro.

## Entrega

- `ClassCatalog` publica +8/+12/+16 HIT plano e uma fonte identificada que passa
  pelo `BuildSnapshot` e pelo `StatCalculator` sem duplicar fórmulas.
- `ProfileCatalog` registra a passiva base em R0–R3 e agora satisfaz o gate de
  disponibilidade do Arqueiro.
- O menu permite criar Arqueiro, mas o personagem persistente nasce sem ranks
  aprendidos e sem passivas equipadas; o piloto legado recebe Precisão R1.
- Autoataques e skills contestadas capturam o HIT aumentado; skills de geometria
  preservam sua resolução independente de HIT/FLEE.
- Fonte duplicada, rank inválido e passiva aprendida mas desequipada não aplicam
  benefício indevido.

## Evidência e limite

`tests/e04_archer_precision_rank_integration_test.gd` cobre tabela R1–R3,
isolamento do catálogo, metadados, criação persistente em R0, fontes, composição,
deduplicação, ranks inválidos, chances contestadas, geometria, cópia do snapshot
e captura de HIT nas três famílias de projéteis contestados. Os testes históricos
do Arqueiro foram atualizados para a nova transição do gate.

Resultado final de import headless e `tools/verify.ps1`: 43 suítes, 1.818 checks;
a suíte nova responde por 33 checks.

Cadência, Técnica de Armadilhas e o fechamento integrado do Arqueiro permanecem
ausentes. Próximo pacote: Cadência, somente após liberação separada.
