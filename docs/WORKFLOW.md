# Desenvolvimento, revisão e playtest

## Atualização humana de28/10/2026 — meta de conclusão F9

Meta ativa: entregar o restante de F9, com mapa possível de testar; F10 reunirá
os mapas em uma fase completa após sua própria abertura. Sol assume código e
integração por ora; Terra cria mapas usando sempre o editor no modo AX; Luna
cuida dos testes automatizados e código fácil ou repetitivo delimitado. Esta
preferência substitui a distribuição anterior nos próximos pacotes. O código
T01 já aplicado por Terra é preservado, com manutenção transferida a Sol.
Prioridade continua desempenho in-game, AX útil e robustez; duração dos testes
não é uma meta. Não reduzir F9 ao incremento atual nem mover lacunas para F10.

## Atualização humana de27/10/2026 — Terra6.1

Decisão explícita na retomada F9: aproveitar Terra6.1 como subagente para o máximo
de implementações generalistas e criação artística que possam ser particionadas
em entregas pequenas ou médias, completas e verificáveis. Sol decompõe, analisa,
integra e extrapola resultados; conserva algoritmos sensíveis, problemas sistêmicos
e fronteiras de risco elevado. A preferência substitui a restrição anterior de
Terra somente a UI/conteúdo sobre APIs prontas. Contratos e dependências ainda
precisam estar concretos antes de cada consumidor.

Cada fatia entrega comportamento observável, arquivos de dono exclusivo,
critérios de aceitação e evidência; não é microtarefa desconectada nem delegação
do editor inteiro. Usar gpt-6.1-terra com esforço proporcional, inicialmente médio;
não presumir autonomia/completude superior nem economia de quota sem dados.
Falha local retorna à mesma fatia/Terra; Sol assume análise de falha persistente
ou sistêmica. Declaração do executor não substitui conferência do contrato.

Luna pode criar testes e fixtures delimitados e gerenciar sua execução/triagem
separadamente. Não altera expectativas para ocultar falhas nem declara sozinho
correção de um sistema complexo. Durante um congelamento, criação de testes novos
também aguarda ou ocorre em rascunho fora dos inputs. Sol consolida a validação.

O usuário revisará a arquitetura com Astra após terminar a construção do editor.
Não antecipar essa revisão ampla nem criar chats/gates por essa preferência.
Demais regras de autorização, preservação, propriedade e aceite humano continuam.

O anexo workflow_multimodelos_terra61_sol.md foi lido como proposta de referência.
Sua lista de rubrica/benchmark/experimentos não vira uma nova tarefa autorizada
por estar no documento. Não introduzir um benchmark paralelo ou novos sistemas
para experimentar modelos. Registrar completude/intervenções nos pacotes reais
já autorizados; ampliar o tamanho conforme os resultados observados.


## Prioridade humana de27/10/2026 — execução no jogo e checkpoints portáteis

O tempo total dos testes não é uma meta de produto. Priorizar desempenho durante
o jogo, autoria AX que facilite o desenvolvimento agêntico e mapas robustos na
mesma autoridade usada pelo runtime. Medir fluidez, pausas/latência de ações e
comportamento em cenário representativo real; não inferir FPS de um tempo de suíte.
Um teste que chama navegação/colisão de gameplay pode revelar custo relevante,
mas seu perfil, escala e fase precisam ser identificados antes de extrapolar.

Não investir em encurtar testes por si só, reduzir cobertura, mudar amostras/perfis
ou relaxar oráculos para parecer mais rápido. Orçamentos de memória, cancelamento
e timeouts de proteção seguem técnicos; excedê-los continua diagnóstico.

Entregar incrementos com resumo Markdown autossuficiente e evidências. Cada
retomada portátil registra base/branch/checkout, alterações ainda não commitadas,
resultado por etapa, pendências e próximo passo reproduzível em shell comum.
O usuário pode levar o trabalho a outro provedor/modelo: os papéis não exigem
ferramentas exclusivas do Codex. Preservar propriedade, critérios e histórico.
Não presumir calendário/reset de modelos nem esperar por ele para salvar estado.

## Norma vigente — atualização humana de 12/10/2026

O usuário autorizou iniciar E06 em08/10 e atualizou o fluxo em 12/10/2026: Luna
acompanha testes automatizados, Sol corrige e consolida a validação, Astra fica
para arquitetura/planejamento de longo prazo. Não há revisão Astra completa
automática por capítulo. Análise puramente visual excepcional ou problema
justificado por Sol como muito complexo pode voltar a Astra. Essa decisão
substitui gates anteriores de revisão independente rotineira e fechamento Astra,
inclusive os de E06; preserva escopos e evidências históricas. Este documento é a fonte única
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
- **Supervisão automatizada:** Luna acompanha a seleção aprovada de testes,
  confirma conclusão e verifica saída, erros, timeouts e hashes. Se falhar,
  envia etapa/log/reprodução a Sol e aguarda correção; não altera runtime nem
  expectativas. Depois acompanha regressão e retomada por impacto. Não precisa
  reler todo o capítulo ou produzir auditoria semântica do código.
