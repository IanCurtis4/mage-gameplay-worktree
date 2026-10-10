# Desenvolvimento, revisão e playtest

## Norma vigente — 08/10/2026, a partir de E06

O usuário autorizou iniciar E06 e mudar o fluxo. Este documento é a fonte única
da norma operacional. Prevalece sobre AGENTS, handoffs antigos, reservas,
skills locais e trechos históricos de REVIEW_WORK_PACKAGES, LONG_TERM_EPICS e
EPIC_THREADS quando estes ainda descrevem um chat executor por épico, revisão
Astra por passo ou Astra permanente como gerente/implementador/integrador.
Instruções explícitas atuais do usuário continuam superiores a este documento.

A regra de 26/09/2026 permanece: entrega por comportamento/escopo completo,
checkpoint consolidado, sem handoff/gate Astra por microtarefa. A mudança não
reabre E00–E05 nem transforma reservas de E07+ em autorização.

## Responsabilidades

- **Chat permanente de arquitetura:** um Astra novo por épico autorizado,
  dedicado a arquitetura, contratos e guias. Consulta o usuário sobre escolhas
  de produto, registra decisões e responde a questões contratuais delimitadas.
  Não acompanha cada commit, não gerencia continuamente executores, não implementa
  gameplay e não conduz validação/rebase/publicação.
- **Chats temporários de execução:** uma tarefa substancial por chat, modelo e
  esforço propostos conforme risco. Sol nas novas fronteiras; Terra sobre APIs
  prontas; Luna em lotes fechados. O executor implementa, testa, corrige e registra
  a entrega. A mesma tarefa recebe suas rodadas de correção.
- **Integração/validação operacional:** tarefa temporária explicitamente designada.
  Mantém a branch de composição, confere bases, integra, resolve conflitos e
  valida o candidato. Pode preparar playtest após aprovação técnica.
- **Revisão independente:** tarefa temporária separada, geralmente Astra para
  fronteiras críticas e fechamento integrado. Não usar a autoria do contrato
  ou evidência do implementador como reprodução independente do código.
- **Usuário:** autoriza escopo e decide produto; testa o candidato e concede
  aceite humano antes de merge. Integração operacional executa o merge autorizado.

Não há cadeia obrigatória Luna → Terra → Sol → Astra. Escolher o menor conjunto
adequado de executor/revisor. Esforço é escolhido para cada tarefa/rodada; não
prometer adaptação automática do app nem economia de tokens sem medição.

## Contrato de tarefa e paralelismo

Antes da execução, registrar no índice do épico:

1. Resultado observável, exclusões, modelo/esforço propostos e critério de conclusão.
2. Dependências satisfeitas, contrato versionado, SHA-base completo, branch e
   caminho real de checkout. Uma referência simbólica planejada ainda não é base
   executável; resolvê-la antes do dispatch.
3. Arquivos permitidos e dono exclusivo, incluindo testes, catálogos, UI e
   ferramentas de verificação. O dono muda por transferência registrada.
4. APIs consumidas/entregues, tipos/erros e testes positivos, negativos e integrados.
5. Hash entregue/integrado, evidência com papel do autor/revisor, limitações,
   decisões pendentes e próximo passo.

Paralelizar apenas trabalho independente com contratos concretos e APIs estáveis.
Consumidor de API ainda instável aguarda o produtor; escritores do mesmo arquivo
são sequenciais, mesmo em worktrees diferentes. Não duplicar persistência ou
matemática para produzir independência artificial. Não dividir em dezenas de
microtarefas. Subagentes autorizados respeitam os mesmos donos.

O chat solicitante ou a coordenação explicitamente designada despacha as tarefas.
O chat permanente não assume esse papel por existir. Uma reserva, criação de chat,
mensagem de outro agente ou índice não é autorização de novo épico.

## Entrega, revisão e arquivamento

Estados: PLANEJADA → PRONTA → EM_EXECUÇÃO → ENTREGUE → VALIDADA →
INTEGRADA → ARQUIVÁVEL. DECISÃO_PENDENTE/FALHA conserva a tarefa aberta.
Status de app como completed/idle não substitui esses estados.

