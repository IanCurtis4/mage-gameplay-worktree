# 56 híbridas — releitura v3

14/11/2026. Pedido do usuário: descrever as híbridas a partir das fichas das 16
classes estendidas ([EXTENDED_CLASS_SPECS.md](EXTENDED_CLASS_SPECS.md)). Substitui a
matriz v2 ([HYBRIDS_56_EXPLORATION.md](HYBRIDS_56_EXPLORATION.md)) como proposta de
trabalho. As seis híbridas do MVP, decididas no handoff de 13/09
([e00_hybrid_handoff_2026_09_13.md](references/e00_hybrid_handoff_2026_09_13.md)),
continuam como estão. Das seis, só a Geômetra está no jogo. Documento de design: não
altera contrato, catálogo nem runtime.

## Método

1. **Fusão de substantivos (handoff de 13/09).** A origem dá o objeto, o material e a
   postura; a afinidade dá o fenômeno que acontece com esse objeto. Cada híbrida
   precisa de **uma interação que só existe por causa da combinação**. "Classe A + duas
   skills de B" é critério de reprovação.
2. **Regras de família (handoff de 13/09):**
   - **Elementalista:** fogo, gelo e raio continuam presentes, reinterpretados no
     substantivo da outra classe.
   - **Bruxo:** toda híbrida mantém DoT e invocação. Com o Demonólogo, a entidade vem
     primeiro; com o Necromante, a aflição prepara a morte e o servo nasce dela.
   - **Caçadora:** se tirar as armadilhas e a classe ficar quase igual, falhou.
   - **Assassino:** ocultação, entrada, golpe pelas costas e a decisão de executar ou
     sair precisam ser evidentes. A segunda classe muda como o golpe pelas costas é
     criado, não o substitui.
   - **Corpo a corpo + distância:** se uma das metades é corpo a corpo, o golpe
     principal termina perto; a parte à distância prepara, marca ou conduz.
3. **Regras novas desta rodada:**
   - **Demonólogo como afinidade traz o demônio**, não o adjetivo "contratado". A
     origem escolhe o arquétipo que faz sentido (às vezes só um dos três).
   - **Necromante como afinidade traz o ciclo morte → resto → uso**, não um esqueleto
     decorativo.
   - **Metamorfo como afinidade traz uma troca real de estado**, com custo e golpe de
     transição.
   - **Dervixe** é o novo arquétipo de vento, duelista e dançarino (14/11). As híbridas
     com ele foram reescritas.
4. **Arte das variantes (decisão do usuário em 14/11).** Uma variante de corpo que já existe
   (forma animal, demônio, servo) ganha **arte própria** quando carrega uma decoração fixa
   da outra classe: uma marca ou um elemento de identidade visual que a classe sempre mostra,
   como as marcas de contrato do Demonólogo. Se a outra classe não tem esse marcador fixo, a
   variante é feita **só em código** (cor, translucidez, brilho, sobreposições simples).
5. **Regra de equilíbrio das receitas.** Cada par de bases tem duas direções. Se uma
   direção usa o ramo A de uma base e o ramo B da outra, a direção inversa usa os dois
   ramos que sobraram. Assim, **cada estendida aparece em exatamente 7 híbridas** (uma
   por base parceira), e nenhuma fica de fora. É a mesma regra da matriz v2. O que
   muda é o critério de escolha: **afinidade temática**, não "2-1 com 2-1".

## Mudanças de receita em relação à v2

Só três pares mudaram de receita. Os três envolvem o Bruxo, que é onde a v2 estava
mais forçada:

| Par | v2 | v3 | Por quê |
|---|---|---|---|
| Espadachim ↔ Bruxo | Defendente + Demonólogo; Necromante + Berserker | **Berserker + Demonólogo; Necromante + Defendente** | A ferida alimentando uma matilha é a fusão natural; os restos virando escudo também. |
| Bruxo ↔ Druida | Demonólogo + Naturalista ("Jardineiro Infernal"); Metamorfo + Necromante | **Demonólogo + Metamorfo; Naturalista + Necromante** | Vestir o próprio demônio é a transformação certa para o vínculo; plantar em restos é o ciclo natural da podridão. |
| Bruxo ↔ Monge | Demonólogo + Elevado; Campeão + Necromante | **Demonólogo + Campeão; Elevado + Necromante** | Mestre e demônio golpeando em compasso é um dueto; erguer os mortos com a mente é o campo do Elevado. |

Nas demais, a receita da v2 foi mantida, e o conteúdo foi reescrito a partir das
fichas novas.

## Matriz

Legenda dos substantivos: Defendente **placa**, Berserker **ferida**, Elementalista
**energia**, Espiritualista **vestígio**, Sentinela **linha**, Caçadora **mecanismo**,
Sacerdote **halo**, Cultista **olho**, Demonólogo **vínculo**, Necromante
**podridão**, Naturalista **raiz**, Metamorfo **pelagem**, Assassino **sombra**,
Dervixe **vendaval**, Elevado **campo**, Campeão **ritmo**.

Cada linha traz o núcleo em uma ou duas frases. O aprofundamento (loop, sete skills,
visual, cinco perguntas) vem depois, em lotes.

### Origem Espadachim

| ID | Receita | Fusão | Nome | Núcleo |
|---|---|---|---|---|
| sp_mg | Defendente + Elementalista | placa + energia = inscrição | **Cavaleiro Rúnico** | MVP (handoff de 13/09): três runas formam fórmulas; bloquear gera Carga Rúnica. |
| sp_ar | Defendente + Sentinela | placa + linha = fortificação | **Bastião** | MVP: declara e protege uma linha; bloquear gera Pressão, que volta em represália pela linha. |
| sp_ac | Defendente + Sacerdote | placa + halo = consagração | **Paladino** | A guarda frontal projeta o Santuário à frente do escudo. Golpes recebidos de frente geram Graça, e o Juízo sai pelo escudo: aguentar de frente vira luz. |
| sp_br | Berserker + Demonólogo | ferida + vínculo = pacto de sangue | **Alfa** | Luta à frente de uma Matilha. As feridas que abre são o faro dos cães, e o HP que paga vai para o vínculo como Oferenda. Só o arquétipo Matilha. |
| sp_dr | Defendente + Naturalista | placa + raiz = baluarte vivo | **Silvano** | Planta a própria muralha: Muralha Mineral e Espinheiros à frente da guarda. Impactos frontais aceleram o crescimento das sementes. |
| sp_la | Defendente + Assassino | placa + sombra = abertura | **Duelista** | Um aparo perfeito gira o atacante e expõe as costas dele, dando Sentença. O Duelista não some; cria a abertura com a guarda. |
| sp_mo | Defendente + Elevado | placa + campo = impulso | **Inabalável** | A guarda absorve o impulso dentro do campo; projéteis bloqueados ficam suspensos e são devolvidos em cone. |

### Origem Mago

| ID | Receita | Fusão | Nome | Núcleo |
|---|---|---|---|---|
| mg_sp | Espiritualista + Berserker | vestígio + ferida = possessão | **Possesso** | MVP: possuído por espíritos, os ecos repetem a sequência de golpes. |
| mg_ar | Elementalista + Sentinela | energia + linha = geometria | **Geômetra** | MVP, implementada: vértices elementais formam paredes e triângulos. |
| mg_ac | Elementalista + Sacerdote | energia + halo = prisma votivo | **Taumaturgo** | O Santuário ganha um elemento: o fogo pune, o gelo protege, o raio acelera a Graça. Alternar elementos dentro do círculo transforma o Foco Prismático em Graça. |
| mg_br | Elementalista + Demonólogo | energia + vínculo = elemental contratado | **Invocador** | Os três arquétipos viram elementais: Bruto de gelo, Matilha de raio, Coro de fogo. Trocar de arquétipo é trocar de elemento, e a sequência de elementos passa pelo demônio. |
| mg_dr | Elementalista + Naturalista | energia + raiz = semente elemental | **Tempestário** | Sementes de fogo, gelo e raio: o raio salta entre flores pelas raízes, e a ordem em que as sementes amadurecem causa reações no território. |
| mg_la | Elementalista + Assassino | energia + sombra = lâmina oculta | **Lâmina Arcana** | O teleporte do Mago leva às costas da vítima. As toxinas viram fogo, gelo e raio, e a Ressonância completa na vítima carrega a Sentença. O golpe final é de perto. |
| mg_mo | Elementalista + Elevado | energia + campo = órbita | **Magister** | Esferas elementais orbitam no campo, e o campo curva a trajetória dos próprios feitiços. |

### Origem Arqueiro

| ID | Receita | Fusão | Nome | Núcleo |
|---|---|---|---|---|
| ar_sp | Caçadora + Berserker | mecanismo + ferida = armadilha brutal | **Saqueador** | MVP: luta dentro da própria rede, usando as armadilhas como impulso. |
| ar_mg | Caçadora + Espiritualista | mecanismo + vestígio = rastro | **Rastreador** | MVP: armadilhas deixam pó de alma, e as flechas que o atravessam ficam espectrais. |
| ar_ac | Sentinela + Sacerdote | linha + halo = julgamento | **Inquisidor** | A linha de tiro vira um corredor sagrado. Parado dentro do Santuário, gera Foco e Graça juntos; o tiro que atravessa o halo julga quem estiver na linha. |
| ar_br | Sentinela + Demonólogo | linha + vínculo = vigia contratada | **Mercenário** | O Bruto segura a frente para a Sentinela ficar parada gerando Foco; o vínculo divide o dano. O Tiro Perfurante que atravessa o demônio espalha a Marca do Credor pela linha. |
| ar_dr | Sentinela + Naturalista | linha + raiz = cobertura viva | **Patrulheiro** | Planta cobertura viva e Flores-cuspideiras na linha de tiro. Parado no território, gera Foco e acelera as sementes. |
| ar_la | Sentinela + Assassino | linha + sombra = tiro velado | **Emboscador** | O tiro saindo da ocultação marca e prende; o golpe final é de perto, entrando pelas costas (regra corpo a corpo + distância). |
| ar_mo | Sentinela + Elevado | linha + campo = trajetória dobrada | **Arqueiro Zen** | Flechas telecinéticas curvam a trajetória; ficar parado junta Calma e Foco numa só reserva, gasta num tiro de descarga. |

### Origem Acólito

| ID | Receita | Fusão | Nome | Núcleo |
|---|---|---|---|---|
| ac_sp | Cultista + Berserker | olho + ferida = êxtase da dor | **Flagelante** | Fere a si mesmo para ver mais: o HP pago vira Êxtase, e as feridas que abre nos inimigos acumulam Loucura. Corpo a corpo. |
| ac_mg | Cultista + Espiritualista | olho + vestígio = profecia | **Oráculo** | A Loucura deixa vestígios: o inimigo em Delírio repete com atraso os próprios golpes nos vizinhos. |
| ac_ar | Cultista + Caçadora | olho + mecanismo = armadilha do olhar | **Observador** | Ídolos-armadilha que disparam quando o inimigo olha para eles (ao adquirir alvo). A Loucura abre a presa. |
| ac_br | Sacerdote + Demonólogo | halo + vínculo = demônio subjugado | **Exorcista** | Prende um demônio dentro de um halo: o Santuário é a coleira. A cura excedente vai para o demônio pelo vínculo, e o Juízo é desferido por ele. |
| ac_dr | Sacerdote + Naturalista | halo + raiz = jardim sagrado | **Hierofante** | Sementes dentro do Santuário viram plantas de luz, e a Graça amadurece as sementes. |
| ac_la | Sacerdote + Assassino | halo + sombra = sentença sagrada | **Executor** | O Selo de Luz marca o condenado; o Executor some num véu de luz e entra pelas costas. A Sentença cai como Juízo. |
| ac_mo | Sacerdote + Elevado | halo + campo = mantra | **Asceta** | O campo do Elevado é o próprio Santuário; a Calma vira Graça, e a palma de luz golpeia à distância. |

### Origem Bruxo

| ID | Receita | Fusão | Nome | Núcleo |
|---|---|---|---|---|
| br_sp | Necromante + Defendente | podridão + placa = baluarte de ossos | **Cavaleiro de Ossos** | Os restos viram placas: um paredão de ossos e carcaças à frente faz a guarda frontal. O dano que os servos absorvem vira token, e o token vira uma onda de podridão. |
| br_mg | Necromante + Espiritualista | podridão + vestígio = alma presa | **Lich** | Cada morto deixa um resto e um eco. Servos que acabam viram espectros temporários, e o Lich canaliza por um filactério. |
| br_ar | Necromante + Caçadora | podridão + mecanismo = cova | **Coveiro** | Restos viram armadilhas (covas) que abrem a presa e levantam um servo; carcaças servem de isca. |
| br_ac | Necromante + Cultista | podridão + olho = evangelho pútrido | **Arauto da Peste** | A Peste espalha Loucura; doentes em Delírio atacam os vizinhos e espalham a peste. Os mortos viram ídolos cadavéricos. |
| br_dr | Demonólogo + Metamorfo | vínculo + pelagem = encarnação | **Encarnado** | Não chama o demônio ao lado: veste-o. A barra de formas vira os três arquétipos (Bruto, Cão, Diabrete), e a vida passa entre a forma humana e a demoníaca pelo vínculo. |
| br_la | Demonólogo + Assassino | vínculo + sombra = cúmplice | **Sicário** | O demônio é o cúmplice: a Matilha chama a atenção enquanto o mestre some e entra pelas costas. A Marca do Credor e a Sentença são a mesma marca, e a Sentença que mata alimenta o demônio. |
| br_mo | Demonólogo + Campeão | vínculo + ritmo = dueto | **Domador** | Mestre e demônio golpeiam em compasso alternado: cada golpe no tempo, de um ou de outro, sobe uma Contagem comum; no 9, um golpe conjunto. Bruto ou Matilha. |

### Origem Druida

| ID | Receita | Fusão | Nome | Núcleo |
|---|---|---|---|---|
| dr_sp | Metamorfo + Berserker | pelagem + ferida = fera de guerra | **Dilacerador** | As formas acumulam feridas no alvo; cada troca de forma detona as cargas no golpe de entrada. |
| dr_mg | Metamorfo + Espiritualista | pelagem + vestígio = forma ancestral | **Ancestral** | Cada transformação deixa um eco da forma anterior, que repete o golpe de entrada dela; uma forma espectral atravessa inimigos. |
| dr_ar | Metamorfo + Caçadora | pelagem + mecanismo = presa preparada | **Predador** | O felino arma armadilhas de garra pelo caminho; a presa aberta recebe o bote com bônus. |
| dr_ac | Metamorfo + Cultista | pelagem + olho = forma impossível | **Aberração** | A forma animal vira algo que não deveria existir: o rugido dá Loucura, e o Êxtase alimenta o Instinto. |
| dr_br | Naturalista + Necromante | raiz + podridão = jardim dos mortos | **Semeador** | Sementes plantadas em restos crescem na hora e mais fortes. Dos restos brotam servos-planta temporários (invocação), e a Semente-Bomba solta pólen pútrido (DoT). |
| dr_la | Naturalista + Assassino | raiz + sombra = toxina oculta | **Envenenador** | Some dentro do próprio território; as sementes ocultas envenenam, e o golpe final é um espeto de pedra que sai nas costas da vítima. |
| dr_mo | Naturalista + Elevado | raiz + campo = pedra suspensa | **Geomante** | A pedra entra no campo: muralhas e espetos ficam suspensos e são arremessados; sementes orbitam. |

### Origem Ladino

| ID | Receita | Fusão | Nome | Núcleo |
|---|---|---|---|---|
| la_sp | Dervixe + Berserker | vendaval + ferida = dança rubra | **Sanguinário** | Cada vítima diferente recebe uma ferida; o vento cresce com as feridas abertas, e a Ciranda detona todas de uma vez. |
| la_mg | Dervixe + Espiritualista | vendaval + vestígio = miragem | **Ilusionista** | Os passos deixam ecos que repetem o corte com atraso; no Devaneio, os ecos dançam sozinhos. |
| la_ar | Dervixe + Caçadora | vendaval + mecanismo = picadeiro armado | **Guerrilheiro** | Joga armadilhas ao longo da dança; inimigo preso conta como vítima nova para o vento. |
| la_ac | Dervixe + Cultista | vendaval + olho = transe contagiante | **Lunático** | O giro espalha Loucura; o Devaneio do Dervixe e o Delírio dos inimigos se alimentam. |
| la_br | Dervixe + Necromante | vendaval + podridão = dança macabra | **Ceifador** | O vento leva a peste de vítima em vítima; os mortos levantam e seguem o rastro da dança. |
| la_dr | Dervixe + Metamorfo | vendaval + pelagem = dança feral | **Feral** | Cada troca de vítima pode ser uma troca de forma; o golpe de entrada conta como passo novo. |
| la_mo | Assassino + Elevado | sombra + campo = mão invisível | **Mentalista** | Puxa a vítima com a mente para fora do grupo e a encontra nas costas; a Calma substitui a ocultação. |

### Origem Monge

| ID | Receita | Fusão | Nome | Núcleo |
|---|---|---|---|---|
| mo_sp | Campeão + Berserker | ritmo + ferida = quebra | **Quebra-Montanhas** | A cada 3 da Contagem, uma carga de ferida; o Último Compasso detona todas. |
| mo_mg | Campeão + Espiritualista | ritmo + vestígio = eco do golpe | **Médium** | O fim da sequência é repetido por ecos, com atraso. |
| mo_ar | Campeão + Caçadora | ritmo + mecanismo = arremesso armado | **Peregrino** | Golpes no tempo arremessam o inimigo para armadilhas preparadas, que abrem a presa e sobem a Contagem. |
| mo_ac | Campeão + Cultista | ritmo + olho = transe marcial | **Abissal** | Cada número da Contagem dá Loucura; no 9, Desorientação garantida. |
| mo_br | Elevado + Necromante | campo + podridão = mortos suspensos | **Titereiro** | Ergue restos e servos no campo e os usa como projéteis e escudos; o colosso é montado no ar. |
| mo_dr | Campeão + Metamorfo | ritmo + pelagem = feras de pé | **Totêmico** | A cada 3 da Contagem, muda de forma antropomórfica (urso, felino, ave): meia-transformação, bípede e de mãos livres. |
| mo_la | Campeão + Dervixe | ritmo + vendaval = compasso de roda | **Dançarino** | A Contagem só sobe trocando de vítima no tempo certo: o rigor do Campeão com a roda do Dervixe. |

## Decisões sobre a matriz

Aprovadas pelo usuário em 14/11: a regra de equilíbrio com critério temático, as três
trocas de receita do Bruxo, os nomes provisórios e a ordem de aprofundamento (primeiro
as sete do Demonólogo). Os itens abaixo ficam como registro do que foi aprovado.

1. **Regra de equilíbrio e critério temático:** cada estendida em exatamente 7 híbridas,
   escolhidas por afinidade temática. De acordo?
2. **As três trocas de receita do Bruxo:** Alfa e Cavaleiro de Ossos,
   Encarnado e Semeador, Domador e Titereiro.
3. **Nomes:** os novos são provisórios. Algum que você queira trocar já?
4. **Ordem de aprofundamento** (loop, sete skills, visual e cinco perguntas, como no
   handoff): proposta de começar pelas **sete híbridas do Demonólogo**, depois as sete
   do Necromante, e então seguir por base de origem.

---

## Aprofundamento — as sete híbridas do Demonólogo

Matriz aprovada pelo usuário em 14/11. Formato do handoff de 13/09: núcleo, a
interação que só existe na combinação, loop, sete skills, o que vem da base, momento
de glória, atributos, visual, cinco perguntas e arte.

**Regras que valem para as sete:**
- **A biblioteca é a da base de origem.** A afinidade não dá as skills da outra classe
  (regra do E06, já aplicada na Geômetra). O demônio, o vínculo e a Marca do Credor
  precisam estar nas 7 skills exclusivas de cada híbrida.
- **Níveis de job:** 20 (entrada gratuita), 23, 25, 28, 31, 34 e 37; 5 ativas e
  2 passivas.
- **O demônio é sempre o mesmo personagem da família:** um arquétipo ativo por vez,
  sem tempo de vida, ligado ao mestre por um elo visível. A origem escolhe quais
  arquétipos fazem sentido.
- **Regra de família do Bruxo:** DoT e invocação presentes; a entidade vem primeiro, e
  a aflição a alimenta.
- **O demônio escala com o atributo principal da origem.** Por exemplo, ATQ corpo a corpo
  no Alfa e MATK no Invocador.
- **Tempo sem demônio é curto ou compensado** (observação do usuário em 14/11: classes de
  demônio ficam fracas demais sem ele). Toda queda ou sacrifício do demônio que deixe
  o mestre sozinho por mais que alguns segundos precisa de uma compensação mecânica
  durante a espera. A medida exata depende de playtest.

---

### Alfa (sp_br) — Espadachim → Bruxo

Receita: **Berserker + Demonólogo**. Fusão: ferida + vínculo = **pacto de sangue**.
Arquétipo: **só a Matilha**.

**Núcleo.** O Alfa luta à frente de uma matilha de cães demoníacos. As feridas que ele
abre são o faro dos cães, e o HP que ele paga vai direto para o vínculo.

**A interação que só existe aqui.** A ferida passa a ser compartilhada: **as mordidas
dos cães também acrescentam cargas** à ferida que o Alfa abriu, e quando o Alfa
detona a ferida, cada cão morde mais uma vez. O custo de HP do Berserker vira Oferenda
automática.

**Loop.** Chamar a Matilha → Ferida de Caça no alvo → os cães acumulam cargas mordendo
→ Pagamento em Sangue para pôr os cães em Fervor → Banquete da Matilha detona as
cargas → os cães saltam para o próximo ferido.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Chamado da Matilha** | ativa, entrada | Chama dois cães demoníacos permanentes. Um cão abatido volta depois de uma recarga. |
| 23 | **Sangue Compartilhado** | passiva | Parte do dano que o Alfa sofre vai para os cães. Os cães escalam com o ATQ corpo a corpo do Alfa. |
| 25 | **Ferida de Caça** | ativa | Golpe que abre a ferida e marca o alvo para a matilha (é a Marca do Credor). Mordidas no alvo ferido somam cargas, até três. |
| 28 | **Pagamento em Sangue** | ativa | Paga HP: os cães entram em Fervor, e o Alfa ganha ATQ corpo a corpo por alguns segundos. |
| 31 | **Faro de Sangue** | passiva | Os cães saltam sozinhos para o alvo ferido com menos vida; abate de alvo ferido cura o vínculo. |
| 34 | **Banquete da Matilha** | ativa | Detona as cargas da ferida: cada cão morde o alvo uma vez por carga, e uma fração do dano cura o vínculo. |
| 37 | **Caçada Rubra** | ativa | Por alguns segundos, um cão a mais, todos em Fervor, e cada golpe do Alfa num alvo ferido faz a matilha inteira atacar o mesmo alvo. |

**Da base Espadachim:** Fúria e Golpe Brutal continuam fortes; o Dash acompanha os cães.

**Momento de glória.** Caçada Rubra num grupo ferido: o Alfa corta, e a matilha inteira
salta junto, de alvo em alvo.

