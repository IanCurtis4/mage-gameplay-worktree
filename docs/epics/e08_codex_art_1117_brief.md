# E08 — Briefing de arte para o Codex (17/11/2026): invocações, formas e aspectos

Escopo aprovado pelo usuário em 14/11 em
[CLASS_IDENTITY_REVIEW.md](../CLASS_IDENTITY_REVIEW.md), seção 4. Este pedido cobre os
corpos de criatura e os efeitos que esse escopo exige:
- as invocações do Bruxo (base) e do Demonólogo;
- as formas do Metamorfo;
- os aspectos da Druida.

As classes ainda não existem no jogo; a arte entra em staging.

## Regras para esta rodada

Iguais às de [e08_codex_art_1116_brief.md](e08_codex_art_1116_brief.md):
- **só imagegen**, saída salva byte a byte; edições com imagegen viram nova versão
  (`_v2`, `_v3`);
- **destino exclusivo:** `assets/art/e08_codex_1117/creatures/<id>/` e
  `assets/art/e08_codex_1117/vfx/`; não tocar em mais nada do projeto;
- não rodar o Godot nem scripts do projeto; sem commit;
- `provenance.json` em cada pasta, com `path`, `sha256`, `width`, `height`,
  `generator: "Codex built-in imagegen"`, `request`, as referências usadas (caminho e
  SHA256) e **`prompt` com o texto exato**;
- **novo nesta rodada:** em cada `provenance.json`, marcar a versão escolhida de cada
  vista com `"selected": true`. Na rodada de 16/11 isso faltou.
- Se faltar limite, seguir a prioridade e listar o que ficou de fora.

## Prioridade

1. **Diabrete** e **Ossudo**: vista sul primeiro; depois leste, oeste e norte.
2. **Bruto demoníaco** e **Cão demoníaco**: na mesma ordem de vistas.
3. **Efeitos de aspecto da Druida** (três folhas de efeito).
4. **Formas do Metamorfo**: urso, felino e ave, na mesma ordem de vistas.

Se o limite estiver acabando, **fechar a vista sul de todos os itens dos grupos 1 e
2 antes das outras vistas**. Com a vista sul aprovada, as demais podem ser
pedidas depois por outra ferramenta, usando a sul como referência.

## Formato dos corpos (igual ao elenco e aos inimigos atuais)

Referências de estilo para anexar:
- `assets/art/e08_codex_1116/characters/warlock/south.png` (o Bruxo; mesmo estilo e
  escala do mestre das invocações);
- `assets/art/e08_enemies/directional/animal_companion/east_source_v1.png` (criatura
  quadrúpede pequena do elenco atual);
- para o Metamorfo: `assets/art/e08_codex_1116/characters/druid/south_v8.png`.

Cada folha:
- PNG **RGBA transparente**, cerca de 1200×1300, grade **4×4 = 16 figuras** em células
  iguais com espaço transparente entre elas;
- **linha 1:** parado (4); **linha 2:** andando (4); **linha 3:** ataque (4, descrito
  em cada criatura); **linha 4:** dano (2) e morte caída (2);
- todas as figuras viradas para a mesma direção, **uma folha por vista**: `south`,
  `east`, `west`, `north`. O perfil é desenhado como perfil de verdade, não espelhado;
- pixel art chibi do elenco, contorno escuro, sombreamento de 2–3 tons;
- **as criaturas trazem a própria arma no desenho**, quando têm uma. Não há equipamento
  separado para elas;
- quadrúpedes com quatro patas e uma cauda coerentes em todas as figuras;
- sem efeitos mágicos soltos, projéteis, chão, sombra projetada, texto ou grade.
  Brilhos que fazem parte do corpo (olhos, rachaduras incandescentes) são permitidos;
- **sem sangue explícito ou gore.**

**Tamanho na célula:** a altura de referência é a do Bruxo. O jogo pode ampliar uma
criatura inteira na hora de desenhar, então o tamanho relativo abaixo é só uma
proporção. A escala precisa ser constante entre as 16 figuras e entre as quatro vistas.

### Gabarito de prompt

> Use case: stylized-concept. Production 2D pixel-art game animation sprite sheet
> for RagRPG. Reference images: the existing cast (chibi proportions, crisp pixel
> art, dark outline, 2–3 tone shading); match their style. Creature: [DESCRIÇÃO].
> Create exactly 4x4 separate full-body figures in equal cells with transparent
> gaps, consistent scale and ground, all facing [SOUTH/front | EAST/right profile |
> WEST/left profile | NORTH/back]. Row 1 idle 4; row 2 walk 4; row 3 attack 4:
> [ATAQUE]; row 4 hurt 2 and collapsed death 2, all in that direction. [ANATOMIA].
> Original design, not based on any existing game's creature. No loose magical
> effects, projectiles, gore, ground, cast shadows, captions, grid lines or text.
> Genuine transparent background.

Para leste, oeste e norte, anexar a vista sul aprovada da criatura e acrescentar:
*"Same creature as the attached south sheet; redraw as a true [direction] view, do
not mirror or recolor it."*

## Grupo 1 — Invocações do Bruxo (base)

