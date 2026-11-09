# P5 — briefing de imagegen para o Codex (WIP)

Estado: **WIP, aguardando geração pelo Codex** a pedido do usuário. Claude não
gera raster; nenhum substituto procedural vira arte final. Usar o imagegen
embutido como nas entregas P3/P4, salvar a saída byte a byte (sem edição de
raster por código) e registrar `provenance.json` em cada pasta com gerador,
prompt completo, nome original da saída, SHA256, largura/altura e referências.
Destino exclusivo: `assets/art/e08_world/staging/` (pastas abaixo). Não editar
runtime, mapas, catálogos, testes ou atlas existentes; a integração é da fase B.

## 1. Espécies (`staging/species/<visual_id>/`)

Mesmo formato de `assets/art/e08_characters/directional/archer/west_source_v2.png`
e dos prompts em `assets/art/e08_enemies/directional/e08_forest_wolf/provenance.json`:
uma folha transparente 4×4 por vista (`south_source_v1.png`, `north_source_v1.png`,
`east_source_v1.png`, `west_source_v1.png`), ~1254×1254, 16 figuras em células
iguais, mesma escala e chão. Linha 1 idle×4, linha 2 caminhada×4, linha 3
ataque×4, linha 4 dano×2 + morte×2 (caído). Estilo chibi pixel-art desenhado à
mão do jogo; sem fundo, texto, sombra de chão, efeitos ou magia. Leste/oeste são
perfis desenhados independentemente (não espelhados); a mão da arma fica do lado
do alvo (lição da P4). Sul de frente, norte de costas.

| visual_id | Referência atual (identidade a preservar/evoluir) | Direção |
|---|---|---|
| `e08_forest_stalker` | `assets/art/animations/warrior.png` com tinta verde | Espreitador da Mata: caçador furtivo humanoide de capuz e capa em verde-musgo/folhas, couro escuro, máscara de pano, duas lâminas curtas embutidas; ataque é investida lateral (flanqueador). Distinto do guerreiro vermelho. |
| `e08_forest_canopy_archer` | `assets/art/animations/directional/archer/npc_body.png` com tinta verde | Arqueiro da Copa: arqueiro esguio de manto de folhas/casca, capuz com galhos, arco longo de madeira viva EMBUTIDO na mão que lidera; ataque = puxar/soltar (sem flecha desenhada voando). |
| `e08_forest_warden` | `assets/art/animations/beast_master.png` com tinta verde-escura | Guardião Ancestral (chefe): humanoide maior e imponente, armadura de casca e musgo, chifres/galhada, cajado-totem; deve ler como chefe na silhueta. Invoca companheiro, mas não desenhar o companheiro. |

Aceite: 4 folhas por espécie, 16 figuras cada, contagem de membros coerente,
arma no mesmo lado da mão de ataque em todas as poses, cabeça e corpo inteiros.

## 2. Materiais do terreno (`staging/materials/`)

`grass_tile.png`, `earth_tile.png`, `stone_tile.png`, `sand_tile.png` (opcional
`moss_tile.png` como variação de grama). Textura vista de cima, **sem emendas**
(seamless nos quatro lados), opaca, 1024×1024, pintura pixel-art de baixo ruído
que não cintile em movimento nem com zoom 50%. Contraste e saturação moderados:
indicadores vermelhos/amarelos de perigo e área devem continuar legíveis por
cima. Paleta coerente com `assets/art/map_authoring/props/*.png`. Referência dos
atuais e da regra de módulo: `assets/art/map_authoring/materials.md`,
`materials_provenance.json`, `docs/ART_DIRECTION_NEXT.md`.

## 3. Variantes de props (`staging/props/`)

Sprites isolados transparentes, mesmo ângulo/iluminação/estilo de
`assets/art/map_authoring/props/oak_tree.png` (prompts em `props/provenance.json`),
~1200–1500 px, base de contato clara para pivô. Decorativos (sem corpo físico):
`fern_cluster.png`, `mushroom_ring.png`, `wildflower_patch.png`,
`fallen_log.png` (baixo, não bloqueia visão). Árvore alternativa:
`birch_tree.png` ou `pine_tree.png`, com tronco e pegada equivalentes ao carvalho
(ela só substituirá carvalhos mantendo o mesmo corpo físico).

## Entrega de volta

Avisar o usuário com a lista de arquivos e SHA256. A fase B (Claude/Terra/Sol)
inspeciona, empacota, calibra, republica mapas e valida; recusas visuais voltam
ao Codex com célula/arquivo específico.
