# E06-TX — checkpoint consolidado da fundação ampliada

12/10/2026. DX ENTREGUE; R1 v1 APROVADA; TX1/TX2/TX3 ENTREGUES PELO AUTOR com validação dirigida; RX da ampliação seguinte.

## Retomada, autorização e base real

- Chat executor: 01a12d55-0ce8-7061-b8e4-bf5650c8c5b7.
- Origem do dispatch: 01a1207c-fca8-79d2-9280-5dbc5e172c96.
- Executor: Sol; configuração solicitada gpt-6.1-sol / high, sem Extra Alto.
- Contrato prevalente: itemization_execution.md, base documental 9d05361f65549189f87f4f5440529aec44e3a904.
- Branch: codex/e06-inventory.
- Checkout exclusivo: C:/Users/João Pedro/.codex/worktrees/e06-inventory/RagRPG.
- HEAD real de entrada: 9d05361f65549189f87f4f5440529aec44e3a904; árvore limpa.
- Código corrigido R1: 7dbe237f85f8308fdfcf5bbee7e8dd6b975080c4.
- Skill ragrpg-resume lida; AGENTS/WORKFLOW/REVIEW_WORK_PACKAGES e handoff conferidos. WORKFLOW_TOOLING.md ausente.
- CLI externo explicitamente autorizado: C:/Users/João Pedro/.codex/worktrees/menu-tabs/RagRPG/tools/workflow/workflow.py, origem 0c008d4843d13f772aa2b69be22d24d2300b80a1, SHA256 e642dbe882cd7ea3cd687da51ed978bdecc93675fbb31d08d26626a0b40a1bae. Status executado: diagnóstico sem aprovação.

Autorizada a análise DX e a implementação sequencial TX1/TX2/TX3 após suas dependências. O dispatch atual substitui cabeçalhos antigos que descrevem TX sem executor. Não iniciar conteúdo/UI/T3/T4, E07/campanha, push, merge ou aplicação de playtest. O checkout fixo não recebe edição.

## Propriedade antes da edição

Sol assume sequencialmente os documentos transferidos no handoff: itemization_execution.md, ../e06_contract.md, ../e06_tasks.md, equipment_loot_requirements.md, este e06_tx.md e novo e06_tx_api.md. Caminhos T2 e equipamentos/cartas/catálogo/compositor transferidos conforme handoff; nenhum runtime será editado antes de registrar o inventário concreto da etapa e resolver dependências.

R1: transferência temporária do relatório e06_r.md e tests/e06_review_* (UIDs incluídos) ao único subagente revisor independente Astra/high durante a retomada. Novo recibo permitido: e06_r1_reviewer_validation.json. Logs exclusivos em .godot/verification/e06_r1/resume_independent/. Revisor pode registrar probes próprios; não corrige runtime, não faz commit nem altera expectativas para esconder falhas. Sol conserva DX em arquivos disjuntos. Runtime/catálogo/cenas/testes autorais/runner congelados até parecer R1. Uma reprodução integrada no fechamento R1 conforme contrato, sem repetir por documentação.

## Estado e evidência

R1 PENDENTE na entrada. F01–F04 corrigidos pelo autor; apenas F01/F02 rechecados independentemente após correção. Evidência178/178 histórica em27dc684; não cobre HEAD. Recibo autoral separado e06_r1_author_validation.json. Não copiar PASS do autor como decisão independente.

DX nesta retomada: inventário de impacto, reconciliação dos requisitos e propostas técnicas/decisões remanescentes. Nenhum teste de gameplay executado pelo executor para edição documental.

## Próximo passo

Revisor conclui delta final/R1; Sol prepara contrato DX e consulta apenas decisões humanas que bloqueiam TX1. Registrar APIs, erros, migração, fontes e arquivos antes de qualquer implementação. Checkpoint não arquivável; RX da ampliação ainda não iniciada.

## DX — decisões e inventário, 11/10/2026

Respostas humanas registradas no manifesto e06_tx_api.md: exemplares por aquisição, migração weapon→main_hand/armor→torso/accessory→accessory_1, referências compartilhadas entre personagens/presets; encaixes apenas armaduras reais/armas/escudos, focos/colares/acessórios sem encaixes; uma arma + escudo/foco, duas mãos bloqueiam off_hand. Retirada gratuita herdada da v1 preservada. Nenhuma resposta silenciosa inferida.

