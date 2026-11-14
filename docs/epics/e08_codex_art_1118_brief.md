# E08 — Briefing de arte (18/11/2026): trajes das dez estendidas novas e armas novas

Fonte de cada classe: as fichas em [EXTENDED_CLASS_SPECS.md](../EXTENDED_CLASS_SPECS.md) (visual,
item 7) e as identidades em [CLASS_IDENTITY_REVIEW.md](../CLASS_IDENTITY_REVIEW.md), aprovadas pelo
usuário em 14/11. Este pedido cobre:
- **A.** o corpo (traje) das dez classes estendidas novas, nas quatro vistas;
- **B.** as armas novas dessas classes e das bases novas.

As híbridas, as variantes de criatura, os ícones e os efeitos ficam para rodadas seguintes
(seção C). As classes ainda não existem no jogo; tudo entra em staging.

## Regras para esta rodada

Iguais às de [e08_codex_art_1117_brief.md](e08_codex_art_1117_brief.md):
- **só imagegen**, saída salva byte a byte; edições viram nova versão (`_v2`, `_v3`);
- **destino exclusivo:** `assets/art/e08_codex_1118/characters/<id>/` e
  `assets/art/e08_codex_1118/equipment/`; não tocar em mais nada do projeto;
- não rodar o Godot nem scripts do projeto; sem commit;
- `provenance.json` em cada pasta, com `path`, `sha256`, `width`, `height`,
  `generator: "Codex built-in imagegen"`, `request`, as referências usadas (caminho e SHA256),
  o **`prompt` exato** e **`"selected": true`** na versão escolhida de cada vista ou folha;
- se faltar limite, seguir a prioridade e listar o que ficou de fora.

## Prioridade

1. **Vista sul dos dez trajes**, na ordem: Demonólogo, Necromante, Naturalista, Metamorfo,
   Sacerdote, Cultista, Assassino, Dervixe, Elevado, Campeão. O usuário confere as dez vistas
   sul antes de seguir.
2. **Folha B1 de armas** (focos, livros e cajados).
3. **Folha B2 de armas** (lâminas e punhos).
4. Vistas **leste** e **oeste** de cada traje, na mesma ordem.
5. Vista **norte** de cada traje.

## A. Trajes das dez estendidas

### Formato (igual às bases de 16/11)

- Uma folha por vista (`south`, `east`, `west`, `north`), PNG **RGBA transparente**, cerca de
  1200×1300, grade **4×4 = 16 sprites** em células iguais, com espaço transparente entre elas.
- **Linha 1:** parado (4). **Linha 2:** andando (4). **Linha 3:** ação (4, gesto da classe abaixo).
  **Linha 4:** dano (2) e morte caída (2).
- Proporção chibi do elenco, pixel art nítida, contorno escuro, sombreamento de 2–3 tons.
- **Mãos vazias e visíveis em todas as poses vivas**, com dedos legíveis; no perfil, a mão
  próxima e a distante distintas. **Nenhuma arma, foco, livro, escudo ou bainha com lâmina no
  corpo**: são equipamentos separados (seção B).
- Sem efeitos mágicos soltos, chão, sombra projetada, texto ou grade.
- O perfil é desenhado como perfil, não espelhado nem retingido.

**Continuidade (decisão do usuário em 14/11).** Cada estendida é **a mesma pessoa da base**, com o
rosto, o cabelo e o porte dela, num traje mais avançado. Sacerdote e Cultista são a Acólita;
Demonólogo e Necromante, o Bruxo; Naturalista e Metamorfo, a Druida; Assassino e Dervixe, o
Ladino; Elevado e Campeão, o Monge. É o que o Berserker fez com o Espadachim. As referências de
rosto e cabelo são as folhas de 16/11 em `assets/art/e08_codex_1116/characters/<base>/`. Aquela
rodada não marcou versões escolhidas; usar a versão listada na tabela "Entrega — 14/11/2026" de
[e08_codex_art_1116_brief.md](e08_codex_art_1116_brief.md) (por exemplo, `south_v5.png` do
Acólito).

**Referências para anexar:** a vista sul da base da classe (16/11) e
`assets/art/animations/directional/swordsman/body.png` (escala do elenco). Para as vistas leste,
oeste e norte, anexar também a vista sul aprovada da própria estendida.

### Gabarito de prompt

