# E08 — Briefing de arte 1120 (escrito em 14/11/2026): híbridas do Demonólogo e armas das híbridas

Escolha do usuário em 14/11, depois da entrega das adagas
([e08_codex_art_1119_brief.md](e08_codex_art_1119_brief.md)). Este pedido cobre:
- **A.** o corpo (traje) das **sete híbridas do Demonólogo**, nas quatro vistas;
- **B.** duas folhas com as **armas das híbridas** que as fichas pedem.

Fonte de cada classe: as fichas em [HYBRIDS_56_V3.md](../HYBRIDS_56_V3.md) (seções "Visual" e
"Arte"), com os nomes simples aprovados em 14/11. As variantes de criatura (elementais do
Invocador, formas do Encarnado, demônios com faixas do Domador), os objetos, os ícones e os
efeitos ficam para rodadas seguintes (seção C). As classes ainda não existem no jogo; tudo entra
em staging.

## Regras para esta rodada

Iguais às de [e08_codex_art_1118_brief.md](e08_codex_art_1118_brief.md):
- **só imagegen**, saída salva byte a byte; edições viram nova versão (`_v2`, `_v3`);
- **destino exclusivo:** `assets/art/e08_codex_1120/characters/<id>/` e
  `assets/art/e08_codex_1120/equipment/`; não tocar em mais nada do projeto;
- não rodar o Godot nem scripts do projeto; sem commit;
- `provenance.json` em cada pasta, com `path`, `sha256`, `width`, `height`,
  `generator: "Codex built-in imagegen"`, `request`, as referências usadas (caminho e SHA256),
  o **`prompt` exato** e **`"selected": true`** na versão escolhida de cada vista ou folha;
- se faltar limite, seguir a prioridade e listar o que ficou de fora.

## Prioridade

1. **Vista sul dos sete trajes**, na ordem da tabela da seção A. O usuário confere as sete vistas
   sul antes de seguir.
2. **Folha H1** (lâminas, escudos e livros).
3. **Folha H2** (cajados e arcos).
4. Vistas **leste** e **oeste** de cada traje, na mesma ordem.
5. Vista **norte** de cada traje.

## A. Trajes das sete híbridas do Demonólogo

### Formato (igual às estendidas de 1118)

- Uma folha por vista (`south`, `east`, `west`, `north`), PNG **RGBA transparente**, cerca de
  1200×1300, grade **4×4 = 16 sprites** em células iguais, com espaço transparente entre elas.
- **Linha 1:** parado (4). **Linha 2:** andando (4). **Linha 3:** ação (4, gesto da tabela).
  **Linha 4:** dano (2) e morte caída (2).
- Proporção chibi do elenco, pixel art nítida, contorno escuro, sombreamento de 2–3 tons.
- **Mãos vazias e visíveis em todas as poses vivas**, com dedos legíveis; no perfil, a mão
  próxima e a distante distintas. **Nenhuma arma, cajado, arco, foco, livro, escudo ou bainha
  com lâmina no corpo**: são equipamentos separados (seção B ou folhas anteriores).
- Sem demônio, efeitos mágicos soltos, chão, sombra projetada, texto ou grade. O elo, as
  correntes de luz e as chamas são efeitos do jogo; no traje, só o que é tecido, metal ou pele.
- O perfil é desenhado como perfil, não espelhado nem retingido.

**Continuidade.** A híbrida é **a mesma pessoa da base de origem**, com o rosto, o cabelo e o
porte dela, no traje que a ficha descreve. A ficha já parte da silhueta da estendida de origem
(o Alfa é o Berserker, o Invocador é a Elementalista, e assim por diante); o Demonólogo entra
pelos detalhes de contrato: ferro marcado, correntes, cicatrizes em brasa, amuleto de chifre,
preto-tinta, carmim e amarelo-bile.

**Referências para anexar,** nesta ordem:
1. a estendida de origem (coluna "Referência de origem" abaixo);
2. a vista sul do Demonólogo, `assets/art/e08_codex_1118/characters/demonologist/south_v3.png`
   (`f507b3b9a034e2ab99ee44ae6d78bc6569dd8eaf6f60251e609d97fb24a0dee8`), para os detalhes de
   contrato;
