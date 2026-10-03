# E05 — checkpoint único da Geômetra

02/10/2026 — autorizada pelo usuário; condutor Sol6.1; base aceita8df3a67.
Contrato vigente:E05_GEOMETER_PLAN.md, com precedência sobre âncoras estáticas
obrigatórias do E00. G0 e input/disparo G1 integrados em fixture; classe completa
ainda indisponível no catálogo de produção.

| Camada | Estado | Commit/evidência | Próximo passo |
|---|---|---|---|
| G0 contratos | DONE (design) | 9527541; ajustes aprovados por Astra em02/10 | Semânticas fechadas; tuning ainda não aceito |
| G1 input/disparo | DONE (interno) | construção107 + casting61 PASS; renderer4 PASS | Efeitos/progressão/arte final continuam pendentes |
| G2 geometria estática | PARTIAL (integração) | núcleo7292583; preview e projétil conectados emG1 | Completar matriz de falhas no encontro real |
| G3 âncoras móveis | PARTIAL (integração) | vínculo real ao boss em casting61/renderer4 | Completar morte/suspensão/expiração integrada |
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

## G1 — seleção, mira e disparo especial — 03/10/2026

Comandos intrínsecos1/2/3 selecionam Fogo/Gelo/Raio, com botões próprios que não
ocupam slots de skill nem gastam SP. Mira direta no corpo captura vínculo móvel;
fora dele captura chão, sem assistência atraindo cliques de piso. Shift força
chão. Backspace/botão Desfazer limpa figura e voos; Direito/Esc cancela somente
intenção/preparo. Preview compartilha validação com commit e distingue vínculo.

`GeometerCastCommand` é copiado no início do preparo. Mudar elemento/objeto do
comando depois disso não muda o disparo. SP/CD são cobrados pelo PlayerActor uma
vez no lançamento validado, usando os cálculos canônicos; geometria/alvo inválido
antes não cobra, invalidação no voo não restitui. `GeometerTraceProjectile` usa
colisão contínua compartilhada em espaço de chão e só entrega o alvo escolhido
ou o ponto fixo; limite600, velocidade900, vida3s, pausa e callback únicos.
Limpeza/timeout invalida dano e âncora de uma entrega tardia.

`GeometerCasting` conecta posições reais, entrega ordenada, dano ao resolver,
vida das âncoras e underlay. Comandos por teclado da Geômetra usam o último evento
de mouse em coordenadas do viewport, convertido pela câmera na confirmação,
como os cliques; sem mudar a origem do cursor nas outras classes. CastIntent
CONFIRM/RELEASE/INSTANT permanece o existente. Foco/menu/movimento cancela preparo.

Só Traçado/Triangulação ganharam dados de execução neste lote; ProfileCatalog
não habilita mg_ar, não há migração de save nem operação sobre perfil real.
Traçado captura0,30→0,50×ATQM no lançamento. Triangulação nesta entrega apenas
entregaC, com16SP/CD3s; resolução da figura pertence aG5 e ainda não causa dano.
Não interpretar esse estado intermediário como tuning final aceito.

Evidência: `e05_geometer_casting_test.gd`61 PASS em fixture da cena real, incluindo
inputs de teclado/mouse, botões, três modos, foco, pausa, no-SP/CD/slot/identidade,
alvo móvel/morto, obstáculo antes/depois do lançamento, cancelamento/limpeza,
cobrança única e emissão real do auto Mago sem colocar âncora. Núcleo107 PASS.
`tools/geometer_g1_renderer_probe.gd`4 capturas OpenGL1280×720 PASS; inspeção de
preview de triângulo e vínculo móvel confirma camada sob atores e HUD sem corte.
Arte do personagem é fallback Mago; sem padrão visual final, testes de FPS ou
efeitos G4/G5. Capturas ficam ignoradas em `.godot/verification/geometer_g1_*.png`.
Suíte integral `tools/verify.ps1` PASS (exit0), incluindo importação do editor,
regressões de input/combate e classes aceitas. `git diff --check` PASS. Nenhum
gate/handoff micro a Astra, nenhuma atualização de playtest/master.

Próxima rodada pequena: fechar matrizG2/G3 no encontro real (duas entregas fora de
ordem, morte com outros portadores, degeneração/obstáculos, retorno e expiração),
antes dos cruzamentos/transformações das seis paredesG4.
