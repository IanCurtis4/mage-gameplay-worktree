# E04-AR-B13 — handoff da Técnica de Armadilhas

Base: `d8e9683`. Escopo: `trap_technique` R1–R3 e permanência armada das
armadilhas de Laço e Explosiva.

## Entrega

- Catálogo de três ranks com +3/+6/+9 s e metadados de progressão base.
- Fonte de regra identificada no `BuildSnapshot`, separada dos modificadores
  de atributos. R0, rank inválido, passiva desequipada e slot duplicado
  preservam a duração correta.
- Controlador materializa ambas as armadilhas com 15/18/21 s conforme a build
  e captura a permanência no instante da colocação.
- Tempo de armação, efeito aplicado, custos, recargas e limite por dono
  conservam seus contratos existentes.

## Evidência e limite

`tests/e04_archer_trap_technique_rank_integration_test.gd` cobre os três
ranks, fontes, ausência de alteração de stats, fronteiras de equipar/rank,
cópia de snapshot, as duas armadilhas no controlador, os dois relógios,
mudança posterior de build e expiração após a permanência capturada.

Import headless e `tools/verify.ps1` passaram: 45 suítes e 1.887 checks;
a suíte nova contém 37 checks.

Este pacote não fecha a integração e o balanceamento do kit completo do
Arqueiro. O próximo passo é o recorte integrado de E04, mediante autorização
separada.
