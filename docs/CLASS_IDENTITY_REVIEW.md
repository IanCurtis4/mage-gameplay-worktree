# Releitura de identidade das classes — rascunho para discussão

13/11/2026. Pedido do usuário: rever tema e personalidade das classes antes de
encomendar arte. A ordem é: primeiro as 8 bases, depois a fusão para as 16 classes
estendidas e, por fim, as híbridas. Os briefings de arte saem do que for decidido
aqui. Este documento é uma proposta: não muda o contrato E00 nem o runtime.

Classes com arte e kit aceitos (Espadachim, Mago e Arqueiro, suas seis estendidas e
as duas híbridas jogáveis) servem de referência. A releitura descreve essas classes,
mas não as refaz.

## 1. Diagnóstico: por que parte das híbridas parece crua

O handoff de 13/09 ([e00_hybrid_handoff_2026_09_13.md](references/e00_hybrid_handoff_2026_09_13.md))
criou um método que funcionou nas seis híbridas do MVP:

- cada classe estendida tem um **substantivo visual** (Defendente = placa,
  Berserker = ferida, Sentinela = linha, Caçador = mecanismo, Elementalista =
  energia, Espiritualista = vestígio);
- cada híbrida é a **fusão de dois substantivos** (placa + energia = inscrição;
  mecanismo + vestígio = rastro);
- a origem dá o objeto ou material, e a afinidade dá o fenômeno que acontece com ele.

As outras 50 híbridas da matriz ([HYBRIDS_56_EXPLORATION.md](HYBRIDS_56_EXPLORATION.md))
são anteriores a esse método e nunca passaram por ele. Há três causas visíveis:

1. **As dez estendidas novas não têm substantivo.** Sem "o que o Demonólogo é" num
   objeto ou fenômeno, as fusões caem para adjetivos: *escudo contratado*,
   *munição contratada*, *semente contratada*, *marca de cobrança*. Nas sete
   híbridas com o Demonólogo, "pacto" virou só uma troca de recurso, e o demônio,
   que é o centro da classe, quase some.
2. **A convenção de pareamento é mecânica.** A matriz combina sempre 2-1 com 2-1
   numa direção e 2-2 com 2-2 na inversa. Foi útil para cobrir a tabela, mas força
   pares sem afinidade temática (Demonólogo + Naturalista = *Jardineiro Infernal*)
   e deixa fora pares naturais (Demonólogo + Berserker, Necromante + Defendente).
   O próprio documento diz que a convenção pode ser trocada.
3. **As bases não têm personalidade, só lista de skills.** O roster de 13/09 define
   o que cada base faz, não quem ela é. Sem temperamento, a fusão de duas classes
   não tem como produzir um personagem; só produz um kit.

Proposta de método para esta rodada:
- **Base:** uma tensão central (o que essa pessoa busca e o que isso lhe custa).
- **Estendida:** um lado dessa tensão levado até o fim, com um substantivo visual.
- **Híbrida:** a origem decide a personalidade e o material; a afinidade decide o
  fenômeno.

## 2. As oito bases

Para cada base: a fantasia, a tensão que os dois ramos dividem, o temperamento, o
corpo (como se move e luta) e a leitura visual. Os substantivos dos ramos novos
são propostas no mesmo formato do handoff.

### Espadachim — o corpo como promessa *(arte aceita)*
- **Fantasia:** quem resolve as coisas de perto e aceita levar o golpe.
- **Tensão:** controle ↔ abandono. O Defendente promete não ceder; o Berserker
  promete não parar.
- **Temperamento:** direto, leal, desconfia de quem luta de longe.
- **Corpo:** pés plantados, peso baixo; os golpes vêm do quadril.
- **Ramos:** Defendente = **placa**; Berserker = **ferida** *(já definidos)*.

### Mago — o estudo do invisível *(arte aceita)*
- **Fantasia:** quem entende as regras do mundo melhor que os outros.
- **Tensão:** dominar ↔ escutar. O Elementalista impõe força à matéria; o
  Espiritualista ouve o que ficou para trás.