Inventário de impacto e tipos/erros/slots/migração/fontes/capacidades/tags/exclusividade/conjuntos/arma/ativas/loot: e06_tx_api.md. APIs propostas não são APIs já entregues. Metadata legada desconhecida requer representação explícita preservadora; não se inventou qualidade/origem/ilvl/poder. TX1 continua sem edição enquanto R1 executa.

Transferências adicionais de autoridades T1 para Sol registradas antes da eventual implementação: scripts/core/identity_ids.gd e scripts/core/character_state.gd (lista canônica/estado dos slots e referências); scripts/core/build_snapshot.gd (captura dos exemplares). Já transferidos T2: ProfileState/Codec/Catalog/Facade/Store/RewardResolver, BuildContentLoader, RunBuildService/CardInventory/RewardService/RunState/BuildPresentation, Main e runner. EquipmentDefinition/CardDefinition/BuildEffectCatalog/Composer transferidos no dispatch. Escopo dessas transferências é apenas TX autorizada; congelamento R1 prevalece enquanto o revisor executa.

Novos caminhos TX1 propostos e reservados a Sol: scripts/core/equipment_instance.gd, equipment_rules.gd e UIDs; tests/e06_tx_inventory_test.gd, e06_tx_migration_test.gd, e06_tx_fixture.gd e UIDs; docs/epics/e06/e06_tx_validation.json. Arquivos existentes e testes legados a editar serão enumerados no plano fechado TX1 após R1; reserva não é edição. CharacterMenu/UI e autoridades causais T1 ainda não são transferidos para mudança de gameplay; impacto está identificado, pacote/limite será declarado antes de editar.

Respostas adicionais DX, 11/10: usuário rejeitou origem/ilvl/qualidade desconhecidos no legado e aprovou tabela dos12 itens (5 iniciais comuns,7 restantes raros, todos ilvl1/origem Arena demonstrativa;1 encaixe em arma/armadura,0 em acessórios), sem mudar stats/efeitos. Tabela no manifesto. Projétil adicional é transformação elite+; ativas usam maior rank, cooldown compartilhado sem reset por troca, captura emitida preservada e cancelamento de preparação sem acesso; cross-class permitido com compatibilidade/adaptador concretos. Garantia de loot é piso de um item, upgrade substitui; loot por mob substitui item/carta da etapa preservando XP/augment. Essas respostas não aprovam taxas finais ou conteúdo/UI.

Árvore Git real do commit de entrada:7c41736da52d9564c930683067109e24925d39cc (SHA1 por git rev-parse HEAD^{tree}). Campo tree de64 caracteres do CLI status é fingerprint da ferramenta, não esse objeto Git. SHA256/origem do CLI conferidos. R1 prossegue independente; nenhum commit ou edição runtime durante a execução integral.

## Retomada de12/10/2026 e última decisão humana DX

Usuário autorizou continuar de onde a interrupção por quota parou, inclusive o mesmo revisor R1. A execução original chegou ao fim após a interrupção: logs/plan/checks.jsonl e marcador final existem até182. Sol somente conferiu disponibilidade; a decisão/recibo são do revisor. Nenhuma etapa foi reexecutada pelo executor nesta retomada.

Resposta humana ainda não registrada antes da interrupção: ativas de item entram na biblioteca quando há fonte equipada, com escolha MANUAL de atalho; após perder a última fonte, conservar o atalho na mesma posição DESABILITADO. Reequipar restaura acesso sem resetar recarga. Não repovoar barra nem limpar organização silenciosamente. A decisão integra TX2/codec/layout, sem implementar enquanto R1 estiver congelada.

Restaurados somente32 assets/art/**/*.import listados em .godot/verification/e06_r1/resume_independent/import_incidental_changes.json, após conferir hash atual=after, flag only_line_endings_vs_HEAD e contenção no checkout autorizado. Documentos/probes/UID e código preservados. R1 mantém seu relatório/recibo próprios.

## Fechamento DX/R1, 12/10/2026

R1 aprovada pelo único revisor independente Astra/high sobre HEAD9d05361f65549189f87f4f5440529aec44e3a904, árvore7c41736da52d9564c930683067109e24925d39cc; código corrigido7dbe237f85f8308fdfcf5bbee7e8dd6b975080c4.182/182 etapas da execução única original PASS; novo probe independente15/15. Retomada12/10 apenas conferiu índices/hashes/logs/inputs e emitiu parecer, sem reexecutar gameplay. Relatório e06_r.md e recibo e06_r1_reviewer_validation.json (SHA2567585792604a7e198a021debb3b2e7a7bc99958b9bea004d82a824cf546bb143a). F01–F04 fechados; sem novo achado bloqueante. Revisor liberou congelamento e devolveu probes/UIDs para adaptação estrutural de TX, conservando seus critérios adversariais. Relatório/recibo R1 históricos não serão editados por Sol.

