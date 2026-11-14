# E08 — Briefing de arte para o Codex (16/11/2026): sprites das cinco bases

Identidades aceitas pelo usuário em 13/11 em
[CLASS_IDENTITY_REVIEW.md](../CLASS_IDENTITY_REVIEW.md) (seção 2). Este pedido cobre
só o corpo das cinco classes base que ainda não têm arte: Acólito, Bruxo, Druida,
Ladino e Monge. Classes estendidas, híbridas, demônios, servos e ícones ficam para
briefings seguintes.

## Regras para esta rodada

- **Só gerar imagens.** Usar o imagegen embutido e salvar a saída byte a byte, sem
  editar o raster por código. Edições com imagegen (como "corrija só a pose da linha
  2, coluna 2") são permitidas e devem ser salvas como nova versão (`_v2`, `_v3`).
- **Destino exclusivo:** `assets/art/e08_codex_1116/characters/<classe>/`. Não tocar
  em `scripts/`, `tests/`, `tools/`, `docs/`, `.godot/`, catálogos, atlas ou arte já
  em uso.
- **Não rodar o Godot nem scripts Python** do projeto.
- **Sem commit.**
- **Proveniência obrigatória com prompt exato.** Em cada pasta de classe, um
  `provenance.json` com, por arquivo: `path`, `sha256`, `width`, `height`,
  `generator: "Codex built-in imagegen"`, `request` (classe e vista), as imagens de
  referência usadas (caminho e SHA256) e **`prompt` com o texto exato enviado**.
- Se faltar limite, seguir a ordem de prioridade abaixo e listar o que ficou de fora.
- Ao terminar, avisar o usuário com a lista de arquivos e qualquer item refeito
  ou pulado.

## Prioridade

1. **Vista sul (de frente) das cinco classes**, na ordem Acólito, Bruxo, Druida,
   Ladino, Monge. É a vista que define o personagem; as outras três partem dela.
2. Vistas **leste** e **oeste** de cada classe, na mesma ordem, usando a vista sul
   aprovada da classe como referência.
3. Vista **norte** (de costas) de cada classe.
4. Opcional: variante **sem cabelo volumoso** (`bare_head`) da vista sul, para
   chapéus e elmos. Só se sobrar limite.

O usuário confere as cinco vistas sul assim que saírem. Se uma for recusada, a
classe para até ser refeita, e as outras seguem.

## Formato (igual ao elenco atual)

Referências de estilo, para anexar ao imagegen:
- `assets/art/e08_characters/directional/spiritualist/south_source_v3.png`
  (personagem criado do zero nas quatro vistas; mesmo tamanho de folha);
- `assets/art/animations/directional/swordsman/body.png` (escala e proporção do
  elenco no jogo).

Cada folha:
- PNG **RGBA transparente**, cerca de **1200×1312** (como as da Espiritualista).
  O tamanho exato pode variar; o empacotador recorta.
- Grade **4×4 = 16 sprites** de corpo inteiro, em células iguais com espaço
  transparente entre elas.
- **Linha 1:** parado (4). **Linha 2:** andando (4). **Linha 3:** ação (4, com o
  gesto da classe descrito abaixo). **Linha 4:** dano (2) e morte caída (2).
- **Todas as poses viradas para a mesma direção.** Uma folha por direção: `south`,
  `east`, `west`, `north`.
- **Proporção chibi** do elenco: cabeça grande, pixel art nítida, contorno escuro,
  sombreamento de 2–3 tons.
- **Mãos vazias e visíveis em todas as poses vivas.** Exatamente dois braços e duas
  mãos, separadas do corpo, com dedos legíveis. No perfil (leste/oeste), a mão
  próxima e a distante ficam claramente distintas. Armas, escudos, livros, cajados
  e focos são equipamentos separados do jogo: **nunca desenhá-los no corpo**, nem
  bainhas com lâmina, nem objetos nas mãos.
- Sem efeitos mágicos, chão, sombra projetada, texto, grade ou moldura.
- O perfil (leste/oeste) é desenhado como perfil de verdade (um olho visível,
  torso de lado). Não espelhar nem retingir a vista sul.
- A mesma roupa, assimetria, cores e escala nas quatro vistas.

### Gabarito de prompt

Para cada vista, substituir os campos entre colchetes:

> Use case: stylized-concept. Production 2D pixel-art game animation sprite sheet
> for RagRPG. Reference images: the existing cast (chibi proportions, crisp pixel
> art, dark outline, 2–3 tone shading); match their scale and
> style exactly. Character: [DESCRIÇÃO DA CLASSE]. Create exactly 4x4 separate
> full-body sprites in equal cells with transparent gaps, all facing
> [SOUTH/front | EAST/right profile | WEST/left profile | NORTH/back]. Row 1 idle 4;
> row 2 walk 4; row 3 action 4: [GESTO DE AÇÃO]; row 4 hurt 2 and collapsed death
> 2, all in that direction. Exactly two arms and two empty hands visible and
> separated from the body in every living pose, physically plausible anatomy,
> visible fingers; in profile, near and far hands clearly separated in depth.
> Weapons, shields, books, staffs and held objects are separate game equipment:
> do not draw any of them, no sheathed blades. Keep identity, hair and asymmetric
> costume consistent across poses. No magical effects, ground, cast shadows,
> captions, grid lines or text. Genuine transparent background.

Para as vistas leste, oeste e norte, anexar também a vista sul aprovada da classe
e acrescentar: *"Same character as the attached south sheet; redraw as a true
[direction] view, do not mirror or recolor it."*

## As cinco classes

Cada classe é a raiz de dois ramos. O traje deve mostrar um iniciante que ainda não
escolheu o caminho, com pequenos sinais dos dois lados. As classes estendidas
virão depois com trajes próprios.

### Acólito (`acolyte`) — a devoção
- **Personagem:** jovem, postura ereta e serena, olhar intenso.
- **Traje:** túnica simples de linho cru até as canelas, com um cordão amarrado na
  cintura. Estola estreita: um lado azul-céu desbotado (o Sacerdote), o outro
  ameixa-escuro (o Cultista). Um pequeno medalhão circular no peito, metade claro e
  metade escuro. Sandálias.
- **Cores:** marfim, linho cru, azul-céu desbotado, ameixa, um toque de dourado
  pálido.
- **Gesto de ação:** ritual em três tempos: mãos juntas em prece, mãos erguidas
  com as palmas para cima, uma mão estendida à frente como quem abençoa ou
  condena.
- **Descrição para o prompt:** *a young serene acolyte with an upright ritual
  posture, plain undyed linen robe to the shins tied with a cord, a narrow stole
  faded sky-blue on one side and dark plum on the other, a small round medallion
  half light half dark on the chest, sandals; ivory, raw linen, faded sky blue,
  plum, a hint of pale gold.*

### Bruxo (`warlock`) — o poder emprestado
- **Personagem:** magro e um pouco curvado, sorriso de quem já fez as contas.
- **Traje:** casaco curto de couro escuro sobre camisa cinza; capuz baixo para
  trás. Antebraços enfaixados, com marcas de contrato (linhas e cicatrizes de brasa)
  aparecendo entre as faixas: **o preço já está sendo pago no corpo**. Cinto com uma
  corrente curta e um pequeno amuleto de chifre (o Demonólogo) e uma bolsinha de
  ossos (o Necromante). Botas gastas.
- **Cores:** preto-tinta, marrom-couro escuro, cinza; carmim nas marcas; amarelo-bile
  em detalhes pequenos (fivela, olhos do amuleto). **Sem verde-néon.**
- **Gesto de ação:** uma mão puxando algo para si, a outra oferecendo à frente com
  a palma para cima. Variar entre puxar, oferecer e um gesto de fechar a mão sobre
  algo invisível.
- **Descrição para o prompt:** *a lean, slightly hunched warlock with a knowing
  smile, short dark leather coat over a grey shirt, hood down, bandaged forearms
  with glowing ember-like contract scars showing between the wraps, belt with a
  short chain, a small horn amulet and a tiny pouch of bones, worn boots;
  ink-black, dark leather brown, grey, carmine marks, small bile-yellow accents,
  no neon green.*

### Druida (`druid`) — o ciclo
- **Personagem:** paciente e territorial; descalço, sempre perto do chão.
- **Traje:** manto curto de fibra trançada e couro cru, com folhas secas presas nos
  ombros. Colar de pedras amarradas e um pequeno dente de animal (o Metamorfo); um
  broto verde nascendo de um ombro ou do cabelo (o Naturalista). Faixas de
  casca nas canelas, pés descalços.
- **Cores:** verde-musgo, marrom-terra, ocre, cinza-pedra, com um único verde vivo
  (o broto).
- **Gesto de ação:** postura baixa, com uma palma em direção ao chão e a outra
  aberta à frente; um gesto de agarrar como garra; um gesto de subir as duas mãos.
- **Descrição para o prompt:** *a patient, grounded barefoot druid, short mantle of
  woven fibre and raw leather with dry leaves pinned at the shoulders, necklace of
  bound stones and a small animal tooth, a single bright green sprout growing from
  one shoulder, bark wraps on the shins; moss green, earth brown, ochre, stone
  grey, one vivid green accent.*

### Ladino (`rogue`) — a oportunidade
- **Personagem:** leve, assimétrico, sempre com um pé saindo; sorriso irônico.
- **Traje:** gibão de couro justo cinza-chumbo, capuz curto e lenço cobrindo metade
  do rosto. Muitas tiras e bolsinhas (bainhas vazias, sem lâmina). Uma faixa de
  tecido vermelho no braço é a única cor viva. Uma perna da calça mais justa e a
  outra com faixa solta (sombra e giro). Botas macias.
- **Cores:** cinza-chumbo, marrom-couro, preto apagado e um único vermelho.
- **Gesto de ação:** golpes curtos e de lado: estocada baixa, corte cruzado, giro
  com o braço aberto, recuo agachado. A mão de golpe fica vazia, porque a adaga é
  equipamento.
- **Descrição para o prompt:** *a light, asymmetric rogue with a wry smile, always
  leaning to move, fitted lead-grey leather jerkin, short hood and a scarf over
  half the face, many straps and small pouches with empty sheaths, one red cloth
  band on an arm as the only vivid colour, one tight trouser leg and one with a
  loose wrap, soft boots; lead grey, leather brown, muted black, a single red.*

### Monge (`monk`) — a disciplina interior
- **Personagem:** contido e gentil, centro de gravidade baixo; humor seco no olhar.
- **Traje:** roupa de tecido cru amarrada, sem mangas num braço; faixa laranja
  apagada na cintura. Faixas brancas nas mãos e nos antebraços, com os dedos de
  fora e legíveis. Um colar curto de contas de madeira com uma conta que parece
  flutuar levemente (o Elevado). Joelheiras gastas (o Campeão). Pés descalços.
- **Cores:** creme, marrom, laranja apagado, branco das faixas; muito contraste e
  poucas cores.
- **Gesto de ação:** palmada para a frente, golpe de cotovelo, chute baixo e uma
  pose de respiração com as duas palmas abertas.
- **Descrição para o prompt:** *a calm, gentle monk with a low centre of gravity and
  dry humour in the eyes, tied undyed cloth garments sleeveless on one arm, faded
  orange sash, white hand and forearm wraps leaving fingers free and readable, a
  short wooden prayer-bead necklace with one bead floating slightly, worn knee
  pads, barefoot; cream, brown, faded orange, white wraps, high contrast.*

## Gênero e variedade

O elenco atual mistura personagens masculinos e femininos. Proposta: Acólito e
Druida femininos; Bruxo, Ladino e Monge masculinos. O usuário pode trocar antes do
envio; basta ajustar a palavra na descrição.

## Depois da entrega (Claude)

Recortar cada folha pela receita direcional existente, montar o atlas V2 (256×1024,
64 células de 64×64, pivô 32,58) e fazer a calibração de mãos, dedos e cabeça das
64 poses, como no restante do elenco. As classes ainda não existem no jogo. Até
terem kit, a arte fica em staging, fora da descoberta automática, e não aparece no
menu.

## Entrega — 14/11/2026

O Codex entregou as quatro vistas das cinco classes em
`assets/art/e08_codex_1116/characters/<classe>/`, com `provenance.json` por classe e o
prompt exato de cada arquivo. Os 33 PNG conferem com os SHA256 registrados. Há
versões intermediárias, e o Codex não marcou qual é a final. A conferência usou a
versão mais alta de cada vista:

| Classe | Sul | Leste | Oeste | Norte |
|---|---|---|---|---|
| Acólito | `south_v5` | `east_v3` | `west_v3` | `north` |
| Bruxo | `south` | `east` | `west` | `north` |
| Druida | `south_v8` | `east_v4` | `west_v2` | `north_v6` |
| Ladino | `south_v7` | `east_v2` | `west_v2` | `north` |
| Monge | `south_v7` | `east_v2` | `west_v2` | `north` |

Conferência visual: estilo e proporção coerentes com o elenco, 16 poses por folha,
mãos vazias e separadas, sem armas. Observações para o empacotamento e a calibração:

- As vistas leste e oeste da Druida estão desenhadas em escala maior que a sul. O
  empacotador precisa igualar a altura do corpo entre as vistas.
- O broto verde da Druida e a conta flutuante do Monge quase não aparecem.
- Quatro das cinco classes têm cabelo castanho. A leitura continua boa pela roupa
  e pela silhueta, mas a variedade de elenco ficou menor que o planejado.
- Os tamanhos de folha variam (de 1108×1420 a 1366×1152). O recorte é por grade, não
  por tamanho fixo.

Empacotamento e calibração ainda não feitos.
