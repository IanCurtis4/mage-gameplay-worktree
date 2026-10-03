# E05 — checkpoint único da Geômetra

03/10/2026 — autorizada pelo usuário; condutor Sol6.1; base aceita8df3a67.
Contrato vigente:E05_GEOMETER_PLAN.md, com precedência sobre âncoras estáticas
obrigatórias do E00. G0–G7 integrados no candidato da branch de implementação.
Biblioteca completa habilitada nessa branch; revisão técnica e playtest humano pendentes.

| Camada | Estado | Commit/evidência | Próximo passo |
|---|---|---|---|
| G0 contratos | DONE (design) | 9527541; ajustes aprovados por Astra em02/10 | Semânticas fechadas; tuning ainda não aceito |
| G1 input/disparo | DONE (interno) | construção107 + casting61 PASS; renderer4 PASS | Regressão integrada emG7 |
| G2 geometria estática | DONE (interno) | núcleo109 + integração46 PASS; renderer6 PASS | Regressão integrada emG7; aceite de produto pendente |
| G3 âncoras móveis | DONE (interno) | matriz real de morte/fila/suspensão/expiração; 30/60/144Hz | Composição densa validada emG7 |
| G4 paredes6 | DONE (interno) | primitivas74 + receitas106 + projéteis96 PASS; renderer7 PASS | Regressão mantida emG5; tuning ainda não aceito |
| G5 triângulos27 | DONE (interno) | receitas597 + projéteis192 PASS; renderer9 PASS | Regressão integrada emG7 |
| G6 edição/progressão | DONE (interno) | edição375 + builds341 PASS; renderer8 PASS | Duas builds legais; preservadas emG7 |
| G7 visual/integração | READY (revisão) | atlas101 + guia276 + integração500 + fluxo26 PASS; renderer15 PASS | Revisão Astra e playtest |

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

## G2/G3 — matriz integrada de geometria e portadores — 03/10/2026

Rodada pequena autorizada pelo usuário, retomada sobre01db84a. O teste
`e05_geometer_geometry_integration_test.gd` usa a cena real, projéteis reais,
callback canônico de morte e boss vivo, sem escrever perfil. Seus46 checks
cobrem duas chegadas fora de ordem/timeout, perda de portador na fila,
obstáculo encerrado na área durante voo, AABB sem interseção, barreira temporária,
pares iguais, terceiro inválido por movimento, misturas estáticas/móveis,
inversão de orientação, degeneração, distância, pausa e expiração inteira.
Em30/60/144Hz, suspensão/retomada preserva relógios/identidade e não repeteC.
Esses testes não afirmam cadência/dano dos futuros campos, que ainda não existem.

Defeitos encontrados e corrigidos dentro do contrato: impactos já confirmados
mas retidos pela fila agora consomem seu prazo desde o impacto e acompanham a
última posição válida do portador. Morte não volta ao ponto inicial nem concede
mais8s. Expiração de um impacto retido também limpa imediatamente, sem esperar
o voo anterior. O núcleo passou109 checks, incluindo esse prazo curto válido.
A figura inicia seu relógio quando efetivamente formada; parede→triângulo
continua preservando seu prazo. Disparos inválidos por expiração/timeout são
retirados visualmente no mesmo avanço; callback tardio não causa dano ou âncora.
Regressão de seleção/cobrança/input: casting61 PASS.

Underlay conserva as três bordas reais inclusive suspenso, ignora coordenadas
não finitas e mostra ordem1/2/3 discretamente. `geometer_g23_renderer_probe.gd`
passou seis estados OpenGL1280×720 inspecionados: triângulo ativo, degenerado,
retomado, depositado no chão, geometria inválida e expiração limpa. Esse probe
isola apresentação por remoção do portador na lista; morte real é coberta no
teste de integração. Capturas ignoradas em `.godot/verification/geometer_g23_*.png`.
Arte continua fallback Mago; onboarding final, cenário denso e FPS pertencemG7.