**Atributos.** FOR > VIT > AGI.

**Visual.**
- Silhueta inclinada e agressiva do Berserker, com um manto de pelagem escura nos
  ombros;
- cor: vermelho, marrom e preto, com carmim e amarelo-bile nos detalhes de contrato;
- material: ferro escuro, couro, corrente;
- VFX: correntes que saem do pulso do Alfa até as coleiras dos cães (o elo), as
  feridas acesas como brasa, e os cães acendendo juntos no Fervor.

**Cinco perguntas.**
- **Distância:** corpo a corpo.
- **Recurso:** cargas de ferida e HP.
- **Abrir e fechar:** abre com a Ferida de Caça; fecha com o Banquete.
- **Contra o chefe:** a matilha morde e soma cargas sem precisar de adds.
- **Fraqueza:** a exposição do Berserker, e dano em área que abate os cães.

**Arte.** O Cão demoníaco já existe. Falta o traje do Alfa (quatro vistas), as correntes
do elo e os efeitos de Banquete e Caçada.

---

### Invocador (mg_br) — Mago → Bruxo

Receita: **Elementalista + Demonólogo**. Fusão: energia + vínculo = **elemental
contratado**. Arquétipos: **os três, cada um com um elemento**.

**Núcleo.** Os três arquétipos viram elementais: o Bruto é de gelo, a Matilha é de raio
e o Coro é de fogo (decisão do usuário em 14/11: o raio combina com a agilidade e a
constância dos cães; o fogo, com a destruição dos diabretes). Trocar de arquétipo é trocar de elemento, e a sequência de
elementos da Elementalista passa pelo demônio.

**A interação que só existe aqui.** Os golpes do demônio **contam como golpes de
elemento** para a sequência do mestre no mesmo alvo. O mestre lança fogo, o Bruto de
gelo golpeia, o mestre lança raio: três elementos distintos, ressonância completa. Ao
ser trocado, o demônio que sai **explode no seu elemento**, e a troca vira parte do
combo.

**Loop.** Chamar o elemental da situação → marcar com a Marca Catalisadora → alternar o
elemento do mestre com o do demônio no mesmo alvo → trocar de arquétipo no pico (a
explosão de saída abre o próximo elemento) → Conjunção dispara a explosão tricolor →
Cataclismo no fim.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Pacto Elemental** | ativa, entrada | Chama um dos três elementais: Bruto de gelo (deixa lento quem o ataca), Matilha de raio (marca Eletrizado a cada mordida, saltos rápidos entre alvos) ou Coro de fogo (dano puro em área). Trocar substitui o atual, e o que sai explode no seu elemento. |
| 23 | **Afinidade do Pacto** | passiva | Os golpes do demônio contam como elemento para a sequência do mestre no mesmo alvo, e os do mestre para a do demônio. |
| 25 | **Marca Catalisadora** | ativa | A Marca do Credor guarda o elemento do primeiro golpe que o alvo recebe; um golpe de outro elemento detona uma reação (fogo + gelo = estilhaço, gelo + raio = condução, raio + fogo = sobrecarga). |
| 28 | **Oferenda Elemental** | ativa | Paga HP: o demônio entra em Fervor, e o elemento dele se intensifica (o Bruto congela, os cães encadeiam raios entre si, o Coro incendeia a área). |
| 31 | **Conjunção** | passiva | Três elementos distintos no mesmo alvo, vindos do mestre e do demônio, disparam uma explosão tricolor em área pequena. |
| 34 | **Sifão de Essência** | ativa | Tira HP do demônio para curar o mestre e devolve SP. |
| 37 | **Cataclismo** | ativa | Por alguns segundos, os três elementais aparecem juntos, mais fracos, atacando em sequência de fogo, gelo e raio; no fim, uma tríplice gigantesca. |

**Da base Mago:** Bola de Fogo, Lanças de Gelo e Relâmpago alimentam a sequência; o
Teleporte é a defesa.

**Momento de glória.** Uma troca de arquétipo no pico: o Bruto de gelo explode ao sair,
a Matilha de raio entra mordendo o alvo congelado, o mestre fecha com fogo, e a
Conjunção estoura.

**Atributos.** INT > DES > VIT.

**Visual.**
- Silhueta da Elementalista, com um tomo acorrentado de capa cristalina;
- cor: o azul, branco, vermelho e amarelo da Elementalista sobre o preto-tinta do pacto;
- VFX: o elo muda de cor com o elemento do demônio ativo; a explosão de saída na
  troca;
- **regra do handoff:** os elementais não podem ser só o demônio retingido. O Bruto de
  gelo ganha placas de cristal, os cães de raio têm a espinha e a juba em arcos
  elétricos violeta, e os diabretes de fogo têm a brasa tomando o corpo inteiro.

**Cinco perguntas.**
- **Distância:** média a longa.
- **Recurso:** SP, HP do vínculo e a sequência de elementos.
- **Abrir e fechar:** abre com o Pacto e a Marca; fecha com a Conjunção ou o Cataclismo.
- **Contra o chefe:** alternar elementos entre mestre e demônio no mesmo alvo.
- **Fraqueza:** conjuração exposta, e a recarga de troca pune a troca errada.

**Arte.** Falta o traje do Invocador (quatro vistas), as **três variantes elementais** dos
corpos de demônio (Bruto de gelo, Cão de raio, Diabrete de fogo, quatro vistas cada) e
os efeitos de troca, reação e Cataclismo. É a híbrida do Demonólogo que mais pede arte.
O usuário confirmou as três variantes em 14/11.

---

### Mercenário (ar_br) — Arqueiro → Bruxo

Receita: **Sentinela + Demonólogo**. Fusão: linha + vínculo = **vigia contratada**.
Arquétipos: **Bruto e Coro**. A Matilha fica de fora, porque arrastaria a luta para
longe da linha.

**Núcleo.** A Sentinela precisa ficar parada para gerar Foco, e o demônio existe para
garantir isso: o Bruto segura a frente, e o Coro observa os alvos e devolve Foco.

**A interação que só existe aqui.** O Tiro Perfurante que **atravessa o próprio
demônio** ganha brasa (DoT) e espalha a Marca do Credor por toda a linha. O dano que
quebraria a preparação de Foco vai para o demônio.

**Loop.** Chamar o Bruto (ou o Coro) → parar atrás dele e gerar Foco → Flecha do
Credor marca o alvo → Tiro Através pela linha do demônio → Sifão quando o Bruto aperta
→ Contrato de Execução no fim.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Vigia Contratada** | ativa, entrada | Chama o Bruto ou o Coro. |
| 23 | **Posto Protegido** | passiva | Parada e com o demônio por perto, parte do dano vai para o demônio, e ser atingida não reinicia a preparação de Foco. |
| 25 | **Flecha do Credor** | ativa | Tiro que aplica a Marca do Credor. Com o Bruto, o alvo só ataca o Bruto; com o Coro, cada acerto dos diabretes no alvo dá Foco. |
| 28 | **Tiro Através** | ativa | Tiro perfurante que, ao atravessar o próprio demônio, ganha brasa (DoT) e espalha a marca por todos os alvos da linha. Gasta Foco. |
| 31 | **Dívida de Foco** | passiva | Foco gasto em alvo marcado cura o demônio. |
| 34 | **Sifão de Vigília** | ativa | Tira HP do demônio para curar a Sentinela e gerar Foco. |
| 37 | **Contrato de Execução** | ativa | Por alguns segundos, o demônio vira um posto fixo (o Bruto se planta como muralha; o Coro forma uma linha de mira), e os tiros da Sentinela pela linha do demônio não gastam Foco. |

**Da base Arqueiro:** Mira Estendida e Flecha Perfurante continuam centrais.

**Momento de glória.** Contrato de Execução com o Bruto plantado: cada tiro atravessa o
demônio, acende em brasa e marca a fila inteira de inimigos.

**Atributos.** DES > INT > VIT.

**Visual.**
- A Sentinela de verde e azul-claro, com o arco envolvido por uma corrente e penas de
  flecha em brasa;
- VFX: a linha de tiro passa pelo demônio e muda de cor ao atravessá-lo; o elo é uma
  corrente esticada entre a Sentinela e o Bruto.

**Cinco perguntas.**
- **Distância:** longa.
- **Recurso:** Foco e HP do demônio.
- **Abrir e fechar:** abre com a Vigia e a Flecha do Credor; fecha com o Tiro Através ou
  o Contrato.
- **Contra o chefe:** o Bruto segura o chefe enquanto a Sentinela gera Foco.
- **Fraqueza:** se o demônio cair, a Sentinela fica exposta e perde a proteção do Foco.

**Arte.** Bruto e Diabrete já existem. Falta o traje (quatro vistas) e os efeitos do tiro
através e do posto.

---

### Exorcista (ac_br) — Acólito → Bruxo

Receita: **Sacerdote + Demonólogo**. Fusão: halo + vínculo = **demônio subjugado**.
Arquétipos: **os três**, todos presos por um halo.

**Núcleo.** O Exorcista não fez um pacto: capturou um demônio e o obriga a servir como
penitência. O halo no pescoço do demônio é a coleira, e o Santuário é a jaula onde ele
serve.

**A interação que só existe aqui.** A luz **fere e alimenta o demônio ao mesmo tempo**.
Dentro do Santuário, o demônio queima um pouco, mas cada dano que sofre ali vira Graça
para o Exorcista. A cura excedente do Exorcista vai para o demônio pelo vínculo, e o
Juízo sai pelas mãos do demônio.

**Loop.** Selo de Contenção prende um demônio → Círculo de Expiação: o demônio luta
dentro → o dano que ele sofre e a cura que sobra viram Graça → Juízo pelo Servo → se
a luta virar, Exorcismo sacrifica o demônio numa explosão de luz → no fim, Absolvição.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Selo de Contenção** | ativa, entrada | Chama um demônio de qualquer arquétipo, com um halo de luz no pescoço. |
| 23 | **Graça Partilhada** | passiva | A cura excedente do Exorcista vai para o demônio; o que passar do HP dele vira Graça. |
| 25 | **Círculo de Expiação** | ativa | O Santuário da família, com uma regra a mais: o demônio dentro queima um pouco, mas entra em Fervor, e os inimigos dentro queimam. |
| 28 | **Juízo pelo Servo** | ativa | Gasta a Graça: o demônio desfere o Juízo (o Bruto num golpe em área, os cães numa mordida radiante, o Coro numa rajada de luz). |
| 31 | **Expiação** | passiva | O dano que o demônio sofre dentro do Santuário gera Graça. |
| 34 | **Exorcismo** | ativa | Sacrifica o demônio: ele explode em luz, com dano alto em área e cura para o Exorcista. Chamar outro tem recarga longa, compensada pelo Vazio Consagrado (abaixo). |
| 37 | **Absolvição** | ativa | Por alguns segundos, o demônio é redimido: vira um ser de luz e ouro, imune ao Santuário, e cada golpe dele cura o Exorcista. |

**Vazio Consagrado (compensação sem demônio, proposta após a observação do usuário em
14/11).** Enquanto o Exorcista está sem demônio depois de um Exorcismo:
- o halo que prendia o demônio fica no próprio Exorcista;
- o Juízo é desferido por ele mesmo, com força total, e a Graça rende o dobro;
- cada Juízo reduz a recarga do Selo de Contenção.

Assim a espera vira uma fase própria, de Sacerdote puro, que encurta conforme ele joga
bem. A medida exata precisa de playtest.

**Da base Acólito:** Prece e Escudo Votivo alimentam a Graça; Luz Punitiva é o dano à
distância.

**Momento de glória.** O Exorcismo no momento em que o Exorcista está para cair: o
demônio explode em luz, cura o mestre e limpa o grupo em volta.

**Atributos.** INT > VIT > DES.

**Visual.**
- Silhueta ereta e simétrica do Sacerdote, com o cetro com aro na mão e uma corrente
  de luz presa a ele;
- cor: marfim e dourado sobre o preto-tinta do demônio;
- VFX: halo dourado no pescoço do demônio, elo de luz (não de corrente), o demônio
  queimando em dourado dentro do círculo; na Absolvição, o demônio fica dourado.

**Cinco perguntas.**
- **Distância:** curta a média, dentro do Santuário.
- **Recurso:** Graça e HP do demônio.
- **Abrir e fechar:** abre com o Selo e o Círculo; fecha com o Juízo pelo Servo ou o
  Exorcismo.
- **Contra o chefe:** o demônio segura o chefe dentro do círculo e gera Graça.
- **Fraqueza:** o Exorcismo deixa o Exorcista sem demônio até a recarga, mesmo com o Vazio
  Consagrado; fora do círculo, os dois são fracos.

**Arte.** Os demônios já existem; o halo-coleira e o dourado da Absolvição podem ser
desenhados em código. Falta o traje (quatro vistas) e os efeitos de Juízo pelo Servo e
Exorcismo.

---

### Encarnado (br_dr) — Bruxo → Druida

Receita: **Demonólogo + Metamorfo**. Fusão: vínculo + pelagem = **encarnação**.
Arquétipos: **os três, como formas do próprio mestre**.

**Núcleo.** O Encarnado não chama o demônio ao lado: veste-o. A barra de formas do
Metamorfo vira os três arquétipos, e o mestre luta como Bruto, como Cão ou como
Diabrete.

**A interação que só existe aqui (e a regra da invocação).** A família exige invocação.
Por isso a forma e a invocação **se alternam**:
- **na forma,** o HP do demônio vira uma camada sobre o HP do mestre;
- **ao sair da forma,** o demônio sai do corpo e luta ao lado por alguns segundos, com a
  força acumulada.

Vestir e soltar viram o ritmo da classe, que é a troca de forma do Metamorfo lida pelo
vínculo.

**Inatas aprimoradas na forma (decisão do usuário em 14/11).** Encarnado, o mestre usa a
habilidade inata do demônio numa versão mais forte do que a do demônio chamado:

| Forma | Inata do demônio chamado | Versão encarnada |
|---|---|---|
| Bruto | provoca os inimigos próximos de tempos em tempos | **provocação em área, sob comando, que também reduz o dano causado pelos inimigos atingidos** |
| Cão | salta no alvo aflito com menos vida | **salto em cadeia por até três alvos aflitos, consumindo a aflição de cada um para dano imediato** |
| Diabrete | disparos rápidos de brasa | **leque de brasas que espalha a Marca do Credor e a aflição para todos os atingidos** |

A inata encarnada ocupa a ação principal da forma (como o golpe de entrada do
Metamorfo), sem gastar slot do loadout.

**Loop.** Vestir o Bruto e segurar o grupo → a Possessão acumula → soltar o demônio, que
sai em Fervor e luta ao lado → nesse tempo, o mestre marca e aflige → vestir o Cão
para perseguir → no fim, Pacto Encarnado: forma e demônio ao mesmo tempo.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Encarnação** | ativa, entrada | Libera a barra de formas e a **forma do Bruto**, com a provocação em área encarnada. Sair de uma forma solta o demônio ao lado por alguns segundos. |
| 23 | **Pele Contratada** | passiva | Na forma, o HP do demônio é uma camada sobre o HP do mestre e é consumido primeiro. |
| 25 | **Forma do Cão** | ativa de forma | Libera a forma de Cão: rápida, corpo a corpo, com o salto em cadeia encarnado. |
| 28 | **Forma do Diabrete** | ativa de forma | Libera a forma de Diabrete: pequena e ágil, com o leque de brasas encarnado. |
| 31 | **Possessão** | passiva | O tempo na forma acumula cargas; ao soltar, o demônio sai em Fervor, mais forte quanto mais cargas. |
| 34 | **Marca do Credor** | ativa | A mesma marca da família, lida pela forma: o Bruto provoca, o Cão consome a aflição, o Diabrete espalha a marca. |
| 37 | **Pacto Encarnado** | ativa | Por alguns segundos, o mestre fica na forma e o demônio também aparece ao lado: os dois ao mesmo tempo. |

**Da base Bruxo:** Praga e Toque Debilitante funcionam na forma humana; o Pacto Vital
compete com a Possessão.

**Momento de glória.** Pacto Encarnado com o Bruto: o mestre vira muralha, e o próprio
Bruto aparece ao lado, os dois segurando a sala.

**Atributos.** VIT > INT > FOR.

**Visual.**
- Forma humana: o Bruxo com as cicatrizes de contrato tomando os braços;
- **nas formas, o mestre não pode ser idêntico ao demônio que ele chama.** Proposta: a
  forma usa o corpo do demônio com uma peça do Bruxo que fica visível (o capuz, a
  corrente do cinto, o amuleto de chifre);
- VFX: a transição sai em fumaça de enxofre, e o demônio solto sai do peito do mestre.

**Cinco perguntas.**
- **Distância:** corpo a corpo (Bruto e Cão) e curta (Diabrete).
- **Recurso:** a camada de HP do demônio e as cargas de Possessão.
- **Abrir e fechar:** abre vestindo; fecha soltando o demônio em Fervor.
- **Contra o chefe:** vestir para segurar, soltar para dobrar o dano.
- **Fraqueza:** quando o demônio está solto, o mestre está na forma humana, frágil.

**Arte.** Falta a forma humana (quatro vistas) e as **três formas do mestre** (variantes
dos corpos de demônio com a peça do Bruxo, quatro vistas cada), mais a transição.

---

### Sicário (br_la) — Bruxo → Ladino

Receita: **Demonólogo + Assassino**. Fusão: vínculo + sombra = **cúmplice**.
Arquétipo: **só a Matilha**.

**Núcleo.** O demônio é o cúmplice. Enquanto os cães chamam a atenção, o mestre some e
entra pelas costas da vítima. A Marca do Credor e a Sentença são a mesma marca.

**A interação que só existe aqui.** A regra do Assassino diz que a segunda classe muda
*como* o golpe pelas costas é criado. Aqui, **as costas são criadas pelo demônio**: quem
ataca um cão vira as costas para o mestre. Uma Sentença que mata paga o demônio
(Oferenda grátis) e devolve a ocultação.

**Loop.** Chamar o Cúmplice → Marca da Cobrança na vítima → os cães a cercam e somam
Sentença → o mestre some, troca de lugar com um cão e aparece nas costas dela →
Sentença → se matou, o demônio é pago e o mestre volta a sumir → Cobrança Final no fim.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Cúmplice** | ativa, entrada | Chama a Matilha (dois cães). Os cães provocam a vítima marcada. |
| 23 | **Sombra do Demônio** | passiva | Um inimigo que ataca um cão perde o mestre de vista: o mestre fica oculto para ele. |
| 25 | **Marca da Cobrança** | ativa | A Marca do Credor que acumula Sentença: mordida dos cães +1, golpe do mestre pelas costas +2. |
| 28 | **Troca de Lugar** | ativa | O mestre troca de posição com um cão e aparece nas costas da vítima que o cão mordia. Conta como Emboscada. |
| 31 | **Dívida Paga** | passiva | Sentença que mata cura o vínculo, põe os cães em Fervor e devolve a ocultação ao mestre. |
| 34 | **Sentença** | ativa | O golpe final do mestre: gasta o acúmulo e é morte certa abaixo do limiar da categoria do inimigo (regra do Assassino); no chefe, dano muito alto. |
| 37 | **Cobrança Final** | ativa | Os cães prendem a vítima enquanto o mestre executa. Em grupo, cada cão marca uma vítima, e o mestre salta de uma para outra. |

**Da base Bruxo:** Praga na vítima mantém os cães em cima dela; Colheita é a cura.

**Momento de glória.** Cobrança Final num grupo: cada cão segura uma vítima, e o mestre
aparece nas costas de uma, depois de outra, depois de outra.

**Atributos.** INT > DES > AGI. A Sentença escala com MATK, porque o golpe é um
punhal de contrato carregado de maldição.

**Visual.**
- O Bruxo mais fino e encapuzado, com um punhal ritual preso ao tomo por uma
  corrente;
- cor: preto, cinza-chumbo e carmim;
- VFX: o mestre some numa fumaça de enxofre e reaparece no lugar do cão; a marca na
  vítima é uma marca de ferro que se enche com a Sentença.

**Cinco perguntas.**
- **Distância:** média (fora da vista) e corpo a corpo no golpe final.
- **Recurso:** Sentença na vítima e HP do vínculo.
- **Abrir e fechar:** abre com o Cúmplice e a Marca; fecha com a Sentença.
- **Contra o chefe:** os cães seguram a atenção do chefe, e o mestre entra pelas costas
  repetidas vezes.
- **Fraqueza:** sem cães, não há costas; o mestre é frágil exposto.

**Arte.** O Cão já existe. Falta o traje (quatro vistas), o punhal ritual (equipamento) e
os efeitos da troca de lugar e da marca.

---

### Domador (br_mo) — Bruxo → Monge

Receita: **Demonólogo + Campeão**. Fusão: vínculo + ritmo = **dueto**.
Arquétipos: **Bruto ou Matilha** (os dois de corpo a corpo).

**Núcleo.** Mestre e demônio lutam em compasso. O tempo certo do Campeão alterna entre
os dois, e cada golpe no tempo, de um ou de outro, sobe uma Contagem comum.

**A interação que só existe aqui.** A Contagem é **do vínculo, não de um corpo**. O
mestre dá toques curtos de maldição no tempo, e o demônio dá os golpes pesados no tempo
seguinte. No 9, os dois golpeiam juntos. Errar o tempo, de qualquer um dos dois, custa
metade da Contagem.

**Loop.** Chamar o parceiro → Toque em Compasso aplica aflição e chama o golpe do
demônio no tempo seguinte → alternar até 3, 6, 9 (Fervor a cada 3) → Troca de Passo
para reposicionar sem perder o tempo → Final a Dois no 9.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Dueto** | ativa, entrada | Chama o Bruto ou a Matilha e liga o ritmo compartilhado: o marcador de tempo alterna entre o mestre e o demônio. |
| 23 | **Compasso do Pacto** | passiva | Golpe no tempo, de qualquer um, sobe a Contagem; fora do tempo, ela cai pela metade. A cada 3, o demônio entra num Fervor curto. |
| 25 | **Toque em Compasso** | ativa | Toque curto de maldição: no tempo, aplica aflição e faz o demônio golpear o mesmo alvo no tempo seguinte. |
| 28 | **Troca de Passo** | ativa | Mestre e demônio trocam de lugar. Conta como golpe no tempo. |
| 31 | **Harmonia do Vínculo** | passiva | Cada número da Contagem reduz o custo de Oferenda e Sifão; no 9, o próximo Sifão é grátis. |
| 34 | **Oferenda Rítmica** | ativa | Paga HP: os próximos três golpes do demônio não saem do tempo. |
| 37 | **Final a Dois** | ativa | No 9, mestre e demônio golpeiam o mesmo alvo ao mesmo tempo, repetindo a sequência inteira num só impacto (o Bruto em área, a Matilha numa mordida múltipla). |

**Da base Bruxo:** Toque Debilitante é o gesto natural do mestre no compasso; Praga
mantém a aflição.

**Momento de glória.** O Final a Dois: depois de uma sequência perfeita, mestre e Bruto
golpeiam juntos, e a onda de choque leva a sala.

**Atributos.** INT > VIT > AGI.

