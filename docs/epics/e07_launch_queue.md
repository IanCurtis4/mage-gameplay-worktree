# E07 — abertura documental autorizada

18/10/2026. Usuário autorizou preparar o mesmo esquema de chats de E06 para E07,
depois concedeu aceite de gameplay de E06 e determinou: **não começar nenhuma
conversa agora; deixar a postos, sem iniciar planejamento ou implementação**, por
orçamento restante de 7%. Em seguida, no mesmo dia, revogou a espera:
**“Pode continuar. Já que o limite de 5h resetou, pode criar as conversas normalmente.”**

**Estado: ABERTURA_DOCUMENTAL_AUTORIZADA.** Registrar IDs efetivos no índice de
chats após criação. Sem automação. Este material não é contrato arquitetural ou
autorização para executar consumidores antes das decisões/interfaces necessárias.

Despacho efetivo18/10, base `029b8ca1d7b1752929d549cbeb51e534ea6d3c1d`:

| Pacote | Estado | Chat | Modelo/esforço |
|---|---|---|---|
| Arquitetura/contratos E07 | INTEGRADA documental; decisões pendentes | 01a14e2d-630b-7c50-bd03-9448f30711fc | gpt-6-astra / high |
| E07-I0 inventário | VALIDADA/INTEGRADA/ARQUIVADA | 01a14e2d-b456-7063-bfe9-4cf727b25a59 | gpt-6.1-sol / medium |
| E07-F0 montagem pura | VALIDADA / INTEGRADA / ARQUIVADA | 01a14f91-d0c6-7c20-82c9-a22650fa5199 | gpt-6.1-sol / high |

F0 usa base `e30c49bb6442344ce8d937910ca6170effc70c7a` em codex/e07-f0;
[despacho](e07/f0_dispatch.md). Integração documental anterior
`3d79d83294d6bf1cfa45d7edc9a4cdd2defa86da`; I0 arquivado após conferência.

Os dois chats documentais receberam checkout/SHA e proibição de commits concorrentes.
F0 recebeu escopo fechado e permissão de commits na branch isolada. Coordenação registra
entrega/validação/integração posteriormente; status do app não basta para arquivar.

## Base e fechamento anterior

- [Aceite E06](e06/e06_gameplay_acceptance_2026_10_18.md).
- Runtime aceito: `a4f846ebaef45e5fa28c113331b6e75b64759525`; candidato documental
  antes desta consolidação: `578ff7609957aeb8e6024a2b36ae3b022b44cca0`.
