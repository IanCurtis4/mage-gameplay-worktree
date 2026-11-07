# Receita — Espadachim direcional em staging

As vistas S/N usam células nativas de `assets/art/animations/swordsman_weaponless.png` e índices exatos em `source_recipe.json`; não são reamostradas. E/W são fontes independentes; caminhada oeste usa correções localizadas nas poses 5 e 7. Prompts integrais e hashes em `provenance.json`.

Reproduzir com `python tools/prepare_e08_directional_art.py swordsman`. Escala das vistas novas 0,17667844522968199, pivô (32,58), atlas 256×1024. Body e weaponless são iguais, em caminhos distintos, sem espada embutida. Manifesto é emitido apenas com hash RGBA compatível com `calibration.json`.

S/N remapeiam main/off e crops do rig legado, com ângulos por fase e profundidades; E/W têm palmas enluvadas escolhidas nas imagens ampliadas. `head.flip` é false também no oeste; espelhamento local dos anexos é separado. A prova offline comparou as 32 células nativas e verificou alpha dos 112 grips vivos nos dois corpos. Posições, ângulos, oclusão, equipamento e capacete precisam de inspeção no renderer; alpha não prova anatomia.
