# E08 — Briefing de arte 1123 (escrito em 14/11/2026): híbridas de origem Espadachim e Mago

Escolha do usuário em 14/11, depois das entregas 1121 e 1122
([e08_codex_art_1121_brief.md](e08_codex_art_1121_brief.md),
[e08_codex_art_1122_brief.md](e08_codex_art_1122_brief.md)): o próximo lote de híbridas. Este
pedido cobre:
- **A.** o corpo (traje) das **oito híbridas de origem Espadachim e Mago**, nas quatro vistas;
- **B.** uma folha pequena com os **dois equipamentos** que ainda faltam a essas híbridas.

Fonte: as fichas em [HYBRIDS_56_V3.md](../HYBRIDS_56_V3.md), seção "Aprofundamento — origens
Espadachim e Mago", com os nomes simples de 14/11. As demais armas e escudos do lote já vieram nas
folhas H1 e H2 de 1120 (seção B). Os efeitos ficam para depois (seção C). As classes ainda não
existem no jogo; tudo entra em staging.

## Regras para esta rodada

Iguais às de 1121:
- **só imagegen**, saída salva byte a byte; edições viram nova versão (`_v2`, `_v3`);
- **destino exclusivo:** `assets/art/e08_codex_1123/characters/<id>/` e
  `assets/art/e08_codex_1123/equipment/`; não tocar em mais nada do projeto;
- não rodar o Godot nem scripts do projeto; sem commit;
- `provenance.json` em cada pasta, com:
  - `path`, `sha256`, `width`, `height`;
  - `generator: "Codex built-in imagegen"`, `request` e o **`prompt` exato**;
  - as referências usadas, com caminho e SHA256;
  - `idle_height_px` de cada folha de traje;
  - `crop_overrides`, se precisar de corte manual;
  - **`"selected": true`** na versão escolhida de cada vista ou folha;
- se faltar limite, seguir a prioridade e listar o que ficou de fora.

## Prioridade

1. **Vista sul dos oito trajes**, na ordem da tabela da seção A. O usuário confere as oito antes
   de seguir.
2. **Folha E1** de equipamento.
3. Vistas **leste** e **oeste** de cada traje, na mesma ordem.
4. Vista **norte** de cada traje.

**Escala entre vistas.** A mesma regra de 1121, que funcionou: todas as vistas ficaram entre
0,97 e 1,05 da vista sul. **O corpo parado (linha 1) de cada vista tem a mesma altura em pixels da
vista sul aprovada**, e a folha mantém o mesmo tamanho dela. Para a vista sul, usar uma folha de
**1254×1254** com o corpo parado em torno de **260 px**, como em 1121.

## A. Trajes das oito híbridas

### Formato (igual a 1121)

- Uma folha por vista (`south`, `east`, `west`, `north`), PNG **RGBA transparente**, grade
  **4×4 = 16 sprites** em células iguais, com faixas transparentes entre elas.
- **Linha 1:** parado (4). **Linha 2:** andando (4). **Linha 3:** ação (4, gesto da tabela).
  **Linha 4:** dano (2) e morte caída (2).
- **Morte:** a coluna 3 cai de joelhos e mãos, e a coluna 4 fica de bruços, compacta, como nas
  outras classes. Em 1122, o Cavaleiro caiu de costas na coluna 3, e a virada para de bruços
  ficou estranha.
- Proporção chibi do elenco, pixel art nítida, contorno escuro, sombreamento de 2–3 tons.
- **Mãos vazias e visíveis em todas as poses vivas**, com dedos legíveis. No perfil, a mão
  próxima e a distante ficam distintas. Na vista sul, **nenhum manto ou capa esconde uma das
  mãos** (foi o problema do Arauto em 1121).
- **Nenhuma arma, escudo, cajado, broquel ou lâmina no corpo**: são equipamentos separados. Um
  braço "de guarda" é só o braço, com a mão vazia.
- Sem efeito mágico, aura, esfera flutuante, pedra solta, chão, sombra projetada, texto ou grade.
  Cristais, contas e runas valem só presos ao traje.
- O perfil é desenhado como perfil, não espelhado nem retingido. **Os gestos da linha 3 são os
  mesmos nas quatro vistas**, inclusive no norte.

### Continuidade e silhueta

Como nas rodadas anteriores, a híbrida é **a mesma pessoa da base de origem**, com o rosto, o
cabelo e o porte dela:
- **Espadachim:** cabelo ruivo-castanho espetado e olhos azuis. Origem **Defendente**, silhueta
  de bloco.