- Checkout habitual: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG`, `codex/playtest`.
- Na retomada, resolver HEAD completo, alterações locais e base de cada pacote.
  Não usar o SHA anterior como se contivesse as decisões finais desta conversa.
- Nenhum merge em master/push foi realizado por este registro.

## Primeiro chat — arquitetura permanente

Título proposto: **RagRPG | E07 — Arquitetura Astra**.
Modelo: `gpt-6-astra`; esforço inicial Alto pela fronteira de mapas/altura e
estado congelado. Reavaliar por tarefa; Extra Alto não é padrão.
Chat permanente de arquitetura, contratos e guias, sem implementar ou integrar.

Mensagem inicial preparada:

> Prepare a arquitetura de E07 do RagRPG a partir das decisões humanas já
> consolidadas. Leia AGENTS.md, docs/WORKFLOW.md, docs/MVP.md,
> docs/ARCHITECTURE.md, docs/PRODUCT_DIRECTION.md, docs/epics/e07.md e este
> registro. E06 tem aceite de gameplay; não reabrir seus gates históricos.
> Identifique as decisões de produto ainda necessárias, sem perguntar de novo
> as já respondidas. Antes de consumidores, apresente escolhas que alterem
> produto ao usuário. Seu trabalho é documentação: contratos, interfaces,
> invariantes, guias e divisão em tarefas substanciais para chats separados.
> Proponha modelos/esforço proporcionais, dependências e dono exclusivo por
> arquivo. Sol nas novas fronteiras, Terra em UI/conteúdo sobre APIs estáveis,
> Luna em lotes fechados/supervisão de testes. Nenhuma revisão Astra rotineira.
> Não criar/despachar executores, implementar runtime ou modificar saves.
> O escopo arquitetural deve delimitar mapas/campanha e dependências de
> persistência/ameaça; economia, consumíveis/profissões e arte low-poly mantêm
> seus gates e não são liberados integralmente por referência em E07.
> Antes de escrever, registre base/checkout e propriedade dos arquivos.
> Saídas propostas: docs/epics/e07_contract.md, docs/epics/e07_tasks.md e guias
> em docs/epics/e07/. Ajustar nomes/propriedade na abertura, sem sobrescrever
> trabalho concorrente. Entregar decisões pendentes, contratos prontos e próximo
> pacote executável; sem dezenas de microtarefas ou chats de reserva.

## Conversas temporárias posteriores

Primeiro pacote delimitado, independente da escrita de contratos: **E07-I0 —
Inventário técnico**, `gpt-6.1-sol`, esforço Médio. Ler runtime e testes existentes,
sem executar gameplay ou modificar código. Dono exclusivo do novo arquivo
`docs/epics/e07/e07_runtime_inventory.md`; nenhum outro arquivo. Mapear APIs,
limitações e consumidores de navegação/altura, montagem/portais, populações,
aggro, estado de run/save/augments, propriedade dos bens e integração UI. Vincular
achados a caminhos/linhas reais e testes existentes, sem decidir produto nem
projetar um segundo sistema. Entrega: mapa factual, riscos/dependências e pontos
que o contrato Astra precisa resolver. Não é reauditoria de E06 ou autorização
de código. Em paralelo, Astra possui somente seus contratos/guias E07 e índice
de tarefas; Sol possui somente esse inventário. Root possui índices globais.

Os dois chats documentais usam o checkout habitual local sem trocar branch;
registrar SHA-base real no prompt antes da criação. Não fazem commit/stage ou
integração concorrente: coordenação consolida apenas seus arquivos após validação.
Caso seja necessária base isolada para implementação, definir no dispatch futuro.

Demais tarefas ainda não especificadas como executáveis: dependem do contrato Astra.
Na liberação futura, cada chat recebe resultado observável, exclusões, APIs,
SHA-base real, checkout/branch, arquivos exclusivos e critérios de validação.
Paralelizar somente produtores/consumidores com dependências estáveis.
Não fabricar contratos/APIs ou declarar tarefa pronta sem a entrega do produtor.
Arquivar apenas após entrega registrada, validada e integrada, conforme WORKFLOW.

## Pendências já conhecidas para encaminhar, sem resolvê-las agora

Migração de bens compartilhados para personagem; destinação de exemplares
existentes; detalhes de mácula/quests; categorias de respawn; HP/SP e retorno
na morte; valor da penalidade; contratos de captura/restauração e geometria.
São decisões/fundação futura, não defeitos de implementação pendentes de E06.
Lista completa e decisões aprovadas: [PRODUCT_DIRECTION](../PRODUCT_DIRECTION.md).

## Validação deste preparo

Este preparo valida coerência documental, referências locais e diff; não repete
gameplay. Criação e planejamento passam a ser autorizados pelo novo sinal humano;
arquitetura não foi produzida por este arquivo. Não agenda retomada automática.

## Atualização de execução18/10 — F0 integrado, F1 autorizado

F0 integrado em `42604ef8674a2c28f5aadc633b73cda15178e0b3` e arquivado;
[evidência de integração](e07/f0_integration.md). Usuário autorizou “Pode começar
F1” e aprovou regras de combate D05. [Despacho F1](e07/f1_dispatch.md) delimita
lógica espacial e testes independentes da apresentação D05, ainda pendente.
Sem início de F2+ ou decisão implícita das demais propostas.