3. `assets/art/animations/directional/swordsman/body.png`
   (`f390cee8e028c4ec82c7310455107dfcc03e9e5f12a417167e8a108edeb05a7a`), para a escala do elenco.

Para as vistas leste, oeste e norte, anexar também a vista sul aprovada da própria híbrida.

| Referência de origem | Caminho | SHA256 |
|---|---|---|
| Berserker (no jogo) | `assets/art/animations/directional/berserker/body.png` | `330b0c7e51a3d8289a7b3449b0428ead8c245ce444439fd5dd445f9627bda779` |
| Elementalista (no jogo) | `assets/art/animations/directional/elementalist/body.png` | `eb0c8823f0e595ce09abe587e269c31f58ef6ce9a9a4809caaeb9fc343f7fb56` |
| Sentinela (no jogo) | `assets/art/animations/directional/sentinel/body.png` | `9b6d9855a24efbbf6593d7f43fd6c2aeae5d4b24d93e82e1e5e8122ca0e5180d` |
| Sacerdote (1118) | `assets/art/e08_codex_1118/characters/priest/south.png` | `9f21a15a47f09a231b8c2efacfb9e01ee369fa093f534f8bb60e3c90ef7ef225` |
| Bruxo (1116) | `assets/art/e08_codex_1116/characters/warlock/south.png` | `c4bace0bef0af4b8a26801cace8be09b4b28291c3281c7e723e7fbf25ec1b338` |

As três primeiras são atlas do jogo com várias direções; usar a vista correspondente.

### Gabarito de prompt

> Use case: stylized-concept. Production 2D pixel-art game animation sprite sheet for RagRPG.
> Reference images: (1) the origin class of this character, (2) the Demonologist's contract
> details, (3) the existing cast scale (chibi proportions, crisp pixel art, dark outline, 2–3 tone
> shading). Keep the SAME person as reference 1 (face, hair, build), now in a hybrid class
> outfit: [DESCRIÇÃO]. Create exactly 4x4 separate full-body sprites in equal cells with
> transparent gaps, all facing [SOUTH/front | EAST/right profile | WEST/left profile |
> NORTH/back]. Row 1 idle 4; row 2 walk 4; row 3 action 4: [GESTO]; row 4 hurt 2 and collapsed
> death 2, all in that direction. Exactly two arms and two empty hands visible and separated from
> the body in every living pose, visible fingers; in profile, near and far hands clearly
> separated. Weapons, staffs, bows, books, foci, shields and sheathed blades are separate game
> equipment: do not draw them. No demon, no summoned creature, no magical effects, ground, cast
> shadows, captions, grid lines or text. Keep the outfit and asymmetry consistent across poses.
> Original design. Genuine transparent background.

Para leste, oeste e norte, acrescentar: *"Same character as the attached south sheet; redraw as a
true [direction] view, do not mirror or recolor it."*

### As sete classes