**Visual.**
- O Bruxo com faixas de mão, como um parceiro de treino, e o demônio com faixas
  iguais;
- VFX: o marcador de tempo pula do mestre para o demônio e volta; os números da
  Contagem aparecem entre os dois, sobre o elo.

**Cinco perguntas.**
- **Distância:** curta (mestre) e corpo a corpo (demônio).
- **Recurso:** a Contagem comum e o HP do vínculo.
- **Abrir e fechar:** abre com o Toque em Compasso; fecha com o Final a Dois.
- **Contra o chefe:** chegar ao 9 com o Bruto segurando o chefe.
- **Fraqueza:** dois tempos para acertar em vez de um; perder o demônio quebra a
  sequência.

**Arte.** Bruto e Cão já existem. Pela regra de arte das variantes (item 4 do método), as
**variantes de Bruto e Cão com as faixas do Campeão** têm arte própria, porque as faixas são a
decoração fixa do Campeão. Falta também o traje (quatro vistas) e os efeitos do marcador
alternado e do Final a Dois.

---

### Resumo da arte das sete

| Híbrida | Demônio reaproveitado | Arte nova |
|---|---|---|
| Alfa | Cão | traje, correntes do elo |
| Invocador | nenhum direto | traje, **três variantes elementais** de demônio |
| Mercenário | Bruto, Diabrete | traje |
| Exorcista | os três (halo em código) | traje |
| Encarnado | os três, como base | traje, **três formas do mestre** |
| Sicário | Cão | traje, punhal ritual |
| Domador | Bruto, Cão | traje, variantes com faixas |

### Decisões do usuário sobre as híbridas do Demonólogo (14/11)

1. **Encarnado:** a alternância entre vestir e soltar o demônio fica. Na forma, o mestre
   usa **a inata do demônio aprimorada** (por exemplo, o Bruto encarnado provoca em área
   e reduz o dano dos inimigos).
2. **Invocador:** um elemento por demônio, com fogo e raio trocados em
   relação à proposta. **Bruto de gelo, Matilha de raio, Coro de fogo**, com as três
   variantes de arte.
3. **Exorcista:** o sacrifício fica, mas precisa de playtest. O usuário
   observou que classes de demônio ficam fracas demais sem ele. Daí o **Vazio
   Consagrado** e a regra geral de compensação, que vale para as sete.
4. **Recortes de arquétipo** aprovados como propostos.

---

## Aprofundamento — as sete híbridas do Necromante

Mesmo formato das híbridas do Demonólogo.

**Regras que valem para as sete** (da ficha do Necromante, aprovadas em 14/11):
- **Peste:** DoT que pula para os vizinhos quando o alvo morre e deixa um resto.
- **Restos:** carcaça e ossos no chão, com um pouco de gore estilizado. O chefe com Peste
  solta um resto a cada 10% de vida máxima perdida, no máximo dois por segundo.
- **Servos:** teto de servos ativos, cada um com tempo de vida; chefes nunca viram servos;
  morte de servo e DoT não geram cadeias infinitas de restos.
- **Parasitismo:** o servo é recurso. Ele pode ser consumido.
- **Regra de família do Bruxo:** DoT e invocação presentes em todas as sete.
- **Biblioteca da base de origem:** quando o Necromante é a afinidade (Semeador, Ceifador,
  Marionetista), a Peste, os restos e os servos vêm das sete skills exclusivas.

---

### Cavaleiro de Ossos (br_sp) — Bruxo → Espadachim

Receita: **Necromante + Defendente**. Fusão: podridão + placa = **baluarte de ossos**.

**Núcleo.** O Baluarte veste os mortos. Os restos viram placas de osso presas ao corpo,
e os servos guardam os flancos que a guarda frontal não cobre.

**A interação que só existe aqui.** O Defendente tem uma fraqueza declarada: o flanco. Aqui,
**os servos cobrem os flancos, e o Baluarte cobre a frente**. Os restos viram as placas que
fazem a guarda frontal; cada placa quebrada por um golpe de frente vira o token de guarda
do Defendente. A regra de corpo a corpo + distância se aplica: o Baluarte luta de perto,
com o cajado de ossos como maça.

**Loop.** Juntar restos com a Armadura de Restos → avançar com as placas à frente →
Escudeiros Mortos nos flancos → golpes de frente quebram placas e geram tokens → Onda
Pútrida gasta os tokens e espalha a Peste → as mortes deixam restos para novas placas.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Armadura de Restos** | ativa, entrada | Puxa os restos próximos e os prende ao corpo como placas de osso, até três. Cada placa absorve um golpe de frente e, ao quebrar, vira um token de guarda. |
| 23 | **Peste de Contato** | passiva | Golpe corpo a corpo do Baluarte aplica a Peste. |
| 25 | **Escudeiros Mortos** | ativa | Ergue até dois Ossudos que se postam nos flancos e interceptam os golpes vindos de lado ou de trás. Têm tempo de vida. |
| 28 | **Muralha de Carcaças** | ativa | Gasta dois restos para erguer à frente uma parede de ossos que bloqueia passagem e projéteis. Quem a ataca pega a Peste. |
| 31 | **Ossos Duros** | passiva | Cada placa ativa dá DEF e MDEF. Um escudeiro que morre no flanco vira placa. |
| 34 | **Onda Pútrida** | ativa | Gasta os tokens de guarda num pulso em volta que aplica a Peste e empurra. Cada servo ativo amplia o pulso. |
| 37 | **Ossário Ambulante** | ativa | Funde os servos e restos próximos numa armadura colossal sobre o próprio Baluarte: por alguns segundos, guarda frontal total e golpes em área. |

**Da base Bruxo:** Toque Debilitante é o golpe de perto natural; Colheita sustenta.

**Momento de glória.** Cercado, com escudeiros nos dois flancos e três placas na frente,
o Baluarte solta a Onda Pútrida e espalha a peste pela sala inteira.

**Atributos.** VIT > INT > FOR.

**Visual.**
- Silhueta pesada: o manto do Necromante coberto de placas de osso e costelas
  amarradas, como uma armadura;
- cor: marfim de osso, verde-musgo apodrecido, ocre e cinza de ferro;
- arma: o cajado de ossos, usado como maça;
- VFX: placas que se prendem ao corpo e estalam ao quebrar; a parede de carcaças.

**Cinco perguntas.**
- **Distância:** corpo a corpo.
- **Recurso:** restos (placas) e tokens de guarda.
- **Abrir e fechar:** abre com a Armadura; fecha com a Onda Pútrida.
- **Contra o chefe:** os restos que o chefe solta viram placas. A decisão é usá-los na
  guarda ou na Muralha.
- **Fraqueza:** sem restos, sem placas; área que mata os escudeiros abre os flancos.

**Arte.** O Ossudo já existe. Falta o traje (quatro vistas) com as placas em três estágios
(sobreposições), a parede de carcaças e a Onda Pútrida.

---

### Lich (br_mg) — Bruxo → Mago

Receita: **Necromante + Espiritualista**. Fusão: podridão + vestígio = **alma presa**.

**Núcleo.** Cada morto deixa dois rastros: o corpo (o resto) e a alma (o eco). O Lich
guarda as almas num filactério e canaliza a partir delas.

**A interação que só existe aqui.** A **morte deixa um eco que repete o último dano nos
vizinhos**, a propagação da Espiritualista, agora movida pela Peste. E o servo que acaba
não some: **vira um espectro por alguns segundos**. Com isso, o servo é usado duas vezes,
o corpo e depois a alma.

**Loop.** Peste Ecoante → as mortes deixam resto e eco → Erguer Mortos → os servos que
acabam viram espectros → as almas vão para o Filactério → canalizar do Filactério →
Procissão Fúnebre solta as almas → no fim, Ascensão do Lich.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Peste Ecoante** | ativa, entrada | A Peste da família. Quando o alvo morre, além do resto, deixa um eco que repete o último dano recebido nos vizinhos, uma vez. |
| 23 | **Alma Presa** | passiva | Toda morte com Peste guarda uma alma no Filactério, até cinco. Cada alma guardada reduz um pouco o HP máximo do Lich. |
| 25 | **Erguer Mortos** | ativa | Levanta os restos como Ossudos. Quando um Ossudo acaba, vira um espectro que atravessa os inimigos e aplica a Peste por alguns segundos. |
| 28 | **Filactério** | ativa | Coloca o Filactério no chão. Perto dele, o Lich canaliza as almas guardadas: dano contínuo num alvo e cura. |
| 31 | **Foco da Morte** | passiva | Uma canalização completa aumenta em um o limite de servos até o próximo Erguer. |
| 34 | **Procissão Fúnebre** | ativa | Solta as almas do Filactério como uma procissão de espectros, um impacto por alma. |
| 37 | **Ascensão do Lich** | ativa | Custa uma fração do HP máximo. Por alguns segundos, o Lich fica espectral: atravessa os inimigos, aplica a Peste em quem atravessa, e cada morte ergue um servo na hora, sem precisar de resto. |

**Filactério e retorno (decisão do usuário em 14/11).** Se o Lich cair com almas guardadas
e o Filactério inteiro, volta com uma fração da vida, **uma vez por luta de chefe**. O
usuário aprovou com uma condição: outras mecânicas da classe devem pôr o Lich em mais
risco que o normal, para justificar o retorno. Proposta:
- **a vida fica fora do corpo:** cada alma guardada no Filactério reduz um pouco o HP
  máximo do Lich. Quanto mais seguro o retorno, mais frágil o corpo;
- **o Filactério é um alvo:** tem HP próprio e atrai os inimigos próximos. Se for destruído,
  as almas se perdem e não há retorno;
- **a canalização prende o Lich** perto do Filactério e parado;
- **a Ascensão custa HP:** uma fração do HP máximo ao ser ativada.

**Da base Bruxo:** Praga e Colheita somam aflição e sustento; Pacto Vital paga a canalização.

**Momento de glória.** A Ascensão no meio de um grupo doente: o Lich atravessa todos,
e cada um que cai já se levanta como servo.

**Atributos.** INT > DES > VIT.

**Visual.**
- Silhueta alta e curvada, com o manto rasgado do Necromante e véus pálidos da
  Espiritualista;
- cor: verde-musgo e ocre do corpo, branco-prata do espírito;
- o Filactério: uma lanterna de osso com uma chama pálida, que se enche com as almas;
- VFX: o eco que sai do corpo na morte, os espectros translúcidos (versão pálida do
  Ossudo), a procissão.

**Cinco perguntas.**
- **Distância:** média a longa.
- **Recurso:** restos, almas no Filactério e SP.
- **Abrir e fechar:** abre com a Peste; fecha com a Procissão ou a Ascensão.
- **Contra o chefe:** os restos do chefe viram servos, e os servos viram espectros. A
  decisão é gastar as almas na Procissão ou guardá-las no Filactério.
- **Fraqueza:** corpo frágil enquanto há almas guardadas; a canalização prende o Lich
  perto do Filactério; destruir o Filactério perde as almas e o retorno.

**Arte.** O Ossudo já existe; o espectro pode ser a versão pálida dele, em código. Falta o
traje (quatro vistas), o Filactério (objeto), o eco da morte e a Procissão.

---

### Coveiro (br_ar) — Bruxo → Arqueiro

Receita: **Necromante + Caçadora**. Fusão: podridão + mecanismo = **cova**.

**Núcleo.** O Coveiro transforma os restos em armadilhas. Uma cova armada
sobre um resto abre a presa e levanta um servo que a agarra.

**A interação que só existe aqui.** A regra da Caçadora exige que as armadilhas sejam
evidentes. Aqui, **a armadilha nasce do resto e produz o servo**:
- a cova armada sobre um resto fica mais forte e invisível;
- quando dispara, abre a presa (a abertura da Caçadora), aplica a Peste e solta uma mão
  de Ossudo que prende o alvo;
- **os servos exploram a abertura** como os tiros da Caçadora.

**Loop.** Cova Rasa sobre um resto → o inimigo pisa, a presa abre e um servo nasce →
os servos exploram a abertura → as mortes com Peste deixam restos → mais covas →
Exumação dispara todas de uma vez → no fim, Cemitério Desperto.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Cova Rasa** | ativa, entrada | Armadilha num ponto. Sobre um resto, arma na hora, fica invisível e mais forte. Ao disparar, abre a presa, aplica a Peste e uma mão de osso prende o alvo. |
| 23 | **Isca de Carcaça** | passiva | Restos atraem levemente os inimigos comuns próximos, que vão até eles. |
| 25 | **Erguer da Cova** | ativa | Toda cova disparada levanta um Ossudo temporário no lugar. Ativada, ergue os restos próximos de uma vez. |
| 28 | **Exumação** | ativa | Dispara à distância todas as covas armadas. |
| 31 | **Coveiro** | passiva | Servos que atacam uma presa aberta causam dano extra, como os tiros de exploração da Caçadora. |
| 34 | **Campo de Sepulturas** | ativa | Planta várias covas em volta de um ponto, de uma vez. |
| 37 | **Cemitério Desperto** | ativa | Por alguns segundos, todo resto no campo vira uma cova armada, e toda morte cria uma nova cova. |

**Da base Bruxo:** Praga mantém a Peste viva nos alvos fora das covas; o Diabrete chama a
atenção para o caminho das covas.

**Momento de glória.** Exumação com o campo cheio: todas as covas disparam, e uma mão de
osso sai do chão sob cada inimigo.

**Atributos.** INT > DES > AGI.

**Visual.**
- Silhueta de coveiro: capuz, avental de couro sujo de terra, cordas e ganchos no cinto;
- cor: verde-musgo, ocre, marrom-terra e marfim;
- arma: o cajado de ossos com uma lâmina de pá na ponta;
- VFX: a terra que se abre, a mão de osso que agarra, a cova invisível marcada só por
  um leve afundamento no chão.

**Cinco perguntas.**
- **Distância:** média a longa.
- **Recurso:** restos, covas armadas e servos.
- **Abrir e fechar:** abre com a Cova; fecha com a Exumação ou o Cemitério.
- **Contra o chefe:** os restos que o chefe solta viram covas no caminho dele. A decisão
  é armar onde ele vai pisar.
- **Fraqueza:** tempo de preparação; chefes que não passam pelas covas.

**Arte.** O Ossudo já existe. Falta o traje (quatro vistas), a cova (prop no chão), a mão de
osso e o efeito da Exumação.

---

### Arauto da Peste (br_ac) — Bruxo → Acólito

Receita: **Necromante + Cultista**. Fusão: podridão + olho = **evangelho pútrido**.

**Núcleo.** O Profeta prega a doença como revelação. A Peste também traz Loucura, os
doentes em Delírio espalham a doença, e os que morrem se levantam como fiéis.

**A interação que só existe aqui.** A **Peste e a Loucura se alimentam**:
- quem tem Peste acumula Loucura mais rápido;
- quem está em Delírio passa a Peste para quem ataca;
- os mortos viram **ídolos cadavéricos** ou **fiéis** (servos).

O Êxtase do Cultista sobe a cada morte com Peste, e com ele o ônus de receber mais dano.

**Loop.** Evangelho Pútrido → os doentes acumulam Loucura → em Delírio, atacam os vizinhos e
espalham a Peste → as mortes viram restos → Ídolo Cadavérico ou Fiéis → o Êxtase sobe →
Sermão para acelerar o Delírio → no fim, Revelação Pútrida.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Evangelho Pútrido** | ativa, entrada | A Peste da família, que também acumula Loucura no alvo. |
| 23 | **Êxtase da Peste** | passiva | Cada morte com Peste dá Êxtase: mais MATK e menor custo, e mais dano recebido com Êxtase alto (o ônus do Cultista). |
| 25 | **Ídolo Cadavérico** | ativa | Consome um resto e ergue um ídolo de carcaça: os inimigos que olham para ele ganham Loucura e Peste. |
| 28 | **Fiéis** | ativa | Ergue os restos como Ossudos fiéis, que acumulam Loucura nos alvos que atacam. Têm tempo de vida. |
| 31 | **Contágio da Mente** | passiva | Inimigo em Delírio que ataca outro passa a Peste para ele. |
| 34 | **Sermão** | ativa | Cone de sussurros: em quem tem Peste, a Loucura sobe em dobro. |
| 37 | **Revelação Pútrida** | ativa | Um grande olho de carne se abre no campo: todos os doentes entram em Delírio (o chefe, em Desorientação), e cada morte vira um fiel na hora. |

**Da base Bruxo:** Toque Debilitante e Praga somam aflição; Pacto Vital paga o ônus do Êxtase.

**Momento de glória.** Revelação num grupo doente: os inimigos se atacam, passam a peste
entre si, caem e se levantam como fiéis do Profeta.

**Atributos.** INT > VIT > DES.

**Visual.**
- Silhueta assimétrica do Cultista, com o pano mortuário do Necromante;
- cor: magenta e turquesa doentio sobre verde-musgo e ocre;
- VFX: olhos que se abrem em manchas de podridão, o ídolo de carcaça, o grande olho de
  carne da Revelação.

**Cinco perguntas.**
- **Distância:** média.
- **Recurso:** Peste, Loucura e Êxtase.
- **Abrir e fechar:** abre com o Evangelho; fecha com a Revelação.
- **Contra o chefe:** a Desorientação abre janelas, e os restos do chefe viram ídolos e
  fiéis.
- **Fraqueza:** o ônus do Êxtase; contra um chefe sozinho, o Delírio não serve.

**Arte.** O Ossudo já existe. Falta o traje (quatro vistas), o ídolo cadavérico (objeto) e o
olho de carne da Revelação.

---

### Semeador (dr_br) — Druida → Bruxo

Receita: **Naturalista + Necromante**. Fusão: raiz + podridão = **jardim dos mortos**.

**Núcleo.** O Semeador planta nos mortos. Sementes plantadas em restos nascem maduras na
hora, e dos restos brotam servos de raiz e osso.

**A interação que só existe aqui.** A Naturalista espera o crescimento; o Necromante tem o
material. Aqui, **o resto é adubo**: semente plantada num resto nasce madura, e restos no
território aceleram todas as sementes. O ciclo fecha: a semente que seca vira resto.

**Loop.** Peste com a Flor-cadáver → as mortes deixam restos → Semente em Carne nos restos
(nascem maduras) → Carniçal de Raiz consome um resto e brota um servo → as sementes secas
viram restos → Jardim dos Mortos faz tudo brotar de uma vez.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Semente em Carne** | ativa, entrada | Planta um Espinheiro (a rede de raízes de espinho). Num resto, nasce maduro na hora. |
| 23 | **Adubo** | passiva | Restos no território aceleram as sementes próximas; o Semeador ganha a Seiva (DEF, MDEF e regeneração) perto das próprias sementes. |
| 25 | **Flor-cadáver** | ativa | Uma flor que cospe projéteis perfurantes em linha reta que aplicam a Peste. |
| 28 | **Carniçal de Raiz** | ativa | Consome um resto e faz brotar um servo de raízes e ossos, temporário, que prende quem o ataca. |
| 31 | **Ciclo** | passiva | Sementes que secam viram restos; restos consumidos devolvem SP. |
| 34 | **Bomba de Esporos** | ativa | Uma Semente-Bomba cuja nuvem de pólen pútrido aplica a Peste. |
| 37 | **Jardim dos Mortos** | ativa | Todos os restos no alcance brotam ao mesmo tempo: os pequenos viram Espinheiros maduros, e os maiores viram Carniçais. |

**Da base Druida:** Raízes segura os inimigos no jardim; Espeto de Pedra é o dano em alvo
único; Broto Restaurador é a cura. Muralha e Fissura são da Naturalista e não entram.

**Momento de glória.** Jardim dos Mortos num campo cheio de restos: o chão inteiro brota em
espinhos e carniçais de uma vez.

**Atributos.** INT > VIT > DES.

**Visual.**
- Silhueta baixa da Naturalista, com o manto de folhas apodrecidas e cogumelos;
- cor: verde-musgo apodrecido, marrom-terra, ocre e flores roxo-hematoma;
- arma: cajado de madeira morta, com raízes e ossos;
- VFX: sementes que nascem de carcaças, a flor-cadáver, a nuvem de pólen pútrido, os
  carniçais de raiz.

**Cinco perguntas.**
- **Distância:** média, dentro do território.
- **Recurso:** restos e sementes.
- **Abrir e fechar:** abre com a Flor-cadáver; fecha com o Jardim dos Mortos.
- **Contra o chefe:** os restos que o chefe solta nascem como sementes maduras em volta dele.
- **Fraqueza:** precisa de restos ou de tempo; fora do território, frágil.

**Arte.** Falta o traje (quatro vistas), as sementes e a flor-cadáver (variantes podres das
sementes da Naturalista), o Carniçal de Raiz (corpo novo, quatro vistas) e o Jardim.

---

### Ceifador (la_br) — Ladino → Bruxo

Receita: **Dervixe + Necromante**. Fusão: vendaval + podridão = **dança macabra**.

**Núcleo.** O vento do Ceifador leva a peste de vítima em vítima, e os mortos se levantam e
seguem o rastro da dança.

**A interação que só existe aqui.** O Dervixe sobe o vento trocando de vítima. Aqui, **cada
vítima diferente recebe a Peste**, e **os servos que acertam um inimigo diferente também
contam Passo** para o Ceifador. A dança deixa de ser solo. O parasitismo aparece na
Ciranda Macabra, que consome os servos em volta.

**Loop.** Passo da Peste atravessa a primeira vítima → cada vítima nova pega a Peste e sobe
o vento → as mortes viram restos → Dança dos Mortos ergue os servos, que seguem o rastro →
os acertos deles também sobem o vento → Ciranda Macabra consome os servos numa roda →
no fim, Dança Macabra.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Passo da Peste** | ativa, entrada | Avanço girando que atravessa o inimigo e aplica a Peste. Conta como Passo. |
| 23 | **Vento Pútrido** | passiva | Liga os Passos e os estágios do vento. Cada vítima nova pega a Peste, e no Vendaval o giro espalha a Peste em volta. |
| 25 | **Dança dos Mortos** | ativa | Ergue os restos próximos como Ossudos que seguem o rastro do Ceifador e atacam o que ele atravessa. Acertos dos servos em inimigos diferentes contam Passo. |
| 28 | **Ciranda Macabra** | ativa | Gasta um estágio de vento e consome os servos próximos numa roda de ossos e esporos, em área grande. |
| 31 | **Colheita no Giro** | passiva | Abate com Peste dá um Passo extra e devolve SP. |
| 34 | **Rajada de Esporos** | ativa | Um redemoinho de esporos à frente que aplica a Peste e puxa os inimigos levemente. |
| 37 | **Dança Macabra** | ativa | Por alguns segundos, todos os servos dançam junto com o Ceifador: cada vítima diferente de qualquer um conta Passo, e no fim todos os servos explodem em esporos. |

**Da base Ladino:** Corte Giratório e Salto Acrobático somam Passos; Veneno soma DoT.

**Momento de glória.** A Dança Macabra: o Ceifador e os mortos girando juntos pela sala, e no
fim a explosão de esporos.

**Atributos.** AGI > INT > SOR.