DX entregue: decisões humanas consolidadas, tabela dos12 IDs, impacto/APIs/tipos/erros/fontes/migração por versão, sem mudança de gameplay. Referências de retomada e tabela conferidas; diff documental sem whitespace inválido. Reuso da prova R1 limitado aos inputs originais; qualquer TX posterior terá evidência própria. R1 não aprova ampliação, consumidores, playtest, merge ou produto.

## Plano fechado TX1 e arquivos permitidos antes da edição

Resultado:14 posições canônicas; exemplar persistente por aquisição, sem fusão; referências compartilhadas entre alts/presets; cartas da run por exemplar e encaixe0–4 em peças elegíveis; reabertura/retry/preview/commit preservadores, mãos legais e dívidas HP/SP. Qualidade/origem/ilvl dos12 atuais seguem tabela humana. Sem novas fórmulas, taxas finais, receitas/UI finais, ativas/tags/conjuntos/cap causal novos ou mobs/loot novos desta etapa.

Novos arquivos declarados: scripts/core/equipment_instance.gd, equipment_rules.gd e UIDs; tests/e06_tx_inventory_test.gd, e06_tx_migration_test.gd, e06_tx_fixture.gd e UIDs; docs/epics/e06/e06_tx_validation.json. Runtime existente: IdentityIds, CharacterState, ProfileState/Codec/Catalog/Facade/Store/RewardResolver, BuildSnapshot/ContentLoader/EffectCatalog/Composer/RunState/RunBuildService/RunCardInventory/RunRewardService/BuildPresentation, EquipmentDefinition/CardDefinition e resources/build_effects/equipment/*.tres +card/*.tres (IDs atuais preservados; apenas representação/metadata da etapa). Main apenas inicialização de instâncias/compatibilidade de run. Actor/stats/dano/causalidade permanecem autoridades sem nova fórmula.

Transferência adicional estrita: scripts/ui/character_menu.gd somente compatibilidade dos3 seletores existentes com main_hand/torso/accessory_1 e rótulos de exemplar; preservar11 posições restantes ao salvar. UI completa14, arte e chapéus ficam para T4/FX. Tools/verify.ps1 apenas registro dos novos checks TX1. Testes legados abaixo podem adaptar campos/fixtures ao novo formato e invariantes explícitas de aquisição/encaixe, mantendo critérios de HP/SP/XP/ranks/backup/pending/identidade/causalidade. Nenhuma adaptação transforma falha de regra em PASS por suprimir asserção; probes R1 preservam expectativa de rejeição sem gravação.
- tests/action_bar_persistence_test.gd
- tests/e02_character_menu_test.gd
- tests/e03_progression_transactions_test.gd
- tests/e04_learn_from_zero_migration_test.gd
- tests/e05_berserker_builds_test.gd
- tests/e05_berserker_catalog_migration_test.gd
- tests/e05_defender_builds_test.gd
- tests/e05_defender_catalog_migration_test.gd
- tests/e05_elementalist_catalog_migration_test.gd
- tests/e05_elementalist_integrated_closure_test.gd
- tests/e05_evolution_menu_integration_test.gd
- tests/e05_evolution_transaction_test.gd
- tests/e05_geometer_builds_test.gd
- tests/e05_hunter_builds_test.gd
- tests/e05_hunter_catalog_migration_test.gd
- tests/e05_hunter_catalog_test.gd
- tests/e05_sentinel_builds_test.gd
- tests/e05_sentinel_integration_test.gd
- tests/e05_spiritualist_catalog_migration_test.gd
- tests/e05_spiritualist_integrated_closure_test.gd
- tests/e06_effects_composition_test.gd
- tests/e06_effects_fixture.gd
- tests/e06_effects_runtime_test.gd
- tests/e06_inventory_fixture.gd
- tests/e06_inventory_persistence_test.gd
- tests/e06_inventory_resources_test.gd
- tests/e06_inventory_test.gd
- tests/e06_migration_test.gd
- tests/e06_review_boundaries_test.gd
- tests/e06_review_identity_test.gd
- tests/e06_review_persistence_edges_test.gd
- tests/e06_review_preset_test.gd
- tests/e06_rewards_test.gd
- tests/persistent_state_test.gd
- tests/profile_facade_test.gd
- tests/profile_run_facade_test.gd
- tests/profile_store_test.gd
- tests/stat_threshold_migration_test.gd
- tests/stat_threshold_rules_test.gd

Validação TX1 por impacto: novos testes de exemplares/slots/capacidade/cartas/migração e os consumidores de codec/fachada/store/inventário/compositor/recompensas/preview/snapshot afetados. Plano de seleção conferido antes da execução; nenhuma repetição integral por mudança documental. Fechamento integrado TX1–TX3/RX conforme contrato. Base pós-commit DX/R1 será registrada no início da edição.

TX1 iniciada em12/10/2026. Base real pós-DX/R1:54e6fad47763310afb307d990759c874c33fd1d3, branch codex/e06-inventory, mesmo checkout. R1v1 aprovada, decisões TX1 satisfeitas. EquipmentRules será a autoridade única de compatibilidade/capacidade; EquipmentInstance conterá somente dados de aquisição. Campos auxiliares legados de leitura são DTOs derivados, não segunda coleção gravável. Nenhum limite global de cópias de carta além dos encaixes físicos é introduzido por TX1.

## TX1 — entrega do autor, 12/10/2026

Resultado implementado:14 posições, EquipmentInstance persistente por aquisição; capacidade0–4 independente da qualidade, cartas por exemplar/índice e repetição da mesma definição; alts/presets compartilham referências; arma de duas mãos rejeita off_hand ocupado, uma mão admite escudo/foco, acessórios idênticos em exemplares diferentes rejeitados. Fonte de carta inclui host/índice/exemplar. Preview/commit/reconcile preservam dívida HP/SP, snapshots emitidos, barras/ranks/XP e durabilidade. Ordem de instâncias usa contador crescente, preservando a escolha do exemplar mais antigo.

Schema3/catalog10, ruleset stat_thresholds_v1: legado validado primeiro em seus3 slots; mapa determinístico depois; um exemplar por ID realmente registrado, sem criar cópias perdidas.12 itens seguem tabela humana de qualidade/ilvl/origem. Slots nulos do catálogo9 preservados; versões1..8 conservam a união histórica de starters. Os11 novos slots iniciam nulos. Catálogo conhecido, futuro/pending/backup, extensões e campos de personagem conservados. ProfileStore aceita novo migration_kind somente quando perfil candidato e legado hidratado são iguais; demais migrations mantêm seus nomes históricos. Campo equipment_collection é DTO legado de leitura de IDs de instância, jamais segunda autoridade salva. Não modificar esse array como mutador de posse.

APIs finais TX1: e06_tx_api.md seção de entrega. UI mudou somente a compatibilidade dos3 seletores antigos e rótulos;11 posições restantes são preservadas ao salvar. Interface14, arte/chapéus e conteúdo final continuam T3/T4/FX.

Validação do autor por tools/verify.ps1:42 etapas distintas com PASS entre planos dirigidos (incluindo import/smoke), sem suíte integral185/185 e sem somar reexecuções. Novas provas: inventário24 checks; migração25. Regressões dirigidas de codec/store/fachada/sessão/barras, migrações históricas/carteira, inventário/recompensas/composição/runtime, probes F01–F04, inicialização/menu/progressão e builds dos consumidores alterados PASS. Logs e planos com papéis/hashes e tentativas falhas: e06_tx_validation.json; .godot/verification/e06_tx/. Reexecução dos probes R1 por Sol é evidência DO AUTOR, não nova reprodução independente. R1v1 permanece histórica e intacta.

Falhas preservadas: primeira seleção omitiu import dos2 tipos novos e timeout; import apontou variável de menu sem tipo, corrigida; tentativa de timeout30 foi rejeitada pelo runner antes de engine. Prova nova de migração apontou migration_kind ainda não aceito pelo writer, corrigido com guarda de igualdade. Fixture comparava tipos int/float antes do wire JSON, corrigida para os valores serializados exatos. Fixtures legadas precisaram de referências de exemplar/14 slots, replay por aquisição em vez de unicidade de definição e envelopes schema2 históricos; nenhum oráculo de stats/dano alterado. Metadata inválida de aquisição agora é rejeitada ANTES de RNG/ticket/save, inclusive treino, com prova negativa; conversões de metadata malformada são guardadas.

Reaproveitamento por impacto identificado no recibo: cada plano mantém seu commit/base/sujeira/inputs/engine e outputs; posteriores mudanças restritas a fixtures, ordenação de instâncias ou rejeição de dados inválidos tiveram seleção própria. Nenhum PASS parcial é reapresentado como execução integral do HEAD. Fechamento amplo da fundação TX1–TX3 e RX ainda obrigatórios antes dos consumidores.

Próxima dependência: TX2 sobre esta entrega local; decisões humanas de rank/cooldown/remoção/cross-class/biblioteca/atalho já registradas. Publicar contrato concreto de capacidades/tags/chave de exclusividade/conjuntos/arma por uso e orçamento causal derivado antes de editar suas autoridades. TX3 aguarda essa composição e seus tipos compartilhados. Sem push, playtest, merge ou aceite de produto. Candidato da ampliação não arquivável antes de TX2/TX3/RX e integração pertinentes.


## TX1 preservada e plano concreto TX2, 12/10/2026

Entrega TX1 local: a8706f8861175ef133ad2247326473f663ca5940; base54e6fad. Recibo autoral com42 etapas distintas/27 seleções,61 outputs com hashes conferidos e manifesto executável idêntico antes do commit.32 imports incidentais restaurados; nenhuma alteração em arte/projeto/addons. R1 histórica fechada permanece intacta.

TX2 inicia nesta base, Sol/high, mesmo checkout/branch. Resultado: regras concretas de capacidades e origem, tags descritivas, efeitos nomeados exclusivos, conjuntos por limiar, cartas repetidas, uso real da arma, ativas de item com organização/cooldown preservados e orçamento causal derivado. Propriedade sequencial transferida antes de edição: scripts/data/effect_definition.gd, skill_definition.gd, equipment_definition.gd, card_definition.gd; scripts/core/build_effect_catalog.gd, build_effect_composer.gd, build_content_loader.gd, skill_effect_resolver.gd, run_state.gd, equipment_rules.gd, effect_proc_ledger.gd, combat_event_context.gd, damage_request.gd, combat_math.gd, profile_codec.gd, profile_facade.gd, action_bar_layout.gd, build_presentation.gd, run_reward_service.gd; scripts/actors/player_actor.gd; scripts/main.gd; scripts/ui/action_bar_editor.gd e tools/verify.ps1. UIDs existentes preservados. Novos: scripts/core/effect_tags.gd, item_skill_adapters.gd, mob_catalog.gd, scripts/data/mob_definition.gd, equipment_set_definition.gd; tests/e06_tx_composition_test.gd, e06_tx_active_test.gd, e06_tx_causality_test.gd e UIDs. MobCatalog é autoridade compartilhada inicial de base/categoria, consumida por TX3; nenhum catálogo paralelo.

Fixtures permitidas: tests/e06_effects_fixture.gd, e06_inventory_fixture.gd, e06_tx_fixture.gd, e06_effects_composition_test.gd, e06_effects_runtime_test.gd, e06_inventory_resources_test.gd, e06_inventory_persistence_test.gd, e06_review_boundaries_test.gd, e06_review_preset_test.gd, e06_review_persistence_edges_test.gd, e06_tx_inventory_test.gd, action_bar_persistence_test.gd. Adaptações apenas metadata/contrato alterado; preservar casos negativos, durabilidade e fórmulas. Seleções adicionais de regressão usam testes existentes sem editar.

Contrato concreto abaixo e no manifesto; sem aprovação por microtarefa. TX2/TX3 terão RX conjunta independente. Sem conteúdo/UI finais/T3/T4/E07/playtest/push/merge.

Transferência TX2 adicional antes da edição: scripts/ui/battle_controls.gd, estritamente preservação/desabilitação do atalho e atualização da biblioteca existente, sem UI14 final.


## TX2 — entrega do autor, 12/10/2026

Resultado: capacidades inferidas por handler e validadas por origem/qualidade/base; mob base autoritativo copiado; tags de efeito/skill apenas metadata; chave de exclusividade semântica; conjuntos legais com uma fonte por limiar; soma de cartas por exemplar e transformação EXCLUSIVE repetida idempotente apenas quando mesma receita. Conflitos diferentes/cross-origin rejeitam toda mudança. Qualidade real do exemplar controla receita, inclusive antes do RNG de aquisição.

Ativas: adaptadores concretos fire_spear/ice_spear/teleport executados nas três bases; maior rank, aprendizado intacto, biblioteca enquanto equipado, seleção manual, atalho persistido desabilitado, CD compartilhado correndo/removal/reequip sem reset. Perda da última fonte cancela preparação; emissão retida. Outros handlers não são liberados por metadata. Ordem anterior da biblioteca aprendida preservada.

Arma: DamageRequest captura exemplares usados por mapeamento explícito; auto, golpes diretos/arco/tiros pagos Sentinela são elegíveis, Rede INT/spells/traps não. Proc agregado conserva parcelas condicionais, não dá bônus da arma a spell genérica. Comparação de ganho considera parcelas genéricas e condicionais, evitando ocultar novo buff pelo cap de uma parcela de arma.

Causalidade: plano congelado de famílias/alvos/carriers por emissão no RunController, orçamento pelo produto finito de pares; dedupe antes de callback, apply_once, proc_child/depth, cancelamento, roots fracas e limites mundiais/kit preservados. Ticks herdam plano/ancestralidade. Não trunca fontes nem usa cap global de buffs. Compatibilidade cap16 exclusivamente fixtures sem plano; novos produtores vivos adotam plano. Novas provas:60 composição,53 ativas,19 causalidade, incluindo26 famílias úteis em emissão real e exclusão da parcela de arma de uma spell.

Validação dirigida pelo autor: 28 nomes distintos PASS em 11 seleções, incluindo import/smoke, fronteiras persistência/barra/inventário e regressões dos sete kits E05. Sem integral188/188 nem decisão RX. Recibo novo permitido/assumido por Sol: e06_tx2_validation.json; logs .godot/verification/e06_tx2/. Probes de revisão executados como evidência autoral, sem alterar relatório R1 fechado. Imports incidentais restaurados após igualdade por conteúdo normalizado.

Tentativas falhas preservadas: parâmetro de decoder inserido inicialmente na função errada (compile), chamada de codec inexistente no teste, fixtures genéricas de proc ainda usavam arma para spell e fixture adversarial sem qualidade. Fixtures de mistura/saturação agora explicitamente usam armadura para conservar seu propósito; teste novo cobre arma verdadeira separadamente, sem retirar assert. A regressão encontrou ordenação lexical nova na biblioteca, corrigida no runtime. Novo delta de assinatura condicional teve provas próprias; não rerodou todos os kits por essa correção local. Nenhuma fórmula de stats/dano ou oráculo E05 mudou.

TX2 aguardará RX junto a TX1/TX3. Próximo: TX3, definição fixa de mob/ocorrência, adaptadores e loot parametrizado, sem taxas de produção inventadas.


## Plano fechado TX3 antes da edição, 12/10/2026

Base real TX2:5d53e486de4656f3c74f51f36c042a24ca69538f; mesmo Sol/high/checkout/branch. MobCatalog já é autoridade compartilhada. Resultado: espécies fixas, ocorrências/categorias separadas, adaptadores concretos, loot por morte congelado antes de coletar, garantias mínimas sem item extra, retry/durabilidade e substituição dos itens/cartas de etapa preservando XP/augment.

Propriedade Sol sequencial: scripts/data/mob_definition.gd; scripts/core/mob_catalog.gd, build_content_loader.gd, run_reward_service.gd, profile_facade.gd; scripts/actors/enemy_actor.gd; scripts/main.gd; tools/verify.ps1; este checkpoint/manifesto. Novos: scripts/core/mob_occurrence.gd, mob_skill_adapters.gd, mob_loot_resolver.gd; scripts/data/mob_loot_table.gd e UIDs; resources/build_effects/mob/demo_chaser.tres e demo_archer.tres; tests/e06_tx_mob_test.gd e e06_tx_loot_test.gd/UIDs; docs/epics/e06/e06_tx3_validation.json. Fixtures anteriores são lidas/reutilizadas; não mudar suas expectativas para ocultar falhas.

Demo chaser/archer transcreverão exatamente atributos/nível1/modificadores/nomes/raios/animações atuais de EnemyActor, sem aumentar dificuldade ou conceder cartas. Apenas ocorrências normais na demo; outras categorias/skills/loot serão fixtures identificadas. Sem taxas finais ou novos itens/cartas/arte/mapas/E07. Boss categoria é suportada pelo contrato; IA de boss/campanha não entra nesta fundação.

TX3 transferência adicional antes da edição: novo scripts/core/skill_impact_rules.gd/UID para o mesmo impacto de Ice Spear em player e mob, sem duplicar o efeito; Main reutiliza essa autoridade.

TX3 transferência adicional antes da edição: tests/e06_tx_active_test.gd para acrescentar a prova de que tecla de atalho desabilitado não cancela outra preparação válida; expectativas TX2 preservadas.

TX3 transferência adicional: scripts/core/run_state.gd para selar a substituição do catálogo de efeitos após configurar loot por mob. O resolver congelado não pode emitir carta cuja definição foi removida por outro catálogo antes da coleta. Setter continua disponível antes dessa fronteira para fixtures.

TX3 transferência corretiva: scripts/core/build_effect_catalog.gd para a lista explícita de componentes secundários/ticks E05 reservados. Regressão Hunter revelou que o plano TX2 só listava famílias de proc e não o canal hunter_thorn_bleed. RunState passa a capturar também skill IDs aprendidos e componentes concretos; EnemyActor usa a mesma lista reservada. Não mudar a expectativa de sangramento/abertura nem criar limite substituto.


## TX3 — entrega do autor, 12/10/2026

Espécie/ocorrência separadas, dados fixos pelo catálogo único e StatCalculator. Os dois inimigos da demo transcritos exatamente, nível1/stats/modificadores/raios/nomes/animações preservados. Variantes permitidas declaradas; cartas da mesma base permanecem a mesma receita. MobSkillAdapters fire_spear/ice_spear executam preparação/custo/CD/projétil/poder/impacto concretos, sem restante do kit. Impacto Ice Spear compartilhado com player em SkillImpactRules.

Loot parametrizado com cinco uniforms e referências/saídas validadas antes de RNG. Rare garante uncommon, rare_elite rare, boss epic; superior substitui em um exemplar; legendary só boss; sockets independentes/inelegíveis0. Nível fixo/origem espacial reais congelados. Serviço registra ator/ocorrência no spawn, só morte própria emite ticket, replay não rerrola e coleta dura precede cartas. Configurar mob loot sela o catálogo para não remover definição de carta antes da entrega. Mobs não inventam XP nem escolhas: etapa mantém XP/augment, substituindo apenas equipamento/carta quando o modo foi explicitamente configurado. Coleta atual de final de encontro drena tickets de mob anteriores em ordem. Taxas de produção não configuradas; dados reais da demo não contêm loot inventado.

Nova prova:27 checks mob e49 loot. TX2 ativa54 (inclui tecla desabilitada não cancelando outra preparação), causal19/composição60 preservadas. Validação autoral dirigida: 22 nomes distintos PASS em 6 seleções, sem integral190/190. Recibo e06_tx3_validation.json; logs .godot/verification/e06_tx3/. Reuso das etapas TX1/TX2 por impacto, não soma contagens/reexecuções como cobertura nova.

Renderer nativo Compatibility/OpenGL3.3/NVIDIA GTX1080, janela oculta e save de fixture: visual/disabled_bar.png e enabled_same_slot.png inspecionadas. Atribuição pela biblioteca real, retirada e reequip preservam posição; slots desabilitados legíveis e recuperados sem repovoar a barra. Sem clipping observado nesse1280x720; não prova UI14/arte final/acessibilidade completa/FPS/diversão. Script/logs/hashes no recibo; nenhum usuário/save pessoal foi alterado. Primeira fixture visual tentava atribuir por controller sem atualizar widget, corrigida para usar a biblioteca real; falha mantida e processo próprio encerrado.

Falhas preservadas/correções: hook de falha do teste inicialmente tinha nome inexistente, corrigido para write_pending sem retirar assert. Hunter integração detectou canal hunter_thorn_bleed ausente no plano TX2: plano agora inclui skill IDs aprendidos e lista explícita de componentes/ticks reservados; genéricos não podem usar esses IDs como família. Regressões Hunter186/302, Geômetra46, Espiritualista86, Berserker76 e demais consumidores dirigidos PASS; suas expectativas/fórmulas não mudaram. Imports32 incidentais restaurados por conteúdo.

Limites: taxas/receitas/cobertura14 e interface de pickups individuais/T3/T4/chapéus/FX permanecem posteriores, boss AI/mapas/campanha E07 não liberados. RX da fundação ampliada inteira precede consumidores; nenhum push/playtest/merge/aceite humano.