| Ordem | id | Híbrida (origem → afinidade) | Pessoa e referência de origem | Descrição para o prompt | Gesto de ação (linha 3) |
|---|---|---|---|---|---|
| 1 | `sp_br` | Alfa (Espadachim → Bruxo) | Espadachim, como o Berserker | *the Berserker's leaning aggressive stance, a dark fur mantle over the shoulders, dark iron and leather harness, an iron chain wrapped around one wrist with a short broken end hanging, ember-glowing contract scars on the forearms; red, brown and black with carmine and bile-yellow contract details* | golpe de cima para baixo com as mãos fechadas; puxar a corrente do pulso para si (chamando a matilha); bater no peito oferecendo o próprio sangue; apontar o alvo com o braço inteiro |
| 2 | `mg_br` | Invocador (Mago → Bruxo) | Maga, como a Elementalista | *the Elementalist's conjurer silhouette and layered robe in blue, white, red and yellow, worn over an ink-black pact undercoat, branded iron clasps, a thin chain belt, faint contract scars on the backs of the hands* | mão erguida conjurando; girar a mão trocando algo (a troca de elemento); empurrar com as duas mãos à frente; abrir os braços para o alto |
| 3 | `ar_br` | Mercenário (Arqueiro → Bruxo) | Arqueira, como a Sentinela | *the Sentinel's green and light-blue ranger gear, an iron chain worn across the chest like a bandolier, ink-black leather patches with carmine stitching, a quiver at the back with ember-orange arrow fletchings, a small horn charm at the belt* | postura de tiro com as mãos vazias (puxar a corda imaginária até o rosto); mão estendida comandando à frente; ajoelhar firmando o posto; puxar uma corrente esticada com as duas mãos |
| 4 | `ac_br` | Exorcista (Acólito → Bruxo) | Acólita, como o Sacerdote | *upright and symmetric, the Priest's ivory linen robe with gold trims over an ink-black undercoat, a gold metal chain hanging from one wrist, a gold ring clasp at the throat, small iron seals sewn along the stole; ivory and gold over ink black* | puxar uma corrente com uma mão erguida; mãos juntas em prece; mão estendida julgando; braços abertos de uma vez (o Exorcismo) |
| 5 | `br_dr` | Encarnado (Bruxo → Druida), forma humana | Bruxo | *the Warlock with ember-orange contract scars spreading over both arms up to the shoulders, sleeves torn away, hood, horn amulet and belt chain clearly visible (these pieces stay on the beast forms), sulfur-yellow glint in the eyes; ink-black, carmine, ember orange* | agachar como fera; mãos em garra; mão aberta sobre o peito (o demônio saindo); curvar-se para trás como quem se transforma |
| 6 | `br_la` | Sicário (Bruxo → Ladino) | Bruxo | *a slimmer, hooded Warlock in fitted black and lead-grey leather, deep hood, a short chain hanging from the belt (the ritual dagger is separate equipment), one carmine sash; black, lead grey, carmine* | estocada baixa pelas costas; agachar sumindo dentro do capuz; apontar marcando a vítima; golpe de cima para baixo |
| 7 | `br_mo` | Domador (Bruxo → Monge) | Bruxo | *the Warlock dressed as a sparring partner: sleeveless dark coat, white hand and forearm wraps leaving the fingers free, contract scars on the upper arms, a chain belt, light footwork stance; ink-black, carmine and white wraps* | soco curto; toque com dois dedos estendidos (a maldição); passo lateral de troca de lugar; postura de guarda |

## B. Armas das híbridas

### Formato (igual às folhas B1 e B2 de 1118)

Referências: `assets/art/e08_equipment_redesign/weapons_source_v2.png`
(`7c40563cf810daefa4a16a21e945e83aa34eb7a53ebf4ac3a258c8a2d7b6e9ca`), formato e estilo da folha;
`assets/art/e08_codex_1118/equipment/weapons_b1.png`
(`a4a088a4601b5c245aea177a6aaa37da058514f727cf734d8c6aae33d445fdfa`), cajados e livros;
`assets/art/e08_codex_1119/equipment/weapons_daggers.png`
(`1aecbcea607e526757c3ddef5ffc7fcd425e4aa30030366faf7dfdd39ad5474d`), lâminas.
- Uma folha **RGBA transparente**, cerca de 2172×724, objetos **numa fileira horizontal**, um de
  cada, cada um na sua coluna com espaço largo e transparente em volta: **nada se toca nem se
  sobrepõe** (foi o problema das adagas de 1118).
- Ilustração **pintada** de fantasia, como as armas atuais (não pixel art), contorno orgânico
  fino, volume legível pequeno (cerca de 80×130 px no jogo).
- Cada objeto **na vertical**, como seria segurado em pé (cabo para baixo). Escudos de frente.
- Sem mãos, personagem, texto, sombra projetada, moldura ou efeito.