`tools/verify.ps1` integral PASS (exit0), incluindo importação do editor,
núcleo109, casting61, integração46 e regressões de persistência, input,
combate e classes aceitas. `git diff --check` PASS. Playtest91b5f63 e
master8df3a67 continuam limpos e inalterados. Esta rodada não equivale a
aprovação independente de Astra, aceitação humana ou classe completa jogável.

Próximo lote pequeno: primitivasG4 de travessia real (ator move, parede não
varre vítimas), contato contínuo e registros de deduplicação por construção.
Depois integrar as seis receitas e transformações dentro do contratoG0.
Sem habilitar catálogo parcial, sem gate por camada ou atualização de playtest/master.

## G4-A — contato, travessia real e registros compartilhados — 03/10/2026

Usuário autorizouG4 após6e45de6. Esta unidade fecha as primitivas do próximo
lote pequeno, não as seis receitas completas. `GeometerGeometry` fornece
primeiro contato contínuo com a faixa finita de meia largura12 + raio do corpo,
com extremidades arredondadas, e ponto de travessia da linha. Diferencia posição
real na trajetória de projeção na aresta: não autoriza teleporte paraA/B.

`EnemyActor.ground_walked(from,to)` informa apenas cada segmento de caminhada
aplicado pela navegação, depois da colisão. Não é uma diferença de posição
entre frames, nem é emitido por spawn, reposicionamento ou push. Não modifica
fórmulas, orçamento de deslocamento ou comportamento das outras classes.
`GeometerCasting` observa esses sinais somente no contexto da Geômetra,
revalida a figura atual e emite candidato espacial `wall_crossed`, sem efeito
de combate. Remove observadores de mortos/retirados e desconecta ao sair.

`GeometerWallContactState` arma a passagem fora da faixa finita. Cruzar o centro
pela caminhada gera um candidato; parar na linha ou oscilar dentro da faixa
não gera ticks. Suspensão limpa histórico espacial; triângulo/preparação não
detecta travessia de parede. Parede sobre ator parado não conta, tampouco um
movimento pequeno posterior consumindo uma mudança de lado antiga.

`GeometerInteractionLedger` é da instância da construção: mesma janela2s por
vítima para consumidores de entrada/saída/pulsos, flags únicas por projétil
(transporte, carga de fogo e duas funções futuras de raio), e janela2s para
restituição de interceptação com capacidade a recuperar. Dono errado, Traçado,
Triangulação e secundários não recebem transformações próprias. Detecção não
consome esses registros; os futuros efeitos devem reivindicar somente uma
interação efetiva. Edição/suspensão/parede→triângulo não troca identidade nem
renova flags/relógios; construção nova e limpeza invalidam o registro anterior.
Tolerância temporal1µs evita atrasar o limite2s um frame por arredondamento.

Evidência: `e05_geometer_wall_primitives_test.gd`74 PASS (geometria finita,
contato rápido, extremidades/raios, continuidade, oscilações, retirada/cleanup,
exclusões, dedup por componente e janelas em30/60/144Hz). Fixture real verifica
boss caminhando, caminho bloqueado, reposicionamento, parede móvel, edição,
pausa, triângulo sem herança e remoção de listeners; nenhum dano/SP de receita.
Suíte integral `tools/verify.ps1` PASS (exit0,73 checksG4 nessa execução);
refinamento final da armação nas extremidades passou74 checks direcionados.
Núcleo109, casting61 e integraçãoG2/G3 46 também repetidos PASS após esse ajuste.
Regressão do rendererG2/G3: seis capturas PASS; nenhuma mudança visual nova.
`git diff --check` PASS. Sem habilitar catálogo, preparar candidato parcial,
mandar microgate para Astra ou alterar o menu reservado por Astra em paralelo.

Próxima unidadeG4-B: receitas de travessia F/G e pulso de saídaF com LoS,
resolver canônico, snapshot e janela compartilhada das vítimas. DepoisG4-C:
interceptação, condução/desvio reais preservando alcance/vida/colisões e Teorema.
Isso mantém as seis receitas do contrato, sem cortar ou chamarG4 de concluído.