**Visual.**
- A silhueta aberta do Dervixe, com as sedas e as fitas apodrecidas e esfarrapadas;
- cor: cinza-esverdeado, ocre, marfim de osso e um vermelho escuro desbotado;
- arma: um **khopesh** (decisão do usuário em 14/11), uma espada de lâmina em gancho,
  como uma foice curta. É um tipo de equipamento novo;
- VFX: o vento carregando esporos, os servos girando no rastro.

**Cinco perguntas.**
- **Distância:** corpo a corpo, sempre em movimento.
- **Recurso:** vento (Passos), restos e servos.
- **Abrir e fechar:** abre com o Passo da Peste; fecha com a Ciranda ou a Dança Macabra.
- **Contra o chefe:** os lados diferentes do chefe contam Passo (regra do Dervixe), e os
  restos do chefe viram servos que dançam junto.
- **Fraqueza:** parar derruba o vento; os servos dependem de restos.

**Arte.** O Ossudo já existe. Falta o traje (quatro vistas), o khopesh (equipamento novo) e
os efeitos de vento com esporos e da Ciranda Macabra.

---

### Titereiro (mo_br) — Monge → Bruxo

Receita: **Elevado + Necromante**. Fusão: campo + podridão = **mortos suspensos**.

**Núcleo.** O Marionetista ergue os mortos com a mente. Os restos flutuam no campo e viram
projéteis e escudos, e os servos são marionetes que só se movem dentro do campo.

**A interação que só existe aqui.** O Elevado move o que existe; o Necromante produz o
material. Aqui, **cada resto é munição e escudo**, e o servo é uma **marionete**: mais forte
que o Ossudo comum, mas só age dentro do campo, porque é a mente do Marionetista que o
move. Um inimigo que morre suspenso deixa um resto já no ar, pronto para ser arremessado.

**Loop.** Fios da Mente arremessa um resto (Peste no impacto) → as mortes deixam restos →
os restos orbitam como escudo → Marionete ergue um servo controlado → Chuva de Ossos derruba
tudo o que está no ar → no fim, Colosso Suspenso.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Fios da Mente** | ativa, entrada | Ergue um resto no campo e o arremessa: o impacto aplica a Peste. |
| 23 | **Órbita Fúnebre** | passiva | Os restos dentro do campo orbitam o Marionetista e absorvem um golpe cada. |
| 25 | **Marionete** | ativa | Ergue um resto como um servo controlado pelo campo: mais forte que o Ossudo comum, mas só age dentro do campo. Tem tempo de vida. O limite de alcance é o preço do bônus (aprovado pelo usuário em 14/11). |
| 28 | **Chuva de Ossos** | ativa | Levanta todos os restos do campo e os derruba sobre uma área, com a Peste. |
| 31 | **Carne Suspensa** | passiva | Inimigos com Peste dentro do campo ficam lentos; quem morre ali deixa o resto já no ar. |
| 34 | **Escudo de Carcaças** | ativa | Os restos em órbita formam um escudo que bloqueia projéteis; quando acaba, são arremessados em volta. |
| 37 | **Colosso Suspenso** | ativa | Monta no ar, com todos os restos e servos do campo, um colosso que o Marionetista move com a mente por alguns segundos. |

**Da base Monge:** Poço Gravitacional junta os inimigos no campo; Respiração Contida dá o SP;
Pulso Mental é a defesa de perto.

**Momento de glória.** O Colosso Suspenso: ossos e carcaças da sala inteira se juntam no ar
num gigante movido pela mente do Marionetista.

**Atributos.** INT > DES > VIT.

**Visual.**
- A silhueta leve do Elevado, com o traje claro manchado de ocre e musgo;
- cor: branco e azul-violeta do Elevado sobre marfim de osso e verde-musgo;
- arma: o rosário flutuante, com contas de osso;
- VFX: fios violeta finos ligando a mente do Marionetista aos ossos e servos; restos
  orbitando; o colosso montado no ar.

**Cinco perguntas.**
- **Distância:** média, dentro do campo.
- **Recurso:** restos no campo e servos.
- **Abrir e fechar:** abre com os Fios da Mente; fecha com a Chuva de Ossos ou o Colosso.
- **Contra o chefe:** o chefe não é erguido (regra do Elevado), mas os restos que ele solta
  viram munição e escudo.
- **Fraqueza:** fora do campo, os servos param; sem restos, sem munição.

**Arte.** O Ossudo já existe (a marionete pode ser o Ossudo com os fios em código). Falta o
traje (quatro vistas), os fios e o Colosso Suspenso (corpo grande, ou montagem de restos
em código).

---

### Resumo da arte das sete

| Híbrida | Reaproveita | Arte nova |
|---|---|---|
| Cavaleiro de Ossos | Ossudo | traje com placas em três estágios, parede de carcaças |
| Lich | Ossudo (espectro em código) | traje, Filactério (objeto com HP) |
| Coveiro | Ossudo | traje, cova, mão de osso |
| Arauto da Peste | Ossudo | traje, ídolo cadavérico, olho de carne |
| Semeador | — | traje, sementes podres, **Carniçal de Raiz (corpo novo)** |
| Ceifador | Ossudo | traje, khopesh |
| Titereiro | Ossudo (fios em código) | traje, Colosso Suspenso |

Todas usam o **resto no chão** (carcaça e ossos, algumas variações), que é arte comum à
família.

### Decisões do usuário sobre as híbridas do Necromante (14/11)

1. **Cavaleiro de Ossos corpo a corpo** aprovado.
2. **Filactério do Lich fica:** o retorno é temático e não pesa no resto, desde que outras
   mecânicas ponham o Lich em mais risco que o normal. Daí o corpo mais frágil com
   almas guardadas, o Filactério como alvo e a Ascensão que custa HP.
3. **Ceifador com khopesh**, um tipo de arma novo.
4. **Marionete aprovada:** um limite de alcance justifica um bônus em outros aspectos.

---

## Aprofundamento — origens Espadachim e Mago

Oito híbridas. Pela regra de equilíbrio, as quatro de origem Espadachim usam o
**Defendente**, e as quatro de origem Mago usam a **Elementalista**. Cada uma precisa
reinterpretar o mesmo núcleo de um jeito próprio:
- **Espadachim:** o token de guarda (o golpe recebido de frente vira resposta);
- **Mago:** a regra da família (fogo, gelo e raio presentes, reinterpretados).

**Bibliotecas de origem (nomes do jogo):**
- **Espadachim:** Corte em cone, Investida, Parede de Escudos, Provocar, Perseverança,
  Grito Perfurante, Fúria, Golpe Brutal, Raiva Concentrada, Grito Aterrorizante,
  Resistência, Vigor e Sede de Sangue;
- **Mago:** Bola de Fogo, Parede de Fogo, Lança de Fogo, Lança de Gelo, Parede de Gelo,
  Teleporte, Relâmpago, Descarga Elétrica, Parede de Raios, Impacto das Almas, Assombro,
  Barreira Fantasma e Regeneração de SP.

---

### Paladino (sp_ac) — Espadachim → Acólito

Receita: **Defendente + Sacerdote**. Fusão: placa + halo = **consagração**.

**Núcleo.** O Paladino carrega o Santuário no escudo. A guarda frontal projeta um cone de
luz à frente, e o que ele aguenta de frente vira luz para punir.

**A interação que só existe aqui.** O **token de guarda vira Graça**. Cada impacto de frente
mitigado e cada cura que passa do HP máximo enchem a mesma reserva. O Juízo do Sacerdote
sai pelo escudo, como uma coluna de luz que desce no cone à frente.

**Loop.** Juramento ergue o cone de luz → os golpes de frente geram Graça → Selo do Condenado
prende um inimigo no cone → Impacto Consagrado gasta a Graça → Égide quando apertar → no
fim, Hora do Juramento.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Juramento** | ativa, entrada | Ergue o escudo e projeta um Santuário em cone à frente por alguns segundos: menos dano de frente para o Paladino, e os inimigos dentro queimam. |
| 23 | **Graça de Guarda** | passiva | Impacto frontal mitigado e cura excedente geram Graça, até cinco cargas. |
| 25 | **Impacto Consagrado** | ativa | Golpe de escudo que gasta a Graça: uma coluna de luz desce no cone à frente. O dano escala com as cargas. |
| 28 | **Égide do Juramento** | ativa | Um halo no corpo absorve dano; ao quebrar, solta um pulso de luz que empurra. |
| 31 | **Fé Inabalável** | passiva | Dentro do Juramento, controles duram menos, e a cura recebida rende mais. |
| 34 | **Selo do Condenado** | ativa | Um aro de luz se fecha sobre um inimigo: ele só pode atacar o Paladino, e todo dano de luz nele gera Graça. |
| 37 | **Hora do Juramento** | ativa | Por alguns segundos, o cone vira um círculo dourado completo: a Graça não tem limite, e o Impacto Consagrado não custa SP. |

**Da base Espadachim:** Parede de Escudos e Perseverança enchem a Graça; Provocar soma ao
Selo.

**Momento de glória.** Hora do Juramento cercado: todo golpe recebido vira luz, e cada
Impacto Consagrado desce uma coluna sobre o círculo inteiro.

**Atributos.** VIT > FOR > INT.

**Visual.**
- Silhueta de bloco do Defendente, ereta como a do Sacerdote;
- cor: prata e dourado, com azul-céu nos tecidos;
- material: aço polido, linho, vitral no escudo;
- arma: espada e escudo com um aro dourado gravado;
- VFX: o cone de luz no chão à frente do escudo; as cargas de Graça como pequenos aros
  girando sobre o elmo.

**Cinco perguntas.** Distância: corpo a corpo. Recurso: Graça. Abre com o Juramento; fecha
com o Impacto Consagrado. Contra o chefe, os golpes de frente do chefe enchem a Graça. Fraqueza:
o flanco, e chefes que atacam fora do cone.

**Arte.** Falta o traje (quatro vistas), o escudo com aro (equipamento) e os efeitos do cone e
da coluna.

---

### Silvano (sp_dr) — Espadachim → Druida

Receita: **Defendente + Naturalista**. Fusão: placa + raiz = **baluarte vivo**.

**Núcleo.** O Guardião planta a própria muralha. Ergue a pedra à frente da guarda e faz os
espinhos crescerem no caminho de quem avança.

**A interação que só existe aqui.** **Cada impacto de frente acelera o crescimento.** A
Naturalista espera as sementes crescerem; o Guardião as faz crescer apanhando. Quanto mais
o empurram, mais rápido a muralha sobe e os espinhos amadurecem.

**Loop.** Raiz de Guarda finca a muralha baixa à frente → os golpes de frente fazem ela
crescer → Espinheiro de Linha no caminho → Golpe de Raiz prende quem chega → Avanço
Enraizado leva a muralha adiante → no fim, Bastião de Gaia.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Raiz de Guarda** | ativa, entrada | Planta à frente uma muralha de pedra baixa que cresce em três estágios (baixa, bloqueia passagem, bloqueia projéteis). Impactos de frente aceleram o crescimento. |
| 23 | **Seiva de Guarda** | passiva | Perto das próprias plantas e pedras, DEF, MDEF e regeneração; cada impacto frontal mitigado cura um pouco. |
| 25 | **Espinheiro de Linha** | ativa | Planta uma faixa de raízes de espinho à frente: quem atravessa leva dano e fica lento. |
| 28 | **Golpe de Raiz** | ativa | Golpe que prende o alvo com raízes e acelera as sementes próximas. |
| 31 | **Floresta Viva** | passiva | Mais um no limite de sementes; sementes perto da muralha amadurecem mais rápido. |
| 34 | **Avanço Enraizado** | ativa | Avança com a muralha andando à frente e empurrando; deixa espinhos no caminho. |
| 37 | **Bastião de Gaia** | ativa | Por alguns segundos, tudo o que foi plantado amadurece, a muralha se abre em arco de fortaleza, e cada impacto de frente devolve espinhos. |

**Da base Espadachim:** Parede de Escudos acelera o crescimento; Provocar traz os inimigos
para os espinhos.

**Momento de glória.** Bastião de Gaia segurando uma horda: quanto mais apanha, mais a
fortaleza cresce e mais espinhos voltam.

**Atributos.** VIT > FOR > INT.

**Visual.**
- Silhueta de bloco, com placas de pedra e madeira viva no lugar do aço;
- cor: cinza-pedra, verde-musgo, marrom e flores pontuais;
- arma: espada e um escudo de pedra com raízes;
- VFX: a muralha subindo em estágios, as raízes de espinho, folhas a cada impacto.

**Cinco perguntas.** Distância: corpo a corpo. Recurso: o crescimento (impactos de frente) e
as sementes. Abre com a Raiz de Guarda; fecha com o Bastião. Contra o chefe, o chefe que
bate de frente faz a fortaleza crescer. Fraqueza: o flanco; precisa ficar no lugar.

**Arte.** Falta o traje (quatro vistas), o escudo de pedra e os efeitos da muralha em
estágios e do espinheiro.

---

### Duelista (sp_la) — Espadachim → Ladino

Receita: **Defendente + Assassino**. Fusão: placa + sombra = **abertura**.

**Núcleo.** O Duelista não some antes da luta: cria a abertura com a guarda. Um aparo no
tempo certo gira o atacante, expõe as costas dele, e o Duelista sai da vista do inimigo
por um instante.

**A interação que só existe aqui.** A regra do Assassino diz que a segunda classe muda *como*
o golpe pelas costas é criado. Aqui, **é o aparo que cria as costas e a ocultação**: o
inimigo aparado é girado e perde o Duelista de vista. A decisão de executar ou sair continua:
Sentença na hora, ou Recuo em Guarda para aparar de novo.

**Loop.** Aparo no golpe do inimigo → o inimigo é girado e perde o Duelista de vista →
Estocada pelas costas (Sentença +2) → Finta para forçar o próximo aparo → Riposte Fatal
quando a Sentença encher, ou Recuo em Guarda → no fim, Duelo.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Aparo** | ativa, entrada | Postura curtíssima: um golpe corpo a corpo de frente dentro da janela é aparado; o atacante é girado (costas expostas) e perde o Duelista de vista por um instante. |
| 23 | **Leitura do Oponente** | passiva | A Sentença no último aparado: aparo +2, golpe pelas costas +2, outros golpes +1. |
| 25 | **Riposte Fatal** | ativa | O golpe final: gasta a Sentença; é morte certa abaixo do limiar da categoria do inimigo (regra do Assassino); no chefe, dano muito alto. Se matar, o próximo Aparo é automático. |
| 28 | **Finta** | ativa | Passo lateral que puxa o golpe do inimigo para o lado: o próximo golpe dele conta como aparado. |
| 31 | **Guarda Paciente** | passiva | Sem atacar por alguns segundos em guarda, a janela de aparo aumenta. |
| 34 | **Recuo em Guarda** | ativa | Passo para trás mantendo a guarda; o inimigo perde o Duelista de vista de novo. É a saída. |
| 37 | **Duelo** | ativa | Por alguns segundos, todo golpe de frente é aparado automaticamente, e cada aparo devolve uma estocada pelas costas. |

**Da base Espadachim:** Investida para entrar; Corte em cone quando cercado.

**Momento de glória.** Um Duelo contra três inimigos: cada golpe que vem é aparado, girado e
respondido pelas costas.

**Atributos.** DES > AGI > FOR.

**Visual.**
- Silhueta esguia, com placa leve só no braço da guarda e uma capa escura;
- cor: prata, preto e um vermelho escuro;
- arma: espada fina e broquel;
- VFX: o brilho curto do aparo, o giro do inimigo, a marca da Sentença.

**Cinco perguntas.** Distância: corpo a corpo. Recurso: Sentença e a janela de aparo. Abre com
o Aparo; fecha com o Riposte Fatal ou o Recuo. Contra o chefe, aparar os golpes corpo a corpo
do chefe e entrar pelas costas. Fraqueza: projéteis e áreas não podem ser aparados.

**Arte.** Falta o traje (quatro vistas), o broquel (equipamento) e os efeitos do aparo e do
giro.

---

### Inabalável (sp_mo) — Espadachim → Monge

Receita: **Defendente + Elevado**. Fusão: placa + campo = **impulso**.

**Núcleo.** A guarda do Guardião não só bloqueia: guarda o impulso. Os golpes de frente viram
Ímpeto, os projéteis bloqueados ficam suspensos à frente do escudo, e tudo é devolvido de
uma vez.

**A interação que só existe aqui.** **O token de guarda vira impulso armazenado**, e o campo do
Elevado vira o espaço à frente do escudo. Um projétil bloqueado não some: fica parado no ar
e é arremessado de volta na Repulsão.

**Loop.** Guarda Vetorial → impactos de frente viram Ímpeto e projéteis ficam suspensos →
Puxão traz um inimigo para a frente do escudo → Repulsão Dirigida devolve tudo em cone → no
fim, Ponto Fixo.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Guarda Vetorial** | ativa, entrada | Guarda frontal que absorve: impactos de frente viram Ímpeto (até cinco), e projéteis bloqueados ficam suspensos à frente. |
| 23 | **Massa Inerte** | passiva | Com Ímpeto, o Guardião resiste a empurrões e controles, e ganha DEF. |
| 25 | **Repulsão Dirigida** | ativa | Gasta o Ímpeto numa onda em cone que empurra e fere, arremessando de volta os projéteis suspensos. |
| 28 | **Campo de Contenção** | ativa | Esfera curta em volta: inimigos comuns que entram ficam suspensos por um instante. |
| 31 | **Retorno** | passiva | Projéteis devolvidos causam dano proporcional ao Ímpeto gasto. |
| 34 | **Puxão** | ativa | Puxa um inimigo comum para a frente do escudo. No chefe, só o força a virar para o Guardião. |
| 37 | **Ponto Fixo** | ativa | Por alguns segundos, o Guardião não pode ser movido e absorve impulso de todas as direções; no fim, solta tudo numa onda em volta. |

**Da base Espadachim:** Parede de Escudos soma Ímpeto; Investida reposiciona.

**Momento de glória.** O fim do Ponto Fixo: todo golpe e todo projétil dos últimos segundos
voltam numa só onda.

**Atributos.** VIT > INT > FOR.

**Visual.**
- Silhueta de bloco, com contas e pequenas pedras flutuando em volta do escudo;
- cor: prata, branco e azul-violeta;
- arma: espada e um escudo liso, com runas de contenção;
- VFX: distorção do ar à frente do escudo, projéteis parados no ar, a onda de repulsão.

**Cinco perguntas.** Distância: corpo a corpo. Recurso: Ímpeto. Abre com a Guarda Vetorial;
fecha com a Repulsão. Contra o chefe, os golpes e projéteis do chefe viram munição. Fraqueza:
o flanco (exceto no Ponto Fixo); inimigos que não atacam não dão Ímpeto.

**Arte.** Falta o traje (quatro vistas) e os efeitos de projétil suspenso e da onda.

---

### Taumaturgo (mg_ac) — Mago → Acólito

Receita: **Elementalista + Sacerdote**. Fusão: energia + halo = **prisma votivo**.

**Núcleo.** O Santuário do Taumaturgo tem elemento. Um círculo de fogo pune, um de gelo
protege e um de raio acelera, e alternar os elementos dentro dele gera Graça.

**A interação que só existe aqui.** A **alternância de elementos vira Graça**. A Elementalista
é recompensada por alternar no mesmo alvo; o Taumaturgo é recompensado por alternar
**dentro do círculo**. O círculo, por sua vez, muda de regra conforme o elemento.

**Loop.** Círculo Votivo → o primeiro feitiço dentro define o elemento → alternar elementos
gera Graça → Mudança de Altar troca o elemento e solta um pulso do anterior → três elementos
em sequência deixam o círculo tricolor → Juízo Prismático → no fim, Aurora Convergente.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Círculo Votivo** | ativa, entrada | Um Santuário que toma o elemento do próximo feitiço lançado dentro dele: fogo (inimigos dentro queimam mais), gelo (DEF para o Taumaturgo e lentidão nos inimigos) ou raio (o SP se recupera mais rápido). |
| 23 | **Prisma Votivo** | passiva | Feitiço de elemento diferente do anterior, lançado de dentro do círculo, gera Graça. |
| 25 | **Refração Curativa** | ativa | Gasta a Graça: cura o Taumaturgo e solta uma onda do elemento atual do círculo. |
| 28 | **Mudança de Altar** | ativa | Troca o elemento do círculo na hora e solta um pulso do elemento antigo. |
| 31 | **Coro dos Elementos** | passiva | Três elementos diferentes lançados em sequência dentro do círculo o deixam tricolor por alguns segundos, com os três efeitos juntos. |
| 34 | **Juízo Prismático** | ativa | Gasta a Graça: uma coluna de luz cai sobre o alvo em três pulsos, de fogo, gelo e raio. |
| 37 | **Aurora Convergente** | ativa | Por alguns segundos, o círculo fica enorme e tricolor, a Graça não tem limite, e os feitiços dentro custam metade do SP. |

**Da base Mago:** Bola de Fogo, Lança de Gelo e Relâmpago alimentam a alternância; Barreira
Fantasma protege.

**Momento de glória.** Aurora Convergente: o círculo enorme e tricolor, com o Taumaturgo
alternando elementos sem custo e soltando Juízos.

**Atributos.** INT > VIT > DES.

**Visual.**
- Silhueta do conjurador, com uma túnica de vitral e detalhes dourados;
- cor: azul, branco, vermelho e amarelo da Elementalista, com o dourado do Sacerdote;
- arma: cajado com um aro e um prisma no centro;
- VFX: o círculo muda de cor com o elemento; tricolor no Coro e na Aurora.

**Cinco perguntas.** Distância: média, dentro do círculo. Recurso: Graça e SP. Abre com o
Círculo; fecha com o Juízo Prismático. Contra o chefe, alternar elementos dentro do círculo
no chefe. Fraqueza: sair do círculo perde tudo; conjuração exposta.

**Arte.** Falta o traje (quatro vistas), o cajado com prisma e os três estados do círculo.

---

### Tempestário (mg_dr) — Mago → Druida

Receita: **Elementalista + Naturalista**. Fusão: energia + raiz = **semente elemental**.

**Núcleo.** O Tempestário planta os elementos. Cada semente nasce do elemento do último
feitiço: o gelo vira espinheiro, o raio vira flor que cospe, o fogo vira bomba. As raízes
ligam as sementes e conduzem os elementos entre elas.

**A interação que só existe aqui.** Os três tipos de semente da Naturalista **casam com os três
elementos**: Espinheiro de gelo (lentidão), Flor de raio (projéteis perfurantes) e Bomba de fogo
(explosão). As **raízes condutoras** levam um elemento de uma semente para as vizinhas, e um
feitiço de outro elemento numa semente causa uma reação.

