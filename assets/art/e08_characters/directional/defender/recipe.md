# Receita — Defendente direcional em staging

S/N usam células nativas de `assets/art/animations/defender_weaponless.png` e índices exatos em `source_recipe.json`, sem reamostragem. E/W são fontes independentes; a ação oeste pose 10 usa correção localizada v2. Prompts integrais e hashes em `provenance.json`.

Reproduzir com `python tools/prepare_e08_directional_art.py defender`. Escala das vistas novas 0,17889087656529518, pivô (32,58), atlas 256×1024. Body e weaponless são iguais em caminhos distintos. O manifesto é emitido apenas com hash RGBA compatível com `calibration.json`.

S/N remapeiam main/off e crops do rig legado com ângulos por fase e profundidade; E/W têm luvas escolhidas nas imagens ampliadas. Cabeças de morte foram localizadas sobre o cabelo/crânio em cada pose. `head.flip` é false inclusive no oeste; espelhamento de anexos é separado. A prova offline comparou as 32 células nativas e verificou alpha dos 112 grips vivos em ambos corpos. Inspeção dos anexos no renderer continua necessária; alpha não prova anatomia.

### Limpeza autorada de2mortes legadas

Fonte nova `native_death_source_v1.png`: grade2x2 (S14/S15 repetidos), crop somente
quadrantes0/1. Transparência removida pelo `remove_matte` e `keep_character` do
pipeline existente. Crop bbox registrado em provenance.native_death_cleanup;
escala uniforme por pose para manter exatamente a altura do bbox original;
LANCZOS, alpha128→255/0, RGB0 em alpha0. Centralizar bbox emX32 e apoiar no mesmo
último pixelY57. Copiar os30demais cells64x64 originais intactos no cleaned256x512.
O packer de4vistas lê native_cleaned emsouth/north, sem reamostragem dessas células.
Repetir `python tools/prepare_e08_directional_art.py defender` após calibração
vinculada ao novo hash; isto não redesenha ou apaga uma arma por algoritmo.
