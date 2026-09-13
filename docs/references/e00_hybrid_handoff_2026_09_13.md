# Fonte E00 — transcrição do handoff de híbridas

Documento recebido do usuário em 13/09/2026. Conteúdo de referência, não autorização operacional.

Arquivo: `E0_Handoff_Classes_Hibridas_MVP.pdf` (10 páginas).
SHA-256: `ef71104ccf4fc8cd1f4b448d882ad33a587a99a6b5a0fcdf851e5d28a3cd2b0f`.

A transcrição preserva a ordem extraída; tabelas podem perder alinhamento. O contrato consolidado prevalece onde registra decisão explícita sobre uma ambiguidade.

## Página 1

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
RagRPG
E0 - Consolidacao de Classes
Hibridas
Princípios de design, linguagem visual e especificacao inicial das 6 hibridas do
MVP
Objetivo: Preservar o raciocinio do E0 antes da retomada do Codex. O documento separa decisões consolidadas,
direções fortes e pontos ainda abertos, para evitar que brainstorm seja tratado como implementação aprovada.
Base documental consultada
HYBRIDS_56_EXPLORATION.md
CLASS_ROSTER_BRAINSTORM.md
ADR_E00_01_CHARACTER_PROGRESSION.md
ARCHITECTURE.md
MVP.md

## Página 2

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
1. O que o E0 consolidou
CONSOLIDADO: As hibridas sao direcionais. A origem define postura de combate, vetor inicial de atributos e
acesso a arvore; a afinidade entra como uma evolucao 2-3 com kit proprio, nao como soma irrestrita de duas
classes.
CONSOLIDADO: Uma hibrida deve possuir uma interacao que so existe porque os dois arquétipos foram
combinados. “Classe A + duas skills de B” e criterio de reprovação.
CONSOLIDADO: Augments ampliam uma identidade que ja funciona; nao devem consertar um loop incompleto.
Para avaliar qualquer hibrida, o E0 passou a usar cinco perguntas: distancia preferida, recurso administrado, forma
de abrir/fechar sequencia, decisao diferente contra boss e fraqueza preservada. Alem disso, surgiram tres tipos de
“momento de gloria” que valem perseguir:
 Leitura: prever corretamente uma acao/rota e obter uma vantagem desproporcionalmente satisfatoria.
 Salvamento: converter uma situacao quase perdida por timing ou gerenciamento correto.
 Combo: preparar varias pecas e produzir um payoff claro, legivel e espetacular.
1.1 Regras de familia que surgiram durante a conversa
Familia Regra de design consolidada
Elementalista
Fogo, Gelo e Raio precisam permanecer presentes. Cada hibrida
reinterpreta a tricotomia no substantivo da outra classe; evitar
sete skins do mesmo sistema elemental.
Bruxo
Toda hibrida deve preservar DoT + invocacao. No Demonologo,
entidade/pacto tende a vir primeiro e a aflicao alimenta ou
estende a entidade; no Necromante, a aflicao prepara
morte/materia e o summon nasce dessa deterioracao.
Cacador Trap/preparacao/rota precisam ser evidentes. Se remover as
armadilhas e a classe continuar quase igual, o design falhou.
Assassino
Stealth, entrada, facing/backstab e decisao de executar ou sair
precisam ser evidentes. A segunda classe altera como o
backstab e criado, nao o substitui.
Melee + ranged
Quando uma das metades e melee, o alcance dominante e
melee; a parte ranged prepara, marca, conduz ou cria a janela,
mas o payoff principal termina no corpo a corpo.
1.2 Estado do MVP expandido
O demo expandido usa Espadachim, Mago e Arqueiro como origens, suas seis evolucoes puras e as seis hibridas
direcionais entre essas tres bases. As identidades tratadas neste handoff sao:
ID conceitual Origem -> afinidade Hibrida do MVP
sp_mg Espadachim -> Mago Cavaleiro Runico
mg_sp Mago -> Espadachim Devastador Astral
sp_ar Espadachim -> Arqueiro Baluarte de Cerco
ar_sp Arqueiro -> Espadachim Saqueador
mg_ar Mago -> Arqueiro Geometra (substitui o nome
exploratorio Arqueiro Arcano)
ar_mg Arqueiro -> Mago Cacador de Espectros

