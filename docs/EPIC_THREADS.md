# Chats e retomada — conferido em 17/10/2026

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
isolado, runner transferido exclusivamente. ID e base documental após criação.