**Loop.** Lançar um elemento → Semente de Tempestade planta a semente dele → plantar uma rede
variada → Rega Elemental amadurece e causa reações → Tempestade Rasteira liga tudo → no fim,
Monção.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Semente de Tempestade** | ativa, entrada | Planta uma semente do elemento do último feitiço: gelo → Espinheiro de gelo (rede que deixa lento), raio → Flor de raio (projéteis perfurantes em linha reta), fogo → Bomba de fogo (explode por tempo ou ao ser atacada). |
| 23 | **Raízes Condutoras** | passiva | Sementes próximas ficam ligadas por raízes: o raio salta entre as ligadas, e o fogo se propaga para as bombas ligadas. |
| 25 | **Rega Elemental** | ativa | Lança o elemento atual sobre as sementes num raio: elas amadurecem na hora. Elemento diferente do da semente causa reação (fogo + gelo = vapor que cega, gelo + raio = condução que atordoa, raio + fogo = sobrecarga que explode). |
| 28 | **Muda de Estação** | ativa | Troca o elemento de todas as sementes no alcance, na ordem fogo → gelo → raio. |
| 31 | **Território Carregado** | passiva | Seiva (DEF, MDEF e regeneração) perto das sementes, e SP a cada reação. |
| 34 | **Tempestade Rasteira** | ativa | Uma linha de raízes elétricas pelo chão liga todas as sementes no caminho e atordoa por um instante quem pisa. |
| 37 | **Monção** | ativa | Uma chuva amadurece todas as sementes no alcance e faz cada uma reagir com as vizinhas, uma vez cada. |

**Da base Mago:** os feitiços da base definem a semente; Parede de Gelo e Parede de Fogo
fecham o território.

**Momento de glória.** A Monção num campo variado: espinhos de gelo, flores de raio e bombas de
fogo reagindo em cadeia pelas raízes.

**Atributos.** INT > DES > VIT.

**Visual.**
- Silhueta do conjurador, com manto de folhas e raízes com cristais;
- cor: verde da Naturalista, com azul, amarelo e vermelho dos elementos;
- arma: cajado de madeira viva com um cristal na ponta;
- VFX: as três sementes elementais, as raízes que brilham ao conduzir, a chuva da Monção.

**Cinco perguntas.** Distância: média, no território. Recurso: sementes e a ordem dos elementos.
Abre plantando; fecha com a Rega ou a Monção. Contra o chefe, plantar onde ele vai estar e
reagir com a Rega. Fraqueza: preparação; fora do território, frágil.

**Arte.** Falta o traje (quatro vistas), o cajado com cristal e as três sementes elementais
(variantes das sementes da Naturalista).

---

### Lâmina Arcana (mg_la) — Mago → Ladino

Receita: **Elementalista + Assassino**. Fusão: energia + sombra = **lâmina oculta**.

**Núcleo.** A Lâmina Arcana some dobrando a luz, aparece nas costas da vítima pelo
teleporte e a corta com uma lâmina de cristal que alterna os elementos.

**A interação que só existe aqui.** A ocultação é **luz refratada** (um prisma), e o golpe pelas
costas é criado pelo **teleporte do Mago**. As toxinas do Assassino viram os três elementos: a
lâmina alterna fogo, gelo e raio, e completar os três na vítima dá Sentença. Pela regra de
corpo a corpo + distância, o golpe final é de perto.

**Loop.** Marca Refratada na vítima → Refração (oculta) → Salto Prismático às costas → golpes
alternando os três elementos → Sentença Prismática → se matar, a Refração volta → no fim,
Espectro de Prisma.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Marca Refratada** | ativa, entrada | Marca a vítima: ela acumula Sentença e fica visível através de obstáculos. |
| 23 | **Lâmina Encantada** | passiva | Uma lâmina de cristal conjurada no cajado; os golpes corpo a corpo alternam fogo, gelo e raio. Os três na vítima dão +2 de Sentença e uma reação. |
| 25 | **Refração** | ativa | Ocultação por luz dobrada. O primeiro golpe ao sair dá +2 de Sentença. |
| 28 | **Salto Prismático** | ativa | Só oculto: teleporte às costas da vítima marcada. Conta como golpe pelas costas. |
| 31 | **Fratura de Luz** | passiva | Sentença que mata devolve a Refração e SP. |
| 34 | **Sentença Prismática** | ativa | Gasta a Sentença num golpe tricolor; morte certa abaixo do limiar da categoria do inimigo; no chefe, dano muito alto. |
| 37 | **Espectro de Prisma** | ativa | Três reflexos de cristal aparecem, um por elemento, e cada um repete o Salto Prismático numa vítima diferente: uma corrente de execuções. |

**Da base Mago:** Teleporte é a saída; Lança de Gelo segura a vítima de longe.

**Momento de glória.** Espectro de Prisma: três reflexos coloridos aparecem nas costas de três
vítimas ao mesmo tempo.

**Atributos.** INT > DES > AGI.

**Visual.**
- Silhueta fina e encapuzada, com uma capa que reflete a luz;
- cor: preto e cinza-chumbo, com os brilhos azul, vermelho e amarelo da lâmina;
- arma: o cajado da origem, com a lâmina de cristal conjurada na ponta (efeito, não
  equipamento; decisão do usuário em 14/11). O formato lembra um machado curvo ou uma
  alabarda de cristal;
- VFX: o personagem some num brilho de prisma; a lâmina muda de cor a cada golpe; reflexos de
  cristal no Espectro.

**Cinco perguntas.** Distância: média (oculta) e corpo a corpo no golpe final. Recurso: Sentença
e a sequência de elementos. Abre com a Marca e a Refração; fecha com a Sentença. Contra o chefe,
entrar pelas costas, alternar os elementos, sair com o Teleporte. Fraqueza: frágil exposta;
fraca contra grupos que a cercam.

**Arte.** Falta o traje (quatro vistas), a lâmina de cristal (efeito) e os efeitos de refração e
dos reflexos.

---

### Magister (mg_mo) — Mago → Monge

Receita: **Elementalista + Elevado**. Fusão: energia + campo = **órbita**.

**Núcleo.** O Tecelão faz os elementos orbitarem. Esferas de fogo, gelo e raio giram no campo
dele, e o campo curva a trajetória dos próprios feitiços na direção do alvo.

**A interação que só existe aqui.** O campo do Elevado **mexe nos feitiços da Elementalista, não
nos inimigos**: projéteis do Tecelão que passam pelo campo curvam para o alvo marcado, e as
esferas guardam elementos para soltar em ordem. A ordem das esferas conta para a ressonância
dos três elementos.

**Loop.** Lançar elementos → Esfera Orbital guarda cada um em órbita → Lançamento Orbital solta
as esferas na ordem certa → Compressão Astral junta o grupo e explode → Eclíptica faz os
feitiços darem uma volta antes de seguir → no fim, Constelação.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Esfera Orbital** | ativa, entrada | Cria uma esfera do elemento do último feitiço, que orbita o Tecelão (até três) e golpeia quem entra no campo. |
| 23 | **Gravidade Astral** | passiva | Projéteis do Tecelão que passam pelo campo curvam na direção do alvo marcado. |
| 25 | **Lançamento Orbital** | ativa | Dispara as esferas em sequência no alvo; a ordem dos elementos conta para a ressonância. |
| 28 | **Compressão Astral** | ativa | Puxa os inimigos comuns para o centro do campo e comprime as esferas numa explosão do elemento mais presente. |
| 31 | **Órbita Estável** | passiva | Sem receber dano por alguns segundos, as esferas giram mais rápido e o limite sobe para quatro. |
| 34 | **Eclíptica** | ativa | Por alguns segundos, o campo vira um anel largo onde os feitiços do Tecelão dão uma volta antes de seguir, acertando o grupo no caminho. |
| 37 | **Constelação** | ativa | As esferas viram três sóis, um de cada elemento, que disparam sozinhos em sequência por alguns segundos; no fim, colapsam numa tríplice. |

**Da base Mago:** Bola de Fogo, Lança de Gelo e Relâmpago definem as esferas; Teleporte
reposiciona o campo.

**Momento de glória.** Eclíptica com três esferas: cada feitiço gira pelo anel, atravessa o
grupo e só então segue para o alvo.

**Atributos.** INT > DES > AGI.

**Visual.**
- Silhueta leve do Elevado, com a túnica clara e detalhes cristalinos;
- cor: branco e azul-violeta, com as esferas azul, vermelha e amarela;
- arma: um cajado com um anel orbital no topo (a origem é Mago, então a arma é da família do
  Mago, não o rosário do Elevado);
- VFX: esferas em órbita, linhas de órbita no chão, feitiços curvando no campo.

**Cinco perguntas.** Distância: média, dentro do campo. Recurso: esferas e SP. Abre com as
esferas; fecha com o Lançamento ou a Constelação. Contra o chefe, curvar os feitiços no chefe e
soltar as esferas na ordem. Fraqueza: perde as esferas e a estabilidade ao receber dano.

**Arte.** Falta o traje (quatro vistas), o cajado com anel orbital e os efeitos das esferas e da
Eclíptica.

---

### Decisões do usuário sobre as origens Espadachim e Mago (14/11)

1. **As quatro de cada origem ficaram distintas:** o Defendente é a única classe só de
   defesa, e a Elementalista tem a tríade elemental, o que dá base para construções
   diferentes.
2. **Aparo do Duelista com janela de tempo** aprovado: aparos ritmados acrescentam
   dificuldade de execução.
3. **Lâmina Arcana:** lâmina de cristal conjurada no cajado, sem trocar de arma; o
   formato lembra um machado curvo ou uma alabarda.
4. **Tempestário:** semente definida pelo último elemento lançado, como está.

---

## Aprofundamento — origens Arqueiro e Acólito

Dez híbridas.
- **Origem Arqueiro:** as quatro usam a **Sentinela** e reinterpretam o Foco (a paciência
  parada que rende).
- **Origem Acólito:** três usam o **Cultista** (Flagelante, Oráculo, Vigia) e três o
  **Sacerdote** (Hierofante, Executor, Asceta).

**Bibliotecas de origem:**
- **Arqueiro (nomes do jogo):** Disparo Duplo, Flecha Perfurante, Chuva de Flechas, Mira
  Estendida, Flecha Entorpecente, Armadilha de Laço, Armadilha Explosiva, Abrigo de
  Folhagem, Precisão, Cadência e Técnica de Armadilhas;
- **Acólito (proposta de 14/11):** Luz Punitiva, Prece, Escudo Votivo, Selo Sombrio,
  Sussurro Perturbador e Devoção.

---

### Inquisidor (ar_ac) — Arqueiro → Acólito

Receita: **Sentinela + Sacerdote**. Fusão: linha + halo = **julgamento**.

**Núcleo.** O Santuário do Inquisidor é um corredor: uma faixa sagrada que vai da Inquisidora
até onde ela mira. Parada dentro, ela gera Foco e Graça ao mesmo tempo, e o tiro que atravessa
o corredor julga todos os que estão nele.

**A interação que só existe aqui.** A Sentinela precisa ficar parada; o Sacerdote é
recompensado por ficar no círculo. Aqui, **a paciência é prece**: no corredor, ser atingida não
reinicia a preparação do Foco, e a cura que sobra vira Graça que reforça o próximo tiro.

**Loop.** Corredor Sagrado → parada dentro, Foco e Graça sobem → Selo de Absolvição no alvo →
Flecha do Julgamento atravessa o corredor → Expurgo quando o corredor é invadido → no fim,
Sentença Celeste.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Corredor Sagrado** | ativa, entrada | Traça um Santuário em faixa longa à frente: dentro, a Inquisidora gera Foco mais rápido e recebe menos dano; inimigos que entram queimam. |
| 23 | **Vigília Devota** | passiva | Parada no corredor, a cura excedente vira Graça, e cada carga de Graça aumenta o dano do próximo tiro que gasta Foco. |
| 25 | **Flecha do Julgamento** | ativa | Gasta Foco: um tiro que atravessa o corredor inteiro; cada inimigo dentro recebe uma coluna de luz e perde um buff. |
| 28 | **Selo de Absolvição** | ativa | Marca um alvo: dano de luz nele gera Graça; se ele morrer, a Inquisidora se cura. |
| 31 | **Linha Inquebrantável** | passiva | Dentro do corredor, ser atingida não reinicia a preparação do Foco. |
| 34 | **Expurgo** | ativa | Gasta a Graça: o corredor pulsa, empurra os inimigos para fora pelas laterais e remove buffs. |
| 37 | **Sentença Celeste** | ativa | Por alguns segundos, o Foco gerado dobra, e cada tiro que atravessa o corredor inteiro ganha uma coluna de luz sem gastar Foco. |

**Da base Arqueiro:** Mira Estendida e Flecha Perfurante; Abrigo de Folhagem na saída.

**Momento de glória.** Sentença Celeste com o corredor cheio: cada tiro desce uma fila de colunas
de luz.

**Atributos.** DES > INT > VIT.

**Visual.**
- Silhueta da Sentinela, com um manto de linho e um símbolo dourado;
- cor: verde e azul-claro da Sentinela, com marfim e dourado;
- arma: arco com um aro dourado gravado;
- VFX: o corredor dourado no chão, colunas de luz em fila.

**Cinco perguntas.** Distância: longa, dentro do corredor. Recurso: Foco e Graça. Abre com o
Corredor; fecha com a Flecha do Julgamento. Contra o chefe, manter o chefe na linha do corredor.
Fraqueza: sair do corredor perde tudo; chefes que atacam de lado.

**Arte.** Falta o traje (quatro vistas), o arco com aro e os efeitos do corredor e das colunas.

---

### Patrulheiro (ar_dr) — Arqueiro → Druida

Receita: **Sentinela + Naturalista**. Fusão: linha + raiz = **cobertura viva**.

**Núcleo.** O Atirador planta a própria trincheira: arbustos que crescem e viram cobertura,
e flores que atiram junto com ela. O tempo parado gera Foco e faz o bosque crescer.

**A interação que só existe aqui.** **O tempo parado rende duas vezes**: gera o Foco da
Sentinela e faz as sementes crescerem. E **as flores atiram junto**: quando um tiro do Atirador
passa por uma flor dele, a flor dispara na mesma direção.

**Loop.** Cobertura Viva à frente → Flor de Mira na linha de tiro → parada, Foco e plantas sobem →
Flecha-raiz prende quem avança e planta espinhos → Florada amadurece tudo → no fim, Bosque
Atirador.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Cobertura Viva** | ativa, entrada | Planta um arbusto que cresce em três estágios; maduro, bloqueia projéteis inimigos e esconde levemente quem está atrás. |
| 23 | **Raízes da Paciência** | passiva | Parada perto das próprias plantas, gera Foco mais rápido, e as sementes amadurecem mais rápido. |
| 25 | **Flor de Mira** | ativa | Uma Flor-cuspideira que atira na direção do inimigo mais próximo; quando um tiro do Atirador passa por ela, ela dispara junto. |
| 28 | **Flecha-raiz** | ativa | A flecha finca raízes no impacto: prende o alvo por um instante e planta um Espinheiro ali. |
| 31 | **Seiva do Atirador** | passiva | Seiva (DEF, MDEF e regeneração) perto das próprias plantas. |
| 34 | **Florada** | ativa | Gasta Foco: amadurece na hora todas as plantas no alcance. |
| 37 | **Bosque Atirador** | ativa | Por alguns segundos, cada tiro do Atirador é repetido por todas as flores maduras na linha. |

**Da base Arqueiro:** Abrigo de Folhagem soma cobertura; Chuva de Flechas sobre quem está
preso nos espinhos.

**Momento de glória.** Bosque Atirador numa linha de flores: cada tiro sai multiplicado pelo
bosque inteiro.

**Atributos.** DES > INT > VIT.

**Visual.**
- Silhueta da Sentinela, com capuz de folhas e manto de musgo;
- cor: verde-folha, marrom-terra e o azul-claro da Sentinela;
- arma: arco de madeira viva com folhas;
- VFX: o arbusto em três estágios, a flor disparando junto, raízes no impacto.

**Cinco perguntas.** Distância: longa, no território. Recurso: Foco e plantas. Abre plantando;
fecha com a Florada ou o Bosque. Contra o chefe, plantar a linha antes do chefe chegar.
Fraqueza: preparação; plantas destruídas.

**Arte.** Falta o traje (quatro vistas), o arco de madeira viva, o arbusto em três estágios e a
flor.

---

### Emboscador (ar_la) — Arqueiro → Ladino

Receita: **Sentinela + Assassino**. Fusão: linha + sombra = **tiro velado**.

**Núcleo.** O Emboscador espera oculto, dispara um tiro velado que marca e prende a vítima e
depois cobre a distância para terminar de perto com uma faca de caça.

**A interação que só existe aqui.** Pela regra de corpo a corpo + distância, o tiro **prepara** e
o golpe final **termina perto**. A ocultação do Assassino vira a paciência da Sentinela: **oculto
e parado, o Foco sobe mais rápido**, e o Foco gasto no tiro velado vira Sentença na vítima.

**Loop.** Ocultar na Linha → oculto e parado, Foco sobe → Tiro Velado gasta Foco, marca e prende
→ Salto da Presa às costas da vítima → Sentença de Caça → se matar, volta a sumir → no fim,
Caçada Silenciosa.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Tiro Velado** | ativa, entrada | Só oculto: um tiro que marca a vítima e a prende por um instante. Gasta Foco: cada 20 de Foco gasto vira +1 de Sentença. |
| 23 | **Espreita** | passiva | Oculto e parado, gera Foco mais rápido; o primeiro tiro ao sair da ocultação dá +2 de Sentença. |
| 25 | **Ocultar na Linha** | ativa | Some (ocultação), deixando visível só para si a linha até a vítima marcada. |
| 28 | **Salto da Presa** | ativa | Salta pela linha até as costas da vítima marcada. Conta como golpe pelas costas. |
| 31 | **Faca de Caça** | passiva | Golpes corpo a corpo na vítima presa contam como pelas costas. |
| 34 | **Sentença de Caça** | ativa | Golpe de faca de perto: gasta a Sentença; morte certa abaixo do limiar da categoria do inimigo; no chefe, dano muito alto. Se matar, volta à ocultação. |
| 37 | **Caçada Silenciosa** | ativa | Por alguns segundos, cada abate devolve a ocultação, e o Tiro Velado não tem recarga. |

**Da base Arqueiro:** Abrigo de Folhagem soma ocultação; Armadilha de Laço segura a vítima.

**Momento de glória.** Caçada Silenciosa: tiro velado, salto, faca, some, e de novo, de vítima
em vítima.

**Atributos.** DES > AGI > SOR.

**Visual.**
- Silhueta da Sentinela encolhida, com capuz e capa escura;
- cor: verde-escuro, preto e um vermelho escuro;
- arma: arco escuro com uma faca de caça presa ao punho (parte do visual do arco, sem
  equipamento novo);
- VFX: a linha até a vítima, o salto pela linha, o brilho da faca.

**Cinco perguntas.** Distância: longa (preparo) e corpo a corpo (golpe final). Recurso: Foco e
Sentença. Abre com o Tiro Velado; fecha com a Sentença de Caça. Contra o chefe, sem abates,
repetir tiro, salto, faca e sair. Fraqueza: frágil exposto.

**Arte.** Falta o traje (quatro vistas), o arco com faca e os efeitos da linha e do salto.

---

### Arqueiro Zen (ar_mo) — Arqueiro → Monge

Receita: **Sentinela + Elevado**. Fusão: linha + campo = **trajetória dobrada**.

**Núcleo.** O Arqueiro Zen dobra as flechas com a mente. Elas contornam obstáculos até o alvo
marcado, e a serenidade parada vira um tiro único de força enorme.

**A interação que só existe aqui.** A Sentinela precisa de linha livre; o Elevado move o que existe.
Aqui, **a linha não precisa ser reta**: a flecha curva até o alvo. E a **Calma do Elevado e o Foco
da Sentinela viram uma só serenidade**: sobe parado e sem ser tocado, e cai ao ser atingido.

**Loop.** Flecha Guiada contornando a cobertura → serenidade parada → Flechas Suspensas no ar →
reativar e soltar todas → Desvio devolve um projétil → no fim, Flecha Interior com o Foco cheio.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Flecha Guiada** | ativa, entrada | A flecha curva até o alvo marcado, contornando obstáculos e inimigos no caminho. |
| 23 | **Mente Serena** | passiva | Parado e sem receber dano, o Foco sobe mais rápido; ser atingido tira Foco. |
| 25 | **Flechas Suspensas** | ativa | Dispara três flechas que ficam paradas no ar; ao reativar, todas voam até o alvo marcado. |
| 28 | **Campo de Mira** | ativa | Um campo em volta: projéteis inimigos que entram desaceleram, e o Arqueiro não pode ser empurrado. |
| 31 | **Respiração do Arco** | passiva | Com o Foco cheio, mais alcance e mais precisão. |
| 34 | **Desvio** | ativa | Agarra com a mente um projétil inimigo dentro do campo e o devolve. |
| 37 | **Flecha Interior** | ativa | Só com o Foco cheio: gasta todo o Foco e o SP numa flecha que atravessa tudo em linha, com dano enorme, depois de uma janela de exposição. |

**Da base Arqueiro:** Mira Estendida; Disparo Duplo enche as Flechas Suspensas.

**Momento de glória.** A Flecha Interior depois de uma luta inteira sem ser tocado: um tiro que
atravessa a sala.

**Atributos.** DES > INT > AGI.

**Visual.**
- Silhueta imóvel e ereta, com a túnica clara do Elevado sobre o equipamento da Sentinela;
- cor: branco, azul-violeta e o verde-claro da Sentinela;
- arma: arco liso, com contas penduradas;
- VFX: trajetórias curvas, flechas paradas no ar, a distorção do campo.

**Cinco perguntas.** Distância: longa. Recurso: Foco (serenidade). Abre com a Flecha Guiada;
fecha com a Flecha Interior. Contra o chefe, a Flecha Interior exige não ser tocado. Fraqueza:
ser atingido tira Foco.

**Arte.** Falta o traje (quatro vistas), o arco com contas e os efeitos das trajetórias e das
flechas suspensas.

---

### Flagelante (ac_sp) — Acólito → Espadachim

Receita: **Cultista + Berserker**. Fusão: olho + ferida = **êxtase da dor**.

**Núcleo.** O Flagelante se fere para ver mais. O HP que ele paga vira Êxtase, e as feridas que
abre nos inimigos viram Loucura.

**A interação que só existe aqui.** O Berserker paga HP pela Execução; o Cultista tem o Êxtase
com ônus. Aqui, **o HP pago é o combustível do Êxtase**, e **a ferida do Berserker vira Loucura**
quando detonada. A Prece da base é o que o mantém vivo.

**Loop.** Flagelo abre feridas e cobra um pouco de HP → Penitência para subir o Êxtase →
Revelação na Carne detona as feridas em Loucura → Delírio → Prece para se manter → no fim,
Êxtase Absoluto.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Flagelo** | ativa, entrada | Golpe de corrente que abre ferida no alvo e custa um pouco de HP ao Flagelante; o HP pago vira Êxtase. |
| 23 | **Êxtase da Dor** | passiva | O Êxtase sobe com o HP pago e com as cargas de ferida; com Êxtase alto, mais dano recebido (o ônus do Cultista). |
| 25 | **Penitência** | ativa | Fere a si mesmo: perde HP e ganha muito Êxtase; o próximo golpe aplica Loucura em dobro. |
| 28 | **Revelação na Carne** | ativa | Detona as feridas do alvo: cada carga vira Loucura; no limite, Delírio na hora. |
| 31 | **Mártir** | passiva | Com HP baixo, o Êxtase não cai, e os golpes acumulam mais Loucura. |
| 34 | **Procissão de Flagelos** | ativa | Um giro de corrente em área que fere todos em volta, inclusive o próprio Flagelante. |
| 37 | **Êxtase Absoluto** | ativa | Por alguns segundos, todo HP pago volta como dano em área, e os inimigos feridos entram em Delírio; no fim, cura parte do que foi pago. |

