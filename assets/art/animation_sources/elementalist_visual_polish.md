# Elementalista — revisão de poses de 28/09/2026

Gerado com o imagegen nativo, em modo de edição, tomando o atlas anterior
`assets/art/animations/elementalist.png` como referência de identidade.
Fonte gerada preservada em `elementalist_visual_polish.png` neste diretório.
O atlas de runtime é normalizado por `tools/prepare_elementalist_atlas.gd`:
recorte mecânico 4×8, descarte de poeira alfa/componentes isolados, escala
uniforme nearest, pivô horizontal medido nas botas após redução e chão y=58.
Nenhuma outra classe é reprocessada pelo script.

## Prompt final

Use case: identity-preserve. Edit target Image 1 is an existing game sprite atlas.
Correct its defective poses without redesigning the SAME brown-haired young
elemental mage, blue and white long robes, brown boots, blue crystal wooden staff.
Output a transparent 4-column by 8-row sprite atlas, exactly 32 full-body sprites,
evenly spaced identical cells, no gridlines, no labels. Portrait canvas 1:2.
Crisp compact pixel-art sprites meant to be reduced to 64x64 cells in an
isometric/top-down 2D RPG. Keep original proportions and costume identity.
Each whole sprite fits inside its own cell with generous transparent gutters;
body and boot contact point centered on a consistent baseline and stable scale,
staff never crosses cell boundary. Walking must show alternating legs and robe
sway, NOT four duplicate pictures. Row 1: four subtly breathing front idle poses.
Row 2: four phases walking toward camera, feet visibly alternating, upright head,
no extreme lean. Row 3: four front casting poses, staff lifted with small glow only.
Row 4: four phases walking AWAY from camera, genuinely rear view, back of head and
cloak, no visible face. Row 5: four rear idle poses. Row 6: four rear casting poses.
Row 7: first two front recoil poses, last two rear recoil poses. Row 8: first two
front collapsed death poses, last two rear collapsed death poses. Correct rear-view
walking and missing legs in original; preserve blue/white/crystal design and clean
pixel-art readability. No ground, no shadows painted into atlas, no cropped body
parts, no fake checkerboard, no text, no background.