## Página 3

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
2. Linguagem visual das seis classes estendidas envolvidas
A conversa passou de paleta para uma linguagem de quatro camadas: cor, material, forma/silhueta e comportamento
de VFX. A leitura ideal deve sobreviver mesmo com pouca saturacao ou sem depender apenas de cor.
Classe estendida Paleta Material / forma Assinatura de VFX
Defendente Prata, dourado, marrom, cinza Aco, couro, pedra; placas,
retangulos, massa
Impactos secos, ondas curtas,
particulas pesadas
Berserker Vermelho, marrom, preto Ferro escuro, couro, feridas;
diagonais e rasgos
Pulsacao, spray, tremor, trails
agressivos
Sentinela Verde, azul-claro, marrom-
claro, branco
Madeira clara, tecido, metal;
linhas longas e mira
Trajetorias limpas, linhas finas,
brilho direcional
Cacador Marrom-escuro, verde-musgo,
marrom-claro
Madeira bruta, corda, osso;
ganchos, nos, mecanismos
Poeira, folhas, marcas no chao,
acionamento mecanico
Elementalista Azul, branco, vermelho,
amarelo
Cristal, vidro, energia; prismas e
formas radiais
Alto brilho, expansao, cristais,
arco eletrico
Espiritualista Branco/palido, preto, cinza,
prata
Tecido, nevoa, ectoplasma;
crescentes, veus, duplicacoes
Afterimages, translucidez,
atraso, dissipacao
REGRA VISUAL: A origem define o objeto/material; a afinidade define o fenomeno que acontece com esse objeto.
Evitar “sprite A tingido com a cor de B”.
Substantivos visuais úteis: Defendente = placa; Berserker = ferida; Sentinela = linha; Cacador = mecanismo;
Elementalista = energia; Espiritualista = vestigio. As seis hibridas podem ser lidas como combinacoes: inscricao,
possessao, fortificacao, armadilha brutal, geometria e rastro.

## Página 4

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
3. Estrutura de progressao e stats usada neste handoff
O ADR E00.1 propõe, ainda sem aceite numerico final, base level 1-30, job 1-40, evolucao a partir de base 10/job 20, 20
pontos de skill de evolucao, ativas rank 1-5 e passivas rank 1-3. Cada evolucao adiciona 4-6 ativas e 2-3 passivas; uma
ativa exclusiva comeca em rank 1 gratuitamente. O loadout proposto tem 5 ativas e 2 passivas, alem do auto.
DIRECAO FORTE: Cavaleiro Runico e Geometra precisam de um pequeno sistema de input intrinseco para suas
linguagens (runas/vertices), em vez de consumir tres dos cinco slots normais so para acessar Fogo, Gelo e Raio.
3.1 Vetores de origem
Origem FOR AGI VIT INT DES SOR
Espadachim 8 5 8 2 5 2
Mago 2 5 5 9 7 2
Arqueiro
(proposto) 3 7 5 2 10 3
A origem conserva esse vetor quando evolui. O respec gratuito proposto no demo e especialmente importante para
hibridas que mudam a prioridade ofensiva, como Saqueador.
3.2 Gap tecnico identificado
A arquitetura atual deriva todo physical_attack apenas de FOR. Isso serve para o Espadachim, mas nao atende bem
Arqueiro nem hibridas que dependem de DES. A direcao sugerida para o E0 e separar dano de precisao (por exemplo,
precision_attack escalando com DES) de melee fisico (FOR), mantendo magia em INT. O objetivo e permitir escolhas
reais de stats em Baluarte, Saqueador e Geometra sem empurrar toda build fisica para FOR.
3.3 Perfis de stats - referencia de build, nao balanceamento final
Hibrida Prioridade sugerida Intencao
Cavaleiro Runico VIT > FOR ~ INT > DES tank que converte defesa em formula;
FOR/INT definem o peso fisico/elemental
Devastador Astral FOR ~ INT > AGI > VIT dual scaling; arma e manifestacao
espectral disputam investimento
Baluarte de Cerco VIT ~ DES > FOR tank de linha; guarda + represalia de
precisao
Saqueador FOR ~ DES ~ AGI > VIT trap + perseguição + payoff melee
Geometra INT ~ DES > AGI potencia da geometria +
precisao/colocacao
Cacador de Espectros DES > INT ~ AGI tiro/rastro + componente espiritual/DoT
4. As seis hibridas do MVP
4.1 Cavaleiro Runico
Espadachim -> Mago | Defendente + Elementalista
CORE: Hwei/Invoker tank: tres runas produzem 18 combinacoes finais. Defender alimenta a linguagem runica; a
formula escolhida define a resposta e a carga obtida ao bloquear define a intensidade.
Identidade visual: Metal/prata/cinza com canais luminosos gravados. Fogo parece metal aquecido, Gelo cristaliza
bordas, Raio corre como circuitos finos. As tres runas devem ser legiveis no proprio personagem.
STATUS: Direcao muito forte; nome Cavaleiro Runico preferido a Runista. Principal risco: input/UI e legibilidade
das 18 formulas.