### Diabrete (`imp`)
- **Papel:** o familiar permanente do Bruxo, fraco e à distância. Mais tarde, várias
  cópias formam a artilharia do Demonólogo.
- **Tamanho:** cerca de metade da altura do Bruxo.
- **Visual:** criatura pequena e magra, de pele carmim-escura, com pequenos chifres
  curvos, orelhas grandes e pontudas, olhos amarelo-bile e cauda fina terminada em
  ponta. Rachaduras de brasa nos ombros. No pescoço, uma pequena marca de ferro igual
  às cicatrizes de contrato do Bruxo: é a marca do vínculo. Sorriso travesso.
- **Ataque:** gestos de lançar com uma mão (preparar, girar o braço, arremessar,
  recuperar). Sem projétil desenhado.
- **Descrição para o prompt:** *a small, wiry imp familiar about half the height of
  the warlock, dark carmine skin, small curved horns, large pointed ears, bile-yellow
  eyes, a thin tail with a pointed tip, faint ember cracks on the shoulders, a small
  iron brand mark on the neck, mischievous grin; ink-black, carmine, bile-yellow,
  ember orange.*
- **Anatomia:** *two arms with small clawed hands, two legs, one tail.*

### Ossudo (`bone_servant`)
- **Papel:** o esqueleto temporário que se levanta de um inimigo aflito. Mais tarde,
  o servo básico do Necromante.
- **Tamanho:** quase a altura do Bruxo, curvado.
- **Visual:** esqueleto pequeno e torto, ossos amarelados, com **fungos** crescendo no
  crânio e nos ombros (chapéus de cogumelo em ocre e roxo-hematoma), musgo podre nas
  juntas, trapos de pano mortuário. Olhos com um brilho fraco verde-musgo. Deve
  parecer frágil e descartável, não um guerreiro.
- **Ataque:** golpes desajeitados com os braços nus (arranhar, empurrar, morder com
  o crânio projetado). Sem arma.
- **Morte:** desmonta em ossos e pó de esporos.
- **Descrição para o prompt:** *a small, crooked skeleton servant, yellowed bones,
  ochre and bruise-purple mushroom caps growing from the skull and shoulders, rotten
  moss on the joints, scraps of burial cloth, faint moss-green eye glow, fragile and
  disposable, not a warrior; bone ivory, rotten moss green, ochre, bruise purple.*
- **Anatomia:** *two bony arms with bony hands, two legs, no weapon; death poses fall
  apart into a pile of bones.*

## Grupo 2 — Demônios do Demonólogo

Os três arquétipos (tanque, matilha e artilharia) foram descritos pelo usuário com
referências de outros jogos. **O desenho precisa ser próprio:** sem pele verde, sem
fogo verde, sem a silhueta de demônios conhecidos. Todos carregam a mesma marca de
ferro do Diabrete e do Bruxo. Paleta da família: preto-tinta, carmim, amarelo-bile e
brasa.

### Bruto demoníaco (`demon_brute`) — tanque
- **Tamanho:** cerca de 1,5× a altura do Bruxo, largo e pesado.
- **Visual:** um bloco de placas de ferro preto **fundidas à pele**, com rachaduras
  carmim por onde a brasa aparece. Chifres grossos curvados para a frente, ombros
  enormes, cabeça pequena e baixa. Uma corrente de ferro sai da marca no peito. Arma:
  um **martelo de ferro marcado**, preso ao pulso por outra corrente.
- **Ataque:** marteladas lentas e pesadas: erguer, golpe para baixo, varrida lateral,
  e uma pose de guarda com o antebraço blindado à frente.
- **Descrição para o prompt:** *a hulking demon brute about one and a half times the
  warlock's height, black iron plates fused into its skin with carmine cracks glowing
  like embers, thick horns curving forward, huge shoulders and a small low head, an
  iron chain hanging from a brand mark on its chest, wielding a branded iron hammer
  chained to its wrist; ink-black, carmine, ember orange, bile-yellow eyes; no green.*
- **Anatomia:** *two arms, two legs, one hammer held in one hand in every living pose.*

### Cão demoníaco (`demon_hound`) — matilha
- **Tamanho:** comprimento parecido com o do lobo da floresta; mais alto e mais magro.
- **Visual:** quadrúpede esguio de costelas aparentes, pele preto-tinta com
  rachaduras de brasa ao longo da espinha, focinho longo, olhos amarelo-bile e coleira
  de ferro com a marca do contrato. Juba curta de fumaça escura na nuca, colada ao
  corpo e não solta como efeito.
- **Ataque:** bote, mordida, investida curta e rosnado agachado.
- **Descrição para o prompt:** *a gaunt demonic hound, exposed ribs, ink-black hide
  with ember cracks along the spine, long muzzle, bile-yellow eyes, an iron collar with
  a brand mark, a short mane of dark smoke clinging to the nape; ink-black, carmine,
  ember orange, bile-yellow; no green, no back tentacles.*
- **Anatomia:** *four legs and one tail in every living figure.*