> Use case: stylized-concept. Production 2D pixel-art game animation sprite sheet for RagRPG.
> Reference images: the base character of this class and the existing cast (chibi proportions,
> crisp pixel art, dark outline, 2–3 tone shading). Keep the SAME person as the base reference
> (face, hair, build), now in an advanced class outfit: [DESCRIÇÃO]. Create exactly 4x4 separate
> full-body sprites in equal cells with transparent gaps, all facing [SOUTH/front | EAST/right
> profile | WEST/left profile | NORTH/back]. Row 1 idle 4; row 2 walk 4; row 3 action 4:
> [GESTO]; row 4 hurt 2 and collapsed death 2, all in that direction. Exactly two arms and two
> empty hands visible and separated from the body in every living pose, visible fingers; in
> profile, near and far hands clearly separated. Weapons, staffs, books, foci and sheathed blades
> are separate game equipment: do not draw them. Keep the outfit and asymmetry consistent across
> poses. No magical effects, ground, cast shadows, captions, grid lines or text. Original design.
> Genuine transparent background.

Para leste, oeste e norte, acrescentar: *"Same character as the attached south sheet; redraw as a
true [direction] view, do not mirror or recolor it."*

### As dez classes

| id | Classe (base) | Descrição para o prompt | Gesto de ação (linha 3) |
|---|---|---|---|
| `demonologist` | Demonólogo (Bruxo) | *now standing upright and calculating; long dark leather coat with branded iron plates, two chains crossing the chest, ember-glowing contract scars running up both forearms and onto the neck, a larger horn amulet, bile-yellow accents on buckles and eyes of the amulet; ink-black, carmine, bile yellow, ember orange; no neon green* | uma mão estendida comandando à frente; puxar uma corrente invisível; oferecer com a palma para cima; fechar o punho sobre algo |
| `necromancer` | Necromante (Bruxo) | *hunched under a heavy hooded mantle of burial cloth, rib bones used as clasps, small mushroom caps growing on the shoulders, rotten moss stains; rotten moss green, ochre, bone ivory, bruise purple* | erguer as duas mãos para levantar algo do chão; espalhar com um gesto lateral; puxar para si com as duas mãos |
| `naturalist` | Naturalista (Druida) | *firm low stance under a heavy rooted mantle of moss and leaves, layered stone plates on the shoulders, living-wood bracers, a few small flowers; leaf green, earth brown, stone grey, barefoot* | palma no chão; erguer as mãos como quem levanta uma parede; mão aberta à frente plantando; abrir os braços |
| `shapeshifter` | Metamorfo (Druida), forma humana | *wolf-grey animal pelt mantle with a hood shaped like an animal skull, stronger body paint stripes in ochre, green and amber, stone necklace and animal tooth, bone amulets, barefoot* | agachar como fera; gesto de garra; peito estufado como rugido; salto curto |
| `priest` | Sacerdote (Acólito) | *upright and symmetric, long ivory linen robe with thin gold trims, sky-blue stole, a stained-glass panel on the chest, a circular gold ornament behind the bun like a halo frame, sandals; ivory, pale gold, sky blue* | mãos juntas em prece; erguer as duas mãos abertas; mão estendida abençoando; mãos abrindo um círculo |
| `cultist` | Cultista (Acólito) | *slightly hunched forward with an ecstatic smile, robe torn into long strips, blue-black with magenta lining, eye-shaped marks painted on the arms, oxidized metal ornaments, asymmetric; blue-black, magenta, sickly turquoise* | mãos abertas ao lado do rosto; inclinar-se oferecendo; braços abertos em êxtase; apontar com dois dedos |
| `assassin` | Assassino (Ladino) | *slim and crouched, matte black fitted leather with angular cuts, deep hood, the half-face scarf, one dark red sash as the only colour; black, lead grey, one dark red* | estocada baixa; golpe pelas costas de cima para baixo; corte rápido em X; recuo agachado |
| `dervish` | Dervixe (Ladino) | *open silhouette caught mid-step, light silks in sand, turquoise and wind-white, long ribbons and small bells, wide flaring trouser panels, one vivid red sash, a few small empty pouches on the belt; sand, turquoise, white, gold, vivid red* | giro com os braços abertos; pirueta; lançamento com uma mão (malabarismo); reverência |
| `ascended` | Elevado (Monge) | *serene and upright, feet slightly above the ground in idle, light white robe, blue-violet sash, prayer beads worn at the neck with one bead hovering; white, blue-violet, light gold* | palma aberta empurrando à distância; duas mãos erguendo algo; braços abertos em campo; meditação flutuando |
| `champion` | Campeão (Monge) | *low wide stance and a competitive grin, training gear in red, orange and black, white hand and forearm wraps leaving fingers free, leather knee pads, a black belt with a knot* | soco direto; cotovelada; chute alto; postura de guarda pronta |

## B. Armas novas

### Formato (igual à folha das armas atuais)

