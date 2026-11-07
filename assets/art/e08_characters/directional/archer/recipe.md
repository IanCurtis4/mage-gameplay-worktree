# Receita — Arqueiro direcional em staging

S/N usam células nativas `assets/art/animations/archer_weaponless.png`, índices exatos em `source_recipe.json`, sem reamostragem. Inspeção ampliada das oito células legadas de dano/morte não identificou arco embutido; aljava e flechas nas costas são parte preservada da roupa original. E/W são gerados independentemente; correções de caminhada E7 e W6/W7 são selecionadas por célula. Prompts e hashes em `provenance.json`.

Reproduzir com `python tools/prepare_e08_directional_art.py archer`. Escala nova 0,18587360594795538; pivô (32,58), atlas 256×1024. Body e weaponless iguais em caminhos separados, arco de jogador é anexo. Manifesto só é emitido com hash RGBA compatível com a calibração.

S/N remapeiam pontos e crops do rig legado com ângulos e profundidade por fase; E/W têm luvas escolhidas nas imagens ampliadas. Head.flip false inclusive oeste; os oito frames de morte têm depth0 e ângulos absolutos PI/2 para equipamentos soltos, contas0. A prova offline compara 32 células nativas e verifica alpha dos 112 grips em ambos corpos; alpha não substitui inspeção anatômica ou de oclusão no renderer.
