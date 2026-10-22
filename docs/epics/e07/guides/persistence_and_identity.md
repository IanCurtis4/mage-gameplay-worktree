# E07 — guia de propriedade e estado congelado

Atualização22/10: as aprovações posteriores e APIs F1–F6 estão indexadas no
[registro de decisões](../e07_decisions.md) e no [recibo integrado](../f1_f6_integration.md).
As propostas e pendências da versão arquitetural abaixo são históricas quando
substituídas por esses registros; não reabrir decisões já respondidas.

Arquitetura v1,18/10/2026. [Contrato](../../e07_contract.md),
[decisões D01/D02/D04](../e07_decisions.md). Este guia define requisitos técnicos;
não aprova migração real, multiplicidade de expedições ou recursos ao reviver.

## Fronteira existente e mudança necessária

ProfileState schema7/catalog14 guarda equipment_instances/card_inventory no perfil;
CharacterState contém builds/referências. ProfileFacade.start_run grava apenas
run_id, character_id e last_committed_seq na reward_session. RunState.from_build
chama reset, que limpa augments/ofertas e reinicia ledger. ProfileCodec lista
campos runtime como proibidos; não basta pôr RunState em extension_fields.

ProfileStore mantém a autoridade de commit/backup/pending; não criar um segundo
writer de expedição com ciclo independente. A proposta é envelope versionado do
perfil contendo seção de expedições explicitamente validada e codec específico.
Novo schema precisa de migração validada, não simples incremento da constante.
O número exato será reservado por F2 após conferir base integrada. Limite atual
do codec: 4 MiB. Medir checkpoint real antes de elevar limite; erro de tamanho
nunca remove entidades/recibos para caber. Se exigir arquivos segmentados, voltar
à arquitetura com protocolo atômico concreto, sem gravar pedaços independentemente.

## Propriedade

Manter IDs globais dos exemplares; adicionar owner_character_id validado para
equipamentos/cartas. Host e cartas encaixadas têm mesmo dono. Queries recebem
character_id; cópia runtime não muda propriedade. Wallet é saldo inteiro por
personagem, com operações sem overflow; não adotar float para gold. Unlocks são
do perfil, não grants materiais. Nenhuma API de transferência entre personagens.

Migração produz MigrationPlan: source_digest/revision, policy_revision,
destino por item/carta, referências de presets afetadas, campos preservados e
avisos. Mapa deve cobrir cada ID exatamente uma vez. Falta de destino, duplicação,
órfão, host/cartas divergentes ou fonte alterada após prévia impede commit.
Decisão D01 resolve as escolhas; não atribuir silenciosamente ao alt ativo.
Dry-run puro e fixtures antes de tocar qualquer save real. Fonte histórica é
validada pelo decoder histórico; preservação de unknowns/backup segue E06.

Enquanto expedição estiver suspensa, D02 governa mutações de personagem. Proposta
de lock pertence à autoridade ProfileFacade/CharacterAssets; desabilitar botão
não basta. XP/bens confirmados durante a expedição não são revertidos pela build
capturada. A build de combate retoma a evolução efetivamente aplicada no último
checkpoint; grants confirmados não são reaplicados como novos eventos.

## Checkpoint completo

| Família | Captura/restauração obrigatória |
|---|---|
| Identidade/versões | expedition, personagem, fase, revisão, schema, receita, manifesto, catálogos/rulesets e compatibilidade |
| Espaço | estágio/superfície/posição/orientação, home, última âncora, rotas e revisão geométrica |
| Atores | HP/SP reais, stats/fontes necessários, estados de vida, controles, ameaça/participação, cooldowns, estados de kit e summons consumidos |
| Build | snapshot, ranks, stacks, fontes temporárias, revisões, déficits/recursos sem recomposição que cure |
| Augments | fila de choice_ids, grants de origem, offer_id/revision/IDs e RNG; reabrir oferece a mesma seleção |
| Ações | cast/preparo/canal, alvo, custo já pago, estágio da emissão, tempo restante, payload capturado, hits já aplicados |
| Entidades efêmeras | projéteis, armadilhas, paredes, zonas, ecos, summons; geometria, owner/alvos, contadores, duração e velocidade |
| Causalidade | raízes/emissões, planos finitos, claims/targets/carriers, filhos/ancestrais e serializadores dos ledgers específicos |
| Tempo/RNG | relógio global, clocks locais, timers de efeitos, streams e estados RNG; nenhum timestamp real usado para avançar |
| Mundo | população de todos os estágios, generations, mortos, cleared_once, portais, objetivos, ondas e spawns pendentes |
| Recompensas | tickets congelados, payload/rates/RNG, ordem/cursor, coletados, intenções incertas e recibos |