- **Mago:** cabelo castanho e olhos castanhos. Origem **Elementalista**, silhueta de conjurador.

Quatro híbridas são a mesma pessoa em cada origem, então **as silhuetas das quatro precisam ser
bem diferentes entre si**.

**Espadachim:**
- **Paladino:** bloco ereto e simétrico, com elmo aberto e tabardo.
- **Silvano:** bloco irregular de pedra e madeira, mais largo embaixo.
- **Duelista:** esguio, com placa só num braço e capa curta.
- **Inabalável:** bloco baixo e firme, com a cabeça descoberta e faixas de monge.

**Mago:**
- **Taumaturgo:** túnica longa e reta de vitral.
- **Tempestário:** manto de folhas verdes vivas com cristais.
- **Lâmina Arcana:** fina e encapuzada.
- **Magister:** túnica clara e leve, de mangas largas.

O **Tempestário** não deve repetir a massa de folhas podres do Semeador de 1121: as folhas são
verdes vivas e o manto é curto, com o recorte do conjurador.

### Referências para anexar

Nesta ordem:
1. **a pessoa:** o atlas do jogo da classe base;
2. **a origem:** o atlas do Defendente ou da Elementalista;
3. **a afinidade:** a vista sul aprovada da classe da afinidade (coluna da tabela), só para
   material e cor;
4. **escala:** `assets/art/animations/directional/swordsman/body.png`.

Os atlas do jogo têm várias direções; usar a vista correspondente (as quatro primeiras linhas
para a vista sul). Para leste, oeste e norte, anexar também a vista sul aprovada da própria
híbrida.

| Referência | Caminho | SHA256 |
|---|---|---|
| Espadachim (pessoa e escala) | `assets/art/animations/directional/swordsman/body.png` | `f390cee8e028c4ec82c7310455107dfcc03e9e5f12a417167e8a108edeb05a7a` |
| Mago (pessoa) | `assets/art/animations/directional/mage/body.png` | `7fbf2b93a17168b0d6b5893fcf8315cc50eb5395b12245011bd54c3099ca026a` |
| Defendente (origem) | `assets/art/animations/directional/defender/body.png` | `376cff77afffde2ce602e1fec1f233ef489dec90f3a86fb6ca079fb19e292766` |
| Elementalista (origem) | `assets/art/animations/directional/elementalist/body.png` | `eb0c8823f0e595ce09abe587e269c31f58ef6ce9a9a4809caaeb9fc343f7fb56` |
| Sacerdote (afinidade) | `assets/art/e08_codex_1118/characters/priest/south.png` | `9f21a15a47f09a231b8c2efacfb9e01ee369fa093f534f8bb60e3c90ef7ef225` |
| Naturalista (afinidade) | `assets/art/e08_codex_1118/characters/naturalist/south.png` | `4ef6eaff803e9d56af6fe758e38c7a9321ab6f331b13c99833a428703f2a124b` |
| Assassino (afinidade) | `assets/art/e08_codex_1118/characters/assassin/south.png` | `432d1471ac4c6f12634e08fd9f8fc3bf0f3b8793d4dd7b617d942972ea3d1e67` |
| Elevado (afinidade) | `assets/art/e08_codex_1118/characters/ascended/south.png` | `cddf6996b95e6334baf2d2194bc270dceaec6c3f97a49a8a5f7d40aa6a8b6b4d` |

### Gabarito de prompt

O de 1121, trocando a referência de família pela afinidade:

> Use case: stylized-concept. Production 2D pixel-art game animation sprite sheet for RagRPG.
> Reference images: (1) the person whose identity you must preserve (face, hair, build), (2) the
> origin class, for silhouette and tailoring only, (3) the affinity class, for material and
> palette only, (4) the existing cast scale (chibi proportions, crisp pixel art, dark outline,
> 2–3 tone shading). If a reference is a tall 4x16 atlas, use just the four rows of the requested
> direction. Keep the SAME person as reference 1, now in a hybrid class outfit: [DESCRIÇÃO].
> Create one transparent RGBA PNG of 1254 × 1254 with exactly 4x4 separate full-body sprites in
> equal cells with clear transparent gaps, all facing [SOUTH/front | EAST/right profile |
> WEST/left profile | NORTH/back], about 260 px body height in row 1. Row 1 idle 4; row 2 walk 4
> in a true alternating gait; row 3 action 4: [GESTO]; row 4: two upright hurt reactions, then
> fall forward to hands and knees, then lie compactly and completely prone. Exactly two arms and
> two empty hands visible and separated from the body in every living pose, visible fingers; no
> cloak or cape hides a hand; in profile, near and far hands clearly separated. Swords, shields,
> bucklers, staffs and blades are separate game equipment: do not draw them. No magical effects,
> aura, floating orbs or stones, ground, cast shadows, captions, grid lines or text. Keep the
> outfit and asymmetry consistent across poses. Original design. Genuine transparent background.

