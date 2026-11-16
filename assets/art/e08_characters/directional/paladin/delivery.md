# Paladino direcional — entrega

Atlas V2 de 64 poses derivado das quatro vistas Codex 1123 de `sp_ac` (receita em `recipe.md`, escolha por `selection.json`). Sem nova geração de imagem.

- `body.png` e `weaponless.png` são iguais (256×1024); SHA256 do arquivo `e68b4bd709ad6d2e79abda31ea18c3905d8253b41a0ed3c13df287e03baaa641`, RGBA canônico `5d058e8abf3c5f66dfd1f5c6dc6a0625336a6342b630a758928db2b172ad9a21`.
- `calibration.json`: 64 registros, 112 grips vivos (main/off por pose viva) mais pontos de queda nas mortes e âncora de cabeça por pose. 17 quadros têm correção manual em `calibration_authoring.json`.
- `presentation.json` é gerado pelo empacotador e só existe se o hash RGBA e o chão de cada pose conferem com a calibração.
- Sem `bare_head.png`: as peças de cabeça compartilhadas assentam sobre `weaponless.png` (encaixe em `scripts/actors/equipment_head_fit_data.gd`).

Prova nativa (renderer real, janela, kind `paladin` pela costura da T1): 64 poses nuas, com espada+escudo, com cajado+foco, marcadores de grip e peças de cabeça. Resultado e limitações em `docs/epics/e09/t7_delivery.md`. Revisão visual por mim; aceite de produto continua do usuário.