Não serializar Node/Callable/WeakRef/Timer ou IDs de instância do processo. Cada
entidade recebe stable_entity_id e generation. Adaptador runtime mantém mapa
bijetivo stable→local e local→stable. Restore em duas passagens: criar entidades
sem _process/callbacks; resolver referências/ledgers/colisões; validar fechamento;
só então ativar. Entidade morta referida por um claim pode permanecer tombstone
sem Node. Referência impossível é erro, não alvo escolhido ao acaso.

Serializadores são explícitos por runtime_kind/revision, com coverage manifest.
Captura deve rejeitar kind desconhecido em vez de omiti-lo. F3 cobre todas as
dez identidades jogáveis atuais e mobs/efeitos habilitados na amostra. Não reduzir
silenciosamente o elenco para evitar restauração. Testes comparativos usam cada
família de efeito e oráculos para causalidade, não só round-trip de Dictionary.

## Barreira e durabilidade

Comandos de suspender entram na fila de simulação. Captura ocorre em fronteira
coerente depois de concluir eventos do tick; nenhum callback pode gravar durante
a captura. Congelar input/timers, produzir candidato, validar e persistir. Não
adiantar tempo para terminar casts; não cancelar ações como atalho de suspensão.
Falha mantém jogo pausado recuperável com mensagem, sem retornar ao lobby como
se tivesse salvo. Commit incerto exige reconciliação pelo writer existente.

Restauração é passiva: não executar configure/start que sorteie população, queue_choice,
callbacks de aquisição ou reset. Estado carregado só publica após validar
digest/versões/posses/referências. Visual reconstruído não aplica dano nem RNG.
Pause/menu usa o mesmo domínio de tempo, sem tick oculto de HUD/VFX.

Suspensão deliberada salva estado completo; queda de processo retoma último
checkpoint durável. Proposta técnica: checkpoint em suspensão, transição,
conclusão, revive, concessão de origem e mutação de recompensa, mais captura
periódica configurada/medida. Não prometer recuperação do último frame não
gravado. A cada commit material, snapshot e ledger da fonte devem corresponder
ao mesmo corte da simulação; caso contrário é possível restaurar um mob já pago.

Tickets emitidos precisam ser duráveis antes de publicar pickup/resultado como
confirmado. Se gravar cada morte ficar caro, agrupar um tick/commit sem publicar
antes; não separar persistência de loot e mundo para ganhar FPS. Medir custo.
Snapshot periódico não pode sobrescrever revisão mais nova do perfil.

## Falhas e compatibilidade

`checkpoint_incomplete`, `unknown_runtime_kind`, `dangling_entity_reference`,
`duplicate_stable_id`, `invalid_rng_state`, `snapshot_too_large`,
`content_revision_unavailable`, `migration_required` e erros comuns do contrato
devem preservar dados. Versão futura desconhecida abre recuperação/leitura,
nunca perfil vazio. Reconciliation usa intenção e payload congelados, não rerrola.

Não persistir augments como coleção permanente. A seção expedição é dado runtime
durável, separado das posses; só completed encerra o conjunto conforme regra
aprovada. Remover recibos antigos para economizar espaço exige prova de horizonte
de replay e tombstones; não cortar ledger arbitrariamente.

## Prova mínima por impacto

Comparar execução contínua e suspensa no mesmo tick: próximo dano, RNG, caminho,
cooldown, offer e claim coincidem. Incluir projétil no ar, canal pago, DoT perto do
tick, armadilha/parede, procs secundários e morte de dono/alvo. Usar ao menos três
taxas de delta representativas, inclusive delta grande cruzando vencimento de onda.
Failpoints antes/depois de persist/rename/publicação, retry, conflito de request,
save corrompido/versão futura, referência de alt e limite de tamanho. Fixture isolada,
sem save pessoal. Exit 0 não comprova restauração de todos os runtime_kinds.