- **Temperamento:** curioso, um pouco distante, confiante no próprio método.
- **Corpo:** gestos amplos e precisos; o poder sai das mãos e do foco, não do
  corpo inteiro.
- **Ramos:** Elementalista = **energia**; Espiritualista = **vestígio** *(já definidos)*.

### Arqueiro — o olhar paciente *(arte aceita)*
- **Fantasia:** quem vence antes de o inimigo perceber que a luta começou.
- **Tensão:** esperar ↔ preparar. A Sentinela domina a linha que já existe; o
  Caçador cria o terreno onde a presa vai errar.
- **Temperamento:** calmo, observador, econômico nas palavras.
- **Corpo:** imóvel no tiro, rápido entre os tiros.
- **Ramos:** Sentinela = **linha**; Caçador = **mecanismo** *(já definidos)*.

### Acólito — a devoção
- **Fantasia:** quem recebeu algo maior que si mesmo e precisa decidir o que
  fazer com isso.
- **Tensão:** servir ↔ contemplar. O Sacerdote oferece a fé aos outros como
  proteção. O Cultista olha diretamente para o que adora, e o que ele adora olha
  de volta.
- **Temperamento:** sereno por fora e intenso por dentro; fala com quem não está ali.
- **Corpo:** postura ereta e ritual; ações em ritmo de liturgia (preparar, erguer,
  soltar), com um objeto sagrado sempre na mão (livro, sino, incensário).
- **Visual da base:** tecido simples, cordão, um símbolo que ainda não escolheu
  lado entre luz e sombra.
- **Ramos (proposta):** Sacerdote = **halo** (luz que envolve e delimita: aros,
  círculos, selos fechados); Cultista = **olho** (a percepção que se abre:
  fendas, pupilas, geometrias que não fecham).

### Bruxo — o poder emprestado
- **Fantasia:** quem quis mais do que nasceu podendo e foi buscar em outro lugar.
- **Tensão:** **negociar ↔ colher**. O Demonólogo consegue poder de *alguém*
  (uma vontade com desejos próprios). O Necromante consegue poder de *algo*
  (o que restou dos mortos, que já não quer nada).
- **Regra de família (handoff):** toda classe da família tem DoT e invocação. No
  Demonólogo, a entidade vem primeiro e a aflição a alimenta; no Necromante, a
  aflição prepara a morte e o servo nasce dela.
- **Temperamento:** ambicioso, pragmático, sempre fazendo contas; nunca o mais
  forte da sala, mas sabe quem é.
- **Corpo:** curvado sobre o próprio foco; gestos de oferecer e de puxar.
- **Visual da base:** couro escuro, marcas no próprio corpo (o preço já está
  sendo pago), um pequeno imp ou caveira de estimação.
- **Ramos (decisão do usuário, 13/11):** as duas classes invocam, mas a relação
  com a invocação é oposta. No Demonólogo ela é **simbiose**; no Necromante, **parasitismo**.
  - Demonólogo = **vínculo**. Tema: corrupção, poder e sofrimento alheio. Há um
    demônio para cada situação, e a troca é justa: o demônio luta pelo mestre e o
    mestre o fortalece em troca.
    - **Um arquétipo ativo por vez, sem tempo de vida.** Trocar de arquétipo é a
      decisão tática da classe.
    - **Três arquétipos:** tanque (um guerreiro demoníaco pesado), corpo a corpo
      (um ou mais cães demoníacos) e à distância (vários diabretes ou um único
      conjurador demoníaco grande).
    - **A vida circula pelo vínculo, nos dois sentidos:** o mestre pode tirar vida
      do demônio para se curar, ou dar a sua para fortalecê-lo.
    - **As maldições combinam com as habilidades inatas de cada demônio.** A aflição
      no inimigo é o alimento que o mestre oferece ao demônio, o que cumpre a regra
      de família (a entidade vem primeiro).
    - **Mais interdependência:** o que acontece com um afeta o outro.
  - Necromante = **podridão** (substitui "resto"). Tema: morte, decomposição,
    apodrecimento, fungos e doenças.
    - **Invocações livres:** até um limite de servos, cada um com tempo de vida
      próprio, sem arquétipo fixo.
    - **Os servos são descartáveis:** nascem da aflição (a doença prepara a morte,
      e o corpo levanta) e se desfazem em pó e fungo quando acabam.
    - **Pouco vínculo:** o Necromante usa e descarta.
