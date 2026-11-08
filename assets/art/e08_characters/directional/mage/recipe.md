# Receita — Mago direcional em staging

Fontes sul e norte são células nativas de `assets/art/animations/mage_weaponless.png`, com os índices explícitos em `source_recipe.json`; sem reescala. Perfis E/W foram gerados independentemente via imagegen, com correções localizadas: E poses 0/3 usam v1, demais v2; W pose 5 usa v2, demais v1. E v3 foi descartada por mão extra. Fontes e prompts: `provenance.json`.

Para reproduzir: `python tools/prepare_e08_directional_art.py mage`. Escala global das vistas novas 0,17452006980802792; pivô (32,58); atlas 256×1024 e corpos idênticos sem arma em caminhos distintos. A calibração nativa S/N remapeia main/off e fingers de `hand_rigs.json`, com profundidade e ângulos por fase derivados do comportamento legado; perfis têm pontos autorados e recortes pequenos. O hash do raster é obrigatório na calibração para emitir manifesto.

A verificação offline comparou byte a byte as 32 células nativas e verificou alpha dos 112 grips vivos em ambos os corpos. O atlas não substitui inspeção das mãos, poses, anexos e chapéu no renderer; especialmente mãos pequenas, morte e profundidade/ângulo das laterais requerem revisão.


## Integração de cabeça — 7/11/2026

O corpo/weaponless originais continuam2def...; bare_head.png é cópia exata da
unidade independente assets/art/e08_head_fit/mage/body.png, RGBAce94ffabe8c1dcd02538bf5264584a916ef7a54b098fbb90eaffe547685e63f8.
Regiões/proteções64, fonte/prompts e produtor próprio permanecem naquele staging
somente leitura. O manifesto opcional bare_head tem path/hash na mesma pasta;
a cópia runtime usa seu path correspondente. Reproduzir as âncoras lendo os64
head_anchor/head_angle dessa calibração e somando [0,4] à âncora uma única vez,
preservando flip/palma/ground e ângulos vivos. Para as poses15/31/47/63,
ângulos finais Sol0,1/0,6/0,65/-0,65radianos alinham a abertura ao rosto
no cadáver, em lugar do roll±90° do staging. Offset Sol decorre da comparação nativa
initial3→fit1; não aplicar novamente sobre a calibração já integrada.

O produtor genérico do corpo original não emite esse opcional. Sua saída isolada
não substitui a unidade integrada: a promoção completa conserva o terceiro
registro e os paths versionados em presentation.json. Sem head conhecido usa-se
a aparência original; equipar head conhecido seleciona a base de cabelo, remover
restaura exatamente o atlas original. Nenhum pixel foi redesenhado por Sol.