- **Validação técnica:** Sol confere comportamento/contrato, invariantes e
  pendências, corrige falhas e consolida evidências com papéis explícitos. Pode
  concluir candidato tecnicamente validado quando os checks necessários passam
  e não resta bloqueio conhecido; não requer carimbo Astra.
- **Consulta excepcional a Astra:** arquitetura e planejamento; fora disso,
  análise visual que exija julgamento ou problema que Sol defina como muito
  complexo, com motivo e reprodução/delta delimitados. Não disparar por cada
  falha ou por terminar um capítulo. Se houver auditoria excepcional, manter
  sua reprodução separada da evidência autoral e da supervisão de Luna.
- **Usuário:** autoriza escopo e decide produto; testa o candidato e concede
  aceite humano antes de merge. Integração operacional executa o merge autorizado.

Não há cadeia obrigatória Luna → Terra → Sol → Astra. Escolher o menor conjunto
adequado de executor/revisor. Esforço é escolhido para cada tarefa/rodada; não
prometer adaptação automática do app nem economia de tokens sem medição.

Preferência humana reiterada em 11/10/2026: respeitar o esforço reduzido escolhido
no chat; Extra Alto não é padrão para delegações. Reservar esforço maior a uma
necessidade concreta de risco, evitando reanálise e validação duplicadas. Usar
pacotes concluíveis e delegar somente quando houver ganho concreto.

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

Validação proporcional ao impacto conforme REVIEW_WORK_PACKAGES. Fronteiras
críticas exigem invariantes e integração pertinentes antes dos consumidores;
agrupar a fundação completa em um checkpoint. Luna supervisiona a execução
automatizada e Sol fecha o resultado técnico. Uma nova regra ou fronteira
amplia os testes necessários, sem criar revisão Astra de código obrigatória.
Testes aprovados não demonstram que toda a especificação ou avaliação visual
foi coberta; registrar limites concretos e preservar o playtest humano.

Arquivar somente quando o registro persistente contiver contrato, base, entrega,
hash integrado, evidências válidas e limitações, e a integração/validação tiverem
sucesso. Um relatório sem commit ou um merge sem checks não basta. O revisor mantém
o chat pendente se tiver segunda etapa prevista. Correções retornam ao mesmo chat;
reabri-lo se necessário. Não apagar histórico técnico ao arquivar.
Worktree não deve ser removida antes de preservar artefatos necessários, inclusive
evidência ignorada pelo Git. Checkpoint versionado resume resultado; logs locais
devem ter caminho, hash e forma de reprodução, com cópia durável quando necessária.

Escalar arquitetura/produto quando for necessária decisão fora do contrato ou
mudar escolha humana, com delta específico. Correção de schema, identidade,
fórmula, API ou input dentro do contrato permanece com Sol, com invariantes.
Falha automatizada, risco ou duas tentativas sem convergir motivam diagnóstico
de Sol; chamar Astra somente se Sol justificar complexidade excepcional ou
necessidade de decisão arquitetural. Correções contratuais não exigem novo
aceite a cada rodada.

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
   resultado por impacto, com supervisão Luna e fechamento Sol; consultar Astra
   apenas nas exceções definidas acima.
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
contratada. Em E06, RX/R2 passam a identificar checkpoints de validação
consolidada Luna/Sol, sem revisão Astra automática; R1 histórica permanece
intacta. Nova regra precisa de invariantes.
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


## Fontes de produto e skills — consolidação17/10/2026

[MVP](MVP.md) descreve o produto existente; [ARCHITECTURE](ARCHITECTURE.md)
indexa autoridades e contratos atuais; [PRODUCT_DIRECTION](PRODUCT_DIRECTION.md)
registra mapas modulares, elevação, populações, consumíveis e economia futuros.
Direção aprovada e skill instalada não são liberação de implementação de E07+.
Contratos e recibos históricos preservam evidência; seus estados/gates revogados
não substituem esta norma ou o [checkpoint atual E06](epics/e06_checkpoint.md).

[Skills de entrega](DELIVERY_SKILLS.md) apoiam os quatro domínios de conteúdo.
Usar o checkout informado, conferir contrato e dono, não descobrir projeto pela
pasta da skill. Novos pacotes continuam proporcionais ao risco, com testes por
impacto e sem auditoria Astra automática. O pedido documental17/10 não altera
runtime, rates, save, status de aceite humano ou regras de publicação.