- **Nomes dos demônios:** os de WoW e TES serviram só de referência de arquétipo.
  Os nomes e o visual precisam ser próprios do projeto.

### Druida — o ciclo
- **Fantasia:** quem pertence a um lugar antes de pertencer a uma pessoa.
- **Tensão:** **enraizar ↔ tornar-se**. O Naturalista faz o terreno lutar por ele.
  O Metamorfo deixa o próprio corpo virar o animal.
- **Temperamento:** paciente, territorial, sem pressa até o momento de não ter.
- **Corpo:** descalço e rente ao chão; os movimentos começam nos pés.
- **Visual da base:** fibra, casca, couro cru, pedras amarradas; cores de estação.
- **Ramos (proposta):** Naturalista = **raiz** (o que cresce do chão, se agarra e
  sustenta); Metamorfo = **pelagem** (pele, garra, crina: a fronteira do corpo que
  muda).

### Ladino — a oportunidade
- **Fantasia:** quem não aceita uma luta justa.
- **Tensão:** **sumir ↔ não parar**. O Assassino escolhe uma vítima e um momento.
  O Dervixe está sempre em movimento, e quem entra no seu caminho apanha.
- **Temperamento:** irônico, inquieto, leal só a quem já provou valor.
- **Corpo:** leve, assimétrico, sempre com um pé saindo; golpes curtos e de lado.
- **Visual da base:** couro justo, capuz, muitas lâminas pequenas, cores
  apagadas com um único detalhe chamativo.
- **Ramos (proposta):** Assassino = **sombra** (recorte, ausência, silhueta);
  Dervixe = **vendaval** (a brisa que vira vendaval; substituiu "órbita" em 14/11).

### Monge — a disciplina interior
- **Fantasia:** quem treinou tanto que o corpo e a mente deixaram de ser coisas
  diferentes.
- **Tensão:** **conter ↔ soltar**. O Elevado guarda a força e a projeta pela mente.
  O Campeão a solta no corpo, em sequências cada vez mais rápidas.
- **Temperamento:** contido, gentil, com humor seco; nunca começa a briga.
- **Corpo:** centro de gravidade baixo, mãos abertas; transições sem pausa entre
  golpes.
- **Visual da base:** tecido amarrado, faixas nas mãos, contas, pés descalços;
  poucas cores, muito contraste.
- **Ramos (proposta):** Elevado = **campo** (o espaço ao redor como extensão do
  corpo: esferas, ondas, objetos suspensos); Campeão = **ritmo** (sequência,
  impacto que se repete, rastros em contagem).

Bases aceitas pelo usuário em 13/11, com o Bruxo ajustado acima.

## 3. As dez estendidas novas

Formato do handoff de 13/09: kit em uma frase, personalidade e as quatro camadas
(cor, material, forma/silhueta, VFX). A regra do handoff vale aqui também: a leitura
precisa sobreviver com pouca saturação. As paletas são propostas e serão
revisadas na folha de referência de cada classe.

### Sacerdote — halo
- **Kit:** protege por área (santuário, égide coletiva) e pune o que não deveria
  existir (exorcismo, com bônus contra mortos-vivos e fantasmas).
- **Personalidade:** fica na frente dos outros de mãos abertas; firme, sem raiva.
- **Cor:** marfim, dourado pálido, azul-céu.
- **Material e forma:** linho, ouro fino, vidro de vitral; círculos fechados,
  simetria, verticais.
- **VFX:** aros que se fecham sobre o alvo, feixes verticais, poeira dourada que
  assenta devagar.

### Cultista — olho
- **Kit:** distorce a percepção dos inimigos (loucura, ataques redirecionados,
  ídolos) e fica mais forte quanto mais o campo enlouquece.
- **Personalidade:** em êxtase; sorri na hora errada e conversa com algo que
  ninguém vê. Ele adora; não negocia (essa é a diferença para o Demonólogo).