## G4 completo — seis paredes, projéteis e Teorema — 03/10/2026

Retomada autorizada para terminarG4, sobre78d0f58. Menu revisado de Astra
0c008d4 incorporado pelo mergecb0f0d3 sem perder Geômetra nem o teste menu_tabs.
Não foi enviado outro microgate; nenhuma alteração no projeto habitual ou master
foi feita por esta rodada. Próximo passo éG5, não publicar esta classe parcial.

`GeometerWallField` consome a mesma geometria/ledger da construção e implementa
as seis receitas ordenadas. EntradaF causa dano mágico; entradaG aplica slow2s;
saídaF emite pulso local45 com LoS e janela2s por vítima compartilhada entre
cruzadores e impactos. R→G não consome a janela de ator sem efeito. Parede não
é obstáculo de navegação. Reposicionamento/parede móvel não simula caminhada.

Pedidos são snapshots do lançamento pago que inicia a instância, retidos por
ticket inclusive na chegada fora de ordem. MAG/rank/passiva equipada não são
recapturados no impacto, edição ou retomada. Defense atual continua no resolver
canônico; pedidos adicionais são cópias secundárias, GEOMETRY, sem crítico ou
cascata genérica. Coeficientes permanecem o tuning inicial doG0, não balanceamento
aceito. Teorema tem três ranks10/15/20% e devolve2/3/4SP somente na interceptação
efetiva, com capacidade disponível e janela global2s da construção.

Projéteis próprios primários recebem condução seA=R, desvio único seB=R e carga
de fogo no próximo impacto seB=F. Traçado/Triangulação, dono errado e secundários
são excluídos. Condução começa no contato físico, percorre atéB capturado naquele
contato e sai na direção original: conserva distância percorrida, alcance/vida,
colisão e piercing. Desvio escolhe deterministicamente o vivo mais próximo deB
em raio110 com LoS deB e do contato real, sem homing ou projétil novo. O raio110
é tuning inicial explícito, não alcance global ou nova semântica aprovada.

Contato de terreno/vítima anterior impede transformação posterior. Flecha hostil
só é dissipada por saídaG; prioridade espacial de alvo, escudo, Barreira Fantasma
e terreno é conservada. Interceptar não converte a flecha nem causa dano aliado.
Flags são únicas por componente/projétil/instância e persistem nas edições e
parede→triângulo. Nenhum novo efeito de parede é concedido por um triângulo.

Limpeza, expiração, suspensão ou passagem para triângulo encerram a condução
em andamento no próximo avanço do projétil, retomando sua direção original
sem teleporte. Carga/Teorema pendentes exigem a mesma parede ativa no impacto;
não resolvem através de uma construção nova, extinta, suspensa ou triangular.
Retomada não renova flags nem refaz condução já interrompida. O projétil base
permanece independente e pode atingir normalmente sem esses adicionais.

Apresentação mínima acompanha eventos reais: fissura/arcoF, cristalG e traço
quebradoR, com duração0,25s e no máximo12 reações. Figura/vértices continuam sob
atores; camada separada de impacto evita ocultação pelo boss. Travessia sem
vítima elegível não finge novo proc visual. Arte de personagem ainda é fallback
Mago e não houve aprovação visual final ou medição de FPS.

Evidências internas: receitas106 PASS (seis pares, ranks1/5, passiva equipada,
LoS, pulso/vítimas, cadência, pausa, suspensão, snapshot e sem herança triangular).
Projéteis96 PASS (condução30/60/144Hz, alcance curto, obstáculo, desvio determinístico,
carga única/piercing, prioridades, reembolso, ciclo de vida, FIFO/snapshot no voo,
auto real contra boss solo e emissão real de flecha hostil). Primitivas74,
casting61 e integraçãoG2/G3 46 continuam no verificador. Fixtures antigas agora
contam/removem apenas projéteis, preservando o novo filho visual permanente.