**Da base Acólito:** Prece e Escudo Votivo são a sobrevivência; Selo Sombrio e Sussurro somam
Loucura.

**Momento de glória.** Êxtase Absoluto com HP baixo: cada golpe que ele paga volta em dano, e o
grupo inteiro entra em Delírio.

**Atributos.** VIT > FOR > INT.

**Visual.**
- Silhueta curvada do Cultista, com tiras de pano e feridas na pele;
- cor: magenta e preto-azulado do Cultista com o vermelho da ferida;
- arma: o livro de orações preso a uma corrente, usado como mangual (sem equipamento novo);
- VFX: feridas que se abrem em olhos, sangue estilizado sem gore, a corrente em arco.

**Cinco perguntas.** Distância: corpo a corpo. Recurso: HP e Êxtase. Abre com o Flagelo; fecha
com a Revelação na Carne. Contra o chefe, a ferida funciona sem adds; o Delírio não, então o
Êxtase vira dano. Fraqueza: o próprio HP.

**Arte.** Falta o traje (quatro vistas), o livro acorrentado e os efeitos de ferida e corrente.

---

### Oráculo (ac_mg) — Acólito → Mago

Receita: **Cultista + Espiritualista**. Fusão: olho + vestígio = **profecia**.

**Núcleo.** O Oráculo vê o que vai acontecer de novo. A Loucura deixa vestígios: o inimigo em
Delírio repete com atraso os próprios golpes, e o Oráculo marca lugares onde o que aconteceu
vai se repetir.

**A interação que só existe aqui.** O eco da Espiritualista **sai do inimigo enlouquecido**: cada
golpe que um Delirante dá é repetido com atraso num vizinho. E a **Profecia** marca uma área onde
o dano do Oráculo se repete um segundo depois.

**Loop.** Visão do Eco acumula Loucura → Sussurro Coletivo liga as mentes → os Delirantes repetem
os próprios golpes → Profecia na área do grupo → Liturgia do Vazio canaliza na rede → no fim, O
Fim Previsto.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Visão do Eco** | ativa, entrada | Canalização de olhar: Loucura e marca de eco; o próximo golpe no alvo é repetido com atraso. |
| 23 | **Eco do Delírio** | passiva | Inimigo em Delírio repete com atraso cada golpe que dá, atingindo um vizinho. |
| 25 | **Profecia** | ativa | Marca uma área: um segundo depois, todo o dano que o Oráculo causou ali se repete. |
| 28 | **Sussurro Coletivo** | ativa | Liga as mentes de inimigos próximos: Loucura aplicada a um vai para todos os ligados. |
| 31 | **Vidente** | passiva | Uma canalização completa dá Êxtase extra. |
| 34 | **Liturgia do Vazio** | ativa | Canal sobre a rede de mentes: dano contínuo em todos os ligados. |
| 37 | **O Fim Previsto** | ativa | Por alguns segundos, todo dano do Oráculo se repete uma vez com atraso, e os ecos aplicam Loucura. |

**Da base Acólito:** Sussurro Perturbador e Selo Sombrio somam Loucura; Escudo Votivo protege a
canalização.

**Momento de glória.** O Fim Previsto numa rede de mentes: cada golpe acontece duas vezes, e o
grupo enlouquece por inteiro.

**Atributos.** INT > DES > VIT.

**Visual.**
- Silhueta do Cultista com véus pálidos da Espiritualista;
- cor: magenta e turquesa com branco-prata;
- arma: o relicário com olho, com um véu;
- VFX: ecos atrasados (imagens remanescentes) saindo dos inimigos, o círculo da Profecia, fios
  ligando as mentes.

**Cinco perguntas.** Distância: média. Recurso: Loucura e Êxtase. Abre com a Visão; fecha com a
Liturgia ou O Fim Previsto. Contra o chefe, a Profecia e o eco de golpes funcionam; o Delírio
não. Fraqueza: a canalização exige ficar parado; o ônus do Êxtase.

**Arte.** Falta o traje (quatro vistas) e os efeitos de eco, Profecia e rede de mentes.

---

### Observador (ac_ar) — Acólito → Arqueiro

Receita: **Cultista + Caçadora**. Fusão: olho + mecanismo = **armadilha do olhar**.

**Núcleo.** O Vigia arma ídolos que disparam quando são vistos. O inimigo que encara um ídolo
enlouquece, e a Loucura abre a presa como uma armadilha da Caçadora.

**A interação que só existe aqui.** A armadilha da Caçadora dispara com o pé; a do Vigia dispara
**com o olhar**: um inimigo que fica de frente para o ídolo, dentro do raio, a aciona. A regra de
frente e costas, criada nesta rodada, define o "olhar". A Loucura **abre a presa** para o
próximo ataque do Vigia.

**Loop.** Ídolo Armado no caminho → Olhar Fixo força um inimigo a encarar o ídolo → o ídolo
dispara, Loucura e presa aberta → ataque de exploração → Rede de Olhos encadeia os ídolos → no
fim, Panóptico.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Ídolo Armado** | ativa, entrada | Um ídolo-armadilha; dispara quando um inimigo fica de frente para ele dentro do raio: Loucura e presa aberta. |
| 23 | **Olho Vigilante** | passiva | O próximo ataque do Vigia numa presa aberta pela Loucura causa dano extra e dá Êxtase. |
| 25 | **Olhar Fixo** | ativa | Força um inimigo a virar para o ídolo mais próximo, o que dispara a armadilha e expõe as costas dele. |
| 28 | **Armadilha do Sussurro** | ativa | Uma armadilha de chão que, ao disparar, faz o inimigo ouvir o ídolo: Delírio curto. |
| 31 | **Paciência do Vigia** | passiva | Ídolos armados há mais tempo disparam mais forte. |
| 34 | **Rede de Olhos** | ativa | Liga os ídolos: um disparo faz todos os outros dispararem em quem estiver de frente para eles. |
| 37 | **Panóptico** | ativa | Por alguns segundos, todo inimigo à vista conta como olhando para todos os ídolos: tudo dispara em sequência. |

**Da base Acólito:** Sussurro Perturbador e Selo Sombrio; Escudo Votivo protege enquanto arma.

**Momento de glória.** Panóptico com a sala cheia de ídolos: todos disparam, e o grupo inteiro
enlouquece de uma vez.

**Atributos.** INT > DES > AGI.

**Visual.**
- Silhueta do Cultista com cordas, ganchos e pequenos ídolos pendurados no cinto;
- cor: magenta, turquesa doentio, marrom-escuro e verde-musgo;
- arma: o relicário com olho;
- VFX: o ídolo abrindo o olho ao disparar, linhas de olhar entre os ídolos.

**Cinco perguntas.** Distância: média. Recurso: ídolos armados e Loucura. Abre armando; fecha com
a Rede ou o Panóptico. Contra o chefe, o Olhar Fixo vira o chefe para o ídolo (a Loucura vira
Desorientação). Fraqueza: preparação; inimigos que não olham (de costas) não disparam.

**Arte.** Falta o traje (quatro vistas), o ídolo-armadilha (objeto) e os efeitos de olhar e de
disparo.

---

### Hierofante (ac_dr) — Acólito → Druida

Receita: **Sacerdote + Naturalista**. Fusão: halo + raiz = **jardim sagrado**.

**Núcleo.** O Santuário do Hierofante é um jardim. As sementes plantadas dentro crescem como
plantas de luz, e a Graça faz o jardim amadurecer.

**A interação que só existe aqui.** **A Graça vira crescimento.** O Sacerdote converte cura
excedente em dano; o Hierofante converte em amadurecimento das sementes, e as sementes
maduras viram colunas de Juízo na colheita.

**Loop.** Jardim Sagrado → plantar Espinheiro de Luz e Flor Votiva dentro → a cura excedente vira
Graça → gastar Graça amadurece o jardim → Colheita Sagrada vira tudo em colunas de luz → no
fim, Éden.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Jardim Sagrado** | ativa, entrada | Um Santuário em que as sementes crescem duas vezes mais rápido. O próprio círculo cresce em três estágios, e a cura dele aumenta a cada estágio. |
| 23 | **Graça Fértil** | passiva | A cura excedente vira Graça; gastar Graça amadurece as sementes dentro do círculo. |
| 25 | **Espinheiro de Luz** | ativa | Rede de espinhos dourados: dano de luz e lentidão; dentro do círculo, remove buffs. |
| 28 | **Flor Votiva** | ativa | Uma flor de luz que atira projéteis perfurantes em linha reta; cada acerto cura o Hierofante. |
| 31 | **Raiz Santa** | passiva | Seiva (DEF, MDEF e regeneração) dentro do círculo. |
| 34 | **Colheita Sagrada** | ativa | Consome as sementes maduras do círculo: cada uma vira uma coluna de Juízo sobre o inimigo mais próximo dela. |
| 37 | **Éden** | ativa | Por alguns segundos, o círculo cresce, tudo dentro amadurece na hora, e a Graça não tem limite. |

**Da base Acólito:** Prece e Escudo Votivo enchem a Graça; Luz Punitiva fora do jardim.

**Momento de glória.** Colheita Sagrada num jardim maduro: cada planta vira uma coluna de luz.

**Atributos.** INT > VIT > DES.

**Visual.**
- Silhueta ereta do Sacerdote com manto de folhas e flores brancas;
- cor: marfim, dourado e verde-folha;
- arma: o cetro com aro, com uma raiz enrolada;
- VFX: o círculo florescendo em estágios, plantas douradas, colunas na colheita.

**Cinco perguntas.** Distância: média, dentro do jardim. Recurso: Graça e sementes. Abre com o
Jardim; fecha com a Colheita. Contra o chefe, levar o chefe ao jardim e colher no pico. Fraqueza:
preparação; sair do jardim perde tudo.

**Arte.** Falta o traje (quatro vistas) e as plantas de luz (variantes douradas das sementes da
Naturalista).

---

### Executor (ac_la) — Acólito → Ladino

Receita: **Sacerdote + Assassino**. Fusão: halo + sombra = **sentença sagrada**.

**Núcleo.** O Executor marca o condenado com um selo de luz, some num véu, entra pelas costas e
cumpre a sentença com uma coluna de luz.

**A interação que só existe aqui.** A Graça do Sacerdote **vira Sentença**: oculto no véu, o
Executor se cura, e a cura que sobra se acumula como Sentença na vítima marcada. Proteger-se é
preparar a execução. Pela regra de corpo a corpo + distância, o golpe final é de perto.

**Loop.** Condenação marca e prende a vítima → Véu → oculto, a cura que sobra vira Sentença →
Passo do Julgamento às costas → Sentença Sagrada → se matar, o Véu volta → no fim, Juízo Final.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Condenação** | ativa, entrada | Um selo de luz na vítima: prende por um instante e a marca para a Sentença. |
| 23 | **Véu Penitente** | passiva | Oculto, o Executor regenera HP; a cura excedente vira Sentença na vítima. |
| 25 | **Véu** | ativa | Ocultação de luz; o primeiro golpe ao sair dá +2 de Sentença. |
| 28 | **Passo do Julgamento** | ativa | Só oculto: aparece nas costas da vítima marcada. Conta como golpe pelas costas. |
| 31 | **Ofício Sagrado** | passiva | Sentença que mata devolve o Véu e cura o Executor. |
| 34 | **Sentença Sagrada** | ativa | Gasta a Sentença: o golpe vem com uma coluna de luz; morte certa abaixo do limiar da categoria do inimigo; no chefe, dano muito alto e remoção de buffs. |
| 37 | **Juízo Final** | ativa | Por alguns segundos, cada inimigo à vista recebe um selo, e cada Sentença que mata leva o Executor direto à próxima vítima marcada. |

**Da base Acólito:** Prece soma Sentença pela cura excedente; Luz Punitiva de longe.

**Momento de glória.** Juízo Final: o Executor salta de condenado em condenado, uma coluna de luz
em cada.

**Atributos.** INT > DES > AGI.

**Visual.**
- Silhueta fina, encapuzada, com o linho do Sacerdote tingido de cinza;
- cor: marfim, cinza-chumbo e dourado;
- arma: o livro de orações com uma lâmina escondida na lombada (sem equipamento novo);
- VFX: o selo de luz sobre a vítima, o véu de luz que some, a coluna na execução.

**Cinco perguntas.** Distância: média (oculto) e corpo a corpo no golpe final. Recurso: Sentença e
o Véu. Abre com a Condenação; fecha com a Sentença Sagrada. Contra o chefe, sem abates: entrar,
acumular pela cura e executar. Fraqueza: frágil exposto.

**Arte.** Falta o traje (quatro vistas), o livro com lâmina e os efeitos do selo e do véu.

---

### Asceta (ac_mo) — Acólito → Monge

Receita: **Sacerdote + Elevado**. Fusão: halo + campo = **mantra**.

**Núcleo.** O Asceta não desenha o Santuário no chão: ele o carrega. O círculo sagrado é o próprio
campo do Elevado, que anda com ele, e a palma de luz golpeia à distância.

**A interação que só existe aqui.** O Santuário **se move**, e a **Calma vira Graça**: o tempo sem
ser tocado acumula Calma, e gastá-la conta como Graça. A Levitação ergue os inimigos dentro do
círculo sagrado, e a Queda vira colunas de luz.

**Loop.** Mantra liga o círculo ao corpo → sem ser tocado, a Calma sobe → Palma de Luz gasta e
empurra → Levitação Sagrada ergue o grupo → Queda Celeste derruba com colunas de luz → no fim,
Ascensão Celeste.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Mantra** | ativa, entrada | O Santuário fica preso ao corpo como um campo que anda junto, menor que o comum. |
| 23 | **Calma Sagrada** | passiva | Sem receber dano, acumula Calma; cada carga gasta conta como Graça. |
| 25 | **Palma de Luz** | ativa | Palma à distância num alvo dentro do campo: empurra e fere com luz; gasta Graça para ampliar. |
| 28 | **Levitação Sagrada** | ativa | Ergue os inimigos comuns dentro do campo; suspensos, recebem mais dano de luz. |
| 31 | **Mantra Suspenso** | passiva | Projéteis inimigos que entram no campo desaceleram e perdem força. |
| 34 | **Queda Celeste** | ativa | Derruba os suspensos com colunas de luz, em área. |
| 37 | **Ascensão Celeste** | ativa | Por alguns segundos, o Asceta flutua, o campo dobra de tamanho, e a Palma de Luz não custa SP. |

**Da base Acólito:** Prece e Escudo Votivo para não perder a Calma; Luz Punitiva fora do campo.

**Momento de glória.** Levitação e Queda Celeste: o grupo sobe e desce sob uma chuva de colunas
de luz.

**Atributos.** INT > VIT > DES.

**Visual.**
- Silhueta leve e flutuante, com o linho do Sacerdote e faixas do Monge;
- cor: marfim, dourado e azul-violeta;
- arma: o cetro com aro, com contas flutuando em volta;
- VFX: o círculo dourado que anda com ele, contas da Calma em órbita, colunas na Queda.

**Cinco perguntas.** Distância: média, dentro do campo. Recurso: Calma (que vira Graça). Abre com
o Mantra; fecha com a Queda Celeste. Contra o chefe, o chefe não é erguido; a Palma de Luz e a
Calma fazem o dano. Fraqueza: ser atingido derruba a Calma.

**Arte.** Falta o traje (quatro vistas) e os efeitos do círculo móvel e das colunas.

---

### Decisões do usuário sobre as origens Arqueiro e Acólito (14/11)

1. **Armas sem equipamento novo** aprovadas: faca presa ao arco (Emboscador), livro
   acorrentado como mangual (Flagelante) e livro com lâmina escondida (Executor).
2. **Olhar do Observador** aprovado. Além disso, funciona como uma forma nova de
   reposicionamento: virar o inimigo para o ídolo.
3. **Risco do Flagelante** na medida, como o usuário imaginava.
4. **Flecha Interior parecida com a Descarga Interior** aprovada: a preparação forte com
   dano enorme é uma característica marcante da família do Monge e pode reaparecer na
   híbrida.

---

## Aprofundamento — origens Druida e Ladino

Doze híbridas.

**Duas regras que pesam neste lote:**
- **A Druida base não se transforma.** As quatro híbridas com o Metamorfo trazem a barra de
  formas nas próprias skills exclusivas, e cada uma escolhe quais formas fazem sentido.
- **A origem Ladino não dá acesso às skills do Dervixe.** As cinco híbridas com o Dervixe
  trazem os Passos (vítima diferente, ou o mesmo inimigo por outro lado), o Vento (Brisa →
  Rajada → Vendaval) e a punição por parar numa passiva própria.

**Bibliotecas de origem (propostas de 14/11):**
- **Druida:** Raízes, Broto Restaurador, Espeto de Pedra, Pele de Urso, Garra Felina, Salto
  da Ave e Memória da Terra;
- **Ladino:** Punhalada, Veneno, Passo Sombrio, Ocultação, Corte Giratório, Salto Acrobático
  e Oportunismo.

---

### Dilacerador (dr_sp) — Druida → Espadachim

Receita: **Metamorfo + Berserker**. Fusão: pelagem + ferida = **fera de guerra**.
Formas: **urso e felino**.

**Núcleo.** O Dilacerador abre feridas em forma animal e as detona trocando de forma.

**A interação que só existe aqui.** **A troca de forma é a detonação**: o golpe de entrada da
forma nova consome as cargas de ferida do alvo. O Instinto do Metamorfo vira a ferida do
Berserker, guardada no alvo em vez de no corpo.

**Loop.** Forma do urso abre feridas → acumular até três cargas → trocar para o felino: o bote
detona as cargas → Rasgar mantém o sangramento → Banquete Selvagem cura → no fim, Frenesi
Primal.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Forma de Guerra** | ativa, entrada | Libera a barra de formas e o urso de guerra; os golpes em forma abrem ferida no alvo, até três cargas. |
| 23 | **Sangue Selvagem** | passiva | Em forma, com HP baixo, mais dano corpo a corpo. |
| 25 | **Forma do Felino de Guerra** | ativa de forma | Libera o felino na barra. |
| 28 | **Rasgar** | ativa | Lida pela forma: no urso, esmaga e soma duas cargas; no felino, rasga e deixa sangramento. |
| 31 | **Fúria Animal** | passiva | Trocar de forma com o alvo em três cargas detona a ferida no golpe de entrada da forma nova. |
| 34 | **Banquete Selvagem** | ativa | Consome as cargas do alvo e cura uma fração por carga. |
| 37 | **Frenesi Primal** | ativa | Por alguns segundos, trocar de forma não tem recarga, e cada troca detona as cargas do alvo. |

**Da base Druida:** Pele de Urso e Garra Felina ganham força nas formas certas; Raízes segura o
alvo.

**Momento de glória.** Frenesi Primal: urso, felino, urso, felino, e cada troca estoura uma
ferida.

**Atributos.** FOR > VIT > AGI.

**Visual.** As formas do Metamorfo com pintura de guerra vermelha (por cima da arte que já
existe); na forma humana, peles e o vermelho do Berserker.

**Cinco perguntas.** Corpo a corpo. Recurso: cargas de ferida e a recarga de troca. Abre com o
urso; fecha com a troca que detona. Contra o chefe, o loop não precisa de adds. Fraqueza: a
recarga de troca e o risco do HP baixo.

**Arte.** As formas já existem. Falta o traje humano (quatro vistas). A pintura vermelha nas
formas é feita em código: o Berserker não tem uma decoração fixa que precise aparecer no
animal.

---

### Ancestral (dr_mg) — Druida → Mago

Receita: **Metamorfo + Espiritualista**. Fusão: pelagem + vestígio = **forma ancestral**.
Formas: **as três, em versão espectral**.

**Núcleo.** As formas do Ancestral são espíritos de animais antigos. Cada forma que ele
deixa fica para trás como um eco, que repete o golpe de entrada dela.

**A interação que só existe aqui.** **Sair de uma forma deixa um eco dela.** O vestígio da
Espiritualista vira a memória da forma anterior: trocar de urso para felino deixa um urso
espectral que ruge com atraso.

**Loop.** Urso ancestral → trocar para o felino: o eco do urso ruge → trocar para a ave: o eco do
felino dá o bote → Uivo das Almas faz todos os ecos repetirem → no fim, Manada de Espíritos.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Forma Ancestral** | ativa, entrada | Libera a barra de formas e o urso ancestral. Sair de uma forma deixa um eco dela que repete o golpe de entrada com atraso. |
| 23 | **Memória da Manada** | passiva | Os ecos de forma duram mais e marcam o alvo como a Maldição do Eco: o próximo golpe nele ecoa. |
| 25 | **Forma do Felino Ancestral** | ativa de forma | Libera o felino ancestral. |
| 28 | **Forma da Ave Ancestral** | ativa de forma | Libera a ave ancestral. |
| 31 | **Pelagem Translúcida** | passiva | Em forma, atravessa os inimigos ao se mover, e o primeiro golpe recebido é reduzido. |
| 34 | **Uivo das Almas** | ativa | Grito que reduz o dano causado pelos inimigos em volta e faz todos os ecos ativos repetirem o golpe. |
| 37 | **Manada de Espíritos** | ativa | Por alguns segundos, os ecos ficam e lutam: até três (urso, felino e ave) junto do Metamorfo. |

**Da base Druida:** os aspectos combinam com as formas; Broto Restaurador é a cura.

**Momento de glória.** Manada de Espíritos: o Metamorfo e os três espíritos ancestrais lutando juntos.

**Atributos.** INT > AGI > VIT.

**Visual.** As formas que já existem, pálidas e translúcidas (em código); na forma humana, a
pintura corporal em branco-prata e véus.

**Cinco perguntas.** Corpo a corpo, com ecos em volta. Recurso: ecos e a recarga de troca. Abre com
a primeira forma; fecha com o Uivo ou a Manada. Contra o chefe, os ecos repetem golpes no chefe.
Fraqueza: os ecos dependem de trocar de forma.

**Arte.** As formas já existem; a versão espectral é em código (a translucidez da Espiritualista é
efeito, não decoração). Falta o traje humano (quatro vistas) e o efeito do eco de forma.

---

### Predador (dr_ar) — Druida → Arqueiro

Receita: **Metamorfo + Caçadora**. Fusão: pelagem + mecanismo = **presa preparada**.
Formas: **felino e ave**.

**Núcleo.** O Predador caça com armadilhas: o felino deixa armadilhas de garra pelo caminho, a ave
marca a presa de cima, e o bote termina o serviço.

**A interação que só existe aqui.** **O caminho do felino vira campo de armadilhas.** A regra da
Caçadora exige armadilhas evidentes: aqui elas nascem do movimento da forma, e a presa aberta
recebe o bote com dano extra.

