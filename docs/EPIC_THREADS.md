# Chats vigentes e histórico — 09/10/2026

Norma: [WORKFLOW.md](WORKFLOW.md). A partir de E06, um Astra permanente novo por
épico cuida exclusivamente de arquitetura/contratos/guias; execução, revisão e
integração ficam em chats temporários com registro Git e arquivamento após
validação/integração. Essa regra substitui qualquer obrigação histórica abaixo
de reutilizar a reserva Sol do épico ou retomar Astra como gerente.

| Papel atual E06 | Título exato no app | ID |
|---|---|---|
| Arquitetura permanente | RagRPG \| E06 — Arquitetura Astra | 01a11e1e-be3d-7243-affc-295c0dc00f9f |
| Chat solicitante, dispatch das tarefas | Iniciar E06 com chats por tarefa | 01a11e1a-5eac-7992-9fd5-76e4cdcced19 |
| T1 — Sol / xhigh | RagRPG \| E06-T1 — Composição e causalidade | 01a11f3e-33db-7ac0-88be-c2916ea3fe1f |
| T2/T3/T4/T5/R | Não criados | Aguardam dependências de e06_tasks |

[Contrato](epics/e06_contract.md), [DAG/donos](epics/e06_tasks.md) e
[checkpoint](epics/e06_checkpoint.md) são o índice persistente.
Após D0, o usuário autorizou diretamente neste chat de arquitetura o dispatch
pontual de T1. Sol já iniciou ragrpg-resume na base0b2e4a0, com checkout próprio;
ver registro completo no checkpoint. A reserva E06 de13/09 não é o executor atual.
Nenhum contato ou retomada de chats históricos por efeito dessa mudança.
E07+ sem autorização. IDs não conferem por si só permissão para enviar mensagens.

---

## Reservas e decisões históricas — não são o roteamento atual

> Estado vigente em 23/09/2026: E04 encerrado e aceito; E05 liberado, somente E05-S0 em execução (docs/E05_START.md). E06–E11 reservados. As atualizações abaixo são históricas.

# Conversas reservadas dos épicos

> Atualização 21/09/2026: usuário aceitou E03 `495ee16`, integrado em master.
> E04 ativo na tarefa existente, um pacote por mensagem conforme
> `E04_SMALL_PACKAGES.md`. E05–E11 continuam reservados.

> Estado vigente em 20/09/2026: ver `RECOVERY_2026_09_20.md`. E02 corrigido,
> E03 ativo com Sol na tarefa já existente; E04–E11 continuam reservados.
> Worktrees antigas de reservas foram removidas; recriar na ativação.

## Roteamento aprovado em 14/09/2026

Estado posterior: E01 aprovado pelo usuário e integrado em master no candidato
`7fdecdd`; E02 explicitamente liberado, Terra conduz na conversa já reservada.
E03–E11 continuam sem execução. O estado de reserva E02 abaixo é histórico.

E00 aceito; E01 aceito tecnicamente e aguardando playtest, mantendo Sol como dono.
As demais tarefas continuam reservadas. Na ativação, usar a mesma conversa e
escolher modelo para o pacote. A tabela histórica registra modelo de criação,
não obriga mantê-lo. Trocas futuras autorizadas, ainda não enviadas ao app.

| Épico | Condutor na próxima ativação | Apoio por pacote |
|---|---|---|
| E02 | Terra | Luna textos/estados |
| E03 | Sol | Terra painel/árvore; Luna tooltips/dados |
| E04 | Sol nas novas mecânicas; Terra nos kits sobre primitivas prontas | Luna ranks/textos; Astra identidade/contratos |
| E05 | Sol na gramática; Terra na UI/integração | Luna combinações definidas; Astra identidade |
| E06 | Sol no pipeline; Terra no catálogo/UI | Luna pools/textos |
| E07 | Sol no fluxo/IA/boss; Terra nos encontros sobre IA pronta | Luna composições |
| E08 | Terra | Luna inventário/receitas; Sol novas fronteiras runtime; Astra padrão visual |
| E09 | Terra na preparação | Luna evidências; Sol defeitos sistêmicos; Astra auditoria final |
| E10/E11 | Escolha por família/par depois do demo | Sem execução agora |

Revisão e pacotes: docs/REVIEW_WORK_PACKAGES.md. Não encaminhar toda entrega
por todos os modelos nem criar conversas duplicadas para trocar modelo.

## Registro histórico de criação

13/09/2026. Todas criadas como reservas; primeiro turno limitado a reconhecimento, sem implementação. Estado de produto: **RESERVADO**, mesmo se o app exibir completed/idle porque o reconhecimento terminou. Ativação somente por liberação futura do usuário a Astra.

| Épico | Título retornado pelo app | ID da conversa | Modelo inicial |
|---|---|---|---|
| E00 | RagRPG \| E00 — Contratos do MVP expandido… | 01a09b9e-f8da-7a21-b1bd-7c385765f1ff | Astra |
| E01 | RagRPG \| E01 — Personagens persistentes… | 01a09b9f-83fa-7c73-bef7-6ecb7bbc4df2 | Sol |
| E02 | RagRPG \| E02 — Menu de personagem e… | 01a09b9f-9399-7e80-abd2-f37f8153d6a3 | Terra |
| E03 | RagRPG \| E03 — Stats, job e níveis de… | 01a09b9f-9e68-7fa0-96e2-96e0362e68d2 | Sol |
| E04 | RagRPG \| E04 — Três classes base completas… | 01a09b9f-b01a-7793-a975-49f864ae0bb1 | Sol |
| E05 | RagRPG \| E05 — Evoluções e seis híbridas… | 01a09ba0-0734-71b2-9c51-30f570b22db2 | Sol |
| E06 | RagRPG \| E06 — Augments, equipamentos… | 01a09ba0-1779-7ba1-b35b-acbed460c68c | Sol |
| E07 | RagRPG \| E07 — Campanha de três fases… | 01a09ba0-244d-7440-9a4d-9385b9def7b7 | Sol |
| E08 | RagRPG \| E08 — Arte, animações e feedback… | 01a09ba0-3311-71f3-bc72-b609e0b99a90 | Astra |
| E09 | RagRPG \| E09 — Integração e primeiro… | 01a09ba0-ed25-7fa2-962f-6219ecbc7f2f | Astra |
| E10 | RagRPG \| E10 — Cinco bases restantes… | 01a09bae-0327-7c91-ae64-a10e750778b6 | Sol |
| E11 | RagRPG \| E11 — Catálogo das 56 híbridas… | 01a09bae-6898-7d52-a54e-9e7f529a2e05 | Astra |

Handoffs: docs/epics/e00.md até e11.md. Escopo/dependências/gates em LONG_TERM_EPICS.md.
As worktrees reservadas podem ter snapshot anterior ao roadmap; a coordenação deve
sincronizar a base aceita antes de executar. Não iniciar código só porque o app
exibe uma conversa nova. Nenhum monitor/agendamento foi criado.

A criação do E10 foi interrompida na preparação do ambiente durante reinicialização
da conexão do app, antes de existir conversa; houve nova criação após verificar
os registros locais. Há uma worktree órfã cf66 sem conversa, preservada sem exclusão.
Os 12 IDs acima são as reservas efetivas, verificadas por read_thread/wait_threads.


