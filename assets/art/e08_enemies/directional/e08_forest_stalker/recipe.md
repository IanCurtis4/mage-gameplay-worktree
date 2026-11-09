# Espreitador da Floresta — receita

Quatro vistas geradas (sul/norte/leste/oeste), folhas 1254² transparentes 4x4 do Codex
(imagegen) em `assets/art/e08_world/staging/species/e08_forest_stalker/<vista>_source_v1.png`,
somente leitura. Linha 1 repouso, 2 caminhada, 3 ataque, 4 dois danos + duas mortes;
`source_recipe.json` declara `generated_views`, `per_view_scale` e `target_height` 50.
Sem atlas V1 nativo, sem desenho/pintura: apenas recorte, matte, conectividade, escala
por vista (mediana de repouso da vista → altura alvo, limitada a 58x56 por quadro),
alfa128 e empacotamento pelo pipeline existente; pivô (32,58), chão 57 nas 64 poses.
Equipamento: adagas duplas; aljava às costas visível sobretudo em O/L/N; sem projeção dinâmica (NPC). Reprodução:
`python -I tools/prepare_e08_enemy_directional_art.py e08_forest_stalker`.
Proveniência: pendente do Codex (ver provenance.json; prompts não inventados).
RGBA `37366758e19770176bb923fd048f71fb0c32b34b1587a5a704700f34771b2251`.