## Página 5

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
Loop: ler ameaca -> escrever formula -> guardar -> acumular Carga Runica -> descarregar/resolver a formula.
Job Skill Funcao
21 Guarda Prismatica arma a formula atual e converte
defesa/perfect guard em Carga Runica
23 Aco Condutor (passiva) melhora geracao de carga; perfect guard
deve ser particularmente eficiente
25 Contra-runa descarrega a formula em arco/contra-
ataque melee
28 Inscricao de Campo fixa uma manifestacao menor da
formula no terreno
31 Sintaxe Belica (passiva)
receitas repetitivas favorecem
especializacao; mistas favorecem
flexibilidade/utilidade
34 Reescrita
troca uma runa sem apagar toda a
formula; ranks altos podem permitir isso
durante guarda
37 Apoteose Runica janela de gloria em que descarregar nao
apaga imediatamente a matriz
Augments exclusivos sugeridos: Palimpsesto (preserva parte da formula apos descarga); Aco Ressonante (mais carga
por bloqueio); Sintaxe Invertida (inverte ordem uma vez por cooldown); Sobrecarga Prismatica (formula tricolor
consome excesso de carga por payoff maior).
4.2 Devastador Astral
Mago -> Espadachim | Espiritualista + Berserker
CORE: Berserker melee possuido por espiritos. A arma continua fisica, enquanto ecos/manifestacoes usam INT.
Tensão Astral cresce com agressao e risco; alta tensao aumenta a presenca dos espiritos e prepara uma repeticao
explosiva da sequencia.
Identidade visual: Vermelho/marrom/preto do Berserker sendo progressivamente dessaturados por
branco/palido/preto do Espiritualista. Golpe fisico primeiro; ecos, bracos e silhuetas repetem o movimento com atraso
de 100-200 ms.
STATUS: Core funcional, mas ainda e a hibrida do MVP que mais precisa de uma assinatura mecanica e talvez
nome mais memoraveis.
Loop: entrar -> Possessao Furiosa -> acumular Tensão Astral -> registrar/empilhar golpes -> Ruptura da Alma -> sair
antes de quebrar.
Job Skill Funcao
21 Possessao Furiosa toggle que converte o auto/skills melee e
gera Tensão
23 Vaso Fraturado (passiva) risco e dano recebido aceleram
manifestacoes
25 Corte de Ecos golpe melee com segundo arco espectral
atrasado
28 Passo Possesso
avanco curto
atravessando/reposicionando em torno
do alvo
31 Canal Aberto (passiva) acertar alvos sob efeitos espirituais
restaura SP e reduz downtime
34 Maldicao do Eco registra proximos golpes melee no alvo
37 Ruptura da Alma consome Tensão e faz espiritos repetirem
parte da sequencia em cone/area

