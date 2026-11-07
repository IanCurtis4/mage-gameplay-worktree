# Receita — Beast Master direcional em staging

S/N usam células nativas de `assets/art/animations/beast_master.png` sem reamostragem, com índices em `source_recipe.json`. E/W são fontes independentes, incluindo o arco na mão e ao lado do corpo nas mortes. Prompts e hashes em `provenance.json`.

Reproduzir: `python tools/prepare_e08_enemy_directional_art.py beast_master`. O produtor deriva altura 50 da mediana de repouso nativa e escala 0,17889087656529518 nas fontes novas; atlas 256×1024, pivô (32,58). `weaponless` é null: os slots são placeholders não usados e head invisível, sem alegação de rig ou encaixe equipável.

A prova offline comparou as 32 células nativas byte a byte, verificou 64 grounds/gutters e quatro blocos distintos e repetiu a geração com hashes idênticos. A leitura do arco, timing e silhueta no renderer, câmera e jogo aguarda Sol; PNG e alpha não provam esses aspectos.
