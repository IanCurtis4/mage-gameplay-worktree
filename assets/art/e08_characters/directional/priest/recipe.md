# Sacerdote direcional — receita

Quatro vistas independentes do lote Codex 1118, uma por direção, sem espelhar nenhuma: `south`, `east`, `west_v2`, `north`. A seleção (`selection.json`, T2 do E10a) vem do registro `selected` do lote. As quatro vistas já estavam na mesma escala (o validador só acusou o véu de alfa, que o empacotador remove), então não houve normalização. As folhas-fonte ficam na pasta do lote e não são copiadas.

Preparar (offline, nesta ordem):

1. `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py priest --atlas-only` grava `body.png` e `weaponless.png` (iguais, sem arma embutida), 256×1024, 64 células 64×64, pivô (32,58), fator global de escala no `provenance.json`.
2. `python tools/prepare_e10a_family_calibration.py priest write` escreve `calibration.json` a partir de `calibration_authoring.json` (correções revisadas) e do detector de pele (máscara mais rosada que a do E09, medida nos tons de pele desta família). `overlay` desenha as pranchas ampliadas com grade para a revisão.
3. `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py priest` confere o hash RGBA e o chão de cada pose e escreve `presentation.json`.
4. `python tools/prepare_e10a_family_calibration.py priest provenance` escreve `provenance.json` (v2, corpo e sem arma, com as quatro vistas escolhidas e os passos do pipeline).
5. `python tools/prepare_e08_head_fit.py write` regenera `scripts/actors/equipment_head_fit_data.gd`.

Calibração: Mesmo conjunto de poses do Acólito e mesma máscara de pele (robe creme com estola azul). Correções manuais: prece (sul 8), mãos erguidas (sul 9 e 10, norte 25–28), mão distante oculta nas vistas laterais (leste 36, 38, 42; oeste 48–51, 55, 56). Os 112 grips vivos caem em pixel opaco, dentro do recorte de 3×3 dedos. O halo dourado faz parte do desenho do corpo.

Sem `bare_head.png` nesta entrega. **Halo:** a regra de topo da cabeça (primeira linha com um trecho opaco ≥ 4 px, a mesma do teste de encaixe) acha o arco do halo, 3 px acima do cabelo, e mede a largura logo abaixo dele; o encaixe fica mais estreito e mais alto do que o das outras classes. A captura nativa e o `delivery.md` registram o efeito.