## Página 6

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
Augments sugeridos: Coro de Guerra (terceiro golpe em alta tensao gera imitacao); Possessao Profunda (teto maior
com risco maior); Reverberacao (segunda repeticao reduzida); Vaso Transbordante (SP excedente vira Tensão).
4.3 Baluarte de Cerco
Espadachim -> Arqueiro | Defendente + Sentinela
CORE: Tank melee que declara e protege uma linha. Sentinela aparece como corredor, vigilancia e represalia, nao
como auto de arqueiro. Bloquear projeteis/avancos pela linha gera Pressao de Cerco, que volta como tiro/onda de
represalia.
Identidade visual: Prata fosca, tecido azul-claro/esverdeado, madeira clara. Defendente e um bloco; Baluarte e um
bloco apontando para uma direcao. Linhas, visor estreito, paves e faixa de vigia dominam a leitura.
STATUS: Core solido. Risco principal: ficar estatico demais; o kit precisa de motivos para desmontar e reconstruir
a posicao.
Loop: declarar Linha de Vigia -> segurar/ler ameaca -> gerar Pressao -> empurrar inimigos de volta para o corredor ->
devolver a pressao.
Job Skill Funcao
21 Postura de Cerco ancora Linha de Vigia; reforca guarda
frontal e gera Pressao
23 Disciplina de Cerco (passiva) premia manter posicao proxima da
ancora
25 Disparo de Represalia tiro longo/perfurante pela linha; escala
com Pressao
28 Paves cobertura instalada; intercepta projeteis
e estende a fortificacao
31 Olho do Baluarte (passiva) alvos que cruzam a linha ficam Avistados
34 Avanco de Muralha investida curta que empurra de volta
para a linha
37 Rompimento de Cerco slam/onda estreita que percorre toda a
Linha de Vigia
Augments sugeridos: Paves Geminado; Resposta Instintiva (perfect guard dispara represalia menor); Corredor de
Morte (ganha dano por perfuracao); Ultimo Reduto (HP baixo concede pressao/guarda inicial).
4.4 Saqueador
Arqueiro -> Espadachim | Cacador + Berserker
CORE: Trapper melee que luta dentro da propria rede. Toda trap serve tanto para a presa quanto, de forma
diferente, para o proprio Saqueador. Bleed acelera a presa e torna a caçada mais perigosa; traps acionadas viram
pontos de impulso para uma investida imparavel.
Identidade visual: Musgo, couro escuro, ferrugem e vermelho seco. Em estado neutro le-se Cacador; quando traps
disparam e Impeto sobe, o vermelho vivo aparece nos trails e na arma. Corda, ganchos, mandibulas e ferragens
precisam estar na silhueta.
STATUS: Direcao muito forte depois do twist de autoativacao. Precisa calibrar reset de traps para evitar loops
infinitos em grupos fracos.
Loop: preparar traps -> ferir/provocar -> Bleed acelera a presa -> trap ativa -> Saqueador Reivindica a trap e atravessa
a formacao -> mata bleeder -> rearma/reduz CD -> continua a cadeia.
Job Skill Funcao
21 Laco de Arrasto inimigo: puxa para o ponto; Saqueador:
usa como impulso/grapple curto
23 Cheiro de Sangue (passiva) Bleed aumenta movespeed do inimigo,
melhora tracking e alimenta Impeto

## Página 7

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
Job Skill Funcao
25 Reivindicar Presa dash ate trap ativada; Unstoppable, strike
damage e knockback nos atravessados
28 Mandibula Serrilhada
inimigo: root + bleed; autoativacao:
pequeno custo de HP, grande ganho de
Impeto
31 Abate Sangrento (passiva)
kill em inimigo com bleed reduz
cooldown/rearme e rearma
prioritariamente uma trap proxima
34 Fio de Tropeco inimigo: derruba/lanca; Saqueador:
converte em movimento/leap
37 Turbilhao de Saque payoff melee que escala com Impeto,
bleeders e traps ativadas recentemente
Momento de gloria: trap A ativa -> dash imparavel -> kill em bleeder rearma B -> autoativa B -> e lancado para C ->
outra trap dispara -> finaliza com Turbilhao. A rede deixa de ser apenas killbox e vira tambem rota ofensiva.
Augments sugeridos: Dentes Duplos (cargas extras em traps fisicas); Arrastao (Laco afeta proximos); Sangue Fresco
(traps ativadas empilham ASPD); Sem Escapatoria (kill logo apos trap pode resetar a trap mais proxima).
4.5 Geometra
Mago -> Arqueiro | Elementalista + Sentinela
CORE: Super-Invoker de range: flechas criam vertices elementais no chao ou em inimigos. Dois vertices distintos
formam 6 paredes direcionadas; tres vertices formam 27 triangulos. As construcoes podem alterar terreno,
inimigos, projeteis ou aliados.
Identidade visual: Branco/azul-claro, madeira muito clara, detalhes amarelo/dourado e acentos elementais. Cartografo
+ astronomo + engenheiro. O campo deve parecer um diagrama vivo. Fogo, Gelo e Raio precisam ter forma alem da
cor.
STATUS: Conceito-joia e maior skill ceiling do MVP, mas tambem maior risco de producao/UI. Complexidade e
intencional; o onboarding deve revelar a gramatica em camadas.
Loop: ler arena -> colocar vertices -> formar parede/triangulo -> explorar a regra da construcao -> editar/colapsar a
figura -> redesenhar.
GRAMATICA: Fogo, Gelo e Raio nao sao apenas cores. A ordem importa. Para paredes, A->B e diferente de B->A.
Para triangulos, a recomendacao e dar semantica aos tres slots: fundacao/terreno -> regra interna ->
resolucao/interacao.
Job Skill Funcao
21 Tracado Elemental vertices + seis paredes direcionadas
23 Teorema de Incidencia (passiva) premia projeteis/atores que interagem
corretamente com paredes
25 Translacao move o ultimo vertice sem destruir toda
a figura
28 Triangulacao desbloqueia triangulos de forma
progressiva
31 Memoria Vetorial (passiva) melhora duracao/estabilidade de vertices
34 Colapso Geometrico consome a figura ativa para resolucao
imediata da formula
37 Reescrita substitui o vertice mais antigo,
permitindo editar sem recomecar
Progressao cognitiva sugerida para Triangulacao: R1 libera FFF/GGG/RRR; R3 libera as 18 composicoes 2+1; R5 libera
as 6 tricolores. O jogador aprende primeiro seis paredes, depois tres triangulos puros, depois 2+1, e so no fim as seis
palavras tricolores.

