# E08 P5 — B2a: prévia do mundo (materiais e props novos do Codex)

Autor: Terra (Sonnet), 8/11/2026. Prévia somente leitura: as texturas e sprites
novos foram trocados **apenas em memória** no processo do probe
(`tools/e08_p5_world_preview_probe.gd`); nenhuma fonte, mapa, catálogo, pacote,
material, textura ou teste foi alterado. Nada foi validado com a suíte de
gameplay (entrega de prévia visual, sem mudança de runtime).

## O que foi renderizado

Renderer real (Forward+/driver nativo, não headless), 1280x720, UI a 120%, mapas
publicados `forest_terraces` (completo), `forest_valleys` e `forest_lair` (lite),
sessão de prévia do `gameplay_app` como em `e08_pilot_probe.gd` (lair). Troca por
`ShaderMaterial` duplicado com os parâmetros `grass_tile/earth_tile/sand_tile/stone_tile`
substituídos por `ImageTexture` carregada de `assets/art/e08_world/staging/` (com
mipmaps, mesmos filtros do shader); props trocados no `Sprite2D` (textura, offset, escala).

- a) antigo x novo (todos os materiais) a zoom 50/100/160 nos três mapas.
- b) variantes isoladas: grama+areia, só terra, só pedra no topo; vista de penhasco
  (face) com todas as variantes.
- c) indicadores reais do jogo (`ExpeditionGeometryView`: marcador, rota e prévia
  de ataque, vermelho `#ff807d` = inválido/perigo, verde `#79e5ba` = válido) sobre
  piso uniforme terra/pedra, antigo x novo, e sobre o mapa natural.
- d) props: 2 arbustos reais substituídos por samambaia/anel de cogumelos/flores/tronco;
  carvalho real -> bétula (pivô/altura do contrato e "ajustada"); todos os 132
  carvalhos -> bétula; fileira de comparação ao lado do personagem.
- e) cintilação: 8 quadros, pan de 0,5 px de tela/quadro a zoom 50, UI e atores ocultos.

## Achado técnico: pedra x penhasco

`stone` (`cliff_tile.png`) é **o mesmo slot** para tudo. `terrain_material.gd` usa
4 texturas (grass/earth/sand/stone), e **os dois shaders** (`terrain_material.gdshader`
e `border_material.gdshader`) amostram `stone_tile` para: (1) faces laterais/penhasco
(`face_arrays` com peso padrão `[0,0,0,1]`), (2) faces de borda, (3) qualquer
superfície de topo com peso de pedra pintado e (4) topos íngremes (`rock_transition`
a partir de gradiente 0,5). Não existe slot separado para "pedra de chão". Trocar o
ID `stone` troca a pedra de penhasco inteira. Na prévia, "pedra só no topo" ficou
**idêntica ao antigo** nas vistas amostradas (nenhum topo pintado de pedra no
spawn/penhasco): em terraces/valleys/lair, 648/657/202 faces x 104/95/11 topos; toda a
pedra visível é face de penhasco. Uma "pedra de chão" real exigiria 5º slot ou novo
ID (mudança de shader/contrato, fora de B2a).

## Números

Estatísticas dos tiles (amostra 1/16; luma 0-1):

| tile | RGB médio antigo | RGB médio novo | saturação | desvio de luma | razão borda-oposta/adjacente |
|---|---|---|---|---|---|
| grass | .33 .45 .10 | .39 .50 .20 | .78 -> .59 | .101 -> .033 | 1,55 -> 3,73 |
| earth | .58 .40 .25 | .45 .22 .12 | .57 -> .73 | .075 -> .041 | 1,52 -> 4,30 |
| sand | .90 .68 .37 | .93 .69 .42 | .59 -> .55 | .057 -> .033 | 1,38 -> 3,70 |
| stone | .53 .49 .44 | .45 .44 .45 | .17 -> .03 | .094 -> .033 | 1,77 -> 3,26 |

Luma média: terra .43 -> .26 (muito mais escura); pedra .50 -> .44; grama .40 -> .46.
(mosaico: a terra nova é visivelmente mais escura e avermelhada que a antiga; a pedra nova é cinza liso com paralelepípedos; o traço de perigo é legível sobre ambas, melhor em luma sobre a terra nova.)
A razão de borda >1 indica que os novos não são seamless por reflexo de borda; no
shader o UV é espelhado (`mirrored`), então não há emenda visível, mas há simetria
em espelho a cada 256 unidades (ver "repetição").