O **conjurador demoníaco grande**, a alternativa ao enxame de diabretes, não entra
nesta rodada. O usuário ainda não escolheu entre os dois, e o enxame reaproveita o
Diabrete.

## Grupo 3 — Aspectos da Druida (efeitos)

Mesmo formato das folhas de efeito de 14/11
([e08_codex_art_1114_brief.md](e08_codex_art_1114_brief.md), seção A):
- PNG **1254×1254 RGBA**, grade **4×4 = 16 quadros** do início ao pico (~quadro 8)
  e à dissipação, com o último quase vazio;
- mesma escala e mesmo centro em todos os quadros; vista 3/4;
- sem personagem, chão ou texto;
- folhas com direção ("→") são pintadas apontando para a direita.

O aspecto é a silhueta do animal sobreposta ao corpo da Druida. Precisa ser
translúcida o bastante para não esconder a personagem, sem virar névoa.

| id do arquivo | Quando aparece | Direção artística |
|---|---|---|
| `aspect_bear` | Pele de Urso, ao redor do corpo | silhueta espectral de um urso erguido sobre as patas traseiras, em verde-musgo e âmbar, contorno de pelagem e casca. Envolve o espaço do corpo, se firma e se desfaz em folhas secas |
| `aspect_feline` → | Garra Felina, à frente da personagem | silhueta de um felino saltando, seguida de **três marcas de garra** em arco, em ocre e verde-vivo; rápida e afiada |
| `aspect_bird` → | Salto da Ave, ao longo do deslocamento | silhueta de asas abertas, com penas castanhas e creme se soltando, em arco ascendente |

Salvar em `assets/art/e08_codex_1117/vfx/<id>.png`, com `provenance.json` na pasta.

## Grupo 4 — Formas do Metamorfo

A identidade do Metamorfo ainda está em revisão (seção 3 do documento de
identidade). Este grupo vem por último e usa a proposta atual: castanho,
cinza-lobo e ocre, com a **pintura corporal da Druida**, que muda de cor conforme a
forma. As três formas precisam ser lidas como a mesma pessoa: a mesma pintura, o
colar de pedras e o dente de animal aparecem em todas.

| id | Tamanho | Visual | Ataque |
|---|---|---|---|
| `shapeshifter_bear` | ~1,3× a Druida, robusto | urso de pelagem castanha, ombros altos, pintura corporal em ocre, colar de pedras no pescoço | patada, investida curta, erguer-se nas patas traseiras, abraço |
| `shapeshifter_feline` | comprimento como o do lobo, baixo e longo | felino esguio cinza-lobo com manchas, pintura em verde-vivo, dente de animal na orelha | bote, garra, recuo agachado, salto curto |
| `shapeshifter_bird` | ~0,8× a Druida, de pé | ave de rapina grande, de penas castanhas e creme, pintura em âmbar nas asas, colar de pedras | bater de asas, garras à frente, mergulho curto, asas abertas em guarda |

Gabarito de corpo com: *"Original design. Same druid as the attached reference,
transformed: keep her body paint, stone necklace and animal tooth recognizable."*

## Depois da entrega (Claude)

Escolher as versões marcadas, recortar e montar os atlas V2 pela receita direcional
(as criaturas não têm calibração de mãos) e empacotar as três folhas de aspecto com
`tools/prepare_e08_vfx_art.py`. Tudo fica em staging até as classes ganharem kit.

## Entrega — 14/11/2026

O Codex entregou os quatro grupos completos. Pastas:
- corpos: `assets/art/e08_codex_1117/creatures/<id>/`, as sete criaturas nas quatro
  vistas;
- aspectos: `assets/art/e08_codex_1117/vfx/`, as três folhas.

Cada pasta tem `provenance.json` com o prompt exato e a versão escolhida marcada
(`selected`). Os SHA256 conferem. Todas as folhas têm 1254×1254 RGBA.

Conferência visual (versões marcadas):
- **Diabrete** e **Ossudo:** de acordo com o pedido nas quatro vistas. A marca de
  ferro no pescoço do Diabrete e os fungos do Ossudo são legíveis. O Ossudo
  desmonta em ossos na morte.
- **Bruto demoníaco:** silhueta e paleta corretas, sem verde. O martelo saiu como um
  bloco cúbico, e as vistas leste e oeste estão em escala menor que a sul e a norte.
- **Cão demoníaco:** correto, com coleira marcada e rachaduras na espinha. O traço é
  menos chibi que o resto do elenco, e a vista norte é mais alongada.
- **Formas do Metamorfo:** urso, felino (leopardo-das-neves) e ave de rapina
  carregam o colar de pedras, o dente e a pintura corporal. Leem como a mesma
  personagem.
- **Aspectos:**
  - `aspect_bear` (âmbar e folhas) e `aspect_bird` (asas e penas) estão de acordo.
  - `aspect_feline` traz a silhueta e rastros de velocidade, mas **não traz as três
    marcas de garra** pedidas. Elas podem ser desenhadas em código no acerto.
- **Escala entre vistas:** precisa ser igualada no empacotamento, sobretudo no Bruto
  e no Cão.

Empacotamento e montagem dos atlas ainda não feitos.