Para leste, oeste e norte, acrescentar: *"Same character as the attached south sheet; redraw as a
true [direction] view, do not mirror or recolor it. Keep the same canvas size and the same body
height in pixels as the attached south sheet, and the same four row-3 gestures."*

### As oito classes

| Ordem | id | Híbrida (origem → afinidade) | Pessoa; origem; afinidade | Descrição para o prompt | Gesto de ação (linha 3) |
|---|---|---|---|---|---|
| 1 | `sp_ac` | Paladino (Espadachim → Acólito) | Espadachim; Defendente; Sacerdote | *the Defender's blocky armoured silhouette standing upright and symmetric like the Priest: polished silver plate, an open-faced helm that leaves the face and some hair visible, a sky-blue linen tabard with gold trim over the breastplate, a small engraved gold ring motif on the chest; silver, gold and sky blue* | erguer o braço da guarda à frente, firme (juramento); golpe de punho para a frente com o ombro atrás; mão aberta erguida, palma para cima (selo); as duas mãos no peito, cabeça baixa (égide) |
| 2 | `sp_dr` | Silvano (Espadachim → Druida) | Espadachim; Defendente; Naturalista | *the Defender's blocky silhouette, heavier and wider at the bottom, armour made of grey stone plates and living wood instead of steel, held together by green roots and moss, a few small pointed flowers; stone grey, moss green, brown, small flower accents* | plantar o pé e empurrar com as duas palmas à frente; agachar com uma palma no chão; braço da guarda erguido em bloqueio, pernas plantadas; erguer as duas mãos devagar, como se algo subisse do chão |
| 3 | `sp_la` | Duelista (Espadachim → Ladino) | Espadachim; Defendente; Assassino | *a slim fencer: fitted black leather coat, light silver plate ONLY on the guard arm and shoulder, a short dark cape over the other shoulder, dark red sash and gloves, slim boots; silver, black and dark red* | postura de aparo, braço da guarda à frente na altura do rosto; torcer com uma mão, como quem gira o braço do inimigo; estocada longa com uma mão vazia; recuo, saltando para trás |
| 4 | `sp_mo` | Inabalável (Espadachim → Monge) | Espadachim; Defendente; Elevado | *the Defender's blocky silhouette, low and planted, head uncovered: light silver plate over a white monk's gi, a blue-violet sash, white hand and forearm wraps leaving the fingers free, small stone beads sewn along the plate edges; silver, white and blue-violet* | braço da guarda à frente, plantado; empurrão com as duas palmas (repulsão); mãos juntas no peito, concentrado; pisão forte com os punhos baixos |
| 5 | `mg_ac` | Taumaturgo (Mago → Acólito) | Mago; Elementalista; Sacerdote | *the Elementalist's conjurer silhouette in a long straight robe whose panels look like stained glass (blue, red and yellow panes with dark lead lines) over white linen, gold trims and a gold collar like the Priest; blue, white, red, yellow and gold* | mãos erguidas traçando um círculo no ar; mão estendida, palma para baixo, à frente; as duas mãos unidas em prece; braço erguido apontando para cima (juízo) |
| 6 | `mg_dr` | Tempestário (Mago → Druida) | Mago; Elementalista; Naturalista | *the Elementalist's conjurer silhouette with a SHORT mantle of fresh living green leaves over the shoulders (not a rotten heavy pile), roots wrapping the forearms with small blue, red and yellow crystals set in them, a green robe below; the Naturalist's green with the three elemental colours as small accents* | agachar plantando, palma no chão; espalhar sementes com um gesto lateral; braços erguidos chamando chuva; mão estendida à frente, a outra no peito |
| 7 | `mg_la` | Lâmina Arcana (Mago → Ladino) | Mago; Elementalista; Assassino | *a thin hooded figure: deep black hood, fitted black and lead-grey layers like the Assassin, a short cape with a faintly reflective inner lining painted in thin blue, red and yellow highlights, face partly shadowed but visible; black and lead grey, small blue, red and yellow glints* | agachar furtivo, uma mão no chão; estocada de uma mão para a frente; corte em arco de baixo para cima (mão vazia); giro saindo, com a capa aberta |
| 8 | `mg_mo` | Magister (Mago → Monge) | Mago; Elementalista; Elevado | *the Ascended's light, serene silhouette: a pale white robe with wide sleeves, blue-violet sash, small crystal facets sewn at the collar and cuffs, a few tiny blue, red and yellow beads on the sash; white and blue-violet with small elemental accents* | mãos em concha em volta de algo invisível; braço estendido soltando para a frente; braços abertos com as palmas para cima; dedos girando sobre a cabeça |

