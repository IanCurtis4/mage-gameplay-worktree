# Acólito direcional — entrega

Atlas V2 de 64 poses derivado das quatro vistas Codex de `e08_codex_1116/characters/acolyte` (receita em `recipe.md`, escolha por `selection.json`). Sem nova geração de imagem. As folhas de leste, oeste e norte foram normalizadas à altura da vista sul pelo `normalize_scale.py` (`*_normalized.png`).

- `body.png` e `weaponless.png` são iguais (256×1024); SHA256 do arquivo `3436347ce3cccc9dd768d1c3732435f2b580a0ef50fa3d1c7ed6afc313157690`, RGBA canônico `c3efbf64b806238962354c516e0c8034cd0071c9ab501ba131c14fb71d62bbd5`.
- `calibration.json`: 64 registros, 112 grips vivos (main/off por pose viva) mais pontos de queda nas mortes e âncora de cabeça por pose. 6 quadros têm correção manual em `calibration_authoring.json`.
- `presentation.json` é gerado pelo empacotador e só existe se o hash RGBA e o chão de cada pose conferem com a calibração.
- Sem `bare_head.png` nesta entrega: as peças de cabeça compartilhadas assentam sobre `weaponless.png` (encaixe em `scripts/actors/equipment_head_fit_data.gd`).

Prova nativa (renderer real, janela, corpo escolhido pela costura da T1): 64 poses nuas, com livro de orações, cetro e relicário, marcadores de grip e peças de cabeça. Resultado, capturas e limitações em `docs/epics/e10a/t8_delivery.md`. Revisão visual por mim; aceite de produto continua do usuário.