- **Cor:** preto-azulado, magenta, turquesa doentio.
- **Material e forma:** tecido em tiras, pele marcada, metal oxidado; olhos,
  espirais que não fecham, assimetria.
- **VFX:** pupilas que se abrem no chão, distorção da imagem, geometrias
  impossíveis; tentáculos de sombra que aparecem só por um instante.

### Demonólogo — vínculo
- **Kit:** um demônio de três arquétipos por vez (tanque, matilha ou artilharia),
  vida trocada pelo vínculo nos dois sentidos e maldições que alimentam o
  demônio ativo.
- **Personalidade:** ambicioso e calculista, mas cumpre o que promete; trata o
  demônio como sócio. Gosta do poder e do sofrimento que ele causa.
- **Cor:** preto-tinta, carmim e amarelo-bile (o fel), com brasa nos pontos de contato. Evitar o verde-néon
  associado a "fel" em outros jogos.
- **Material e forma:** couro, ferro marcado a fogo, correntes, pele com cicatrizes
  de contrato; elos, chifres, ganchos.
- **VFX:** um elo visível entre o mestre e o demônio, que pulsa e muda de cor
  conforme a vida flui num sentido ou no outro. Fumaça de enxofre e brasas. As
  maldições aparecem como marcas de ferro sobre a vítima.
- **Demônios:** cada um carrega uma marca igual à do mestre.
  - **Tanque:** um bloco de armadura e chifres com arma pesada.
  - **Matilha:** quadrúpedes magros, de costelas expostas.
  - **Artilharia:** um enxame de diabretes ou um conjurador alto. A escolha
    entre os dois está em aberto.

### Necromante — podridão
- **Kit:** doenças que se espalham, e os mortos levantam como servos temporários
  até um limite. Os servos são consumidos para outros efeitos.
- **Personalidade:** frio, paciente e curioso sobre a morte; vê corpos como
  colheita.
- **Cor:** verde-musgo apodrecido, ocre, marfim de osso, roxo de hematoma.
- **Material e forma:** osso, pano mortuário, terra, fungos; costelas, chapéus de
  cogumelo, manchas que se espalham.
- **VFX:** esporos, nuvens de doença, chão que apodrece e brota fungos; os servos
  se desfazem em pó e fungo ao expirar.
- **Cuidado:** o Naturalista também faz coisas crescerem. A diferença é que o
  Naturalista cresce do vivo e o Necromante cresce do morto.

### Naturalista — raiz
- **Kit:** faz o terreno trabalhar por ele: raízes que prendem, pedra que protege,
  jardins que curam.
- **Personalidade:** guardião sereno e territorial; fala pouco.
- **Cor:** verde-folha, marrom-terra, cinza-pedra, com flores em pontos isolados.
- **Material e forma:** madeira viva, pedra, musgo; raízes que se agarram,
  camadas de rocha.
- **VFX:** brotos subindo, pedra que emerge do chão, pétalas, seiva brilhante.

### Metamorfo — pelagem
- **Kit:** troca de forma: urso para aguentar, felino para se reposicionar, ave
  para atravessar. A troca tem custo previsível.
- **Personalidade:** instintivo; a voz e a postura mudam a cada forma.
- **Cor:** castanho, cinza-lobo, ocre, com pintura corporal que muda de cor
  conforme a forma.
- **Material e forma:** pele, amuletos de osso, garras. Na forma humana usa uma
  máscara ou um manto de pele de animal.
- **VFX:** a transformação explode em pelos ou penas; marcas de garra.
- **Custo de arte:** cada forma animal é uma folha de personagem a mais (três
  além da forma humana). É a estendida mais cara de produzir.

### Assassino — sombra
- **Kit:** escolhe uma vítima, some, entra pelas costas e decide entre executar ou
  sair.
- **Personalidade:** frio, profissional, paciente.
- **Cor:** preto, cinza-chumbo e um vermelho escuro como única cor viva.
- **Material e forma:** couro fosco e tecido que absorve a luz; silhueta fina,
  capuz, recortes.