**Gabarito:** *"Use case: stylized-concept. Asset type: original game equipment sprite source
sheet, transparent background. Ultrawide landscape native PNG around 2172 × 724, real RGBA,
exactly ONE horizontal row with exactly [N] separate hand-painted fantasy equipment objects, left
to right: [LISTA]. One object of each, upright as held (handle at the bottom), shields seen from
the front, each alone in its own column with a wide, completely clean transparent gap; nothing
touches or overlaps. Match the attached weapon sheets: fine organic outlines, painted metal, wood
and leather, neutral upper-left highlights, readable at about 80 × 130 px. No hands, people,
labels, letters, frame, grid, floor, cast shadow, drop shadow or effects. Genuine clear alpha
background."*

### Folha H1 — lâminas, escudos e livros (`equipment/weapons_h1.png`)

| Ordem | id | Objeto | Híbrida |
|---|---|---|---|
| 1 | `ritual_dagger` | punhal ritual de lâmina escura e reta, cabo de couro preto, com um pedaço curto de corrente preso ao pomo | Sicário |
| 2 | `contract_tome_crystal` | tomo de capa cristalina azulada envolto por uma corrente de ferro, com um cadeado | Invocador |
| 3 | `khopesh` | khopesh: lâmina em gancho como uma foice curta, bronze escurecido, cabo com fitas desbotadas | Ceifador |
| 4 | `buckler` | broquel redondo pequeno de aço polido com bossa central e borda escura | Duelista |
| 5 | `halo_shield` | escudo de aço polido com um aro dourado gravado e um vitral pequeno no centro | Paladino |
| 6 | `stone_shield` | escudo de pedra cinza com raízes vivas e musgo prendendo as placas | Silvano |
| 7 | `chained_prayer_book` | o livro de orações da Acólita preso a uma corrente comprida, como um mangual | Flagelante |
| 8 | `bladed_prayer_book` | o livro de orações da Acólita com uma lâmina fina saindo da lombada | Executor |

### Folha H2 — cajados e arcos (`equipment/weapons_h2.png`)

| Ordem | id | Objeto | Híbrida |
|---|---|---|---|
| 1 | `prism_staff` | cajado claro com um aro dourado no topo e um prisma no centro do aro | Taumaturgo |
| 2 | `crystal_living_staff` | cajado de madeira viva com folhas e um cristal na ponta | Tempestário |
| 3 | `orbital_staff` | cajado claro com um anel orbital inclinado em volta de uma esfera no topo | Magister |
| 4 | `chained_bow` | arco escuro envolvido por uma corrente de ferro, com detalhes carmim | Mercenário |
| 5 | `halo_bow` | arco claro com um aro dourado gravado no punho | Inquisidor |
| 6 | `living_bow` | arco de madeira viva com folhas brotando nas pontas | Patrulheiro |
| 7 | `knife_bow` | arco escuro com uma faca de caça presa ao punho | Emboscador |
| 8 | `beaded_bow` | arco liso de madeira clara com contas de madeira penduradas | Arqueiro Zen |

Cada arco desenhado sem corda frouxa e sem flecha. O livro acorrentado, o livro com lâmina e o
arco com faca são variantes visuais de equipamentos que já existem; não são tipos novos.

## C. Rodadas seguintes (não pedir agora)

- **Variantes de criatura do Demonólogo:** elementais do Invocador (Bruto de gelo, Cão de raio,
  Diabrete de fogo); formas do Encarnado (Bruto, Cão e Diabrete com uma peça do Bruxo); Bruto e
  Cão com as faixas do Campeão (Domador).
- **Trajes das outras 43 híbridas**, em lotes (próximo natural: as sete do Necromante).
- O restante da seção C de [e08_codex_art_1118_brief.md](e08_codex_art_1118_brief.md): corpos
  novos, objetos, cabeças de conjunto, ícones e efeitos.

## Depois da entrega (Claude)

Conferir hashes, prompts e versões marcadas; igualar a escala entre as vistas; montar os atlas e
calibrar mãos, dedos e cabeça; recortar as armas das folhas H1 e H2, medir os grips e criar os
ícones. Tudo fica em staging até as classes ganharem kit.

## Entrega — 14/11/2026

