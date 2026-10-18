# E07 — checkpoint de arquitetura v1

18/10/2026. **Entrega documental, aguardando integração pela coordenação e
decisões humanas para consumidores.** Não é aprovação técnica de runtime.

## Base e papel

- Chat permanente Astra de arquitetura E07; esforço Alto pelo risco de geometria,
  identidade e conservação completa de estado. Não gerencia ou integra executores.
- Checkout `C:/Users/João Pedro/Documents/ChatGPT/RagRPG`, branch `codex/playtest`.
- Base inicial conferida: `029b8ca1d7b1752929d549cbeb51e534ea6d3c1d`.
- HEAD avançou externamente durante a leitura para
  `82948a66e5d45f678366d6d474c09851063b456f`. Diff conferido: somente
  docs/EPIC_THREADS.md e docs/epics/e07_launch_queue.md; nenhum runtime nesse delta.
  Esta tarefa não fez stage/commit, troca de branch ou integração.
- Runtime aceito E06: `a4f846ebaef45e5fa28c113331b6e75b64759525`;
  [aceite humano](../e06/e06_gameplay_acceptance_2026_10_18.md) lido, sem reauditoria.

## Entrega e propriedade

Somente oito arquivos desta tarefa:

1. [Contrato](../e07_contract.md): autoridades, modelo, APIs/erros, lifecycle e I01–I15.
2. [Pacotes](../e07_tasks.md): F0–F8, dependências, resultado, dono e transferência de arquivos.
3. [Decisões](e07_decisions.md): sete grupos de escolhas com propostas/impacto e bloqueios.
4. Este checkpoint.
5. [Mundo](guides/world_geometry.md): partes, montagem, superfícies, combate e visual.
6. [Persistência](guides/persistence_and_identity.md): posse, migração, captura, IDs e writer.
7. [População](guides/population_and_combat.md): limpeza, portais, ondas, grants e ameaça.
8. [Validação](guides/validation.md): matriz positiva/negativa/integrada e evidência por impacto.

[Inventário I0](e07_runtime_inventory.md) lido quando ficou disponível, sem editá-lo.
Seus achados incorporados: travessia planar do teleporte é exceção real; EXP atual
vem da etapa, não de abate; garantias de drop exigem política específica para
respawn; abrir facade hoje descarta sessão abandonada; limpeza atual reseta efeitos.
Não repetir essas regras do piloto nos consumidores novos por acidente.

Fontes lidas integralmente: AGENTS, WORKFLOW, MVP, ARCHITECTURE, PRODUCT_DIRECTION,
e07, e07_launch_queue, E06 consolidado/checkpoint/aceite, REVIEW_WORK_PACKAGES,
TESTING e gate low-poly. Skills usadas: ragrpg-mapdelivery e ragrpg-enemydelivery.
Também houve leitura dirigida do código/assinaturas de navegação, perfil/save,
rewards, mobs, RunState, causalidade, controller e atores; I0 amplia o mapa factual.

## Decisões e próximo trabalho

D01 migração/destinos, D02 simultaneidade/lobby/estágios ausentes/quest antecipada,
D03 elegibilidade/mácula/EXP, D04 revive, D05 altura/apresentação e exceções,
D06 ameaça, D07 amostra/requisitos/tabelas. Todas pendentes. Números oferecidos
são propostas de playtest; nenhum foi instalado como default de produção.
Sem perda de save, destinação automática de bens ou aprovação de múltiplas runs.

F0 é o primeiro pacote preparável depois de integração documental e dispatch com
base real: montagem pura/manifesto/contratos em fixtures. Não é PRONTO agora.
F1/F2 exigem D05 e D01/D02 respectivamente; os demais aguardam produtores e decisões.
F5 inclui apenas participação mínima em combate; F6, ameaça completa, é opcional
com dispatch próprio e não bloqueia geração/campanha por associação.
Coordenação resolve SHA-base/checkout/dono efetivos; nenhuma referência futura
foi fabricada. Economia completa, consumíveis/profissões, low-poly e multiplayer
mantêm gates próprios. Este chat permanece aberto para arquitetura, sem arquivar.

## Validação documental e limites

Conferência de referências locais, fronteiras de arquivos, DAG e precedência
realizada por leitura e verificação local. Assinaturas existentes distinguem-se
das propostas; nenhum consumidor foi marcado PRONTO. Revisão de coerência corrigiu
teleporte, fonte de EXP e garantias após incorporar I0. SHA-base observado não
é SHA de entrega/integração; esses campos permanecem para a coordenação.

Conferência local final: oito documentos, 34 links locais resolvidos, nenhum
link quebrado, whitespace final ou fence de código sem par detectado. Diff em
scripts/tests/tools/scenes/data/project.godot vazio; índice Git sem novos arquivos
stageados na conferência. HEAD permaneceu no avanço documental citado acima.
Hash de export_presets.cfg conferido igual ao registro inicial de conteúdo desta
tarefa: `342ab283a5d0e973c7e4ba4f4d3a360d98df9036a7d0a288cd30ebccc2a35972`.
Os sidecars apareceram no status inicial e não foram escritos por esta tarefa;
não se afirma comparação SHA individual anterior de todos os sidecars.

CLI de workflow ausente nesta base; docs/WORKFLOW_TOOLING.md também ausente.
Usados Git, contratos e evidência de leitura; nenhuma aprovação CLI inventada
e nenhuma origem externa buscada. TESTING conserva trecho histórico de revisão
independente/R1/R2; WORKFLOW mais recente prevalece, sem gate Astra rotineiro.

Não houve execução de Godot, importação, ferramentas de gameplay, suíte, renderer,
medição de desempenho ou leitura/escrita do save pessoal. Nenhum resultado PASS
de gameplay é alegado. Arquivos locais de importação/exportação não foram editados
por esta tarefa. Não houve mensagem externa, automação, chat/subagente novo,
runtime/Resource/cena alterados, stage/commit, merge, push ou arquivamento.

Limites: policies ainda pendentes impedem candidato jogável; APIs novas ainda
não implementadas; escala e restauração completa exigirão prova real, não são
certificadas por este texto. A integração documental não concede aceite de produto.