## B. Equipamento novo (folha E1, `equipment/weapons_e1.png`)

Os escudos do Paladino e do Silvano, o broquel do Duelista e os três cajados do Taumaturgo, do
Tempestário e do Magister já vieram em 1120 (H1 e H2). Paladino, Silvano e Inabalável usam a
espada do Espadachim; a Lâmina Arcana usa o cajado da origem. Faltam só dois objetos:

| Ordem | id | Objeto | Híbrida |
|---|---|---|---|
| 1 | `rapier` | espada fina e reta de aço polido, guarda em concha simples e cabo escuro com um toque de vermelho | Duelista |
| 2 | `rune_shield` | escudo liso de aço claro, de frente, com runas de contenção gravadas em azul-violeta na borda | Inabalável |

Formato igual às folhas H1 e H2 de 1120:
- PNG RGBA transparente, cerca de 2172×724, **uma fileira**;
- dois objetos **separados, sem se tocar**, centralizados em cerca de 30% e 70% da largura;
- ilustração pintada (não pixel art), na vertical como é segurado; o escudo de frente.

Referência: `assets/art/e08_codex_1120/equipment/weapons_h1_v2.png`
(`b36825e12f9d3729bb5943ccf4ec5c9182b26616ac75c3dd76ee52e00b83016d`). Ela serve para o formato,
o traço e o tamanho, e tem o broquel e o escudo do Paladino, que precisam combinar com os novos.

**Gabarito:** o de 1120, com *"exactly 2 separate hand-painted fantasy equipment objects"* e a
lista acima. Fundo sem véu: alfa zero fora dos objetos.

## C. Rodadas seguintes (não pedir agora)

- **Trajes das outras 28 híbridas**, em lotes:
  - origens Arqueiro e Acólito (10);
  - Druida e Ladino (12);
  - Monge (6).
- **Corpos novos:** Carniçal de Raiz e Colosso Suspenso.
- **Camadas de placa do Cavaleiro de Ossos.**
- **Variantes de criatura do Demonólogo:** a seção C de
  [e08_codex_art_1120_brief.md](e08_codex_art_1120_brief.md).
- **Efeitos deste lote:**
  - Paladino: cone e coluna de luz;
  - Silvano: muralha em estágios e espinheiro;
  - Duelista: aparo e giro;
  - Inabalável: projétil suspenso e onda;
  - Taumaturgo: os três estados do círculo;
  - Tempestário: sementes elementais;
  - Lâmina Arcana: lâmina de cristal, refração e reflexos;
  - Magister: esferas e Eclíptica.

## Depois da entrega (Claude)

Conferir hashes, prompts e versões marcadas; medir a altura do corpo entre as vistas; verificar
os braços e os gestos da linha 3 nas quatro vistas; comparar as quatro de cada origem no tamanho
do jogo. Recortar a folha E1 e medir os grips. Tudo fica em staging até as classes ganharem kit.

## Entrega — 15/11/2026

O Codex entregou as oito híbridas nas quatro vistas e a folha E1 em `assets/art/e08_codex_1123/`.
A conferência automática passou:
- todos os PNG listados, com SHA256, largura e altura conferindo;
- todos em RGBA, com o gerador certo, o prompt exato e `idle_height_px`;
- as referências conferem pelos SHA256;
- nenhum arquivo ficou sem registro;
- uma versão marcada por vista e uma na folha E1.

Cada folha separa em 4×4 pelas faixas transparentes.

**Versões escolhidas e escala.** Altura do corpo parado em cada vista em relação à vista sul:

| id | Sul | Leste | Oeste | Norte |
|---|---|---|---|---|
| `sp_ac` Paladino | `south` (251 px) | `east_v2` 1,01 | `west` 1,03 | `north_v3` 1,00 |
| `sp_dr` Silvano | `south` (238 px) | `east_v2` 0,98 | `west_v6` 1,02 | `north_v3` 0,99 |
| `sp_la` Duelista | `south` (242 px) | `east` 1,00 | `west` 0,98 | `north_v2` 0,97 |
| `sp_mo` Inabalável | `south` (248 px) | `east` 0,99 | `west` 0,98 | `north` 1,00 |
| `mg_ac` Taumaturgo | `south` (253 px) | `east` 1,00 | `west_v2` 0,98 | `north` 0,99 |
| `mg_dr` Tempestário | `south` (212 px) | `east_v2` 1,01 | `west_v2` 1,02 | `north_v3` 0,97 |
| `mg_la` Lâmina Arcana | `south` (242 px) | `east_v3` 0,97 | `west_v4` 1,00 | `north_v2` 0,98 |
| `mg_mo` Magister | `south` (244 px) | `east_v2` 0,98 | `west_v3` 1,02 | `north` 1,01 |

Entre as vistas, a regra de escala segurou: tudo ficou entre 0,97 e 1,03. A altura absoluta ficou
abaixo dos 260 px pedidos (212 a 253 px); o empacotamento normaliza.

**Braços, gestos e morte.** Nas oito classes:
- as poses vivas têm dois braços e as mãos vazias e visíveis;
- nenhum manto ou capa esconde uma mão;
- os quatro gestos da linha 3 são os mesmos nas quatro vistas, inclusive no norte;
- na morte, a coluna 3 cai de joelhos e mãos e a coluna 4 fica de bruços.

A regra nova de morte funcionou em todas.

**Assimetria do Duelista.** Placa no braço direito e capa no ombro esquerdo, coerentes nas quatro
vistas: o leste mostra o lado direito (placa à frente), o oeste mostra o lado esquerdo (capa à
frente) e o norte tem a placa do lado direito da tela.

**Espadachim.** No tamanho do jogo, as quatro silhuetas são bem diferentes entre si:
- **Paladino:** prata, dourado e tabardo azul.
- **Silvano:** bloco verde-oliva e pedra.
- **Duelista:** preto e vermelho, com um só braço de placa.
- **Inabalável:** quimono branco e faixa violeta.

Duas diferenças aceitas:
- o **Paladino** usa uma tiara de placa em vez de elmo aberto; o rosto e o cabelo ficam visíveis,
  como pedido;
- o **Silvano** tem mais folha do que madeira: ombreiras e joelheiras de pedra, raízes e um manto
  de folhas. Ele não se confunde com o Semeador nem com o Tempestário, pelo cabelo, pela pedra e
  pelo tom mais escuro.

**Mago.** O Taumaturgo e a Lâmina Arcana estão certos. Duas classes têm problemas de pessoa:
- **Tempestário.** A vista sul marcada e as vistas leste, oeste e norte feitas a partir dela
  mostram outra pessoa: pele morena, cabelo comprido e ondulado repartido ao meio, outro rosto, e
  212 px de altura. A alternativa **`south_v4`** (260 px) tem a pessoa certa (pele clara, cabelo
  castanho curto e desalinhado, como o Taumaturgo), o traje pedido e os gestos certos. A
  alternativa `south_v3` copiou o vitral do Taumaturgo e não serve.
- **Magister.** O cabelo saiu bege-claro e fofo, diferente da pessoa do Mago, nas quatro vistas e
  na alternativa `south_v2`. O gesto 4 lê como as mãos segurando a cabeça (dor), não como dedos
  girando acima dela.

**Folha E1 (`weapons_e1_v3`).** Florete com guarda em concha e toque de vermelho; escudo liso de
aço claro com runas azul-violeta na borda. Os dois estão separados, em 30% e 69% da largura, no
mesmo traço de H1. O escudo tem 595 px de altura, maior que os escudos de H1; o tamanho no jogo é
definido no empacotamento. Há 10.962 px de véu (alfa 1–16), que vão a zero no empacotamento.

**Resultado.**
- **Aprovados para staging:** Paladino, Silvano, Duelista, Inabalável, Taumaturgo e Lâmina Arcana
  (quatro vistas cada) e a folha E1 (`weapons_e1_v3`).
- **Tempestário:** `south_v4` passa a ser a vista sul aprovada; leste, oeste e norte serão
  refeitos a partir dela.
- **Magister:** as quatro vistas serão refeitas.

Pedido de correção: [e08_codex_art_1124_brief.md](e08_codex_art_1124_brief.md).