**Loop.** Ave marca a presa de cima → felino corre e deixa armadilhas no caminho → a presa pisa,
abre → Bote Preparado → no fim, Caçada Selvagem.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Forma de Caça** | ativa, entrada | Libera a barra de formas e o felino, que deixa uma armadilha de garra a cada trecho percorrido (limite de armadilhas). |
| 23 | **Instinto de Presa** | passiva | Presa aberta por armadilha recebe o bote com dano extra e dá Instinto. |
| 25 | **Forma da Ave de Rapina** | ativa de forma | Libera a ave, que marca presas de cima (janela maior e mais recompensa, como a Marca do Caçador). |
| 28 | **Armadilha de Garra** | ativa | Coloca à mão uma armadilha que prende e abre a presa. |
| 31 | **Rastro** | passiva | A presa marcada deixa um rastro visível; armadilhas no rastro disparam mais forte. |
| 34 | **Bote Preparado** | ativa | Bote até a presa aberta mais próxima; se ela estiver presa, crítico garantido. |
| 37 | **Caçada Selvagem** | ativa | Por alguns segundos, cada bote em presa aberta arma uma nova armadilha no lugar. |

**Da base Druida:** Raízes também abre a presa; Garra Felina no felino.

**Momento de glória.** Caçada Selvagem num grupo: bote, armadilha, bote, armadilha, de presa em presa.

**Atributos.** AGI > DES > FOR.

**Visual.** As formas de felino e ave com cordas e garras de osso amarradas (arte própria); na forma
humana, couro e musgo da Caçadora.

**Cinco perguntas.** Corpo a corpo, com preparação. Recurso: armadilhas e Instinto. Abre marcando;
fecha com o Bote. Contra o chefe, o caminho em volta do chefe vira campo de armadilhas. Fraqueza:
chefes que não passam pelas armadilhas.

**Arte.** As formas já existem. Falta o traje humano (quatro vistas), a armadilha de garra (prop) e
**as variantes de felino e ave com cordas e garras de osso amarradas** (arte própria: cordas,
nós e ganchos são a decoração fixa da Caçadora).

---

### Aberração (dr_ac) — Druida → Acólito

Receita: **Metamorfo + Cultista**. Fusão: pelagem + olho = **forma impossível**.
Formas: **as três, corrompidas**.

**Núcleo.** As formas da Fera viram coisas que não deveriam existir: olhos se abrem na pelagem,
membros a mais aparecem, e o rugido enlouquece.

**A interação que só existe aqui.** **O Instinto vira Êxtase.** O que a Metamorfo acumula para trocar
de forma, a Fera acumula enlouquecendo os inimigos, com o ônus do Cultista. E a forma ganha um
membro a mais, com alcance imprevisível.

**Loop.** Urso do Eclipse ruge e dá Loucura → Delírios sobem o Êxtase → trocar de forma no pico →
Rugido Delirante → no fim, Eclipse.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Forma Impossível** | ativa, entrada | Libera a barra de formas e o urso do Eclipse; o golpe de entrada é um rugido que dá Loucura. |
| 23 | **Êxtase Selvagem** | passiva | O Instinto vira Êxtase: sobe a cada Delírio e amplia o golpe de entrada; com Êxtase alto, mais dano recebido. |
| 25 | **Felino do Eclipse** | ativa de forma | Libera o felino do Eclipse. |
| 28 | **Ave do Eclipse** | ativa de forma | Libera a ave do Eclipse. |
| 31 | **Membro a Mais** | passiva | Em forma, alguns golpes alcançam mais longe (um membro que não deveria existir) e acumulam Loucura. |
| 34 | **Rugido Delirante** | ativa | Cone de Loucura grande; inimigos comuns em Delírio atacam os vizinhos. |
| 37 | **Eclipse** | ativa | Por alguns segundos, o céu escurece: todos à vista ganham Loucura, e a Fera troca de forma sozinha a cada golpe. |

**Da base Druida:** os aspectos; Broto Restaurador compensa o ônus.

**Momento de glória.** Eclipse: a Fera muda de corpo a cada golpe, e o grupo inteiro enlouquece.

**Atributos.** INT > FOR > VIT.

**Visual.** As formas com olhos abrindo na pelagem, manchas magenta e um membro a mais (arte
própria); na forma humana, a pintura corporal em magenta e turquesa.

**Cinco perguntas.** Corpo a corpo. Recurso: Êxtase e Loucura. Abre com o rugido; fecha com o Rugido
Delirante ou o Eclipse. Contra o chefe, a Loucura vira Desorientação. Fraqueza: o ônus do Êxtase.

**Arte.** As formas já existem. Falta o traje humano (quatro vistas) e **as três formas do Eclipse
com olhos e o membro a mais** (arte própria: o olho é a decoração fixa do Cultista).

---

### Envenenador (dr_la) — Druida → Ladino

Receita: **Naturalista + Assassino**. Fusão: raiz + sombra = **toxina oculta**.

**Núcleo.** A Herborista some dentro do próprio território. As sementes ocultas envenenam quem passa,
e ela sai do chão nas costas da vítima para cravar uma estaca de pedra.

**A interação que só existe aqui.** **O território esconde.** A regra do Assassino diz que a segunda
classe muda como o golpe pelas costas é criado: aqui, **pelas raízes**, a Herborista sai do chão
atrás de uma vítima que esteja perto de uma semente dela. As toxinas do Coquetel viram três
ervas.

**Loop.** Plantar sementes venenosas → oculta dentro do território → Marca da Erva → a vítima passa
pelas sementes e acumula toxinas → Brotar Atrás → Estaca → no fim, Jardim Mortal.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Semente Venenosa** | ativa, entrada | Planta uma semente oculta; madura, envenena quem passa (DoT). Cada semente tem uma de três ervas: dormideira (lentidão), urtiga (sangramento) e cicuta (enfraquece). |
| 23 | **Folhagem** | passiva | Perto das próprias sementes, fica oculta enquanto não ataca. |
| 25 | **Marca da Erva** | ativa | Marca a vítima para a Sentença; ela fica visível através de obstáculos. |
| 28 | **Brotar Atrás** | ativa | Só oculta: sai do chão nas costas da vítima que esteja perto de uma semente dela. |
| 31 | **Coquetel de Ervas** | passiva | As três ervas na mesma vítima causam uma reação e dão +2 de Sentença. |
| 34 | **Estaca** | ativa | O golpe final de perto: uma estaca de pedra pelas costas; gasta a Sentença; morte certa abaixo do limiar da categoria; no chefe, dano muito alto. |
| 37 | **Jardim Mortal** | ativa | Por alguns segundos, todo o território floresce em veneno, e cada abate devolve a ocultação e faz brotar sementes no corpo da vítima. |

**Da base Druida:** Raízes prende a vítima sobre as sementes; Espeto de Pedra de longe.

**Momento de glória.** Jardim Mortal: a Herborista some e brota atrás de uma vítima após a outra.

**Atributos.** INT > AGI > DES.

**Visual.** A silhueta baixa da Naturalista, encapuzada, com folhas escuras e flores venenosas; verde
escuro, roxo e preto.

**Cinco perguntas.** Média (oculta) e corpo a corpo no golpe final. Recurso: sementes e Sentença.
Abre plantando; fecha com a Estaca. Contra o chefe, plantar onde ele passa e brotar atrás. Fraqueza:
preparação; fora do território, exposta.

**Arte.** Falta o traje (quatro vistas), as sementes das três ervas e a estaca.

---

### Geomante (dr_mo) — Druida → Monge

Receita: **Naturalista + Elevado**. Fusão: raiz + campo = **pedra suspensa**.

**Núcleo.** O Geomante arranca a pedra do chão e a mantém no campo. Muralhas flutuam e empurram,
rochas orbitam e caem, e as sementes são lançadas pelo ar para plantar longe.

**A interação que só existe aqui.** **A pedra da Naturalista entra no campo do Elevado.** Em vez de
erguer uma parede parada, o Geomante a move com a mente; em vez de plantar onde está, lança as
sementes pela órbita.

**Loop.** Pedra Suspensa (até três rochas em órbita) → as rochas bloqueiam projéteis → Muralha
Flutuante empurra o grupo → Sementes em Órbita plantam longe → Pressão Telúrica → no fim, Montanha
Suspensa.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Pedra Suspensa** | ativa, entrada | Arranca uma rocha do chão e a mantém em órbita no campo (até três); reativar arremessa a rocha. |
| 23 | **Gravidade da Terra** | passiva | As rochas em órbita bloqueiam projéteis; parado, a órbita fica mais estável e mais rápida. |
| 25 | **Muralha Flutuante** | ativa | Ergue um muro de pedra e o empurra com a mente na direção escolhida, arrastando os inimigos comuns. |
| 28 | **Sementes em Órbita** | ativa | As sementes giram no campo e são lançadas para plantar à distância; amadurecem ao cair. |
| 31 | **Raiz Profunda** | passiva | Rochas que caem abrem pequenas fissuras que ferem em linha. |
| 34 | **Pressão Telúrica** | ativa | Pressiona o terreno sob o alvo: espetos sobem de baixo e as rochas em órbita caem de cima. |
| 37 | **Montanha Suspensa** | ativa | Ergue o chão inteiro do campo e o derruba em área. |

**Da base Druida:** Espeto de Pedra combina com a Pressão; Raízes segura os inimigos sob a queda.

**Momento de glória.** Montanha Suspensa: o chão do campo sobe e cai sobre o grupo.

**Atributos.** INT > VIT > DES.

**Visual.** A Naturalista com faixas do Monge, flutuando um pouco; pedras e sementes em órbita; cinza,
verde-musgo e azul-violeta.

**Cinco perguntas.** Média, dentro do campo. Recurso: rochas em órbita e sementes. Abre com a Pedra
Suspensa; fecha com a Pressão ou a Montanha. Contra o chefe, o chefe não é erguido; as rochas e os
espetos fazem o dano. Fraqueza: as rochas se perdem ao serem arremessadas.

**Arte.** Falta o traje (quatro vistas) e os efeitos de rocha em órbita, muro flutuante e montanha.

---

### Sanguinário (la_sp) — Ladino → Espadachim

Receita: **Dervixe + Berserker**. Fusão: vendaval + ferida = **dança rubra**.

**Núcleo.** Cada vítima diferente recebe uma ferida, e o vento cresce com as feridas abertas. No fim
da dança, a Ciranda detona todas de uma vez.

**A interação que só existe aqui.** O Berserker insiste no mesmo alvo; o Dervixe troca de alvo. Aqui,
**a ferida se espalha pela troca**: cada vítima nova ganha uma carga, e as feridas abertas no campo
contam para o estágio do vento.

**Loop.** Corte Rubro abre feridas em vítimas diferentes → Sangria Dançante soma cargas em volta → o
vento sobe com as feridas → Salto Sangrento atravessa o grupo → Ciranda Rubra detona → no fim, Dança
da Carnificina.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Corte Rubro** | ativa, entrada | Avanço girando que atravessa o inimigo e abre uma ferida nele. Conta Passo. |
| 23 | **Compasso Rubro** | passiva | Liga os Passos, os três estágios do Vento e a punição por parar; cada ferida aberta no campo também conta para o vento. |
| 25 | **Sangria Dançante** | ativa | Giro curto que acrescenta uma carga a todas as feridas em volta. |
| 28 | **Salto Sangrento** | ativa | Salto que atravessa o grupo; cada inimigo ferido atravessado conta Passo. |
| 31 | **Transe Rubro** | passiva | Com HP baixo, o Devaneio vem mais rápido e o dano sobe. |
| 34 | **Ciranda Rubra** | ativa | Gasta um estágio de vento e detona todas as feridas em volta. |
| 37 | **Dança da Carnificina** | ativa | Por alguns segundos, cada vítima diferente ganha três cargas na hora; no fim, todas detonam. |

**Da base Ladino:** Corte Giratório e Salto Acrobático somam Passos; Veneno soma DoT.

**Momento de glória.** O fim da Dança da Carnificina: todas as feridas do grupo estouram juntas.

**Atributos.** AGI > FOR > SOR.

**Visual.** A silhueta aberta do Dervixe, com sedas vermelho-escuras e ferro escuro; rastro vermelho no
giro.

**Cinco perguntas.** Corpo a corpo, em movimento. Recurso: feridas espalhadas e vento. Abre com o Corte
Rubro; fecha com a Ciranda. Contra o chefe, golpes por lados diferentes sobem o vento, e as cargas
se acumulam no chefe. Fraqueza: parar derruba o vento; o risco do HP baixo.

**Arte.** Falta o traje (quatro vistas) e os efeitos de ferida e da Ciranda Rubra.

---

### Ilusionista (la_mg) — Ladino → Mago

Receita: **Dervixe + Espiritualista**. Fusão: vendaval + vestígio = **miragem**.

**Núcleo.** Os passos do Dançarino deixam ecos que repetem o corte com atraso. No Devaneio, os ecos
dançam sozinhos.

**A interação que só existe aqui.** **Os ecos também contam Passo.** O acerto de um eco num inimigo
diferente sobe o vento, e no Devaneio os ecos seguem sozinhos até a próxima vítima.

**Loop.** Passo Fantasma deixa um eco → os ecos repetem os cortes e somam Passos → Facas Lembradas →
Devaneio: os ecos dançam sozinhos → Roda de Lembranças puxa os ecos de volta → no fim, Corpo de
Miragens.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Passo Fantasma** | ativa, entrada | Avanço girando que deixa, no ponto de partida, um eco que repete o corte com atraso. Conta Passo. |
| 23 | **Compasso do Eco** | passiva | Liga Passos, Vento e punição por parar; acertos dos ecos em inimigos diferentes também contam Passo. |
| 25 | **Facas Lembradas** | ativa | Lança três facas que voltam até o Dançarino; a volta é repetida por um eco. Pegar no ar dá bônus. |
| 28 | **Véu de Miragem** | ativa | Salta para o lado e deixa uma miragem que provoca e aguenta um golpe. |
| 31 | **Devaneio de Ecos** | passiva | No Devaneio, os ecos seguem sozinhos até a próxima vítima e cortam. |
| 34 | **Roda de Lembranças** | ativa | Todos os ecos ativos giram de volta até o Dançarino, cortando no caminho. |
| 37 | **Corpo de Miragens** | ativa | Por alguns segundos, cada Passo deixa um eco que fica; no fim, todos repetem o último golpe juntos. |

**Da base Ladino:** Corte Giratório e Salto Acrobático; Passo Sombrio.

**Momento de glória.** O fim do Corpo de Miragens: uma roda de ecos repete o mesmo golpe ao mesmo tempo.

**Atributos.** AGI > INT > SOR.

**Visual.** O Dervixe com sedas pálidas e véus; ecos translúcidos com fitas (em código).

**Cinco perguntas.** Corpo a corpo, em movimento. Recurso: vento e ecos. Abre com o Passo Fantasma;
fecha com a Roda ou o Corpo de Miragens. Contra o chefe, ecos por lados diferentes do chefe sobem o
vento. Fraqueza: parar derruba o vento.

**Arte.** Falta o traje (quatro vistas); ecos em código.

---

### Guerrilheiro (la_ar) — Ladino → Arqueiro

Receita: **Dervixe + Caçadora**. Fusão: vendaval + mecanismo = **picadeiro armado**.

**Núcleo.** O Acrobata joga armadilhas pela dança. O picadeiro é armado durante o número, e cada
inimigo preso conta como vítima nova para o vento.

**A interação que só existe aqui.** **A armadilha renova a vítima**: uma presa aberta conta como Passo
novo mesmo que já tenha sido golpeada. E o malabarismo do Dervixe vira malabarismo de armadilhas.

**Loop.** Salto Armado deixa armadilhas no caminho → malabarismo arma um leque → os presos contam
como vítimas novas → Corda Bamba fecha um corredor → Grande Truque dispara tudo → no fim, Número da
Arena.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Salto Armado** | ativa, entrada | Avanço girando que deixa uma armadilha no ponto de saída. Conta Passo. |
| 23 | **Compasso de Guerrilha** | passiva | Liga Passos, Vento e punição por parar; presa aberta por armadilha conta como vítima nova. |
| 25 | **Malabarismo de Armadilhas** | ativa | Lança três armadilhas pequenas em leque, que armam onde caem; pegar no ar uma que ainda não armou a recarrega. |
| 28 | **Corda Bamba** | ativa | Estica uma corda entre dois pontos: inimigos que a cruzam tropeçam e abrem; andar sobre ela não derruba o vento. |
| 31 | **Picadeiro** | passiva | Armadilhas dentro do raio do giro disparam mais forte; o raio cresce com o vento. |
| 34 | **Grande Truque** | ativa | Dispara todas as armadilhas armadas de uma vez. |
| 37 | **Número da Arena** | ativa | Por alguns segundos, cada Passo arma uma armadilha no lugar. |

**Da base Ladino:** Salto Acrobático; Veneno nas armadilhas.

**Momento de glória.** Número da Arena seguido do Grande Truque: o picadeiro inteiro dispara de uma vez.

**Atributos.** AGI > DES > INT.

**Visual.** O Dervixe com cordas, guizos e armadilhas penduradas no cinto; musgo e areia.

**Cinco perguntas.** Corpo a corpo, em movimento. Recurso: armadilhas e vento. Abre com o Salto Armado;
fecha com o Grande Truque. Contra o chefe, armadilhas em volta do chefe renovam a vítima. Fraqueza:
parar derruba o vento; chefes que não passam pelas armadilhas.

**Arte.** Falta o traje (quatro vistas), a armadilha pequena e a corda.

---

### Lunático (la_ac) — Ladino → Acólito

Receita: **Dervixe + Cultista**. Fusão: vendaval + olho = **transe contagiante**.

**Núcleo.** O giro do Lunático espalha Loucura. O transe dele e o delírio dos inimigos se
alimentam.

**A interação que só existe aqui.** **Devaneio e Delírio são o mesmo estado, de lados diferentes.**
Inimigos em Delírio sempre contam como vítimas novas, e o Devaneio do Dervixe dá Êxtase, com o ônus
do Cultista.

**Loop.** Giro Delirante → a Loucura sobe → Delirantes contam como vítimas novas → Plateia: os
Delirantes atacam quem chega perto do Dervixe → Devaneio e Êxtase → Ciranda do Vazio → no fim, Dança do
Fim.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Giro Delirante** | ativa, entrada | Avanço girando que aplica Loucura. Conta Passo. |
| 23 | **Transe Compartilhado** | passiva | Liga Passos, Vento e punição por parar; inimigos em Delírio sempre contam como vítimas novas, e o Devaneio dá Êxtase (com o ônus). |
| 25 | **Sussurro no Vento** | ativa | Rajada que espalha Loucura em volta. |
| 28 | **Plateia** | ativa | Marca uma área: Delirantes dentro dela atacam os inimigos que se aproximam do Dervixe. |
| 31 | **Êxtase do Vazio** | passiva | Com Êxtase alto, mais dano e mais dano recebido. |
| 34 | **Ciranda do Vazio** | ativa | Gasta um estágio de vento numa roda de Loucura. |
| 37 | **Dança do Fim** | ativa | Por alguns segundos, todo inimigo atingido entra em Delírio na hora (o chefe, em Desorientação). |

**Da base Ladino:** Corte Giratório e Salto Acrobático.

**Momento de glória.** Dança do Fim: cada golpe enlouquece, e a sala inteira se volta contra si mesma.

**Atributos.** AGI > INT > SOR.

**Visual.** O Dervixe com sedas magenta e turquesa e olhos bordados nas fitas.

**Cinco perguntas.** Corpo a corpo, em movimento. Recurso: vento, Loucura e Êxtase. Abre com o Giro;
fecha com a Ciranda ou a Dança do Fim. Contra o chefe, Desorientação nas janelas. Fraqueza: parar; o
ônus do Êxtase.

**Arte.** Falta o traje (quatro vistas) e os efeitos de Loucura no vento.

---

### Feral (la_dr) — Ladino → Druida

Receita: **Dervixe + Metamorfo**. Fusão: vendaval + pelagem = **dança feral**.
Formas: **felino e ave** (o urso é lento demais para a dança).

**Núcleo.** O Feral troca de forma ao trocar de vítima. A transição é o golpe, e o golpe
conta Passo.

**A interação que só existe aqui.** **Trocar de vítima e trocar de forma no mesmo movimento** dá Passo
duplo. O Instinto do Metamorfo sobe com o vento.

**Loop.** Passo Feral: troca de vítima e de forma ao mesmo tempo → Passo duplo → Bote Giratório pela
forma → o vento e o Instinto sobem → Vendaval de Garras → no fim, Dança Feral.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Passo Feral** | ativa, entrada | Libera a barra de formas (humana e felino); trocar de forma ao golpear uma vítima nova dá Passo duplo. |
| 23 | **Compasso Feral** | passiva | Liga Passos, Vento e punição por parar; o golpe de entrada de cada forma conta Passo. |
| 25 | **Forma da Ave Dançante** | ativa de forma | Libera a ave na barra. |
| 28 | **Bote Giratório** | ativa | Lido pela forma: no felino, bote em espiral; na ave, rasante girando; na forma humana, corte girado. |
| 31 | **Instinto do Vento** | passiva | O Instinto sobe com o estágio do vento; no Devaneio, a troca de forma não tem recarga uma vez. |
| 34 | **Vendaval de Garras** | ativa | Gasta um estágio de vento num giro de garras em área. |
| 37 | **Dança Feral** | ativa | Por alguns segundos, a forma troca sozinha a cada vítima nova, sem recarga. |

**Da base Ladino:** Corte Giratório; Salto Acrobático.

**Momento de glória.** Dança Feral: felino, ave, humano, felino, um corpo novo a cada vítima.

**Atributos.** AGI > FOR > SOR.

**Visual.** O Dervixe com peles e penas nas fitas; as formas de felino e ave com fitas de seda e
guizos (arte própria).

**Cinco perguntas.** Corpo a corpo, em movimento. Recurso: vento e Instinto. Abre com o Passo Feral;
fecha com o Vendaval de Garras. Contra o chefe, lados diferentes do chefe e trocas de forma. Fraqueza:
parar; a recarga de troca.

**Arte.** As formas já existem. Falta o traje humano (quatro vistas) e **as variantes de felino e ave
com fitas de seda e guizos** (arte própria: as fitas são a decoração fixa do Dervixe).

---

### Mentalista (la_mo) — Ladino → Monge

Receita: **Assassino + Elevado**. Fusão: sombra + campo = **mão invisível**.

**Núcleo.** O Mentalista puxa a vítima com a mente para fora do grupo e a encontra pelas costas.
A ocultação vem da calma: sem ser tocada, ninguém a vê.

**A interação que só existe aqui.** A regra do Assassino diz que a segunda classe muda como o golpe
pelas costas é criado: aqui, **pela telecinese**, que puxa a vítima e a vira de costas. A ocultação
continua evidente, mas vem da **Calma** do Elevado: sem receber dano por alguns segundos, ela some.

