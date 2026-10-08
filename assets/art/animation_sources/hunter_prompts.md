# Caçadora — fonte e atlas H6

08/10/2026. Ferramenta integrada imagegen, fundo transparente, sem CLI/API.
Fonte original preservada: hunter_source.png. Referências de identidade e escala:
docs/references/CODEX_HANDOFF_MVP_2026-09-14/art/extended/waylayer_cacador.png
e assets/art/animations/archer.png, respectivamente. Concept não recortado.

Atlas runtime: ../animations/hunter.png, 256×512, 32 células64×64, pés32,58.
Preparador mecânico tools/prepare_hunter_atlas.gd derivado do Geômetra:
limpeza de poeira alpha/fragmentos, escala única nearest, alinhamento dos pés;
nenhuma pintura ou pose gerada por código. Fonte permanece byte-exata.
Reprodução: Godot --headless --path . --script res://tools/prepare_hunter_atlas.gd
(a entrada headless padrão usa o isolamento de perfil H5).

## Prompt final

Use case: stylized-concept. Asset type: production transparent pixel-art animation sprite sheet for RagRPG original Caçadora/Hunter evolution. Image1 is APPROVED identity COSTUME PALETTE reference only, NOT an image to crop. Image2 is existing Archer sprite scale, pixel-cluster and exact animation layout reference only; do NOT copy its simple outfit. Create one coherent female fieldcraft hunter: short ivory/blond tousled hair, small dark moss hood with two restrained leaf accents, dark olive short layered cape, bone/linen sash, dark leather trap pack and rope coil at belt, brown boots, short wooden field bow visible at side and held for attack. Compact adult-chibi Korean2000s MMO pixel art, restrained large readable clusters, bone/cream face and sash separate from moss terrain, no oversized headgear, no heavy plate armor, no pet/companion. Exactly FOUR columns and EIGHT rows of equal cells, exactly32 full-body sprites on portrait canvas1:2. Transparent true alpha, no opaque checkerboard, no grid, no text, no shadows, no background. Wide transparent gutters, feet aligned same baseline each cell, consistent scale and costume. Row1 front three-quarter idle four breathing poses. Row2 front walk four alternating boots/contact/passing. Row3 front bow attack four windup/draw/release/recovery. Row4 genuine BACK walking four alternating boots with cape sway NO FACES. Row5 BACK idle four NO FACES. Row6 BACK bow attack four windup/draw/release/recovery NO FACES. Row7 front hurt two recoil frames then BACK hurt two recoil frames. Row8 front fallen death two poses then BACK fallen death two poses, all four lying on ground NOT standing. Bow and body contained in each cell, no cross-cell objects, simplified readable final64x64 texture, dark colored selective outline. No scenery, spell effects, typography, reference-sheet panels or additional poses.

## Limites

Frente/costas e espelhamento suportados pelo runtime, não oito desenhos novos.
Cast/preparo usa a linha de ação existente; não há uma linha extra de ajoelhar
ou implantação. VFX e animação não mudam colisão, dano ou velocidade. Aprovação
de produto e revisão visual integrada ainda pertencem ao fechamento H7/Astra.