`geometer_g4_renderer_probe.gd` PASS em sete capturas OpenGL1280×720 inspecionadas:
travessiaF/G, contato de condução, impactoF, desvio, interceptação e expiração.
Capturas ignoradas em `.godot/verification/geometer_g4_*.png`. O probe usa eventos
reais da cena, sem perfil persistente ou aprovação de produto.

`tools/verify.ps1` integral final PASS (exit0), incluindo importação do editor,
276 checksG4, núcleo109, casting61, integração46, menu_tabs38, smoke da cena,
regressões de classes aceitas/persistência e administração12. `git diff --check`
PASS. Evidências do implementador não equivalem a revisão independente de Astra.
G5/G6/G7 permanecem pendentes:27 campos, edição/progressão completa e arte/onboarding/
composição densa. Revisão Astra será integrada no fechamento da classe.

## G5 — 27 campos compostos, manutenção e resolução — 03/10/2026

Usuário autorizouG5 sobre0569cde. `GeometerTriangleField` compõe as três funções
por elemento: três puros,18 mistos e seis tricolores, com gatesR1/R3/R5. Não há
27 skills novas nem efeitos de aresta herdados. `ClassCatalog` guarda tuning e
descrições compostas; tooltip de Triangulação informa as funções atuais ou a
receita prevista com o elemento selecionado. Catálogo de produção continua fechado.

Fundação/regraF compartilham agenda1s e somam o poder em um único pedido por
ocupante, resolvido uma vez contra a defesa atual. Sem dano inicial de manutenção,
sem catch-up; avanço longo entrega no máximo um tick e conserva a fase da agenda.
Pausa congela tudo; suspensão continua consumindo os prazos sem aplicar efeitos.
SlowA/B usa o maior10/20%, com residual0,6s; campo móvel considera somente a área
atual, não sua varredura. Todos os alvos exigem círculo versus triângulo e LoS.

C resolve uma vez ao fechar: explosãoF, dano/rootG0,7s via `HardControlState`
com resistência/orçamento do boss, ou descargaR até três ocupantes únicos, a
partir do mais próximo deC, com elos<=110 e LoS. Identidade é reivindicada antes
de emitir dano. Edição, Reescrita, suspensão/retomada, expiração e notificação
duplicada não repetemC. Colapso e sua resolução própria pertencem ao futuroG6.

Snapshot de MAG/rank é capturado no lançamento pago do terceiro disparo e
retido por ticket até formação. Recalcular atributos/ranks, editar ou retomar
não recaptura a construção. Pedidos são cópias secundárias GEOMETRY, sem crítico,
Teorema ou cascatas genéricas; nenhuma fórmula de defesa foi duplicada no campo.

O gancho opcional existente dos projéteis delega triângulos ao novo campo.
Contato contínuo usa a mesma área de ocupação, sem a faixa12 das paredes, e
respeita vítima/terreno anterior. A-R acrescenta componente mágico uma vez no
próximo impacto elegível; B-R emite um único arco para outro ocupante<=110.
Para ambos, o impacto primário deve permanecer na área com LoS; se estiver fora,
suspenso, expirado ou em outra identidade, os adicionais são descartados sem
alterar o projétil base. Essa leitura conservadora do requisito de alvos na área
está explícita no tooltip e nos testes. Nenhum alcance/piercing é renovado.
Nascer dentro permite transformação; sair/reentrar não renova flags da instância.
Traçado/Triangulação, secundários e outro dono não recebem esses adicionais.
RRR funciona com o auto Mago real contra boss solo, sem inventar vizinho para arco.

Apresentação mínima: preenchimento discreto da área sob os atores, marca pequena
da regraB e um efeito dominanteC sobre o contorno real. Fogo expande/fissura,
gelo converge/segmenta e raio percorre elos reais. Sem tempestades contínuas
sobre cada vítima; reações compartilham o limite12 existente. Isso não fecha
arte do personagem, onboarding, cenário denso, FPS ou balanceamento deG7.

