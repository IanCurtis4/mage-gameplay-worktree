# Chats e retomada — atualizado em6/11/2026

> Estado vigente em 6/11: [piloto aceito com ressalva sonora](epics/e08_p3_product_acceptance.md); P4 autorizado, [contrato](epics/e08_p4_contract.md). Bloqueios por aceite P3 nos registros abaixo são históricos. P5/P6/P7 ainda dependem das entregas anteriores; não despachados.


## E08 — piloto aceito com ressalva sonora; P4 autorizado

[Plano aprovado](epics/e08_approved_plan.md), [dispatch/donos](epics/e08_dispatch.md),
[checkpoint](epics/e08_checkpoint.md) e [candidato jogável](epics/e08_pilot_release.md).
Arquitetura: `01a1ae95-13a2-71c2-84d6-8f98c23b57d6`.

| Papel | Chat | Estado |
|---|---|---|
|P0/P7 Sol|01a1ae9c-2471-74d2-84ad-9805a14dc543|P0/piloto consolidado; P7 final ainda bloqueado|
|P1 Sol|01a1aea0-d67a-7023-9fcf-dbecfe5cef85|Ponte e atlas/UI validados/integrados|
|P2 Sol|01a1aebf-dbc4-7701-8b17-1441618fb9c6|Áudio e soma validados/integrados|
|P3 Terra|01a1aede-5799-76f2-835d-5418b5e395d9|Piloto validado/integrado e aceito com ressalva sonora|
|P4 Terra 6.1 médio|01a1b369-442b-7f91-82a1-2316a4a0514d|Espiritualista V2 integrada tecnicamente; conferência Luna em preparo; Elementalista em staging e demais artes pendentes|

Host local, checkout de execução/branch codex/e08 conforme dispatch; nunca dois
escritores. P1–P3 continuam disponíveis para correções no mesmo chat, com mensagens
autorizadas pelo usuário. Luna low concluiu conferência dos checkpoints e release.
P4 aberto após aceite humano do piloto; P5–P7 dependem das entregas anteriores. Sem master/push.

## Histórico da abertura — 5/11/2026

[E07/F10 aceitos em produto com ressalvas](epics/e07/e07_closure_2026_11_05.md).
O [brief de arquitetura E08](epics/e08_opening_2026_11_05.md) está preparado;
novo Astra permanente ainda não criado. Não inventar ID nem retomar reserva
histórica automaticamente. Nenhum chat foi criado/arquivado ou recebeu mensagem
por esta consolidação; integração operacional permanece separada.

## Situação atual22/10 — integração e consumidor F7

F1–F6 foram integradas; evidência, base efetiva e arquivamento estão no
[recibo operacional](epics/e07/f1_f6_integration.md). Worktrees produtoras e logs
permanecem preservados para correção, mesmo após arquivar os chats entregues.
F7 recebeu aval humano no próprio chat e tem [despacho real](epics/e07/f7_dispatch.md),
checkout `C:/Users/João Pedro/.codex/worktrees/e07-f7/RagRPG`, branch codex/e07-f7.
F8 continua aguardando aval. As reservas e pendências datadas18/10 abaixo são
históricas; não reabrir integração/decisões já comprovadas pelos novos registros.
Nenhuma mensagem automática foi enviada a F7 por esta integração.


Fonte normativa: [WORKFLOW](WORKFLOW.md). Estado de execução mora no
[checkpoint E06](epics/e06_checkpoint.md), não no status idle/completed do app.
Reservas e IDs antigos permanecem no [histórico](EPIC_THREADS.history_2026_10_17.md).

