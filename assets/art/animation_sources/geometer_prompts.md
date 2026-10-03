# Geômetra — fonte e atlas G7

03/10/2026. Geração pela ferramenta integrada imagegen, fundo transparente.
Direção aprovada: `docs/E05_GEOMETER_PLAN.md` e concept
`docs/references/CODEX_HANDOFF_MVP_2026-09-14/art/hybrids/geometer_geometra.png`.
O concept é referência de identidade, não sprite recortado.
`mage.png` foi referência do contrato de poses/escala, não do traje.

Fonte preservada: `geometer_source.png`. Atlas runtime:
`../animations/geometer.png`, 256×512, 32 células 64×64, pés (32,58).
Preparação mecânica reproduzível via
`Godot --headless --path . --script res://tools/prepare_geometer_atlas.gd`:
limpeza de alpha-dust herdada do preparador de Elementalista, resize nearest
com escala única e alinhamento dos pés, sem mudança de design ou poses.
VFX são composição nativa da geometria; não há 33 sheets independentes.

## Prompt final

Use case: stylized-concept. Asset type: production transparent pixel-art animation sprite sheet for original RPG Geometer evolution. Image1 is APPROVED COSTUME/PALETTE reference only, not a sheet to crop. Image2 is small game sprite scale/layout style reference only, do NOT preserve its mage costume. Create the female cartographer/astronomer from image1: short silver-white bob, small navy scholar cap with one gold triangular pin, ivory/navy short split coat, light blue small crystal accents, visible brown boots and separated legs, compact gold/navy mechanical BOW instrument held at side, NOT a mage staff, NOT a witch cone hat, no companion. Simplify to large readable pixel clusters at final64x64. Exactly4 columns by8 rows in equal-sized cells32 full-body sprites, canvas portrait1:2, transparent true alpha with wide transparent gutters, no background no checkerboard no labels no grid no shadow. All sprites same scale centered feet baseline. Row1 front three-quarter idle4 subtly breathing. Row2 front walk4 distinctly alternating boot contact and passing poses. Row3 front cast4 bow-instrument windup raise release recover, small lightblue crystal glow only. Row4 genuine BACK VIEW walking4 alternating boots with robe sway, NO FACES. Row5 BACK idle4 NO FACES. Row6 BACK cast4 same action NO FACES. Row7 two front hurt recoil then two rear hurt recoil. Row8 two front collapsed death poses then two rear collapsed death poses, on ground not standing. Sprite body and bow entirely contained in every cell. Crisp original fantasy MMO-style pixel art, restrained antialiasing, adult chibi proportions, ivory/navy/gold silhouette distinct from base mage. No global VFX or scenery, no typography.