Evidências internas: `e05_geometer_triangle_recipes_test.gd`597 PASS, cobrindo
27 receitas no rank mínimo/R5, gates, manutenção somada, slow, área/LoS, cadeia
limitada, boss, snapshot, edição/Reescrita, mobilidade, pausa/suspensão/expiração.
`e05_geometer_triangle_projectile_test.gd`192 PASS, cobrindo27 composições,
contato finito/contínuo, prioridades, exclusões, payload único/piercing, ciclo
de vida, snapshot do terceiro disparo pago, tooltip e auto solo30/60/144Hz.
A fixtureG2/G3 desliga apenas o novo campo para continuar isolando geometria
e morte; as suitesG5 exercitam dano/controle real pelo aplicador central.

`geometer_g5_renderer_probe.gd` PASS em nove capturas OpenGL1280×720 inspecionadas:
FFF fechamento/piso, GGG contenção, RRR fechamento/arco real, FGR composto,
âncora móvel suspensa/retomada sem replay e expiração limpa. Capturas ignoradas
em `.godot/verification/geometer_g5_*.png`. Regressão do rendererG4: sete estados
PASS após os novos efeitos. Nenhuma fixture grava perfil persistente do usuário.

`tools/verify.ps1` integral PASS (exit0): importação do editor,789 checksG5,
276 checksG4, núcleo109, casting61, integração46, menu_tabs38, smoke, classes
aceitas, persistência e administração12. Importação final também PASS.
`git diff --check` PASS. Não houve publicação no diretório habitual, alteração
de master ou microgate a Astra. Evidências internas não são aceite de produto.

Próximo lote, mediante autorização do usuário: G6 — Translação, Reescrita,
Colapso, Memória Vetorial e progressão/menu/build/save com duas builds legais.
G7 fecha apresentação/integração e o único pacote de revisão da classe para Astra.

## G6 — edição, Colapso, Memória Vetorial e builds — 03/10/2026

Usuário autorizou G6 sobre `b466a0a`. Translação, Reescrita, Colapso e Memória
Vetorial agora têm catálogo de ranks, execução e descrições no menu. As sete
skills de Geômetra estão registradas na progressão; `content_ready=false` segue
intencionalmente fechado em produção até G7. Não houve microgate a Astra,
publicação de classe parcial, mudança de master ou do diretório habitual de playtest.

Translação conserva o elemento do último vértice; Reescrita passa A/B/C para
B/C/D, usando o elemento escolhido no comando. Clique no corpo vincula àquela
instância viva; chão/Shift desprende. Alcance600, LoS, geometria inteira e gate
da receita candidata são revalidados antes de mutar ou cobrar. Sem SP/CD em
edição inválida, sem editar enquanto há disparos pagos na fila. Identidade,
deadline da figura, cadência, ledger e snapshots sobrevivem à edição e à
suspensão/retomada. Somente a âncora substituída ganha TTL normal novo; não
repeteC. Translação custa12 SP/CD4 s; Reescrita14 SP/CD5 s, instantâneas.

Memória Vetorial é passiva equipada, três ranks: vértice +1/+2/+4 s, figura
+1/+2/+3 s, ambos limitados a12 s. Durações são capturadas no lançamento pago
e na edição, sem benefício retroativo ao equipar/desequipar. Editar não renova
o deadline existente da figura; a âncora antiga retém o próprio prazo.

Colapso custa18 SP/CD8 s, SELF instantâneo, somente parede/triângulo válido e
ativo sem reservas pendentes. Consome e limpa a construção antes dos callbacks
de dano. Seu pedido usa MAG atual e rank próprio, nunca o snapshot de formação.
Parede: um pulso na faixa física finita12+raio com LoS, sem atingir vizinho fora
da faixa ou executar travessia/interceptação/Teorema. Triângulo: uma resoluçãoC
na área atual, explosãoF/rootG/cadeiaR existente, com limites de área/LoS,
três alvos únicos/elos110 e orçamento de controle do boss. Sem manutenção,
crítico, Teorema ou cascatas; segunda tentativa após consumir não cobra.

