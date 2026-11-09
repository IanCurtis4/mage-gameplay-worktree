# Guardião da Floresta (chefe) — receita

Quatro vistas geradas (sul/norte/leste/oeste), folhas 1254² transparentes 4x4 do Codex
(imagegen) em `assets/art/e08_world/staging/species/e08_forest_warden/<vista>_source_v1.png`,
somente leitura. Linha 1 repouso, 2 caminhada, 3 ataque, 4 dois danos + duas mortes;
`source_recipe.json` declara `generated_views`, `per_view_scale` e `target_height` 55.
Sem atlas V1 nativo, sem desenho/pintura: apenas recorte, matte, conectividade, escala
por vista (mediana de repouso da vista → altura alvo, limitada a 58x56 por quadro),
alfa128 e empacotamento pelo pipeline existente; pivô (32,58), chão 57 nas 64 poses.
Equipamento: cajado de galhos embutido; galhada; sem projeção dinâmica (NPC). Reprodução:
`python -I tools/prepare_e08_enemy_directional_art.py e08_forest_warden`.
Proveniência: pendente do Codex (ver provenance.json; prompts não inventados).
RGBA `09d72c9613e6e7c9a1adedd56571c3128838675a68904fe83aa1e5777bf07424`.