- **VFX:** some num recorte de sombra e deixa rastro escuro; o único brilho é o da
  lâmina na hora do golpe pelas costas.

### Dervixe — vendaval
*Reescrito em 14/11; a ficha completa está em
[EXTENDED_CLASS_SPECS.md](EXTENDED_CLASS_SPECS.md).*
- **Kit:** dança trocando de vítima a cada passo; cada inimigo diferente aumenta o
  vento até o vendaval cortar tudo em volta. Transe de devaneio, malabarismo de facas
  e fintas.
- **Personalidade:** duelista, dançarino, trapaceiro e saltimbanco; leve, exibido e
  um pouco ausente.
- **Cor:** areia, turquesa, branco-vento, dourado e vermelho vivo nos tecidos.
- **Material e forma:** seda leve, fitas, guizos, facas no cinto; espirais, saias e
  faixas que abrem no giro, lâminas curvas.
- **VFX:** fitas de vento, poeira e folhas em espiral, redemoinho que cresce com o
  vento.

### Elevado — campo
- **Kit:** controla o espaço ao redor com a mente: telecinese, levitação, campos de
  força, e uma grande descarga com custo e janela de resposta.
- **Personalidade:** sereno e distante; parece sempre um pouco acima do chão.
- **Cor:** branco, azul-violeta, dourado leve.
- **Material e forma:** tecido leve, contas e pedras suspensas; esferas, círculos
  concêntricos.
- **VFX:** distorção do ar, ondas de pressão, objetos e pedras flutuando.

### Campeão — ritmo
- **Kit:** sequências de golpes cada vez mais rápidas, com saltos de impacto,
  redirecionamento e um final explosivo.
- **Personalidade:** competitivo e entusiasmado; trata a luta como treino.
- **Cor:** vermelho, laranja, preto, faixas brancas.
- **Material e forma:** faixas, luvas de couro, pele; punhos, diagonais rápidas.
- **VFX:** impactos que se repetem na contagem do combo, rastros de punho
  sobrepostos, onda de choque curta no golpe final.

## 4. Escopo das bases com invocação ou transformação

14/11, pedido do usuário. Regra do roster de 13/09: toda base antecipa os dois
ramos com versões simples das suas mecânicas. Isso já vale para as bases jogáveis:
o Mago tem fogo, gelo e Assombro, e o Arqueiro tem armadilhas. A questão é quanto
do verbo exclusivo do ramo pode aparecer na base sem tirar a graça da evolução.

Princípio proposto: **a base ensina a linguagem e o ramo entrega o verbo.** O
iniciante deve sentir o gosto dos dois caminhos, mas transformar-se de verdade
ou comandar um demônio é a recompensa de evoluir.

### Druida: aspectos, não formas
- **Proposta:** a Druida não se transforma. Ela invoca **aspectos**: o animal aparece
  como uma silhueta espectral sobreposta ao corpo, durante uma ação, e some.
  - Pele de Urso: proteção curta, com a silhueta de um urso por cima.
  - Garra Felina: golpe em arco com marcas de garra.
  - Salto da Ave: deslocamento com penas e silhueta de asas.
- **Os mesmos três animais do Metamorfo** (urso, felino e ave), para que a evolução
  pareça natural. O "lobo" do roster de 13/09 sai, porque não é uma das formas do
  Metamorfo.
- **O lado Naturalista** (raízes, broto, pedra) não muda: são skills de terreno.
- **Por quê:** a transformação é o que define o Metamorfo. Se a base já se
  transforma, a evolução vira "mais do mesmo". Os aspectos também cabem em todos
  os equipamentos e não exigem um corpo novo.
- **Arte:** só efeitos (silhuetas de aspecto, marcas de garra, penas). Nenhuma
  folha de personagem extra na base. As três formas completas do Metamorfo (urso,
  felino, ave) ficam para a arte da estendida.
- **Alternativa recusada nesta proposta:** uma forma curta de verdade na base
  (o "Forma de lobo curta" do roster). Ela custaria quatro folhas de corpo
  e anteciparia o verbo do Metamorfo.