Tuning inicial de Colapso, para posterior balanceamento/aceite de produto:

| Rank | Parede | C-Fogo | C-Gelo | C-Raio |
|---|---|---|---|---|
| R1 | 0,60 MAG | 0,80 MAG | 0,30 MAG | 0,60 MAG |
| R5 | 1,00 MAG | 1,20 MAG | 0,50 MAG | 1,00 MAG |

Ranks intermediários interpolam linearmente. RootG continua0,7 s pelas regras
existentes. Ranks de Translação/Reescrita conservam os mesmos custos/CD/alcance;
não foi inventado um benefício numérico fora do contrato. Esses números não
equivalem a tuning final aprovado por Astra ou pelo usuário.

Progressão: origem Mago, sem biblioteca de Arqueiro/irmãos; gates20/23/25/28/31/
34/37 e caps5/3/5/5/3/5/5. TraçadoR1 é grátis, até quatro ranks comprados.
O codec vigente salva ranks e cinco slots ativos/dois passivos, sem schema novo
nem persistência de construção. Override de fixture só abre `content_ready`;
override de biblioteca substitui explicitamente os metadados, sem mistura.
Respec devolve as carteiras e conserva apenas a entrada grátis.

Duas builds reais de job40, compradas via `ProfileFacade`, esgotam legalmente
19 pontos base e20 de evolução, salvam/recarregam e iniciam run isolada:

- Paredes: TraçadoR5, IncidênciaR3, TranslaçãoR5, MemóriaR3, ColapsoR5;
  ativos Traçado/Translação/Colapso/Bola de Fogo/Lança de Gelo, duas passivas.
- Triângulos: TraçadoR3, IncidênciaR3, TriangulaçãoR5, MemóriaR3, ColapsoR2,
  ReescritaR5; ativos Traçado/Triangulação/Reescrita/Colapso/Relâmpago, duas passivas.

Correções encontradas na integração: inicializar o ledger ao capturar uma nova
parede/triângulo, antes de um projétil nascido dentro avançar, evita contato0
sem progresso. A barra limita a largura dos cinco botões e usa elipse com
tooltip completo: nomes longos não empurram o quinto botão para fora da tela.
O teste headless compara coordenadas com o viewport lógico, não a janela física.
O teste histórico do roster agora exige explicitamente os sete metadados de
Geômetra sem liberar seu gate; demais placeholders continuam estritos.

Evidências internas: `e05_geometer_editing_test.gd`375 PASS — transações reais,
27 receitas emR1/R5, seis paredes, inválidos atômicos, binding/morte, TTL equipado,
cadência30/60/144Hz, snapshot/payload, consumo antes de dano e três modos de input.
`e05_geometer_builds_test.gd`341 PASS — catálogo/gates/carteiras, duas builds
legais, save/load/codec/respec, corrupção rejeitada e menu emjob22/23/40.
Fixtures usam somente `.godot/verification`, nunca o perfil persistente do usuário.

`geometer_g6_renderer_probe.gd` PASS em oito capturas OpenGL1280×720 inspecionadas:
preview/edição de Translação e Reescrita, Colapso triangular, pulso finito de
parede e limpeza de ambos; todos os cinco botões dentro da tela. Regressão do
rendererG5 também PASS em nove estados. Capturas ignoradas em `.godot/verification`.
Arte do personagem ainda é fallback de Mago; densidade/FPS, onboarding, tuning
e aceite da classe completa não são evidências desta rodada.

`tools/verify.ps1` integral final PASS (exit0), incluindo importação do editor,
716 checks novosG6, núcleo109/casting61/integração46, paredes276/triângulos789,
UI de batalha47/layout28/menu_tabs38, persistência e classes já aceitas,
smoke da cena e administração12. `git diff --check` PASS. Evidências do
implementador não substituem revisão independente de Astra ou playtest humano.