## Página 8

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
Augments sugeridos: Parede Residual; Vertice Ambulante; Prisma Balistico; Prova por Contradicao. Evitar “quarto
vertice” ou quadrados no MVP: o sistema ja tem 33 resultados.
4.6 Cacador de Espectros
Arqueiro -> Mago | Cacador + Espiritualista
CORE: Cacador que transforma mortos e armadilhas em infraestrutura de tracking. Pó de alma fica no chao;
flechas que atravessam a trilha tornam-se espectrais, perfuram, aplicam DoT e podem fazer novos inimigos
produzirem trilha. A arena melhora para o jogador conforme a historia da luta se acumula.
Identidade visual: Couro/musgo/osso do Cacador + branco palido/prata/cinza azulado translúcido. A flecha fisica
praticamente perde materia ao cruzar o pó. Armadilha Espectral, Banimento e Assombrosa precisam ter silhuetas
diferentes antes mesmo da cor.
STATUS: Direcao muito forte. Ponto a validar: largura/duracao dos rastros e resposta contra boss sem depender
de horda.
Loop: trap Espectral -> alvo deixa trilha -> tiro cruza trilha e fica espectral -> perfura/espalha DoT e novas trilhas ->
mortes consolidam o mapa -> jogador explora corredores antigos para novos tiros.
Job Skill Funcao
21 Armadilha Espectral perene; pequeno DoT + marca de trilha;
rearma em ~5 s
23 Olho do Alem (passiva) tracking e leitura visual de alvos/rastros
25 Disparo de Vestigio forma confiavel, menos eficiente, de iniciar
trilha; util contra boss
28 Armadilha de Banimento bane em area: imovel e intangivel durante a
duracao; controle sem DPS gratis
31 Pó Persistente (passiva) melhora duracao/continuidade e
consequencias de morte
34 Armadilha Assombrosa fear em area + reducao de armor/MRES;
dano quebra fear
37 Procissao Espectral grande tiro que explora corredores e alvos
marcados existentes
Interacao intrinseca: flecha que cruza pó -> espectral -> sem a limitacao de distancia definida para o tiro fisico, perfura
alvos, aplica DoT e tem chance de fazer a vitima gerar trilha ate o DoT expirar. A morte de alvos marcados deve
produzir/propagar um payoff de trilha.
Augments sugeridos: Ectoplasma Denso; Banimento Fraturado; Assombracao Residual; Eco Mortuario.

