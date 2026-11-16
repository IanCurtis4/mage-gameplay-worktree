# Taumaturgo direcional — entrega

Atlas V2 de 64 poses derivado das quatro vistas Codex 1123 de `mg_ac` (receita em `recipe.md`, escolha por `selection.json`). Sem nova geração de imagem.

- `body.png` e `weaponless.png` são iguais (256×1024); SHA256 do arquivo `768a03e7e4581a4bb176459230b58bb1fdd1d3390c3205ac280123c397b92768`, RGBA canônico `c5e3022813dfe7e36caa223eed74a954075a97c5cb57bff728b9853eb6d2c942`.
- `calibration.json`: 64 registros, 112 grips vivos (main/off por pose viva) mais pontos de queda nas mortes e âncora de cabeça por pose. 25 quadros têm correção manual em `calibration_authoring.json`.
- `presentation.json` é gerado pelo empacotador e só existe se o hash RGBA e o chão de cada pose conferem com a calibração.
- Sem `bare_head.png`: as peças de cabeça compartilhadas assentam sobre `weaponless.png` (encaixe em `scripts/actors/equipment_head_fit_data.gd`).

Prova nativa (renderer real, janela, kind `thaumaturge` pela costura da T1): 64 poses nuas, com espada+escudo, com cajado+foco, marcadores de grip e peças de cabeça. Resultado e limitações em `docs/epics/e09/t7_delivery.md`. Revisão visual por mim; aceite de produto continua do usuário.
