# Lâmina Arcana direcional — entrega

Atlas V2 de 64 poses derivado das quatro vistas Codex 1123 de `mg_la` (receita em `recipe.md`, escolha por `selection.json`). Sem nova geração de imagem.

- `body.png` e `weaponless.png` são iguais (256×1024); SHA256 do arquivo `f27ef129457d68735aaef46e08c26883933a9f44c153587a064a6976422c38c8`, RGBA canônico `ce1aa89cbcf8680ed9b042744208dc913301d99b019238239956d104d344e4af`.
- `calibration.json`: 64 registros, 112 grips vivos (main/off por pose viva) mais pontos de queda nas mortes e âncora de cabeça por pose. 9 quadros têm correção manual em `calibration_authoring.json`.
- `presentation.json` é gerado pelo empacotador e só existe se o hash RGBA e o chão de cada pose conferem com a calibração.
- Sem `bare_head.png`: as peças de cabeça compartilhadas assentam sobre `weaponless.png` (encaixe em `scripts/actors/equipment_head_fit_data.gd`).

Prova nativa (renderer real, janela, kind `arcane_blade` pela costura da T1): 64 poses nuas, com espada+escudo, com cajado+foco, marcadores de grip e peças de cabeça. Resultado e limitações em `docs/epics/e09/t7_delivery.md`. Revisão visual por mim; aceite de produto continua do usuário.