## Página 9

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
5. Matriz visual rapida das seis hibridas
Hibrida Fusao visual Leitura em gameplay
Cavaleiro Runico placa + energia = inscricao formula visivel na armadura/escudo;
metal continua dominante
Devastador Astral ferida + vestigio = possessao aumentar Tensão dessatura o Berserker
e multiplica ecos atrasados
Baluarte de Cerco placa + linha = fortificacao postura literalmente aponta/declara um
corredor; Pressao cresce na linha
Saqueador mecanismo + ferida = armadilha brutal estado neutro e Cacador; traps/bleed
fazem o Berserker emergir
Geometra linha + energia = geometria vertices, paredes e triangulos sao o VFX
principal; campo vira diagrama
Cacador de Espectros mecanismo + vestigio = rastro infraestrutura palida cresce no terreno e
altera fisicamente os projeteis
6. Pontos ainda abertos antes de E04/E05
Area Pendencia
Devastador Astral
Achar uma assinatura mecanica/nome tao fortes quanto runas,
geometria e rastro. O atual loop Possessao/Tensão/Eco e
funcional, mas ainda pode ganhar um twist de maior
inevitabilidade visual.
Cavaleiro Runico
Formalizar exatamente as 18 formulas e a regra “dois slots
permitindo repeticao + um com escolha nao-repetida”; definir
como selecionar runas sem sobrecarregar 5 slots.
Geometra
Catalogar as 6 paredes + 27 triangulos por gramatica, nao por
lista arbitraria; definir limite de vertices/figuras e regras
quando vertices estao em atores moveis.
Baluarte de Cerco
Adicionar ou fortalecer um momento de gloria que nao seja
apenas “guardei muito e devolvi dano”; validar
mobilidade/realocacao de Paves e Linha.
Saqueador
Calibrar autoativacao, custo de HP, Bleed que aumenta
movespeed, Unstoppable e resets para que o loop seja poderoso
sem virar reset infinito em trash.
Cacador de Espectros
Definir se “sem distancia minima” significa remover minimum
range ou alcance maximo; validar Banimento + intangibilidade
e a persistencia da trilha em boss.
Stats
Decidir oficialmente como DES escala armas/skills de precisao e
como hibridas dual scaling entram no CombatMath sem
duplicar multiplicadores.
Progressao
Confirmar a proposta do ADR para ranks, niveis de unlock e
orcamento de 4-6 ativas/2-3 passivas antes de codificar as
arvores definitivas.
7. Ordem recomendada para retomada do Codex
Para preservar escopo e reduzir retrabalho, a recomendacao e nao implementar seis kits completos de uma vez. O
melhor proximo passo e transformar este handoff em contratos de classe e validar um piloto por familia de
complexidade:
1. Fechar fundacao de stats de precisao (DES) e a regra de recursos/intrinsecos de identidade.
2. Cavaleiro Runico: validar input de 3 runas, uma pequena amostra de formulas e o ciclo guarda -> carga -> contra-
runa.

## Página 10

RagRPG - E0 / Handoff de design
13/09/2026  |  Documento de consolidacao - nao substitui playtest/aceite numerico
3. Saqueador: validar traps autoativaveis, Reivindicar Presa, bleed/movespeed e rearme por kill.
4. Cacador de Espectros: validar trilha persistente, transformacao de flecha e as 3 traps.
5. Baluarte de Cerco e Devastador Astral: validar loops com kits menores antes de preencher progressao.
6. Geometra por ultimo entre os seis: implementar a linguagem depois que o pipeline de skill/targeting/area estiver
provado; começar com paredes e so depois triangulos.
GATE DE E0: O objetivo do proximo checkpoint nao deve ser “ter todas as skills”. Deve ser conseguir olhar para
20-30 segundos de gameplay e identificar sem tooltip qual hibrida esta sendo jogada, qual decisao ela esta
tomando e qual momento de gloria esta tentando construir.
8. Resumo executivo
O E0 saiu de uma matriz de nomes + duas skills assinatura e chegou a seis identidades do MVP com regras de familia,
loops, recursos, direcao de stats, progressao inicial, augments e linguagem visual. As duas identidades mais maduras
conceitualmente sao Cavaleiro Runico e Geometra; Cacador de Espectros e Saqueador tambem ganharam hooks muito
claros. Baluarte de Cerco tem um core funcional de tank de linha; Devastador Astral permanece como principal
candidato a mais uma rodada de design antes de congelar especificacao.
A regra mais importante para o Codex: implementar a interacao central primeiro e provar em playtest; skills, ranks,
numeros e augments entram depois. O valor das hibridas esta em produzir uma engine de personagem que nao existe
nas classes puras, nao em acumular efeitos tematicos.