| Papel | Título no app | ID |
|---|---|---|
| Arquitetura E06 | RagRPG \| E06 — Arquitetura Astra | 01a11e1e-be3d-7243-affc-295c0dc00f9f |
| Solicitação/consolidação documental | Iniciar E06 com chats por tarefa | 01a11e1a-5eac-7992-9fd5-76e4cdcced19 |
| T1 | RagRPG \| E06-T1 — Composição e causalidade | 01a11f3e-33db-7ac0-88be-c2916ea3fe1f |
| T2 | RagRPG \| E06-T2 — Inventário e persistência | 01a1207c-fca8-79d2-9280-5dbc5e172c96 |
| TX e extensões | RagRPG \| E06-TX — Itemização em etapas | 01a12d55-0ce8-7061-b8e4-bf5650c8c5b7 |
| Arquitetura E07 permanente | RagRPG \| E07 — Arquitetura Astra | 01a14e2d-630b-7c50-bd03-9448f30711fc |
| E07-I0 arquivado após integração | RagRPG \| E07-I0 — Inventário técnico | 01a14e2d-b456-7063-bfe9-4cf727b25a59 |
| E07-F0 arquivado após integração | RagRPG \| E07-F0 — Montagem reproduzível | 01a14f91-d0c6-7c20-82c9-a22650fa5199 |
| E07-F1 executor | RagRPG \| E07-F1 — Altura e combate espacial | 01a14fae-037f-7602-814a-d1dbb5942143 |

Não duplicar tarefas existentes por ler uma tabela antiga “não criado”. Conferir
contrato/base/estado antes de retomar. IDs não autorizam mensagens a outros chats.
Nenhum chat foi criado, retomado ou arquivado nesta consolidação.

Na abertura18/10 posterior à consolidação: dois chats E07 criados na base
`029b8ca1d7b1752929d549cbeb51e534ea6d3c1d`, checkout habitual, apenas documentação
em arquivos disjuntos. Astra Alto prepara contratos/guias; Sol Médio inventaria
runtime. Não houve dispatch de implementação, arquivamento ou merge em master.

E07: [abertura autorizada](epics/e07_launch_queue.md). Em18/10 o usuário revogou
a espera por orçamento e autorizou criar conversas normalmente. Registrar IDs
efetivos abaixo; consumidores aguardam contratos. E08+ não liberados.
Na abertura efetiva de um novo épico, criar seu Astra permanente
de arquitetura; execução em tarefas temporárias proporcionais, com arquivamento
somente após registro/validação/integração. O Astra antigo não volta a ser gerente.

F0 despachado18/10: Sol/Alto, `codex/e07-f0`, checkout isolado
`C:/Users/João Pedro/.codex/worktrees/content-delivery-docs/RagRPG`, base
`e30c49bb6442344ce8d937910ca6170effc70c7a`. [Escopo](epics/e07/f0_dispatch.md).
I0 integrado em `3d79d83294d6bf1cfa45d7edc9a4cdd2defa86da` e arquivado.

Atualização18/10: F0 integrado em `42604ef8674a2c28f5aadc633b73cda15178e0b3`
e arquivado após conferência dos comprovantes; [registro](epics/e07/f0_integration.md).
F1 autorizado para lógica espacial com combate D05 aprovado; apresentação pendente.
[Despacho F1](epics/e07/f1_dispatch.md), branch codex/e07-f1 no mesmo checkout
isolado, runner transferido exclusivamente. Chat `01a14fae-037f-7602-814a-d1dbb5942143`, base executável `ab351817a7157e90b6853556b193c5cd28757f7c`.
Sol/Alto iniciou lógica espacial; apresentação D05 continua pendente.

Atualização posterior18/10: por pedido humano explícito, criados sete chats
temporários F2–F8 **AGUARDANDO_AVAL_HUMANO**, sem iniciar suas tarefas.
[Títulos, IDs e modelos](epics/e07_launch_queue.md#chats-a-postos--autorização-humana1810).
Todos receberam instrução de apenas confirmar espera e encerrar o turno, sem
ferramentas/planejamento/implementação/testes. Não há início automático após F1.
F6 continua opcional; base, checkout e propriedade serão definidos na liberação.
