# Receita — Elementalista direcional em staging

Quatro vistas geradas independentemente a partir da linha superior do conceito aprovado; prompts integrais e hashes em `provenance.json`. A receita seleciona correções localizadas norte poses 4 e 6, leste pose 3, preservando as outras células originais. Nenhuma vista foi espelhada.

Preparar: `python tools/prepare_e08_directional_art.py elementalist`. A ferramenta usa um fator global 0,18018018018018017, pivô (32,58), atlas 256×1024 e 64 células 64×64. Sem arma embutida, body e weaponless são cópias iguais em caminhos separados. O manifesto só é emitido se o hash RGBA do atlas coincidir com o da calibração; `--atlas-only` é preparação para autoria.

A calibração foi conferida visualmente com raster ampliado e candidatos de cor de pele; a mão direita anatômica é main, com profundidade por vista. Poses de morte têm pontos próprios, mas requerem inspeção de equipamentos e capacete no renderer; alpha sozinho não prova anatomia ou legibilidade. Prova nativa e aceite artístico continuam pendentes.
