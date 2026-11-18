# Acólito direcional — receita

Quatro vistas independentes do lote Codex 1116, uma por direção, sem espelhar nenhuma: `south_v5`, `east_v3`, `west_v3`, `north`. O lote 1116 nunca guardou `selected`; a escolha é a da tabela de C4.1 (versão mais recente de cada vista) e está em `assets/art/e08_codex_1116/characters/acolyte/selection.json` (a T2 do E10a). As folhas-fonte ficam na pasta do lote e não são copiadas.

**Escala.** O validador do pipeline neutro (`validate_sheet.py --reference south`) apontou `scale_mismatch` em três vistas: leste 0,868, oeste 0,836 e norte 1,120 da altura parada do sul. O `normalize_scale.py` (filtro `nearest`, sem suavização) igualou as três à vista sul (alturas paradas 246 px depois, razão 0,998) e as folhas normalizadas ficam aqui (`east_normalized.png`, `west_normalized.png`, `north_normalized.png`); `source_recipe.json` aponta para elas, e o sul sai direto da seleção (`@south`). O `provenance.json` registra cada passo de normalização com os hashes de entrada e de saída.

Preparar (offline, nesta ordem):

1. `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py acolyte --atlas-only` grava `body.png` e `weaponless.png` (iguais, sem arma embutida), 256×1024, 64 células 64×64, pivô (32,58), fator global de escala no `provenance.json`.
2. `python tools/prepare_e10a_family_calibration.py acolyte write` escreve `calibration.json` a partir de `calibration_authoring.json` (correções revisadas) e do detector de pele (máscara mais rosada que a do E09, medida nos tons de pele desta família). `overlay` desenha as pranchas ampliadas com grade para a revisão.
3. `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py acolyte` confere o hash RGBA e o chão de cada pose e escreve `presentation.json`.
4. `python tools/prepare_e10a_family_calibration.py acolyte provenance` escreve `provenance.json` (v2, corpo e sem arma, com as quatro vistas escolhidas e os passos do pipeline).
5. `python tools/prepare_e08_head_fit.py write` regenera `scripts/actors/equipment_head_fit_data.gd`.

Calibração: O robe é creme e a máscara de pele do E09 (r−g 22–60) pegava o tecido; a máscara desta família usa r ≥ 200 e r−g 34–62, g−b 16–34 (palmas medidas em r−g 40–56 e g−b 21–27, robe creme em r−g 20 e g−b 12). Correções manuais só onde as mãos estão dentro das mangas ou erguidas: prece (sul 8, norte 24, oeste 56), mão erguida (sul 9 e 10) e mão distante oculta (oeste 55). Os 112 grips vivos caem em pixel opaco, dentro do recorte de 3×3 dedos; nas mortes (poses 14–15 de cada vista) as armas soltas ficam atrás do corpo e horizontais, como nas classes do E08. As cabeças usam o ponto do crânio, 8 px abaixo do topo medido; os ângulos de queda são os mesmos das classes do E08.

Sem `bare_head.png`: o encaixe de cabeça é medido sobre `weaponless.png` (peças de cabeça cobrem o cabelo desenhado). Cabelo longo e laço aparecem sob a faixa nos quadros de dano e queda, como nas híbridas do E09; um `bare_head` só entra se a captura nativa mostrar choque de elmo, o que o `delivery.md` registra.