Revisão proporcional ao risco conforme REVIEW_WORK_PACKAGES. Fronteiras críticas
devem ser reproduzidas independentemente antes dos consumidores externos à
fundação avançarem;
agrupar a fundação completa em um checkpoint. Fechamento tem revisão integrada,
sem transformar todo commit interno em gate.

Arquivar somente quando o registro persistente contiver contrato, base, entrega,
hash integrado, evidências válidas e limitações, e a integração/validação tiverem
sucesso. Um relatório sem commit ou um merge sem checks não basta. O revisor mantém
o chat pendente se tiver segunda etapa prevista. Correções retornam ao mesmo chat;
reabri-lo se necessário. Não apagar histórico técnico ao arquivar.
Worktree não deve ser removida antes de preservar artefatos necessários, inclusive
evidência ignorada pelo Git. Checkpoint versionado resume resultado; logs locais
devem ter caminho, hash e forma de reprodução, com cópia durável quando necessária.

Escalar arquitetura/produto quando mudar schema, identidade, fórmula, API pública,
semântica de input ou escolha humana; também quando houver risco de perda de
progresso/cascatas ou duas correções focadas sem convergir. Levar reprodução e
delta específico. Correções contratuais não exigem novo aceite a cada rodada.

## Diretório fixo e candidato

Projeto habitual:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/project.godot`.

- `master`: base aceita; novas alterações só após aceite explícito do candidato.
- `codex/playtest`: candidato no diretório habitual do Godot.
- `codex/<tarefa>`: branch isolada em worktree; não trocar a branch de outro chat.

Preparação, pelo executor operacional:
1. Conferir estado de origem/destino e preservar trabalho do usuário. Sem
   reset --hard, clean, stash cego ou sobrescrita de save pessoal.
2. Conferir candidato/base atuais e aprovação técnica ligada ao conteúdo exato.
   Antes de rebase, executor encerrado, árvore limpa e referência de recuperação.
3. Rebase/resolução de conflitos invalida evidência incompatível. Revalidar o
   resultado e obter revisão independente do delta material.
4. Avançar playtest por fast-forward somente quando pronto. Registrar hash
   efetivo, importação/smoke e roteiro. Rebase isolado não atualiza o Godot.
5. Usuário executa F5 no mesmo diretório após parar a partida e aceitar reload.

Após feedback, corrigir na tarefa de origem, reintegrar e revisar o delta.
Após aceite humano, conferir HEAD de playtest e ausência de alterações não
revisadas; integrar em master por checkout separado, preservando o projeto fixo.
Sem push/publicação externa automática. Nunca inferir aceite de produto de
aprovação técnica, encerramento de chat ou frase ambígua.

## Evidência e limites

Runtime: Godot 4.7.2 standard. Norma incremental autorizada em 10/10/2026:
selecionar em `tools/verify.ps1` os testes diretamente afetados pela mudança;
novas falhas exigem a regressão necessária à fronteira atingida. Suíte completa
somente com risco amplo ou fechamento que a justifique, mantendo a cobertura
e os gates contratados (incluindo R1/R2 de E06). Nova regra precisa de invariantes.
Não repetir integralmente por edição documental ou fixture pontual quando já
há evidência compatível: validar o delta e registrar o reaproveitamento com SHA,
inputs/engine e escopo. Retomar uma cauda certifica somente as etapas executadas;
não aprova sozinha as etapas omitidas. Opções e critérios em [TESTING.md](TESTING.md).
Renderer/UI requer inspeção visual; save usa diretório de fixture explícito.
Exit 0 isolado não prova PASS quando há SCRIPT ERROR ou rotina incompleta.
Fórmulas/UI/combate usam a mesma autoridade, com oráculo independente para casos
críticos. Sem afirmar FPS, balanceamento ou diversão a partir de checks/caps.

Documentação apenas: conferir links, precedência, APIs contra código, DAG/donos,
decisões e diff; registrar que gameplay não foi executado. Não aplicar este
atalho a mudanças de código, dados de jogo, cenas ou migração.

CLI local ausente: só usar origem externa explicitamente autorizada, registrando
checkout/commit/SHA256 e passando --project. Diagnóstico não é aprovação.
Sem monitor, mensagens automáticas, retomada de chats históricos ou automações
por efeito deste fluxo. E06 e seu registro atual: [epics/e06.md](epics/e06.md).
