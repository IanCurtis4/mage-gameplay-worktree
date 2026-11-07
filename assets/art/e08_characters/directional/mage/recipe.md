# Receita — Mago direcional em staging

Fontes sul e norte são células nativas de `assets/art/animations/mage_weaponless.png`, com os índices explícitos em `source_recipe.json`; sem reescala. Perfis E/W foram gerados independentemente via imagegen, com correções localizadas: E poses 0/3 usam v1, demais v2; W pose 5 usa v2, demais v1. E v3 foi descartada por mão extra. Fontes e prompts: `provenance.json`.

Para reproduzir: `python tools/prepare_e08_directional_art.py mage`. Escala global das vistas novas 0,17452006980802792; pivô (32,58); atlas 256×1024 e corpos idênticos sem arma em caminhos distintos. A calibração nativa S/N remapeia main/off e fingers de `hand_rigs.json`, com profundidade e ângulos por fase derivados do comportamento legado; perfis têm pontos autorados e recortes pequenos. O hash do raster é obrigatório na calibração para emitir manifesto.

A verificação offline comparou byte a byte as 32 células nativas e verificou alpha dos 112 grips vivos em ambos os corpos. O atlas não substitui inspeção das mãos, poses, anexos e chapéu no renderer; especialmente mãos pequenas, morte e profundidade/ângulo das laterais requerem revisão.
