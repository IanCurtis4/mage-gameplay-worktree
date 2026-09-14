# Conversas reservadas dos épicos

## Roteamento aprovado em 14/09/2026

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