Contraste dos indicadores (retângulo ~165x157 px ao redor do marcador, quadro sem
indicador; razão WCAG com luminância linear; p05 = 5% piores pixels; "<2" = fração
de pixels com razão < 2,0; ~0,5% de ruído vem do sprite do jogador no retângulo):

| piso | cor | razão média | p05 | frac <2,0 | |Δluma| médio |
|---|---|---|---|---|---|
| terra antiga | perigo | 2,29 | 1,92 | 0,102 | 0,206 |
| terra nova | perigo | 4,00 | 3,02 | 0,022 | 0,356 |
| pedra antiga | perigo | 1,94 | 1,30 | 0,625 | 0,145 |
| pedra nova | perigo | 2,27 | 1,93 | 0,117 | 0,194 |
| terra antiga / nova | válido | 3,64 / 6,35 | 3,05 / 4,80 | 0,007 / 0,006 | 0,39 / 0,54 |
| pedra antiga / nova | válido | 3,07 / 3,61 | 2,06 / 3,07 | 0,036 / 0,006 | 0,33 / 0,38 |
| mapa natural, spawn (antigo / novo todos) | perigo | 2,40 / 3,31 | 1,99 / 2,14 | 0,052 / 0,029 | 0,216 / 0,296 |

Cintilação (zona central 640x360, 8 quadros, zoom 50, pan subpixel):

| | variância temporal bruta | resíduo subpixel | gradiente espacial |
|---|---|---|---|
| antigo | 9,404 | 0,511 | 2,226 |
| novo (4 materiais) | 7,449 | 0,423 | 1,792 |

O novo cintila ~21% menos, mas porque tem **menos contraste de textura** (desvio de
luma 0,03-0,04 contra 0,06-0,10): a razão cintilação/gradiente é equivalente
(0,80 x 0,83). Não há alias novo; há também menos detalhe. As três métricas medem
energia de alta frequência sob movimento, não a percepção humana.

Saturação/luma média do quadro (terraces z100): antigo .56 / .288, novo .50 / .299;
a grama nova é menos saturada que o antigo e se aproxima mais dos personagens e props.

## Constatações por material (olhando as capturas)

- **Grama**: a nova é mais suave e mais clara/menos saturada; sem emenda em z50/100/160.
  A repetição lê como manchas largas em z50 (aceitável; o antigo tinha textura de
  folha mais evidente). Props e personagem destacam melhor sobre ela. Sem cintilação
  perceptível. Boa.
- **Areia**: quase idêntica à antiga em cor, um pouco mais lisa; sem problemas.
- **Terra**: ferrugem avermelhada escura, saturada (RGB .45/.22/.12). Domina o quadro
  como "mancha de sangue" no caminho, bem mais forte que a antiga. A luminância ajuda
  o contraste com o indicador, mas o **matiz** do perigo (~1 grau) fica mais perto do
  da terra nova (~18 graus) do que da antiga (~28 graus) e com saturação alta: o traço
  salmão ainda é legível nas capturas, porém pior para daltonismo e sobre manchas
  mais claras. Precisa de recolor.
- **Pedra**: calçamento de paralelepípedos cinza, quase sem saturação. Como piso de
  penhasco/encosta lê como **estrada pavimentada/asfalto** atravessando a floresta,
  sem relevo de rocha; o antigo (casca/rocha com veios) lê como rocha. Sobre o
  indicador de perigo, a pedra nova é melhor que a antiga (p05 1,93 x 1,30), mas isso
  não compensa a leitura de "estrada construída" numa face de penhasco.

## Props

Métricas de alfa (caixa opaca, centroide da base): bétula 1215x1295, caixa .986x.984,
base em x=.515, base y=.992; carvalho antigo base x=.52, y=.998 (pivô contratual
.53/.94, altura 226). Samambaia/cogumelos/flores 1536x1024 (mesmo canvas do arbusto,
conteúdo .71/.74/.62 da altura contra .94 do arbusto), tronco 2172x724.

- **Samambaia**: mesmo pivô/altura do arbusto (.49/.91, 46) fica ~25% menor, assenta
  no chão, boa. Adotar.
- **Anel de cogumelos**: pequeno (largura .58 do canvas), laranja chama atenção; bom
  como detalhe raro. Adotar com baixa frequência.
- **Flores silvestres**: baixas e largas (.62 de altura), leem como canteiro; boas. Adotar.
- **Tronco caído**: 2172x724 na escala em pixels do arbusto (46/1024 mundo/px) dá
  ~97 unidades de comprimento, pivô pela base da caixa; plausível ao lado do personagem
  e assenta no chão. Adotar (decorativo, sem corpo).
