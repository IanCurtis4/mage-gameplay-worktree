# E04-AR-B12 — handoff da Cadência

Base: `006d67a`. Escopo: `archer_cadence` R1–R3 e intervalo canônico do auto.

## Entrega

- `ClassCatalog` publica +10%/+15%/+20% de ataques por segundo como fonte
  identificada e percentual.
- `ProfileCatalog` registra a segunda passiva do Arqueiro em R0–R3 sem conceder
  ranks ou alterar slots iniciais.
- `BuildSnapshot` compõe Cadência com Precisão e Ritmo de Batalha pela autoridade
  existente do `StatCalculator`; o índice ASPD deriva do valor efetivo.
- O autoataque arma o recíproco do APS no momento da emissão. Recalcular APS
  preserva cooldown em curso e afeta somente o próximo auto.
- Fonte duplicada, rank inválido e passiva aprendida mas desequipada não aplicam
  benefício indevido.

## Evidência e limite

`tests/e04_archer_cadence_rank_integration_test.gd` cobre tabela R1–R3,
isolamento do catálogo, metadados de progressão, fontes, APS/índice, composição,
dois slots passivos, deduplicação, ranks inválidos, snapshot copiado, emissão de
auto, preservação de cooldown corrente e adoção do novo intervalo no auto seguinte.

Resultado final de import headless e `tools/verify.ps1`: 44 suítes, 1.850 checks;
a suíte nova responde por 32 checks.

Técnica de Armadilhas e o fechamento integrado do Arqueiro permanecem ausentes.
Próximo pacote: Técnica de Armadilhas, somente após liberação separada.
