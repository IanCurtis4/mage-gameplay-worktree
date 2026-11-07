# Guerreiro NPC — receita

Preserva32nativas S/N de warrior.png, sem reamostragem, mapeamento explícito em
source_recipe.json. E/W novos independentes mantêm combatente ruivo/lenço rubro,
espada na mão direita e broquel esquerdo incorporados; oeste apresenta escudo
mais próximo, leste espada mais próxima. Transparência, crop/matte/conectividade,
escala global alvo50 e alfa128 pelo pipeline existente, sem raster procedural.
Reprodução: `python tools/prepare_e08_enemy_directional_art.py warrior`.
Fontes/prompts completos/hashes em provenance.json. Pivô32,58 e64grounds medidos.
Sem arma/chapéu separado: slots/head são explicitamente não usados neste NPC.
