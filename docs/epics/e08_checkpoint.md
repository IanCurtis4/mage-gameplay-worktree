# E08 — checkpoint portátil de execução

6/11/2026. Coordenação P0/P7, chat `01a1ae9c-2471-74d2-84ad-9805a14dc543`.
[Autorização](e08_approved_plan.md), [contrato](e08_p0_contract.md),
[dispatch/donos](e08_dispatch.md). Este arquivo resume o ponto atual; recibos e
hashes detalhados continuam nas entregas. Não é aceite de produto.

## Checkout e estado

`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`, branch
`codex/e08`. Base F10 `c8b80b13d29c468afb7f2ad7ba75eec838e7df32`.
Último candidato recebido `55960be86ffe9e4b7ddec4570cd84abd1c184a15`, código
de correção P1 `3c405e9903ae930b719020b402afe65fc62caa22`. Apenas documentos
de coordenação serão commitados depois dessa base nesta rodada.
Quatro .bak de data/map_authoring permanecem não rastreados e preservados,
com hashes no recibo P0. Não trocar o habitual nem copiar seu save.

| Pacote | Estado real | Referência |
|---|---|---|
| P0 | Contratos/inventário/donos registrados; coordenação continua | e08_p0_receipt.md |
| P1 apresentação | Ponte e correção atlas/UI validadas/integradas por Sol/Luna | e08_p1_delivery.md; e08_p1_pilot_corrections_delivery.md |
| P2 áudio | Serviço e correção de soma validados/integrados | e08_p2_delivery.md; e08_p2_mix_delivery.md |
| P3 piloto | INCOMPLETO; WIP preservado em7f04830e01db0f49acefd47899c271b45b65adaf, Terra parado para produtor | e08_p3_delivery.md |
| P4–P7 | BLOQUEADOS pelo aceite humano do piloto completo | e08_approved_plan.md |

## Próximo passo autorizado

Luna concluiu o checkpoint P1 de atlas/UI sem divergência ou rerun. P0 devolve escrita ao MESMO Terra
P3 (`01a1aede-5799-76f2-835d-5418b5e395d9`) com novoHEAD/API e lista de arte.
Terra produzirá e integrará os atlas próprios de lobo/javali, concluirá provas
nativas/regressões e devolverá posse. P0 não substitui essa implementação.
Somente depois: supervisão do piloto, comparação F10/embalagem e candidato jogável
com antes/depois e roteiro para o usuário. Ainda NÃO há release E08 aprovado.

P1 (`01a1aea0-d67a-7023-9fcf-dbecfe5cef85`) e P2
(`01a1aebf-dbc4-7701-8b17-1441618fb9c6`) continuam disponíveis para correções.
Nunca dois escritores no checkout; novos dispatches precisam da transferência
explícita registrada. Sem chats P4–P6 reservados, master/push ou migração.

## Evidência e limites atuais

P1 correção:9/9 etapas e61checks nativos em1280×720/1920×1080, UI efetiva120%.
API set_body_atlas mantém estado, offsets, death_copy e snapshot por campos atuais.
UI real preenchida passou acesso por roda/foco e encaixe; ui_layout_test30PASS
resolveu a falha herdada sem mudar o oráculo. Supervisão desse checkpoint concluída.
P2mix validado por Sol/Luna:24impactos e32slots com pico protegido≈0,89026,
zero quadros>1; impacto isolado preservado após2,042ms de atraso de áudio.

P3 WIP: primeiros12WAVs e feedback/cores existem, mas recoloração não resolve
identidade de lobo/javali; não declarar acabamento concluído. Pares técnicos
antigos com HUD vazio são limitação de preparação da captura; provas reais de UI
preenchida pertencem à correção P1. Imagens/poses não certificam timing percebido.
Desempenho/release final e aceite visual/sonoro continuam pendentes.

Engine fixada: standard4.7.2.stable.official.ed1daf0bf no principal .tools/godot,
SHA256ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424.
Uma fixture reutilizável em .godot/verification/e07_f1/fixture_project;
APPDATA isolado. CLI tools/workflow/workflow.py e WORKFLOW_TOOLING.md não existem
nesta base: retomadas usam Git/contratos, sem copiar tooling adivinhado.
O habitual não foi modificado por esta coordenação; inspecionar novamente antes
de qualquer aplicação. Não houve nova execução de gameplay por este resumo.
