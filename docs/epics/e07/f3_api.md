# E07-F3 — API de snapshot em memória

Implementação F3,21/10/2026. [Escopo, decisão D02, base e propriedade](f3_dispatch.md).
Esta API não grava perfil, não migra save e não publica suspensão no lobby.
O recibo final deverá identificar o candidato e a cobertura efetivamente validada.

## Corte e recuperação

`RunController.request_memory_snapshot() -> Dictionary` enfileira o corte no
fim do tick. `memory_snapshot_ready(result)` entrega uma única resposta após
a captura. O controlador e sua subárvore permanecem congelados, inclusive em
falha; `release_memory_snapshot()` é a recuperação/continuação explícita e
restaura a pausa anterior. Liberar antes de executar o callback cancela o pedido
enfileirado e conserva a pausa que já existia. O consumidor não deve sair ao lobby nem declarar save
durável por receber este resultado. Input/focus-out não cancelam o cast enquanto
o corte está pendente. Pedido de summon entra no livro de intenções antes de
qualquer callback diferido, sendo consumido uma única vez.

`SnapshotTickBarrier.acquire(root)` aceita uma fixture desconectada ou uma árvore
já pausada, conserva os modos dos nós e bloqueia o avanço. `release()` restaura
esses modos. A chamada síncrona de captura exige que essa barreira pertença à
raiz; produtores vivos usam a entrada diferida do controlador.

## Grafo e identidade

`SnapshotRegistry.capture(root, barrier)` retorna `ok`, `snapshot`, `bytes` e
`capture_usec`. `validate(snapshot)` verifica formato, cobertura, versões,
fechamento e estrutura. `restore(snapshot, facade = null)` também valida os
tipos e invariantes dos objetos antes de ligar sinais e entregar a raiz passiva.
`install(result, parent)` reconstrói apresentação básica sem configure/reset/start
de gameplay; `activate(result)` publica os modos de processamento explicitamente.
Quem rejeitar um resultado válido deve liberar sua raiz desconectada.
Para RunController, instalar precede obrigatoriamente a ativação. A instalação
congela também os novos controles/câmera e mantém a guarda passiva; esperar nessa
etapa não expõe controles nem avança relógios. Uma instalação rejeitada devolve
a raiz desconectada e inerte. Ativação repetida é idempotente.

O envelope de formato1 contém objetos por kind/revision, campos explícitos,
contêineres tipados compartilhados, referências por ID estável, gerações,
tombstones, contador de novas identidades, cobertura e referências imutáveis de
conteúdo. Posições/transformações, prioridade e ordem dos nós são conservadas.
Não contém Node, Callable, WeakRef, RID ou IDs locais usados como referências.
Bindings de método são descritores puros e são reconstruídos sem emissão.

`StableEntityRegistry` pertence ao escopo da run, sob metadado técnico reservado
`_expedition_snapshot_identity_service`, excluído do envelope. Sobreviventes
mantêm seus IDs entre cortes e após restauração; nascimentos não reutilizam o
serial de uma entidade retirada. `register`, `stable_for`, `resolve`,
`generation_for` e `local_for` mantêm a bijeção. Geração é não negativa e não
muda silenciosamente para a mesma instância. IDs estáveis do grafo não substituem
`slot_id`/generation da população que F5 ainda entregará.

Um alvo morto pode permanecer como tombstone sem ator. A restauração reserva um
token local positivo, inerte e fora da árvore, para compatibilidade com a API
finita dos ledgers; ele nunca é um CombatActor e não participa de gameplay.
O serviço de identidade libera esses tokens ao terminar seu escopo.

Referências diretas já destruídas conservam tipo Variant, invalidade e aliases
em uma tabela `dead_references`, separada dos tombstones escalares. Proxies de
tipo explícito são criados fora da árvore e destruídos antes da publicação;
nenhum ator é revivido. Referência destruída sem tipo declarado é erro.

O manifesto versionado `scripts/core/expedition/snapshot/runtime_manifest.json`
enumera campos e omissões por script, incluindo bases. Propriedade nova sem
classificação e kind desconhecido interrompem o corte. Os papéis de identidade
e as gramáticas compostas estão em `snapshot_identity_roles.gd`/SnapshotRegistry;
contadores de equipamento, emissões e valores numéricos comuns não são IDs de
ator. Uma nova gramática/referência exige atualização explícita do adaptador.

## Passagens e autoridades

Primeiro são alocados objetos passivos e contêineres vazios; depois se resolvem
estado, aliases, referências, bindings e sinais. A validação semântica precede
a ligação dos sinais e a instalação na árvore. Nenhum custo, dano, sorteio,
oferta, concessão, construção ou recomposição que cure é repetido na hidratação.
AStar é reconstruído somente dos dados capturados; rotas/revisões são conservadas.
Os donos temporários do grafo são liberados ao ativar, para não prolongar raízes
causais que só devem viver enquanto houver envelopes reais.

ProfileFacade/Store permanecem externos e não são clonados. Se houver facade
persistente, o envelope registra perfil/revisão/reward_session; restore exige
uma facade correspondente e rejeita ausência/divergência. Isso verifica a ligação
em memória; o commit atômico, crash/restart e reconciliação durável são F4.

Erros principais: `tick_barrier_required`, `snapshot_barrier_busy`,
`save_in_progress`, `checkpoint_incomplete`, `unknown_runtime_kind`,
`dangling_entity_reference`, `duplicate_stable_id`, `invalid_identity`,
`stale_generation`, `invalid_rng_state`, `invalid_payload`,
`content_revision_unavailable`, `snapshot_too_large`, `restore_binding_required`,
`invalid_session`, `stale_revision`. Falha não publica um grafo parcial.

## Limites

Envelope limitado a4 MiB e16384 objetos; o serviço admite até1000000 identidades
durante um escopo. Exceder limite falha, sem apagar atores, tickets ou claims.
Medição final, kinds exercitados e limitações concretas constarão do recibo.

A prova usa o runtime atual e fixtures nativas importadas. Consumidores de
persistência, população/ondas, revive, campanha e UI de retomada continuam em
seus pacotes. D02 congela ações locais de estágios sem jogador; a expedição
suspensa congela todos os relógios. F3 não inventa intervalo de onda ou política
de morte para implementar um relógio global de produção ainda inexistente.
Estado de modal/apresentação não autoriza rerrolar a oferta já capturada.
Seleção de alvo, cast_intent e controles em memória são capturados; o caminho
externo de configurações não vem do envelope. Câmera e UI básica são reconstruídas.
Modais abertos, latch físico de teclas e transientes puramente visuais não são
uma promessa de continuidade visual: a prova F3 é de estado e efeitos de gameplay.
