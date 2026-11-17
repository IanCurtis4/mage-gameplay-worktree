# Duelista direcional — receita

Quatro vistas independentes da entrega Codex 1123 (`sp_la`), uma por direção, sem espelhar nenhuma: `south, east, west, north_v2`. A escolha vem de `assets/art/e08_codex_1123/characters/sp_la/selection.json`; a `source_recipe.json` aponta cada vista por `@south`, `@north`, `@east` e `@west` e o empacotador resolve pelo `load_selection()` de `tools/art_pipeline/selection.py`, que confere o SHA256 antes de ler. As folhas-fonte ficam na pasta do lote e não são copiadas para cá.

Preparar (offline, nesta ordem):

1. `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py duelist --atlas-only` grava `body.png` e `weaponless.png` (iguais, sem arma embutida), 256×1024, 64 células 64×64, pivô (32,58), fator global de escala no `provenance.json`.
2. `python tools/prepare_e09_hybrid_calibration.py duelist write` escreve `calibration.json` a partir de `calibration_authoring.json` (correções revisadas) e do detector de pele.
3. `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py duelist` confere o hash RGBA e o chão de cada pose e escreve `presentation.json`.

Calibração: Luvas de couro vermelho-escuro, sem pele visível: todos os quadros vivos foram posicionados à mão sobre as células ampliadas. Os 112 grips vivos caem em pixel opaco, dentro do recorte de 3×3 dedos. Nas mortes (poses 14–15 de cada vista) as armas soltas ficam atrás do corpo e horizontais, como nas classes do E08. As cabeças usam o ponto do crânio, 8 px abaixo do topo medido; os ângulos de queda são os mesmos das classes do E08.

Sem `bare_head.png`: o encaixe de cabeça é medido sobre `weaponless.png` (peças de cabeça cobrem o cabelo desenhado). Um `bare_head` só entra se a captura nativa mostrar choque de elmo, o que o `delivery.md` registra.