### Bruxo: aflição, preço e um familiar
O Bruxo junta os dois ramos pelo que eles têm em comum: os dois ferem com aflições e
usam o que a aflição produz. Proposta de núcleo:
- **Afligir:** Praga menor e Toque debilitante (DoT e enfraquecimento). É a base das
  duas famílias.
- **Pagar:** Pacto vital, que troca a própria vida por poder. É o gesto que o
  Demonólogo transforma no vínculo de mão dupla.
- **Colher:** Colheita de essência, que drena vida de um alvo aflito. É o gesto que
  o Necromante transforma em parasitismo.
- **Uma invocação permanente pequena: o Diabrete.**
  - Um único diabrete, fraco, que ataca à distância.
  - O Bruxo pode dar vida a ele ou tirar vida dele, o vínculo em versão simples.
  - Prepara o Demonólogo sem entregar os arquétipos: o tanque e a matilha são da evolução.
- **Uma invocação temporária pequena: o Ossudo.**
  - Quando um inimigo aflito morre, pode levantar como um esqueleto fraco, com
    duração curta. Limite de um ou dois.
  - Prepara o Necromante sem entregar o exército: vários servos, consumo de servos
    e doença que se espalha são da evolução.
- **Arte:** dois corpos de criatura, o diabrete e o esqueleto, no mesmo formato
  direcional dos inimigos. Os dois são reaproveitados na evolução:
  - o diabrete vira a artilharia do Demonólogo, se o usuário escolher a opção
    "enxame de diabretes";
  - o esqueleto vira o servo básico do Necromante, com fungos e podridão.

### Outras bases
Acólito, Ladino e Monge não têm invocação nem transformação. A ocultação do Ladino
é um efeito de desenho (translucidez), sem arte extra de corpo.

### Arte extra que este escopo pede
Escopo aprovado pelo usuário em 14/11. Briefing:
[e08_codex_art_1117_brief.md](epics/e08_codex_art_1117_brief.md). Em ordem de
prioridade:
1. **Diabrete** e **Ossudo** (base do Bruxo, reaproveitados nas estendidas).
2. **Demônio tanque** e **cão demoníaco** (Demonólogo). O conjurador grande só se o
   usuário preferir esta opção ao enxame de diabretes.
3. **Formas do Metamorfo:** urso, felino e ave, quatro vistas cada.
4. **Efeitos de aspecto da Druida:** silhuetas de urso, felino e ave, garra e penas.
   São folhas de efeito, como as de 14/11.

## 5. Sobreposições a vigiar

- **Corpo que muda:** Berserker (ferida), Metamorfo (pelagem) e Campeão (ritmo).
  Fúria que custa sangue, corpo que vira bicho e disciplina que vira velocidade
  precisam ter silhuetas diferentes.
- **Algo invisível:** Espiritualista (vestígio de quem morreu), Cultista (olho do
  que nunca viveu), Demonólogo (vínculo com alguém que quer algo) e Necromante
  (podridão do que morreu). A regra de 13/09 continua valendo; os substantivos a
  deixam visível.
- **Proteção:** Defendente (posição do corpo), Sacerdote (halo de luz),
  Naturalista (terreno que sustenta) e Elevado (campo mental).
- **Invocação:** Demonólogo (um demônio permanente em simbiose) e Necromante
  (vários servos temporários e descartáveis). O Metamorfo vira animal, mas não
  invoca. Nenhuma classe jogável tem hoje uma fera de companhia; ela só existe no
  inimigo Mestre das Feras.

## 6. Próximos passos

1. Bases aceitas em 13/11.
2. Estendidas novas (seção 3): aprofundadas família por família em
   [EXTENDED_CLASS_SPECS.md](EXTENDED_CLASS_SPECS.md), a partir de 14/11, começando
   pelo Bruxo.
3. Híbridas: refazer o pareamento por afinidade temática, começando pelas sete do
   Demonólogo, com o método de fusão de substantivos.
4. Briefings de arte, em ordem: as cinco bases que faltam
   ([e08_codex_art_1116_brief.md](epics/e08_codex_art_1116_brief.md), escrito em
   13/11), as dez estendidas, demônios e servos, ícones de skill e híbridas.