**Loop.** Fio Mental marca → sem ser tocada, some → Puxão Mental traz a vítima para fora do grupo,
de costas → Passo Telecinético → Sentença Mental → no fim, Mão Invisível.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Fio Mental** | ativa, entrada | Marca a vítima para a Sentença e a puxa levemente. |
| 23 | **Mente Quieta** | passiva | Sem receber dano por alguns segundos, fica oculta. |
| 25 | **Puxão Mental** | ativa | Puxa uma vítima comum para fora do grupo até a Lâmina, virando-a de costas; no chefe, só o vira. |
| 28 | **Passo Telecinético** | ativa | Só oculta: se arremessa até as costas da vítima. |
| 31 | **Lâmina Suspensa** | passiva | As adagas flutuam junto: golpes pelas costas acertam duas vezes. |
| 34 | **Sentença Mental** | ativa | Gasta a Sentença; morte certa abaixo do limiar da categoria do inimigo; no chefe, dano muito alto. |
| 37 | **Mão Invisível** | ativa | Por alguns segundos, puxa cada vítima marcada até ela, uma após a outra, executando em sequência. |

**Da base Ladino:** Ocultação e Passo Sombrio; Punhalada pelas costas.

**Momento de glória.** Mão Invisível: as vítimas são puxadas uma a uma, de costas, até a lâmina.

**Atributos.** AGI > INT > DES.

**Visual.** O Ladino com faixas do Monge e adagas flutuando em volta das mãos; preto, cinza-chumbo e
azul-violeta.

**Cinco perguntas.** Média (puxão) e corpo a corpo. Recurso: Sentença e Calma. Abre com o Fio Mental;
fecha com a Sentença Mental. Contra o chefe, virá-lo de costas e entrar. Fraqueza: ser atingida tira a
ocultação.

**Arte.** Falta o traje (quatro vistas) e os efeitos do fio mental e das adagas flutuantes.

---

### Decisões do usuário sobre as origens Druida e Ladino (14/11)

1. **Formas por híbrida** aprovadas como propostas.
2. **Arte das variantes:** arte própria quando a variante carrega uma decoração fixa da outra
   classe; só código quando não há esse marcador. Regra registrada no método (item 4).
   Aplicada a este lote:

   | Variante | Decoração fixa? | Arte |
   |---|---|---|
   | Dilacerador (pintura vermelha) | não | código |
   | Ancestral (translucidez) | não, é efeito | código |
   | Predador (cordas e garras de osso) | sim, Caçadora | própria |
   | Aberração (olhos e membro a mais) | sim, Cultista | própria |
   | Feral (fitas e guizos) | sim, Dervixe | própria |

   Antes desta regra, as variantes das híbridas do Demonólogo já tinham arte própria
   (elementais do Invocador e formas do Encarnado, com as marcas de contrato).
3. **Dervixe como passiva própria** em cada híbrida de origem Ladino, com mais ou menos
   recursos do Dervixe conforme a combinação.
4. **Ocultação por Calma no Mentalista** aprovada.

---

## Aprofundamento — origem Monge

Seis híbridas, todas com o **Campeão** (o Titereiro, com o Elevado, já foi
aprofundado com o Necromante).

**Regra deste lote:** a base Monge não tem a Contagem nem a janela de tempo. Cada híbrida traz
a Contagem (0 a 9, sobe com golpes no tempo certo, cai pela metade fora do tempo, zera sem
golpes) numa passiva própria, como as híbridas do Dervixe trazem o Vento.

**Biblioteca de origem (proposta de 14/11):** Palma de Impacto, Passo Evasivo, Aparar Projétil,
Sequência de Três Golpes, Pulso Mental, Poço Gravitacional e Respiração Contida.

---

### Quebra-Montanhas (mo_sp) — Monge → Espadachim

Receita: **Campeão + Berserker**. Fusão: ritmo + ferida = **quebra**.

**Núcleo.** A cada três números da Contagem, uma carga de ferida no alvo. O golpe final no 9
detona todas.

**A interação que só existe aqui.** O Campeão perde metade da Contagem ao errar o tempo; o
Berserker paga com HP. Aqui, **o Quebra-Montanhas pode pagar o erro com sangue**: no Sangue no
Compasso, errar o tempo custa HP em vez de Contagem. E a ferida é o registro da sequência no
corpo do alvo.

**Loop.** Punho Ferido abre a ferida → golpes no tempo sobem a Contagem; a cada 3, uma carga →
Sangue no Compasso para não perder a sequência → Avalanche detona as feridas em área → no 9,
Quebra-Montanhas.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Punho Ferido** | ativa, entrada | Golpe ritmado que abre ferida no alvo; no tempo, +2 de Contagem. |
| 23 | **Compasso de Guerra** | passiva | Liga a Contagem e a janela de tempo; a cada 3, uma carga de ferida no alvo. |
| 25 | **Golpe da Montanha** | ativa | Golpe pesado que gasta até 3 de Contagem para mais dano e um empurrão. |
| 28 | **Sangue no Compasso** | ativa | Por alguns segundos, errar o tempo custa HP em vez de Contagem. |
| 31 | **Obstinação Marcial** | passiva | Com HP baixo, a janela de tempo fica maior. |
| 34 | **Avalanche** | ativa | Salto com impacto em área que detona as feridas de todos os atingidos. |
| 37 | **Quebra-Montanhas** | ativa | No 9, um golpe final que detona todas as cargas do alvo e repete a sequência num só impacto. |

**Da base Monge:** Sequência de Três Golpes e Palma de Impacto sobem a Contagem; Passo Evasivo
entre os tempos.

**Momento de glória.** Chegar ao 9 com HP baixo, pagando os erros com sangue, e estourar todas as
feridas num golpe.

**Atributos.** FOR > VIT > AGI.

**Visual.** O Campeão com faixas sujas de sangue e ferro escuro; vermelho, preto e laranja;
números da Contagem em vermelho.

**Cinco perguntas.** Corpo a corpo. Recurso: Contagem, feridas e HP. Abre com o Punho Ferido;
fecha com o Quebra-Montanhas. Contra o chefe, a sequência e as feridas no mesmo alvo. Fraqueza: o
HP que paga os erros.

**Arte.** Falta o traje (quatro vistas) e os efeitos de ferida e do golpe final.

---

### Médium (mo_mg) — Monge → Mago

Receita: **Campeão + Espiritualista**. Fusão: ritmo + vestígio = **eco do golpe**.

**Núcleo.** Os golpes do Médium se repetem com atraso, e o golpe final é repetido por um
eco de cada número da sequência.

**A interação que só existe aqui.** **O eco mantém o ritmo.** Um eco que cai dentro da janela de
tempo conta como golpe no tempo e sobe a Contagem. O atraso da Espiritualista vira parte do
compasso.

**Loop.** Golpe Ecoante marca o alvo → os golpes seguintes ecoam → ecos no tempo sobem a
Contagem → Ritmo Fantasma cobre um erro → Procissão de Golpes → no 9, Ressonância Final.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Golpe Ecoante** | ativa, entrada | Golpe ritmado que marca o alvo: o próximo golpe nele é repetido com atraso. |
| 23 | **Compasso do Eco** | passiva | Liga a Contagem e a janela de tempo; ecos que caem dentro da janela também sobem a Contagem. |
| 25 | **Palma das Almas** | ativa | Palma que repete os três últimos golpes como ecos. |
| 28 | **Ritmo Fantasma** | ativa | Por alguns segundos, um eco cobre o primeiro golpe fora do tempo, e a Contagem não cai. |
| 31 | **Recolhimento Marcial** | passiva | Ecos que acertam devolvem SP. |
| 34 | **Procissão de Golpes** | ativa | Três aparições do Punho atacam o alvo em sequência, cada uma no tempo. |
| 37 | **Ressonância Final** | ativa | No 9, o golpe final é repetido por um eco de cada número da sequência. |

**Da base Monge:** Sequência de Três Golpes enche os ecos; Pulso Mental na defesa.

**Momento de glória.** A Ressonância Final: nove ecos repetem o último golpe, um atrás do outro.

**Atributos.** AGI > INT > FOR.

**Visual.** O Campeão com faixas pálidas e véus; imagens remanescentes do punho (em código).

**Cinco perguntas.** Corpo a corpo. Recurso: Contagem e ecos. Abre com o Golpe Ecoante; fecha com a
Ressonância. Contra o chefe, o loop é de alvo único. Fraqueza: errar o tempo; ser empurrado para
longe.

**Arte.** Falta o traje (quatro vistas); os ecos são em código.

---

### Peregrino (mo_ar) — Monge → Arqueiro

Receita: **Campeão + Caçadora**. Fusão: ritmo + mecanismo = **arremesso armado**.

**Núcleo.** O Peregrino prepara o terreno com armadilhas e, no tempo certo, arremessa os inimigos
para dentro delas.

**A interação que só existe aqui.** **O golpe no tempo é o que leva a presa à armadilha.** A regra
da Caçadora exige armadilhas evidentes; aqui elas são o destino dos arremessos. A presa aberta
pela armadilha conta como golpe no tempo e sobe a Contagem.

**Loop.** Selo de Pouso arma o chão → golpes no tempo → Arremesso Ritmado leva o inimigo ao selo →
presa aberta, Contagem sobe → Contrapé arremessa quem ataca → Campo de Treino → no 9, Último
Arremesso.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Arremesso Ritmado** | ativa, entrada | Golpe no tempo que arremessa um inimigo comum na direção escolhida; no chefe, só um pequeno empurrão. |
| 23 | **Compasso do Peregrino** | passiva | Liga a Contagem e a janela de tempo; presa aberta por armadilha conta como golpe no tempo, +2. |
| 25 | **Selo de Pouso** | ativa | Armadilha num ponto: quem pisa ou é arremessado nela fica preso e aberto. |
| 28 | **Contrapé** | ativa | Agarra o golpe do inimigo e o arremessa; arremessado numa armadilha, dispara ela. |
| 31 | **Peregrinação** | passiva | Armadilhas armadas há mais tempo prendem por mais tempo. |
| 34 | **Campo de Treino** | ativa | Arma várias armadilhas em volta, de uma vez. |
| 37 | **Último Arremesso** | ativa | No 9, um arremesso que leva o inimigo por todas as armadilhas no caminho, disparando cada uma. |

**Da base Monge:** Poço Gravitacional junta os inimigos perto das armadilhas; Palma de Impacto
empurra.

**Momento de glória.** Último Arremesso por um campo armado: o inimigo atravessa e dispara cada
armadilha.

**Atributos.** FOR > AGI > DES.

**Visual.** O Campeão com cordas, sandálias de viagem e selos de pano pendurados; laranja e
marrom-musgo.

**Cinco perguntas.** Corpo a corpo, com preparação. Recurso: Contagem e armadilhas. Abre armando;
fecha com o Último Arremesso. Contra o chefe, o chefe não é arremessado; a presa aberta e a
Contagem fazem o dano. Fraqueza: preparação; chefes que não pisam nas armadilhas.

**Arte.** Falta o traje (quatro vistas) e o selo de pouso (prop).

---

### Abissal (mo_ac) — Monge → Acólito

Receita: **Campeão + Cultista**. Fusão: ritmo + olho = **transe marcial**.

**Núcleo.** Cada número da Contagem acrescenta Loucura no alvo. No 9, o alvo perde a noção de onde
está.

**A interação que só existe aqui.** **A Contagem é o Êxtase.** Quanto mais alta a Contagem, mais
forte o Punho e mais exposto ele fica (o ônus do Cultista). E a Loucura não vem de olhar: vem de
golpes que acertam "por dentro".

**Loop.** Golpe Sacrílego → cada número da Contagem soma Loucura → Olhar do Lutador abre uma
Desorientação a cada 3 → Transe Marcial no 6 → Impacto Impossível no grupo → no 9, Nono Selo.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Golpe Sacrílego** | ativa, entrada | Golpe ritmado que aplica Loucura. |
| 23 | **Compasso Profano** | passiva | Liga a Contagem e a janela de tempo; cada número soma Loucura no alvo; a Contagem alta conta como Êxtase, com o ônus. |
| 25 | **Palma Impossível** | ativa | Palma que acerta "por dentro": ignora parte da DEF e dobra a Loucura. |
| 28 | **Olhar do Lutador** | ativa | Marca o alvo: a cada 3 da Contagem, ele fica desorientado por um instante. |
| 31 | **Transe Marcial** | passiva | No 6 ou mais, a janela de tempo aumenta, mas o Punho recebe mais dano. |
| 34 | **Impacto Impossível** | ativa | Golpe em área: Loucura em volta; inimigos comuns com Loucura alta entram em Delírio. |
| 37 | **Nono Selo** | ativa | No 9, o alvo entra em Desorientação (respeitando a imunidade do chefe), e os comuns em volta entram em Delírio. |

**Da base Monge:** Sequência de Três Golpes; Pulso Mental soma Loucura em volta.

**Momento de glória.** O Nono Selo num grupo: o golpe final e todos em volta enlouquecem.

**Atributos.** FOR > INT > AGI.

**Visual.** O Campeão com faixas magenta e olhos pintados nas manoplas; números da Contagem em
turquesa.

**Cinco perguntas.** Corpo a corpo. Recurso: Contagem (Êxtase) e Loucura. Abre com o Golpe
Sacrílego; fecha com o Nono Selo. Contra o chefe, Desorientação nas janelas. Fraqueza: a Contagem
alta expõe.

**Arte.** Falta o traje (quatro vistas) e os efeitos da Loucura nos golpes.

---

### Totêmico (mo_dr) — Monge → Druida

Receita: **Campeão + Metamorfo**. Fusão: ritmo + pelagem = **feras de pé**.

**Núcleo.** A sequência do Mestre passa por três formas animais **antropomórficas**: um meio-termo
entre o monge e o animal (decisão do usuário em 14/11). O corpo continua de pé e luta com as mãos,
mas ganha os traços do animal: a massa e as garras do urso, a agilidade e as orelhas do felino, as
penas e o bico da ave. A cada três números, a forma muda, e o primeiro golpe de cada forma é o golpe
de entrada dela.

**A interação que só existe aqui (e a regra do Metamorfo).** A regra diz que o Metamorfo como
afinidade traz uma troca real de estado, com golpe de transição. Aqui, a troca é **uma
meia-transformação que acompanha a Contagem**: no 3, no 6 e ao zerar, o corpo do Mestre muda de forma,
e o primeiro golpe da nova forma é a transição (rugido, bote, salto). Não é a transformação completa
do Metamorfo (o Mestre continua bípede e golpeando com as mãos), nem só uma postura.

**Loop.** Forma do urso nos três primeiros → no 3, bote do felino → no 6, salto da ave → no 9,
Sequência Quimérica.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Golpe da Fera** | ativa, entrada | Golpe ritmado lido pela forma atual: no urso, empurra em área curta; no felino, dois golpes rápidos; na ave, um golpe com salto curto. |
| 23 | **Compasso das Feras** | passiva | Liga a Contagem e a janela de tempo; a forma muda no 3 (felino), no 6 (ave) e volta ao urso ao zerar. O primeiro golpe de cada forma é o golpe de entrada dela. |
| 25 | **Rugido de Forma** | ativa | Troca de forma na hora, sem perder a Contagem. |
| 28 | **Instinto Marcial** | ativa | Por alguns segundos, a forma não muda, e os golpes dela ficam mais fortes. |
| 31 | **Pele Treinada** | passiva | Cada forma dá um bônus enquanto ativa (urso: DEF; felino: velocidade de ataque; ave: esquiva). |
| 34 | **Investida da Fera** | ativa | Avanço lido pela forma. |
| 37 | **Sequência Quimérica** | ativa | No 9, três golpes finais, um de cada forma, passando pelas três em sequência, cada um com a silhueta completa do animal por trás. |

**Da base Monge:** Sequência de Três Golpes; Passo Evasivo.

**Momento de glória.** A Sequência Quimérica: urso, felino e ave, um golpe de cada, com as três
silhuetas.

**Atributos.** AGI > FOR > VIT.

**Visual.**
- Três formas antropomórficas, bípedes, com as faixas do Campeão nas mãos e nos antebraços
  (decoração fixa do Campeão) e a pintura corporal do Metamorfo:
  - urso: massa, ombros largos, garras;
  - felino: corpo esguio, orelhas e cauda, manchas;
  - ave: penas nos braços como asas curtas, crista, pés de garra.
- O design é próprio do projeto. A referência citada pelo usuário serve só para o conceito de
  meia-forma animal;
- a silhueta completa do aspecto aparece por trás no golpe de entrada e na Sequência Quimérica.

**Cinco perguntas.** Corpo a corpo. Recurso: Contagem e a forma. Abre na forma do urso; fecha com a
Sequência Quimérica. Contra o chefe, o loop é de alvo único. Fraqueza: errar o tempo derruba a forma
junto com a Contagem.

**Arte.** Os aspectos já existem. Falta o traje humano (quatro vistas), **as três formas
antropomórficas** (corpos novos, quatro vistas cada) e os três golpes de entrada.

---

### Dançarino (mo_la) — Monge → Ladino

Receita: **Campeão + Dervixe**. Fusão: ritmo + vendaval = **compasso de roda**.

**Núcleo.** O Dançarino conta, mas só conta vítimas diferentes. A Contagem só sobe com golpes
no tempo certo em inimigos diferentes, e a cada três números o vento sobe um estágio.

**A interação que só existe aqui.** O rigor do Campeão com a roda do Dervixe: **o tempo certo e a
troca de vítima são exigidos ao mesmo tempo**. Golpear o mesmo alvo pelo mesmo lado não conta;
golpeá-lo por outro lado conta, pela regra dos lados.

**Loop.** Passo Marcial até a próxima vítima, no tempo → Roda de Palmas no grupo → Contratempo salta
por cima e troca de lado → a cada 3, o vento sobe → Ciranda Marcial → no 9, Grande Roda.

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Passo Marcial** | ativa, entrada | Avanço até uma vítima diferente; no tempo, +2 de Contagem. |
| 23 | **Compasso de Roda** | passiva | A Contagem sobe só com golpes no tempo em vítimas diferentes (ou no mesmo alvo por outro lado). A cada 3, um estágio de vento (Brisa, Rajada, Vendaval). Parar faz a Contagem cair mais rápido. |
| 25 | **Roda de Palmas** | ativa | Giro de palmas em volta: cada inimigo atingido no tempo conta. |
| 28 | **Contratempo** | ativa | Salta por cima de uma vítima e cai do outro lado; conta como golpe no tempo. |
| 31 | **Fôlego da Roda** | passiva | No Vendaval, a janela de tempo aumenta. |
| 34 | **Ciranda Marcial** | ativa | Gasta 3 de Contagem numa roda grande em volta. |
| 37 | **Grande Roda** | ativa | No 9, um golpe final em cada vítima atingida durante a sequência, na ordem em que foram atingidas. |

**Da base Monge:** Passo Evasivo entre as vítimas; Pulso Mental quando cercado.

**Momento de glória.** A Grande Roda depois de uma sequência perfeita por nove inimigos diferentes.

**Atributos.** AGI > FOR > DES.

**Visual.** O Campeão com fitas de seda do Dervixe nos pulsos e na cintura, guizos nas manoplas;
laranja, areia e turquesa.

**Cinco perguntas.** Corpo a corpo, em movimento. Recurso: Contagem e vento. Abre com o Passo Marcial;
fecha com a Grande Roda. Contra o chefe, os lados diferentes do chefe contam como vítimas.
Fraqueza: é a classe mais exigente de executar; parar ou errar derruba tudo. O usuário aceitou que
alguma classe seja a mais difícil; a dificuldade será avaliada em playtest.

**Arte.** Falta o traje (quatro vistas) e os efeitos de roda e de vento.

---

### Decisões do usuário sobre a origem Monge (14/11)

1. **Contagem como passiva própria** em cada híbrida de origem Monge.
2. **Totêmico com formas antropomórficas:** um meio-termo entre a postura e a transformação
   completa. O corpo continua bípede e de mãos livres, com os traços do urso, do felino e da ave.
   Pede arte nova: três formas, quatro vistas cada.
3. **Quebra-Montanhas** pagando os erros com HP: justo.
4. **Dançarino** fica como a híbrida mais difícil; avaliar em playtest.

---

## Nomes simples (decisão do usuário em 14/11)

Os nomes foram simplificados: nomes curtos, próximos do tema, no lugar de nomes compostos
que tentavam descrever a mecânica. Os IDs (`sp_ar`, `mg_sp`...) não mudam. Evitados nomes
que já existem em inimigos (Mestre das Feras, Guardião Ancestral, Vigia Invernal). Para
`mo_la`, o usuário escolheu um nome genérico (Dançarino) em vez de Capoeirista ou Bailarino.
Mantidos: Cavaleiro Rúnico, Paladino, Duelista, Geômetra, Taumaturgo, Tempestário, Saqueador,
Inquisidor, Emboscador, Arqueiro Zen, Flagelante, Hierofante, Lich, Encarnado, Geomante e
Quebra-Montanhas.

| Nome anterior | Nome atual |
|---|---|
| Baluarte de Cerco | **Bastião** |
| Alfa Infernal | **Alfa** |
| Guardião de Gaia | **Silvano** |
| Guardião Cinético | **Inabalável** |
| Devastador Astral | **Possesso** |
| Invocador do Cataclismo | **Invocador** |
| Lâmina Prismática | **Lâmina Arcana** |
| Tecelão Astral | **Magister** |
| Caçador de Espectros | **Rastreador** |
| Atirador do Pacto | **Mercenário** |
| Atirador Silvano | **Patrulheiro** |
| Oráculo do Abismo | **Oráculo** |
| Vigia do Abismo | **Observador** |
| Exorcista dos Pactos | **Exorcista** |
| Executor Velado | **Executor** |
| Asceta Celestial | **Asceta** |
| Baluarte Ossuário | **Cavaleiro de Ossos** |
| Caçador de Sepulturas | **Coveiro** |
| Profeta da Peste | **Arauto da Peste** |
| Lâmina do Contrato | **Sicário** |
| Dueto Infernal | **Domador** |
| Fera de Guerra | **Dilacerador** |
| Metamorfo Espectral | **Ancestral** |
| Predador da Mata | **Predador** |
| Fera do Eclipse | **Aberração** |
| Semeador da Podridão | **Semeador** |
| Herborista Sombrio | **Envenenador** |
| Dança Rubra | **Sanguinário** |
| Dançarino de Miragens | **Ilusionista** |
| Acrobata de Guerrilha | **Guerrilheiro** |
| Dervixe do Vazio | **Lunático** |
| Ceifador Dançante | **Ceifador** |
| Dançarino Feral | **Feral** |
| Lâmina Psíquica | **Mentalista** |
| Punho dos Ecos | **Médium** |
| Peregrino das Armadilhas | **Peregrino** |
| Punho do Abismo | **Abissal** |
| Marionetista dos Mortos | **Titereiro** |
| Mestre das Feras | **Totêmico** |
| Dançarino Marcial | **Dançarino** |

Documentos históricos (explorações, handoffs, contrato E00 e sua fixture) mantêm os nomes da
época. No runtime, só as três híbridas do MVP têm nome visível: Bastião (`sp_ar`), Possesso
(`mg_sp`) e Rastreador (`ar_mg`).

---

## Situação das 56

Todas as 56 híbridas estão descritas (14/11/2026). As 6 do MVP seguem o handoff de 13/09; as 50
restantes foram aprofundadas e revisadas pelo usuário nesta rodada. Próximo passo: briefings de arte
a partir das fichas.