Próximo lote, mediante autorização: G7 — apresentação final, onboarding e
integração densa; então um único checkpoint da classe completa para revisão
de Astra e candidato de playtest, sem confundir gate técnico com aceite humano.

## G7 — apresentação e candidato integrado — 03/10/2026

Usuário autorizou G7 sobre `317a48d`. Fecha a implementação da Geômetra no
worktree E05, sem liberar outras classes/híbridas, terreno quadrado, Ressonância
ou painel de balanceamento. O merge de menu em abas já estava incorporado
(`cb0f0d3`); G7 não modifica seus contratos/core/save. Revisão é da classe inteira,
não um gate por skill. Master e diretório habitual de playtest não foram alterados.

Personagem deixa o fallback de Mago: cartógrafa/astrônoma de cabelo prateado,
chapéu navy com pin triangular dourado, traje ivory/navy e arco instrumental,
seguindo a referência aprovada por Astra. Um atlas próprio 256×512 com 32 poses,
frente/costas, passos alternados, preparo/ação, hurt e morte. Fonte imagegen
integrada e prompt final preservados em `assets/art/animation_sources/geometer_*`;
normalização nearest/pés reproduzível por `prepare_geometer_atlas.gd`.
Texturas são compartilhadas, relógio/pose por instância; morte copia o atlas e
o alinhamento. Não existe acerto, colisão ou custo condicionado a frame visual.

Gramática visual nativa: chama/cristal/raio, base elíptica de chão versus aro/vínculo,
faixa finita e seta A→B nas paredes; seis motivos pequenos interiores por fundação
do triângulo, marca B e um acento C. Suspensão tracejada/acinzentada sem piso ativo.
Não foram geradas 33 sheets nem transformada a área triangular num losango.
O teste denso mostrou excesso de círculos de slow/root; somente nas runs Geômetra,
inimigos usam pequenos indicadores nos pés. Slow/root e orçamento do boss são
os mesmos; outras classes mantêm seus círculos anteriores. Reações limitadas a 12.

Onboarding: Caderno Geométrico compacto no lugar da ajuda genérica, com estado,
sequência A/B/C, vínculo móvel ↟, menor prazo e próximo passo; guia recolhível para
1/2/3, gates R1/R3/R5, corpo/chão/Shift, edição e Esc versus Backspace/Colapso.
É somente-leitura e deixa cliques passarem fora do botão. Ajuda aberta não pausa,
cancela mira ou altera SP/relógios; menus reais continuam pausando normalmente.

`content_ready=true` agora apenas em `mg_ar` no candidato completo. Evolução
Mago 10/job 20, Traçado R1 grátis sem autoequip, progressão/ranks/slots e save usam
o catálogo/fachada vigentes. As builds G6 agora são exercitadas sem override;
o teste de bloqueio histórico usa fixture explicitamente false, sem remover a
invariante. Nenhum gate de outros placeholders foi afrouxado e nenhum schema novo.

Regressão histórica: o menu em abas agora espera Geômetra disponível, mantendo
o bloqueio do placeholder `mg_sw`. Os testes G1/G2/G3 de biblioteca parcial usam
fixture explicitamente indisponível, em vez de exigir que o candidato completo
continue bloqueado. O fluxo G7 verifica disponibilidade real sem override.

Evidências novas G7 (903 checks):

- Atlas 101: 32 células/alpha/pés/source regions, passos distintos, morte e Mago intacto.
- Guia 276: vazio/A/preparação/parede/triângulo/trânsito/suspensão/pausa, requisitos,
  invariância de estado e layout 1280/1920, expansão/recolhimento e mouse pass-through.
