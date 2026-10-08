# E05 — Caçadora: checkpoint consolidado

08/10/2026. Contrato: [E05_HUNTER_PLAN.md](E05_HUNTER_PLAN.md).
Autorização humana conferida no chat Astra, turno `01a11b69-b678-74d0-a9e5-c8efff3d17f0`.
Branch `codex/e05-hunter`, base `3d452fa2e4455f4c8636f4fb319a2d0607d08582`.

## Estado

Contrato numérico de protótipo consolidado; implementação começando.
Caçadora permanece indisponível. Nenhuma revisão/aceite de gameplay desta classe.
Playtest habitual limpo na base3d452fa, sem alteração nesta entrega.
Atributos já revisados/publicados por Astra; cabeçalho antigo do checkpoint de
atributos antecede essa decisão. Ícones aee3e18/revisão35901f6 separados e não
integrados. Master e saves pessoais não foram alterados.

## Camadas / evidência

- H1: contrato, IDs, tuning, consumidores, builds e limites definidos.
- H2: próximo núcleo — ativação→abertura→tiro→Passo; invariantes de snapshots,
  claims por emissão/vítima, pausa, letal e limpeza antes de integrar variantes.
- H3: traps/campos e Piche→Explosiva.
- H4: Marca, Tiro de Cobertura, camuflagem territorial com limite compartilhado.
- H5: catálogo/passivas/builds/save/admin/menu e testes ponta a ponta.
- H6: atlas/ícones/VFX e provas nativas solo/grupo/boss.
- H7: integral no HEAD limpo e pacote único para revisão, sem publicar playtest.

Nenhuma execução anterior dos atributos é evidência desta classe. CLI externo
autorizado: `menu-tabs/tools/workflow/workflow.py`, origem0c008d4,
SHA256 `e642dbe882cd7ea3cd687da51ed978bdecc93675fbb31d08d26626a0b40a1bae`;
sempre `--project` no d066, derivando seleção do verify.ps1 local.
Engine `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe`,
4.7.2standard. Evidência de implementador e reviewer permanecem separadas.

## Limitações e próximo passo

Kit/arte/playtest ainda não concluídos; não declarar classe jogável nem desempenho.
Prosseguir H2 e demais camadas autorizadas, atualizar este checkpoint com commits,
resultados e pendências. Nenhum gate por microtarefa nem mensagem a outros chats
por efeito das skills. Só escalar bloqueio ou divergência relevante do contrato.