Referência: `assets/art/e08_equipment_redesign/weapons_source_v2.png` (as sete armas atuais) e
`contact_sheet.png` na mesma pasta.
- Uma folha **RGBA transparente**, objetos **numa fileira horizontal**, bem espaçados, um de cada.
- Ilustração **pintada** de fantasia, como as armas atuais (não pixel art), proporções clássicas,
  contorno orgânico fino, volume legível em tamanho pequeno.
- Cada objeto **na vertical**, como seria segurado em pé (cabo para baixo).
- Sem mãos, personagem, texto, sombra projetada ou moldura.
- Cada objeto precisa ser reconhecível pequeno (cerca de 80×130 px no jogo).

**Gabarito:** *"Use case: stylized-concept. Asset type: original game equipment sprite source
sheet, transparent background. [N] separate hand-painted fantasy equipment objects, spaced widely
in one horizontal row: [LISTA]. One object of each, upright, no characters, no hands, no labels or
grid. Fine organic outlines, painted materials and readable volume at small scale, matching the
attached existing weapon sheet. Genuine transparent background, no cast shadow, no text."*

### Folha B1 — focos, livros e cajados (`equipment/weapons_b1.png`)

| Ordem | id | Objeto | Classe |
|---|---|---|---|
| 1 | `prayer_book` | livro de orações pequeno, capa de couro claro com um medalhão meio claro, meio escuro | Acólito (base) |
| 2 | `halo_scepter` | cetro de metal claro com um aro dourado no topo | Sacerdote |
| 3 | `eye_reliquary` | relicário de metal oxidado com um olho dentro, preso a uma corrente curta | Cultista |
| 4 | `contract_tome` | tomo de capa preta marcada a fogo, com uma corrente enrolada e um cadeado | Demonólogo |
| 5 | `bone_staff` | cajado de ossos amarrados, com um crânio pequeno e um fungo no topo | Necromante |
| 6 | `living_staff` | cajado de madeira viva com folhas e uma flor no topo | Druida e Naturalista |
| 7 | `floating_rosary` | rosário de contas de madeira em círculo, desenhado como se flutuasse | Elevado |

### Folha B2 — lâminas e punhos (`equipment/weapons_b2.png`)

| Ordem | id | Objeto | Classe |
|---|---|---|---|
| 1 | `daggers` | par de adagas retas simples, cruzadas | Ladino (base) |
| 2 | `curved_daggers` | par de adagas curvas de lâmina escura, cruzadas | Assassino |
| 3 | `scimitars` | par de cimitarras curvas de lâmina clara, com fitas no cabo | Dervixe |
| 4 | `hand_wraps` | um par de faixas de mão reforçadas com placas finas de couro | Monge (base) |
| 5 | `gauntlets` | um par de manoplas de couro e ferro, com os dedos livres | Campeão |

As armas de punho (faixas e manoplas) são presas às mãos, não seguradas; a integração vai exigir
calibração própria.

**Entrega (14/11):** as posições 1 e 2 vieram cruzadas e não dão recorte limpo; foram pedidas de
novo, uma lâmina de cada, em [e08_codex_art_1119_brief.md](e08_codex_art_1119_brief.md).

## C. Rodadas seguintes (não pedir agora)

Registro do que as fichas pedem, para os próximos briefings:
- **Trajes das 50 híbridas** (quatro vistas cada), em lotes.
- **Variantes de criatura com arte própria:**
  - elementais do Invocador (Bruto de gelo, Cão de raio, Diabrete de fogo);
  - formas do Encarnado (Bruto, Cão e Diabrete com uma peça do Bruxo);
  - Bruto e Cão com as faixas do Campeão (Domador);
  - formas do Predador, da Aberração e do Feral;
  - as três formas antropomórficas do Totêmico.
- **Corpos novos:** Carniçal de Raiz (Semeador); colossos do Necromante.
- **Objetos:** Filactério (Lich), cova (Coveiro), ídolos (Cultista, Profeta, Vigia),
  sementes da Naturalista e variantes, resto no chão (carcaça e ossos).
- **Armas de híbridas:** khopesh (Ceifador), broquel (Duelista), escudo com aro (Paladino),
  escudo de pedra (Silvano).
- **Cabeças de conjunto e ícones** das classes novas.
- **Efeitos** de cada classe (sementes, Santuário, Loucura, vento, Contagem e outros).

## Depois da entrega (Claude)

Escolher as versões marcadas, igualar a escala entre as vistas, montar os atlas V2 e calibrar mãos,
dedos e cabeça; recortar as armas, medir os grips e criar os ícones. Tudo fica em staging até as
classes ganharem kit.