- **Bétula x carvalho** (mesmo pivô/altura do contrato): escala igual à do carvalho,
  copa mais clara e amarelada, tronco branco bem legível; a base fica ~5% (~11 unidades)
  abaixo do pivô .94 (raízes levemente afundadas); com pivô de ajuste (.515/.977,
  altura 228,5, mesma altura visível) assenta melhor. Em bosque misto fica natural;
  substituir todos os 132 carvalhos deixa o mapa mais claro/amarelado e perde o
  contraste da copa escura com a areia. Uso recomendado: variante em parte dos carvalhos.
  Corpo, LOS e oclusão devem ser idênticos aos do carvalho, como exige o contrato.

## Recomendações

| item | decisão |
|---|---|
| grass novo | adotar |
| sand novo | adotar |
| earth novo | adotar com brief de recolor ao Codex (marrom mais claro e menos saturado: luma média ~.36-.42, saturação ~.5, matiz mais laranja/amarelo, longe de vermelho) |
| stone novo como `stone` | rejeitar (cobblestone = estrada pavimentada nas faces de penhasco); manter `cliff_tile.png`. Se quiser estrada de pedra, pedir um ID/slot novo (decisão de arquitetura, não de textura) |
| samambaia, flores, anel de cogumelos, tronco caído | adotar como variantes decorativas |
| bétula | adotar como variante de parte dos carvalhos, com pivô ajustado |

Provenance: os arquivos ainda não têm `provenance.json` (pendência do Codex antes
de qualquer promoção).

## Limitações

- Não há telegrafo de ataque inimigo em área no código; usei marcador/rota/prévia de
  ataque do `ExpeditionGeometryView`, que são o vermelho/verde desenhados pelo jogo.
  Área de habilidades (ex.: parede de fogo) não foi lançada.
- A prévia de pedra/terra "uniformes" põe grass/earth/sand = o mesmo tile no topo
  para isolar a leitura do indicador; o mapa natural foi medido separadamente.
- Cintilação medida com UI/atores ocultos e sem a camada de ambiência; é métrica
  relativa, não percepção.
- Valleys e lair rodaram em modo lite (sem props/indicadores/cintilação).
- Capturas com o painel do jogo a 120% cobrem parte da tela; os mosaicos recortam a
  parte limpa.

## Evidência (`.godot/verification/p5/`)

- Definitivas: `B2a_terra_world_preview_probe_b2a_probe6_terraces/`,
  `..._probe6_valleys/`, `..._probe6_lair/` (todas em `probe/`; JSON
  `preview_terraces.json`, `preview_valleys.json`, `preview_lair.json`).
- Mosaico: `B2a_terra_world_preview_probe_b2a_mosaic3/probe/b2a_mosaic.png`
  (linha de cima ANTIGO, de baixo NOVO; colunas: terraces z50, terraces z160,
  valleys z100, covil z100, perigo sobre terra, perigo sobre pedra).
- Execuções descartadas/preservadas: `b2a_probe2` (rejeitada pelo wrapper por
  divergência de fonte de outro agente), `b2a_probe3` (primeira rodada completa de
  terraces; retângulo de contraste vazio por bug de ordem da câmera, corrigido),
  `b2a_probe4_valleys`/`b2a_probe5_lair` (barradas pelo wrapper), `b2a_mosaic1`
  (janela limitada, mosaico quebrado; trocado por SubViewport), `b2a_mosaic2` (caminhos com acento corrompidos no spec, imagens vazias), mosaico final `b2a_mosaic3`,
  sincronizações `b2a_sync2/3/6_1..3/7/8/9`.

## Nota de retomada (queda de energia)

O probe original foi sobrescrito por engano na retomada (o aviso dizia que nenhum
arquivo existia; o doc e as evidências `probe6_*`/`mosaic3` já existiam). O probe foi
reescrito e revalidado pelo wrapper: `b2a_reprobe1_terraces` (bug de ordem da câmera no
retângulo de contraste, reproduzindo o defeito de `probe3`) e `b2a_reprobe2_terraces`
(corrigido). Reproduzem os números acima: cintilação 9,40 -> 7,45, classes de malha
104 topos/648 faces, razão de contraste terra nova 4,01/p05 3,00, pedra nova 2,21/1,93.
O modo `mosaic` do probe reescrito não foi reexecutado; o mosaico definitivo vem do
probe anterior (`mosaic3`). Evidência primária continua `probe6_*`.
