# E05 — checkpoint único da Geômetra

02/10/2026 — autorizada pelo usuário; condutor Sol6.1; base aceita8df3a67.
Contrato vigente:E05_GEOMETER_PLAN.md, com precedência sobre âncoras estáticas
obrigatórias do E00. G0 consolidado; runtime da classe ainda não integrado.

| Camada | Estado | Commit/evidência | Próximo passo |
|---|---|---|---|
| G0 contratos | DONE (design) | 9527541; ajustes aprovados por Astra em02/10 | Semânticas fechadas; tuning ainda não aceito |
| G1 input/disparo | PARTIAL (núcleo) | reservas ordenadas/timeout no teste de construção107 PASS | Integrar seleção, mira e projétil ao combate |
| G2 geometria estática | PARTIAL (núcleo) | limites, obstáculos e transações no teste107 PASS | Preview/runtime compartilhados ainda não conectados |
| G3 âncoras móveis | PARTIAL (núcleo) | morte, suspensão e relógios no teste107 PASS | Integrar posições reais do encontro e validar boss móvel |
| G4 paredes6 | PENDING | semânticas emG0 | Implementar gatilhos reais e dedup |
| G5 triângulos27 | PENDING | — | Puros → mistos → tricolores |
| G6 edição/progressão | PENDING | — | Duas builds legais |
| G7 visual/integração | PENDING | — | Revisão Astra e playtest |

Master permanece na entrega aceita do Espiritualista. Não iniciar outras
classes, terreno quadrado/Ressonância ou painel de balanceamento. Não mover
playtest com código parcial. Aceite técnico e aceite humano ainda pendentes.

## Rodada documental limitada — 02/10/2026

Usuário pediu primeiro passo gradual por disponibilidade de uso. Esta rodada
consolida apenasG0: interfaces, máquina de estados, seis paredes,27 receitas,
limites e semânticas de cobrança/edição/expiração. Não pede novo gate a Astra.
Os rascunhos locais de código anteriores foram preservados, não incluídos no
commit documental e não apresentados como implementação testada.

Evidência desta rodada: conferência documental e `git diff --check`. Sem mudança
de runtime entregue, sem nova execução de `tools/verify.ps1` ou teste de gameplay.
Próxima retomada: testes direcionados dos rascunhos de geometria/reservas/âncoras;
não começar efeitosG4/G5 antes de validar essa base. Playtest permanece intacto.

## Núcleo de construção validado — 02/10/2026

Rodada pequena autorizada pelo usuário: quatro estados puros (`GeometerGeometry`,
`GeometerGrammarState`, `GeometerAnchor`, `GeometerConstructionState`) e consulta
de área livre na navegação. Até três vértices, reservas finitas em ordem de comando,
elemento/intenção congelados, preparação/parede/triângulo, transações de edição,
identidades monotônicas e expiração inteira. Sem custo, dano, Nodes ou save.

O teste `e05_geometer_construction_test.gd` passou107 checks em Godot4.7.2:
limites exatos24/600/256,27 receitas e gates3/21/27, obstáculo encerrado na área
(incluindo barreira temporária), caso de AABB sem interseção, hit-test de círculo,
impactos fora de ordem/falhos/duplicados/tardios, timeout, captura isolada de
contexto, Colapso finito, edição FIFO/atômica, morte na última posição livre,
suspensão/retomada e expiração sem renovar relógios ou resoluçãoC.

Correções dentro do contrato: rejeitar duração inválida antes de reservar;
revalidar posições móveis atuais ao receber impacto; recusar vértices não finitos
no hit-test. Catálogo ainda não habilitado, UI/projétil/cobrança/efeitos não
integrados. O teste entrou em `tools/verify.ps1`; suíte integral PASS (exit0),
incluindo importação do editor, navegação, Parede de Gelo e regressões das classes.
`git diff --check` também passou.
Não afirma pausa real de Nodes, dano ou clareza visual sem integração ao encontro.

Próximo lote: seleção direta e contexto congelado do cast, mira chão/inimigo e
projétil especial, conectando o núcleo validado (G1). Sem entregar código parcial
no diretório habitual. Revisão Astra continua única no fechamento da classe.
