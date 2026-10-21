# E07-F2 — API de posse e migração assistida

20/10/2026. Estado de execução e decisões humanas: [despacho](f2_dispatch.md). Esta API não publica migração pessoal nem UI. Schema8/catalog14/stat_thresholds_v1; leitor histórico fechado em schema7, separado do envelope de posse.

## Envelope e autoridades

ProfileState mantém o registro global de IDs, mas cada EquipmentInstance tem owner_character_id e cada carta tem uma entrada validada em card_inventory.owners. Gold inteiro exato entre0 e9007199254740991 pertence a CharacterState. profile_unlocks é conjunto de IDs técnicos do perfil, sem grants materiais. Recursos de catálogo e fórmulas permanecem inalterados.

expeditions é Dictionary de ExpeditionAssetLock por expedition_id; exige personagem existente, fase técnica, revision inteira e lifecycle active/suspended/recovering/reconciling. No máximo uma reserva por personagem. É seção tipada de fundação, **não snapshot de mundo ou promessa de retomada**: campos adicionais não são aceitos como conteúdo opaco. F3/F4 definirão os respectivos codecs e transferência de propriedade antes dos consumidores.

ProfileStore é o único writer. ProfileFacade publica candidatos somente após persistência/reconciliação. Equipamentos/cartas existentes não podem trocar de dono por um commit comum. Presets ativos e inativos, opções, snapshots, trocas, encaixes e loot usam a posse por personagem. Não existe API de transferência entre personagens; a intenção histórica transfer move carta entre encaixes do mesmo dono.

## Queries e transações

- ProfileState.equipment_for_character(character_id): cópias somente dos exemplares do dono.
- RunCardInventory.for_character(character_id, equipment): projeção por dono com IDs/counters de aquisição preservados; merge de sockets não elimina acervo de outros personagens.
- ProfileFacade.assets_for_character / CharacterAssets.query: gold, exemplares, cartas, unlocks e estado de lock copiados.
- ProfileFacade.preview_assets / commit_assets e CharacterAssets.preview / commit: wallet mínima (credit_gold/spend_gold com amount inteiro positivo) e unlock com unlock_id técnico. Recebem character_id, intent, request_id e expected_revision. IDs de requisição/payload são persistidos em asset_receipts; retry idêntico retorna recibo e payload diferente retorna request_conflict. Não atribui gold a mobs, loja, bônus de fase ou preço novo.
- Equipamento/encaixes continuam pelas APIs existentes preview_inventory_change/commit_inventory_change e RunBuildService. Consomem CharacterAssets.check_intent e o mesmo codec/store; não foi duplicado compositor ou gravador.

Personagem com reserva pendente pode ser consultado, mas as mutações de build/equipamento/carteira e início de outra fase são recusadas na autoridade. Outro personagem permanece livre. Lifecycle real, concessões do checkpoint e encerramento da expedição são consumidores futuros de F4/F5; F2 não os implementa por inferência.

## Migração em duas fases

ProfileCodec.decode de schema1–7 primeiro valida pelo decoder histórico e então retorna ok=false, migration_required/read_only. O candidato histórico é diagnóstico e não é aceito por encode/commit comuns. ProfileStore.load_profile não converte nem substitui esse arquivo automaticamente. Versão futura permanece protegida e não cai para backup antigo.

1. MigrationPlan.dry_run(source_text, catalog, assignments) / ProfileStore.preview_migration(assignments) / ProfileFacade.preview_asset_migration: produzem plan, plan_digest e complete. assignments contém ID global → character_id, nunca índice de menu. Sugestão de peça só quando um personagem a referencia; não preenche destino. Cartas encaixadas herdam apenas o destino explicitamente escolhido para o host. Carta solta precisa de escolha. plan inclui source_digest/revision, policy_revision, todos os destinos, referências e remoções por layout/slot.
2. MigrationPlan.validate reconstitui a prévia a partir da mesma fonte. Mapa incompleto, dono ausente, ID desconhecido, carta divergente do host, prévia adulterada ou qualquer mudança nos bytes da fonte impedem aplicação.
3. MigrationPlan.apply é puro; ProfileStore.apply_migration / ProfileFacade.apply_asset_migration gravam pelo writer existente. Exigem plan, confirmed_digest igual ao digest do resumo completo e request_id. A chamada significa confirmação específica daquele plano; não inferir autorização a partir de sugestões ou da aprovação da política D01.

A aplicação preserva IDs, metadados, encaixes, contadores, recibos, campos desconhecidos e a origem inteira em profile.ownership.<source_sha256>.json. Somente remove referências indicadas na prévia e atribui donos; gold legado zero. Falha anterior ao replace mantém a fonte; pending só é descartado em retry quando coincide integralmente com o candidato revalidado e a fonte continua idêntica. Resultado perdido após replace é reconciliado pelo recibo sem nova revisão/aquisição. Recibos não são truncados para caber: tamanho excedido falha preservando dados.

## Limites de compatibilidade

O plano não inventa personagem para um legado sem personagens: bens sem destino continuam pendentes. Um campo histórico desconhecido que colida com uma nova seção reservada impede migração em vez de ser sobrescrito. Backup legado, primary ausente/corrompido ou pending divergente permanecem em recuperação; não se escolhe silenciosamente outra fonte para satisfazer uma confirmação antiga. A restauração normal de backup schema8 conserva o corte completo e os recibos.

A UI de prévia/seleção/confirmação pertence a F7. Save pessoal não foi aberto ou migrado. Sem loja, consumível, venda/desencaixe novo, captura completa ou aplicação no playtest/master.

Inteiros fora da faixa exata são recusados também em campos desconhecidos, antes de regravar. Erros estruturais de posse/recibo/expedição e limite de tamanho preservam o primary em leitura/recuperação; não fazem fallback silencioso para um corte material anterior. Antes de rotacionar o backup legado, o writer verifica a cópia exata arquivada.