O Codex entregou tudo: as quatro vistas dos sete trajes e as duas folhas de armas, em
`assets/art/e08_codex_1120/`. Cada pasta tem `provenance.json`. A conferência automática passou:
- todos os PNG listados, com SHA256, largura e altura conferindo;
- todos em RGBA, com o gerador certo e o prompt exato;
- as referências conferem pelos SHA256;
- nenhum arquivo ficou sem registro;
- uma versão marcada por vista ou folha.

**Versões escolhidas pelo Codex.**

| id | Sul | Leste | Oeste | Norte |
|---|---|---|---|---|
| `sp_br` Alfa | `south` | `east` | `west` | `north_v2` |
| `mg_br` Invocador | `south` | `east` | `west_v3` | `north` |
| `ar_br` Mercenário | `south` | `east` | `west` | `north` |
| `ac_br` Exorcista | `south` | `east` | `west` | `north_v2` |
| `br_dr` Encarnado | `south` | `east` | `west_v2` | `north_v2` |
| `br_la` Sicário | `south` | `east_v3` | `west` | `north_v2` |
| `br_mo` Domador | `south` | `east` | `west` | `north` |

Equipamento: `weapons_h1_v2` e `weapons_h2`. A `weapons_h1` (v1) tem objetos encostados e não foi
marcada.

**Conferência visual dos trajes.** Nas sete classes as folhas são 4×4 com 16 poses. As mãos estão
vazias e separadas, não há arma, demônio nem efeito, e os gestos da linha 3 seguem a tabela. O
perfil é desenhado, não espelhado.
- **Alfa:** manto de pelagem, corrente no pulso, cicatrizes nos braços. O vermelho ficou discreto;
  predomina o marrom.
- **Invocador:** o casaco azul e branco da Elementalista, com laranja, corrente no peito e fechos
  de ferro.
- **Mercenário:** capuz e manto verde-oliva, a corrente cruzando o peito, aljava com penas em
  brasa. O azul-claro da Sentinela quase não aparece.
- **Exorcista:** linho marfim e dourado, corrente dourada no pulso, aro dourado atrás da cabeça.
- **Encarnado:** cicatrizes em brasa tomando os dois braços, mangas rasgadas, corrente no cinto.
  O capuz aparece nas costas.
- **Sicário:** capuz fundo, couro preto e chumbo, faixa carmim.
- **Domador:** colete sem mangas, faixas brancas nas mãos e antebraços, corrente no cinto.

**Para o empacotamento.**
- **Escala entre vistas.** Altura do corpo parado em relação à vista sul:
  - Sicário: leste 0,71 e oeste 0,78;
  - Encarnado: oeste 0,81;
  - Domador: leste 1,19;
  - as demais classes ficaram entre 0,97 e 1,05.

  O empacotador iguala a altura, como na Druida de 1116. Os tamanhos de folha variam (de
  1113×1413 a 1358×1159), e o recorte é por grade.
- **Leitura entre classes.** Alfa, Encarnado e Domador são o mesmo menino de cabelo castanho do
  elenco, com marrom, carmim e corrente. A diferença está no manto de pelagem, nas cicatrizes e nas
  faixas; vale conferir em jogo, no tamanho real.

**Conferência das armas.** As duas folhas trazem oito objetos cada, separados, sem mãos, texto ou
sombra.
- **H1:** colunas opacas separadas (de 55–200 a 1928–2131). Os objetos, na ordem pedida:
  - punhal com corrente no pomo;
  - tomo azul cristalino com corrente e cadeado;
  - khopesh de bronze com fitas;
  - broquel;
  - escudo com aro dourado e vitral;
  - escudo de pedra com raízes;
  - livro acorrentado;
  - livro com lâmina, que sai pelo alto do livro.
- **H2:** as colunas também estão separadas. Os objetos:
  - cajado com aro e prisma;
  - cajado de madeira viva com cristal;
  - cajado com anel orbital;
  - arco acorrentado com carmim;
  - arco claro com aro dourado no punho, discreto;
  - arco de madeira viva com folhas;
  - arco escuro com faca;
  - arco liso com contas.

  Os arcos vieram com a corda esticada e sem flecha.

Aprovada para staging. Nada foi pedido de novo.
