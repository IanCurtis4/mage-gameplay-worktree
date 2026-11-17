# Duelista direcional — entrega

Atlas V2 de 64 poses derivado das quatro vistas Codex 1123 de `sp_la` (receita em `recipe.md`, escolha por `selection.json`). Sem nova geração de imagem.

- `body.png` e `weaponless.png` são iguais (256×1024); SHA256 do arquivo `14b573c7c9524b31f04d6d9f8c0414eab5fbd44f7f0d1ec73bc450eead7302a3`, RGBA canônico `5d6b5e05cce3e03f7fc8294910402e3097f9644151f4bd2f5830d216ac472a95`.
- `calibration.json`: 64 registros, 112 grips vivos (main/off por pose viva) mais pontos de queda nas mortes e âncora de cabeça por pose. 56 quadros têm correção manual em `calibration_authoring.json`.
- `presentation.json` é gerado pelo empacotador e só existe se o hash RGBA e o chão de cada pose conferem com a calibração.
- Sem `bare_head.png`: as peças de cabeça compartilhadas assentam sobre `weaponless.png` (encaixe em `scripts/actors/equipment_head_fit_data.gd`).

Prova nativa (renderer real, janela, kind `duelist` pela costura da T1): 64 poses nuas, com espada+escudo, com cajado+foco, marcadores de grip e peças de cabeça. Resultado e limitações em `docs/epics/e09/t7_delivery.md`. Revisão visual por mim; aceite de produto continua do usuário.
