# E04-AR-A — handoff do recorte inicial do Arqueiro

Base: `c7206f7`. Escopo: contrato e sequência; nenhum runtime alterado.

## Entrega

- A biblioteca aprovada recebeu IDs estáveis, targeting, eixo de rank e dependência
  técnica em [E04_ARCHER_A_KIT_CONTRACT.md](E04_ARCHER_A_KIT_CONTRACT.md).
- Foram separadas as três fronteiras críticas: projétil físico de precisão,
  armadilha/controle e ocultação/aquisição de alvo.
- O primeiro comportamento executável ficou delimitado como E04-AR-B1: autoataque
  do Arqueiro sobre uma colisão compartilhada de projétil, sem liberar a classe no
  perfil/menu prematuramente.

## Evidência e limite

Inspeção confirmou que persistência/atributos/apresentação conhecem `archer`, mas
`ClassCatalog`, `ProfileCatalog` e `PlayerActor` ainda não formam uma classe jogável.
Import headless e `tools/verify.ps1` passaram: 32 suítes, 1.309 checks; este pacote
documental não adiciona suíte nem altera runtime.

Próximo pacote: E04-AR-B1, somente após liberação separada.
