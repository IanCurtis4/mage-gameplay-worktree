# Cultista direcional — entrega

Atlas V2 de 64 poses derivado das quatro vistas Codex de `e08_codex_1118/characters/cultist` (receita em `recipe.md`, escolha por `selection.json`). Sem nova geração de imagem.

- `body.png` e `weaponless.png` são iguais (256×1024); SHA256 do arquivo `ac3d1aea2941def8f5fc501c51b5c8b755a571133eecb59f38cceb175ace33d9`, RGBA canônico `8bba5b2127657eb441ba77fd06ca2edef7dbe39d6fb1adc4b26dff0e482582d5`.
- `calibration.json`: 64 registros, 112 grips vivos (main/off por pose viva) mais pontos de queda nas mortes e âncora de cabeça por pose. 7 quadros têm correção manual em `calibration_authoring.json`.
- `presentation.json` é gerado pelo empacotador e só existe se o hash RGBA e o chão de cada pose conferem com a calibração.
- Sem `bare_head.png` nesta entrega: as peças de cabeça compartilhadas assentam sobre `weaponless.png` (encaixe em `scripts/actors/equipment_head_fit_data.gd`).

Prova nativa (renderer real, janela, corpo escolhido pela costura da T1): 64 poses nuas, com livro de orações, cetro e relicário, marcadores de grip e peças de cabeça. Resultado, capturas e limitações em `docs/epics/e10a/t8_delivery.md`. Revisão visual por mim; aceite de produto continua do usuário.
