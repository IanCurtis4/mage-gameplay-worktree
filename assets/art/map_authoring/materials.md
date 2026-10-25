# Materiais locais do terreno F2

24/10/2026. Dois albedos opacos, gerados com imagegen integrado (modo built-in)
para esta entrega; sem imagens de referência como entrada, sem download externo.
Originais copiados integralmente para grass_tile.png e earth_tile.png. Hashes de
bytes constam nos manifestos da validação e nas dependências do pacote v2.

Repetição em coordenadas de mundo, um tile a cada128 unidades, com espelhamento
alternado no shader para continuidade das bordas. Máscaras Grama/Terra interpolam
nas amostras; normais suavizadas modulam iluminação. O material pedregoso escuro
é derivado do albedo de terra, dessaturado, segundo inclinação: mistura inicia em
gradiente0,7 e chega a1 em gradiente1 (45°). É indicação de declive, não autoridade
de clique ou navegação, e não altera a pintura salva. Não há terceiro bitmap.

## Prompt final — Grama

Use case: stylized-concept. Asset type: seamlessly repeating square terrain albedo texture for an isometric fantasy map editor. Generate one full-bleed square tile of lush meadow grass seen exactly top-down, hand-painted naturalistic game terrain quality, fine interwoven small green blades and subtle moss, warm muted medium greens with slight olive variation, evenly distributed fine detail, neutral diffuse lighting. Absolutely flat orthographic albedo, no perspective, no horizon, no ground object, no tree, no stones, no flowers, no paths, no borders, no captions, no watermarks, no heavy shadows, no bright hot spots, no vignette. All four opposite edges must tile seamlessly. Texture scale shows small grass detail rather than large clumps. Polished painterly fantasy game ground, softly modeled detail rather than pixel art. Single square opaque image, not a demonstration layout or scene.

## Prompt final — Terra

Use case: stylized-concept. Asset type: seamlessly repeating square terrain albedo texture for an isometric fantasy map editor, a companion to hand-painted meadow grass. Generate one full-bleed square tile of compacted warm brown earth seen exactly top-down, naturalistic painterly strategy/RPG terrain quality, fine irregular dusty soil grains, subdued tiny grit and minute organic flecks evenly distributed. Warm neutral umber/tan palette with subtle local variation, medium value; neutral flat diffuse albedo lighting. All opposite edges tile seamlessly. No grass, no plants, no large rocks, no footprints, no path shape, no perspective, no horizon, no borders, no captions, no text, no watermark, no vignette, no large bright blobs or deep cast shadows. High quality softly painted detail, not pixel art and not a scene. Single square opaque texture image.
