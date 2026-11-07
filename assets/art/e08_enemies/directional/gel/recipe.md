# Gel — receita de autoria

E/W novos independentes imagegen; fontes e prompts em provenance.json.
S/N mantêm32células originais sem reamostragem, mapeamento em source_recipe.
Normalização mecânica pelo pipeline existente remove_matte/keep_character,
escala global e alpha128; alvo38,5px da mediana original, não altura humanoide.
Reprodução: `python tools/prepare_e08_enemy_directional_art.py gel`.
O wrapper produz64grounds, slots não usados e head.visible=false; não foi
calibrado rig de mão porque essa espécie não equipa acessórios. Não promover
sem prova nativa/consumidor real/PCK/coldrestore/custo conforme contratoNPC.