- Integração 500: builds compradas legalmente em R1/R3/R5, cinco receitas representativas,
  19 adds + Guardião (total 20), três disparos pagos, auto Mago e cinco flechas hostis
  reais, contato 30/60/144 Hz, âncora móvel, pausa/suspensão/retomada, cap 12 e limpeza
  síncrona por morte/resultado/reinício, evolução real com catálogo sem override.
- Fluxo 26: dois Magos e foco diferente da seleção persistida; confirmação 10/20,
  +1.000 XP job → 22 bloqueia Incidência; +500 → 23 libera; equipar/save/reload, treino
  sem escrita/recompensa, run normal com atlas/guia, recompensa no dono correto.

`geometer_g7_renderer_probe.gd`: 15 capturas PASS em Compatibility, incluindo
silhueta final, parede/direção/interceptação real, FFF/GGG/RRR, tricolor móvel,
suspensão/retomada, ajuda aberta/fechada, piso escuro, combate denso e limpeza.
Fixtures elevam HP e congelam atores nas capturas para inspeção; não são teste
de balanceamento. Obstáculos do cenário permanecem reais. Guardião é o chaser
de treino vigente; não foi inventado um telegraph de boss que o runtime não possui.
Capturas e relatório bruto ficam ignorados em `.godot/verification/geometer_g7_*`.

Medição observacional na máquina Windows/i7-8700/GTX 1080, Godot 4.7.2 standard,
gl_compatibility, janela 1920×1080 e viewport lógico 1280×720: 240 intervalos reais
por fase após 60 frames de warmup, com 20 inimigos e APIs reais avançadas por
delta explícito 1/60. Baseline sem figura: média 13,39 ms/p95 13,49 ms/pior 26,74 ms;
RRR ativo: média 13,59 ms/p95 17,00 ms/pior 26,71 ms, até 3 reações simultâneas.
Diferença de médias +0,20 ms não é custo isolado do campo: fases sequenciais,
pacing/vsync/CPU/GPU misturados e estado dos atores evoluindo. Não demonstra
60 FPS sustentados nem substitui playtest humano; tuning continua inicial.

Fechamento: `tools/verify.ps1` PASS integral em Godot 4.7.2 standard, exit 0,
incluindo import, regressões de menu/save/classes, todas as camadas Geômetra
(2.900 checks), smoke da cena e admin de playtest. A primeira execução apontou
a expectativa antiga de bloqueio no menu; a execução completa final passou
após alinhar os testes históricos ao catálogo G7. `git diff --check` PASS.
As 15 capturas finais foram inspecionadas pelo condutor, além da validação do
probe; alpha, alinhamento, piso claro/escuro, ajuda recolhível e limpeza conferidos.

### Revisão integrada de Astra e roteiro de produto

Revisar Geômetra inteira desde a base aceita 8df3a67, com precedência de
`E05_GEOMETER_PLAN.md`/`E05_GEOMETER_G0_PROPOSAL.md`; commits de sistemas G1–G6
e este G7 compõem um candidato. Conferir gates/cards/mira, reservas/cobrança,
geometria/nav/vínculos, seis paredes, 27 composições, snapshots/dedup/CC, edição,
Colapso/TTL, duas builds/save e legibilidade do atlas/campo em piso claro/escuro.
Testes automáticos/capturas do implementador não são reprodução independente.

Após aceite técnico, Astra pode preparar rebase/FF de `codex/playtest`, preservando
alterações do usuário e os menus aceitos. Roteiro humano: Mago 10/job 20→Geômetra,
equipar Traçado grátis; testar uma parede por dois elementos distintos e preparação
por iguais; no job 28 equipar Triangulação para C; experimentar puros R1/mistos R3/
tricolor R5, chão/inimigo/Shift, vínculo móvel/morte, edição/Colapso/Esc/limpeza,
duas builds G6 e boss solo/com adds. Avaliar leitura, tempo útil/SP, controle,
animação/pés e FPS percebido; balanceamento não está automaticamente aprovado.
Merge em master somente após aceite explícito do candidato testado. Não iniciar
próxima classe/marco por completar G7.
