# Cultista direcional — receita

Quatro vistas independentes do lote Codex 1118, uma por direção, sem espelhar nenhuma: `south`, `east`, `west`, `north`. A seleção (`selection.json`, T2 do E10a) vem do registro `selected` do lote. As quatro vistas já estavam na mesma escala (o validador só acusou o véu de alfa, que o empacotador remove), então não houve normalização. As folhas-fonte ficam na pasta do lote e não são copiadas.

Preparar (offline, nesta ordem):

1. `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py cultist --atlas-only` grava `body.png` e `weaponless.png` (iguais, sem arma embutida), 256×1024, 64 células 64×64, pivô (32,58), fator global de escala no `provenance.json`.
2. `python tools/prepare_e10a_family_calibration.py cultist write` escreve `calibration.json` a partir de `calibration_authoring.json` (correções revisadas) e do detector de pele (máscara mais rosada que a do E09, medida nos tons de pele desta família). `overlay` desenha as pranchas ampliadas com grade para a revisão.
3. `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py cultist` confere o hash RGBA e o chão de cada pose e escreve `presentation.json`.
4. `python tools/prepare_e10a_family_calibration.py cultist provenance` escreve `provenance.json` (v2, corpo e sem arma, com as quatro vistas escolhidas e os passos do pipeline).
5. `python tools/prepare_e08_head_fit.py write` regenera `scripts/actors/equipment_head_fit_data.gd`.

Calibração: Braços e ombros de pele nua: a máscara mais rosada acha as palmas e os antebraços, e a revisão corrigiu só onde o detector tomou ombro ou rosto por mão distante (oeste 48, 49, 53, 54, 55; leste 36) e o primeiro quadro do sul. Os 112 grips vivos caem em pixel opaco, dentro do recorte de 3×3 dedos. As cabeças usam o ponto do crânio, 8 px abaixo do topo medido.

Sem `bare_head.png`: o encaixe de cabeça é medido sobre `weaponless.png`. Os chifres de carneiro do penteado ficam sob a peça de cabeça nos quadros mais baixos; a captura nativa e o `delivery.md` registram o efeito.
