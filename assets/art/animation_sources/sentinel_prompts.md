# Sentinela — fonte original e atlas

03/10/2026. Gerada pelo recurso integrado image_gen, com
`transparent_background=true`; sem CLI/API externa. Fonte original preservada
sem alteração em `sentinel_source.png`.

Referências somente de direção/layout, não alvos de edição:

- `docs/references/CODEX_HANDOFF_MVP_2026-09-14/art/extended/sentinel_sentinela.png`
- `assets/art/animations/archer.png`

Normalização mecânica reproduzível em Godot 4.7.2:
`tools/prepare_sentinel_atlas.gd`, derivado do preparador Geômetra.
Separação regular 4×8, limpeza de poeira alpha desconectada, escala uniforme
nearest, alinhamento horizontal pelas botas e última linha opaca y58.
Sem recolor, desenho novo ou mudança artística da fonte. Saída runtime
`assets/art/animations/sentinel.png`: 256×512, 32 células 64×64.
Catálogo/pivô compartilham CharacterAnimation; animação não determina gameplay.

SHA-256 fonte: `3A1A46896C28F583A7A58B63FE7CD613031D6D38D45A042928F67A0B9AFF15E8`.
SHA-256 atlas: `059E7A84BC41B0F800E455B64A8E1666826ED57A1D77A7A1F85CCA658D588BA6`.

## Prompt exato

Use case: stylized-concept. Asset type: original RPG production transparent pixel-art character animation sprite sheet. Input images: Image 1 is approved Sentinel costume/palette concept REFERENCE ONLY, not an edit target, not an image to crop. Image 2 is pose layout and small game scale reference ONLY, do not reuse its base archer outfit. Create the female Sentinel scout from Image 1 simplified for 64x64 cells: short pale-silver hair, low forest-green hood/headband (not a wizard hat), forest-green short shoulder cape with pale-blue panel, ivory tunic, light-brown leather belts/boots, ONE large wooden longbow and small quiver. Two legs/boots clearly separated, balanced stance. NO owl companion, no telescope, no banner, no extra dangling ornaments. Distinct from base orange hood archer and navy astronomer Geometer. Style: crisp readable fantasy MMO pixel art, adult chibi proportions, large pixel clusters not tiny noisy details. Canvas portrait 1:2. Exactly 4 columns x 8 rows of 32 equally sized cells, generous genuinely transparent alpha gutters, no grid, no labels, no checkerboard, no background, no ground shadow, full character and bow contained in EVERY cell at identical scale with fixed centered foot baseline. Row 1: front three-quarter idle 4 subtle breathing poses. Row 2: front walk 4 clearly different alternating left/right boot contact and passing phases. Row 3: front aiming/drawing bow then release and recover 4 distinct poses. Row 4: genuine BACK VIEW walking 4 alternating boots, NO FACES. Row 5: BACK idle 4 poses NO FACES. Row 6: BACK draw/release/recover bow 4 poses NO FACES. Row 7: two front hurt recoils then two back hurt recoils. Row 8: two front collapsed death then two back collapsed death poses, lying on ground not standing. Consistent outfit, silhouette, colors, anatomy across all cells. Restrain light-blue accent to cloth; no global VFX or glow clouds. Preserve transparent true alpha.

## Verificação e limites

`tests/e05_sentinel_atlas_test.gd` confere 32 poses, bordas alpha,
contenção, pivô/botas, passos distintos, corpos horizontais e cópia de morte.
O argumento `--sentinel-preview` exige renderer real e salva uma captura
em `.godot/verification/sentinel_atlas_native.png`, nos pisos claro/escuro.
Frente/costas e leitura de arco/capa são inspecionadas visualmente; testes de
pixels não comprovam direção anatômica nem aceite estético. Aprovação do padrão
permanece na revisão integrada Astra e no playtest humano.
