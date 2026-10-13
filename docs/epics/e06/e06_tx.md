# E06-TX — checkpoint consolidado da fundação ampliada

12/10/2026. DX ENTREGUE; R1 v1 APROVADA; TX1/TX2/TX3 ENTREGUES PELO AUTOR com validação dirigida; RX rejeitada na primeira rodada; correções RX-F01/F02 entregues em e725756; fechamento técnico Luna/Sol CONCLUÍDO conforme norma humana de 12/10.

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

## Retomada de 12/10/2026 e última decisão humana DX

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

TX1 iniciada em 12/10/2026. Base real pós-DX/R1:54e6fad47763310afb307d990759c874c33fd1d3, branch codex/e06-inventory, mesmo checkout. R1v1 aprovada, decisões TX1 satisfeitas. EquipmentRules será a autoridade única de compatibilidade/capacidade; EquipmentInstance conterá somente dados de aquisição. Campos auxiliares legados de leitura são DTOs derivados, não segunda coleção gravável. Nenhum limite global de cópias de carta além dos encaixes físicos é introduzido por TX1.

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


## Dispatch RX da fundação ampliada, 12/10/2026

TX1 a8706f8861175ef133ad2247326473f663ca5940; TX2 5d53e486de4656f3c74f51f36c042a24ca69538f; TX3 94ae228fee41fc1b71a568d75c86255c25aa5e49. Base de código da ampliação54e6fad47763310afb307d990759c874c33fd1d3. Runtime/tree serão congelados durante RX. Este registro documental não altera o candidato executável.

Retomar o mesmo único subagente r1_resume, Astra/high, para RX independente TX1–TX3 conjunta (autorização de continuação/subagentes/revisão crítica do contrato/AGENTS; sem novo chat nem gate por microtarefa). Dono temporário exclusivo: novo docs/epics/e06/e06_rx.md, e06_rx_reviewer_validation.json e tests/e06_rx_* +UIDs para probes próprios. Nenhum outro escritor nesses paths. Revisor lê/testa; não corrige runtime/runner/dados nem altera testes autorais. Logs exclusivos .godot/verification/e06_rx/. R1 relatório/recibo fechados intactos. Sol conserva somente este checkpoint/manifesto durante revisão; achados retornam ao autor e suspendem freeze para correção registrada.

Critério RX: inspeção das fronteiras ampliadas e consumidores, probes próprios adversariais, uma integral tools/verify.ps1 de fechamento (190 etapas antes de probes novos) se não houver bloqueio conhecido. Não reexecutar a integral por documentação/ajuste de fixture isolado; decidir reuso por hash/impacto. Separar provas recebidas TX1/2/3 da execução do revisor. Skill ragrpg-review lida; CLI externo autorizado menu-tabs/0c008d4/e642dbe... para pacote diagnóstico. validate/approve antigos não entendem Add-GodotCheck, limitação já conferida em R1: não modificar CLI nem fabricar approve. Decisão manual responsável deve vincular manifesto/HEAD/tree/engine/runner/logs do runner atual.

RX não é aprovação T3/T4/FX/playtest/produto/merge. Sem push, nova conversa, aplicar no checkout fixo ou iniciar E07.


## Correção consolidada RX-F01/F02 antes da edição

Revisor fechou primeira rodada REJECTED, sem integral e sem nova importação; recibo SHA2564ad858e72c0d177292b249208239064d6aade251954be4fab9bd4f3e6b796281. RX-F01/P1: reforço rastreado validamente recebe trap primary/stream mas perde tick pelo domínio de alvos congelado. RX-F02/P2: caster legal para fora do alcance real da skill. Expectativas dos probes tests/e06_rx_causal_late_test.gd e e06_rx_mob_ai_test.gd preservadas; execução autoral autorizada, código/relatório/recibo seguem propriedade do revisor.

Freeze liberado pelo revisor para Sol neste pacote corretivo completo. Caminhos transferidos antes de edição: scripts/core/effect_proc_ledger.gd, combat_event_context.gd; scripts/actors/enemy_actor.gd; scripts/world/spiritualist_echo_state.gd (consumidor adjacente); tests/e06_tx_causality_test.gd; novo tests/e06_tx_late_fields_test.gd/UID; tools/verify.ps1 e este checkpoint/manifesto. Nenhuma mudança de fórmulas/custo/CD/expectativas E05. Registro dos2 probes independentes no runner autorizado; fechará192 etapas antes do novo teste autoral. Não editar relatório RX/R1 nem probes do revisor.

Contrato revisado causal: congelar famílias/fontes e valores, não suprimir vítimas que o produtor legítimo admite durante a vida finita da emissão. Impacto primário validado em HealthState pode admitir vítima no budget antes de callback; componente/tick intrínseco válido pode admitir antes do claim. claim_batch genérico sozinho, proc_child, contexto secundário derivado ou família desconhecida não podem ampliar domínio. Orçamento continua produto de famílias finitas e IDs de vítimas admitidas uma vez por produtores finitos, mais pares de carriers; claims/apply_once/depth/cancelamento e limites de duração/projétil/campos/roots dos kits preservados. Não criar número substituto/ICD/teto de fontes. Ticks herdam plano atualizado do produtor.

Echo deve vincular uma única vez carriers ao snapshot finito real de elegíveis que EchoState cria no primeiro impacto (não adivinhar esse conjunto no plantio). Carriers posteriores não entram na mesma onda; vítimas posteriores legitimamente atingidas pela onda podem ser admitidas no claim nativo sem permitir cascata genérica. Budget derivado recalcula produto por admissão, não reabre pares nem expande famílias. Arqueiro sem skills conserva faixa150..390/posição280; caster usa alcance do rank declarado para parar/aproximar/atacar.

Provas: probes independentes5/4 sem editar; novos campos/ticks/echo com reforços e reentrada/proc_child/cancelamento; regressões de canais e AI afetados; uma integral RX somente após nenhum bloqueio conhecido.

Recibo autoral novo transferido antes da escrita: docs/epics/e06/e06_rx_author_validation.json; logs exclusivos .godot/verification/e06_rx_author/.


## Correção RX-F01/F02 — entrega do autor, 12/10/2026

Impacto primário validado admite vítima real antes do callback. Canal intrínseco conhecido admite vítimas posteriores por tick finito; desconhecidos/proc_child/secondary genérico não ampliam domínio. Claims continuam anteriores ao callback e apply_once; cancelamento/ancestralidade preservados. Eco vincula carriers uma vez ao snapshot real no primeiro hit, exige vínculo antes de pares planejados e rejeita lista duplicada sem mutação. Vítimas posteriores recebem Eco, sem virar carrier da mesma onda. Caster aproxima usando range real; archer básico mantém banda/standoff anteriores.

18 etapas distintas PASS em três seleções autorais, 23 outputs conferidos; não integral193/193 nem decisão independente. Probes originais5/4 sem edição passam; thorn existente/reforço9/9, caster375→aproxima/emite. Causal21 e novo late-fields22: LightningWall real com alvo após placement, tick intrínseco sem primary anterior, EchoState real com marks posteriores à emissão, reentrada/proc_child/cancelamento/duplicatas. Consumidores dirigidos Hunter186/12768, Geômetra46/106, Espiritualista30/37/16/86, Berserker18/76, ledger29/runtime53/mobs27 PASS. Recibo e06_rx_author_validation.json separa seleções e reaproveitamento por impacto.32 imports restaurados após igualdade normalizada; UIDs gerados automaticamente, sem editar probes independentes.

Retomar mesmo Astra/high para revisar delta corretivo e executar uma integral de fechamento somente sem bloqueio conhecido. Freeze de runtime/runner/resources/tests após commit; Sol conserva apenas checkpoint/manifesto, revisor conserva RX/probes/recibo. Decisão R1 histórica e RX rejeitada da primeira rodada preservadas no histórico; sem consumidores T3/T4, playtest/push/merge.


## Norma humana de 12/10 e transferência antes da edição

Usuário substituiu revisão Astra completa por capítulo: Luna acompanha bateria automatizada e encaminha falhas a Sol; Astra fica exclusivamente em arquitetura/planejamento de longo prazo e exceções de análise visual ou complexidade justificada por Sol. Não há nova aprovação Astra automática no fechamento. Sol consolida resultado técnico com testes/contrato/pendências, sem apresentar supervisão automatizada como auditoria semântica. Aceite de produto e merge continuam humanos.

Sol assume documentalmente AGENTS.md, docs/WORKFLOW.md, docs/REVIEW_WORK_PACKAGES.md, docs/LONG_TERM_EPICS.md, docs/EPIC_THREADS.md, docs/epics/e06.md, e06_contract.md, e06_tasks.md, e06/itemization_execution.md e este checkpoint/API para refletir essa autorização. Nenhuma mudança de runtime por norma. Histórico R1/RX e decisões anteriores permanecem rastreáveis.

Astra r1_resume interrompido por nova norma e já indisponível por limite de uso; antes disso reproduziu4 testes dirigidos PASS no candidato e725756. Integral foi iniciada, terminou na etapa90 e04_learn_from_zero_migration_test com falha detectada pelo runner apesar exit0;1..89 ainda requerem conferência de recibos para reaproveitamento. Não concluir RX por mensagem de progresso nem executar outra integral sem avaliar impacto. Logs .godot/verification/e06_rx/round2/ preservados; nenhum parecer final dessa rodada.

Dispatch autorizado ao único novo subagente test_watch, gpt-6-luna/low, contexto mínimo: verificar saída/hashes, reportar falha90 a Sol, aguardar correção e acompanhar cauda/regressão proporcional. Dono exclusivo novo docs/epics/e06/e06_test_watch.md, e06_test_watch_validation.json e logs .godot/verification/e06_test_watch/. Não escrever runtime/runner/fixtures/expectativas/relatórios RX. Sol mantém correções e transferência registrada; não chamar Astra apenas por falha automatizada. Testes ficam congelados até diagnóstico, consumidores/playtest/merge continuam fora desta retomada.

Transferência corretiva Luna90 antes da edição: Sol assume tests/e04_learn_from_zero_migration_test.gd, somente envelope legado schema2/catalog1/3 slots reais e guardas de resultado para não truncar a rotina. Perfil atual schema3/catalog10 não deve fingir catálogo1; runtime/codec permanecem intactos. Todas as expectativas de grants/wallet/XP/identidade/counters/backup/respec mantidas.

Transferência corretiva Luna110 antes da edição: Sol assume scripts/core/run_state.gd (available_active_ids tolera snapshot temporariamente nulo, preservando cache missing_snapshot existente) e tests/e06_tx_active_test.gd (prova nulidade/restauração de concessões e biblioteca persistente/piloto). Teste e05_spiritualist_readability_test e suas39 expectativas intactos. Runtime sem snapshot não pode apresentar concessões de cache antigo; restaurar snapshot reconstitui biblioteca/rank. Demais caminhos com snapshot existente preservados.


## Fechamento técnico TX1–TX3 / RX sob fluxo Luna–Sol, 12/10/2026

**VALIDADA TECNICAMENTE por Sol, com supervisão automatizada Luna.** Candidato executável final2803f1165ee8883e462bfa8909e6707bb30e004d, árvoreb5582130407daea85c37a248ee75bf74efe60271. Nova norma1adfe95920e4bf586433be6520ef104fec37925e, correção de fixture90d2b64e0f3a445be109576238668f39beed335764. Correção causal/range e7257563e70f0cb00c931d0067b7c7a89d76354c. Este registro/recibos finais são documentais e não mudam inputs executáveis; não reexecutar gameplay por sua inclusão.

Cobertura consolidada de193 nomes distintos do plano original:1..89 PASS em e725756;90 corrigido em d2b64e0;91..109 PASS em d2b64e0;110 corrigido e sete consumidores dirigidos PASS em2803f11;111..193 PASS em2803f11.202 registros de outputs e todos engine logs presentes, hashes de output/plan/checks verificados por Luna e novamente por Sol. As falhas90/110 permanecem nas tentativas originais, fora de latestPASS; não somar reexecuções para inflar193. Nunca houve uma execução integral193/193 com PASS num único HEAD: fechamento por reuso compatível + retomadas explicitadas.

Reuso por impacto: depois de e725756, runtime/runner/recursos/cenas só diferem em RunState.available_active_ids: guarda de snapshot nulo sem alterar caminho com snapshot presente; cache já existente missing_snapshot limpa concessões e restaura composição depois. Provas novas TXactive58 incluem biblioteca/rank/cache sem snapshot e restore, mantendo ordem/concessões; readability39 intacto. Fixture90 agora representa schema2/catalog1/3slots reais; grants/wallet/XP/identidade/counters/backup/respec preservados,20 checks. Seleção7/7 inclui integração Mago103, E02-run9, UI47, arena33/runtime53; cauda83/83 inclui novos contratos/mobs/loot/causalidade e probes próprios originais sem edição. Sem nova integral por estes deltas focados/documentos.

Recibo supervisionado: [e06_test_watch.md](e06_test_watch.md), [e06_test_watch_validation.json](e06_test_watch_validation.json), SHA256D4B4716B6A0F5B20A07B2ED1B8FAA30C74DB20E43E3A1EC287164ACCC380263D; MarkdownA434B6CF6C2FEEEBD06E56016EC6AB8602CD97694E5C20A22AD9001B4F435E06. Manifestos atuais ligados a HEAD/tree/engine/runner, falhas históricas e fingerprints. Evidência bruta .godot/verification/e06_rx/round2/ e .godot/verification/e06_test_watch/, ignorada no Git e preservada nesta worktree. Runner SHA2560A8143EF881AD75502E6D3DA778ADAE8CA14426B92A477018657402AF23BDAFD; Godot4.7.2 SHA256AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424.

Achados RX-F01/F02 resolvidos com provas5/4 originais: reforço Espinhos9/9 e caster aproxima/emite. Campos/echo22 e causal21 passam; famílias/fontes/valores capturados, alvos admitidos por produtores válidos, carriers finitos do primeiro hit, dedupe/cancelamento/proc_child mantidos. R1 histórica APROVADA182 etapas permanece intacta (recibo7585792604a7e198a021debb3b2e7a7bc99958b9bea004d82a824cf546bb143a). Astra RX da primeira rodada rejeitou e seus quatro probes dirigidos pós-correção passaram antes do limite; não emitiu auditoria/parecer final RX integrado. Nova decisão humana substituiu essa exigência, não fabricou aprovação Astra. Relatório/recibo histórico RX permanecem intactos como registro daquela rodada.

Sol confere entrega dentro do contrato aprovado, invariantes, correções e nenhuma falha automatizada pendente; declara fundação TX1–TX3 pronta tecnicamente sob norma atual. Não equivale a auditoria semântica independente completa nem aceite de produto. Visual autoral limitado à barra em1280x720 continua no recibo TX3, sem nova inspeção nesta supervisão.

Limites/próximo passo: conteúdo/receitas/taxonomias/poder/rates finais e UI14/pickups/chapéus/FX ainda não entregues; T3/T4 dependem dessa base e de autorização/donos/decisões pertinentes, sem iniciar aqui. E07/campanha/boss AI permanecem fora do escopo. Checkout fixo codex/playtest não editado/aplicado, nenhum push/merge ou aceite humano inferido. Manter esta worktree e logs até integração/preservação da evidência; não arquivar como entrega integrada. Próxima retomada consulta este checkpoint e WORKFLOW atualizado, usa Luna em bateria e Sol em falhas; Astra somente arquitetura/planejamento ou exceção concreta justificada.


## Autorização T3-A — base de conteúdo, 12/10/2026

Usuário abriu base racional para conteúdo, deixando nomes/flavor para Luna. Recorte/donos/base/critério em [e06_content_base.md](e06_content_base.md). Suspensão anterior de T3 prevalece para catálogo final, UI e decisões pendentes; T3-A é o novo pacote autorizado. Mesmo checkout isolado, sem editar playtest. Sol implementa infraestrutura de autoria/copiar/validar, Luna faz população editorial delimitada sobre fichas estáveis.


## Entrega T3-A — base de autoria e população demonstrativa, 12/10/2026

Usuário autorizou Sol na estrutura racional e Luna nos nomes/flavor. [Pacote](e06_content_base.md) ENTREGUE/VALIDADO: ContentAuthoring, modelos/fichas/texto vinculado à assinatura, descrição factual gerada, prévia nativa e24 entradas preenchidas por Luna. Dados editoriais são separados/copied; nenhuma fórmula, save ou identidade é alterada por texto. Compatibilidade/capacidade/qualidade/mob/conjuntos usam autoridades existentes.

[Guia](../../../content/authoring/README.md) e [prévia legível](../../../content/authoring/demo_preview.md).12 nomes dirigidos PASS,160 checks novos autoria/editorial,13 outputs verificados,24 Resources recarregados e catálogo de produção estável. [Recibo](e06_content_validation.json), SHA256CC7E6D8403347C599DC0C2831714C901D1F1CA7DC351062D4319339DA931A8D9; logs/papéis/tentativas/reuso no pacote. Runner195 agora; não afirmar integral195 executada nem reutilizar193 como novos testes.

Base de conteúdo pronta; não é catálogo final T3 nem UI T4. Próximo lote Sol fixa orçamento/rates/receitas/cobertura/compatibilidades e exemplos concretos, Luna recebe só sua população aprovada. Parâmetros não decididos continuam pendentes, não substituídos por números de fixture. Sem aplicar no checkout fixo, publicar conteúdo ativo, push/merge ou inferir aceite humano. Preservar esta worktree e os logs até integração.

Entrega concreta T3-A:917ad44e5a016632b2ecf19cb863376464a5db76 (árvore680c8f88c94063e7556e9605e9585b7c04301f89). Código congelado conforme inputs do recibo de Luna; anotações posteriores são documentais. Sem preparar/aplicar playtest ou iniciar catálogo final por efeito deste fechamento.

## T3-B — catálogo piloto no ilvl 1, entregue em12/10/2026

Continuação autorizada pelo usuário com receitas manuais no ilvl1; progressão/rates depois. [Contrato/checkpoint](e06_content_pilot.md):63 receitas offline (25 equipamentos/25 augments/6 cartas/6 espécies/1 conjunto), Luna63 nomes/flavors, descrição factual Sol.20 comparações de composição em10 identidades,14 posições legais e5 híbridas bloqueadas rejeitadas. Contratos/metadata dos12 antigos preservados em cópias; publicação futura precisa reconciliar preservação de stats.

Seleção final Luna10/197 PASS, novos testes468/244 checks, regressões pertinentes aprovadas. [Recibo](e06_content_pilot_validation.json) SHA2561B359EBEB3903E49754D58F7C8C7D72BFF7B8CD1DBBE9AB28A4EEE38234DF30D; fonte local congelada por manifest, base075eb8f não confundida com candidato limpo. Sol conferiu hashes/outputs e63 Resources da prévia. Sem delta de catálogo ativo/atores/fórmulas/codec/playtest. Piloto validado tecnicamente; vinte direções táticas, progressão/rates, novos handlers específicos e integração continuam posteriores. Não disparar Astra rotineiro.

Entrega preservada:68b5ab8cfba1914d03908cd32301f5dcc35233ac, árvore4b72d9719218872d67e4d6404a9b68c58dbb4f23, branch codex/e06-inventory, worktree limpa após entrega. Vínculo posterior estritamente documental; fontes/editorial/receitas/recibo validados não mudaram após a supervisão.

## Provas reais e próximo lote espacial,12/10/2026

[Provas](e06_pilot_execution.md):08 procs exclusivos por habilidades reais com/comsem receita, captura em voo preservada. Whitelist obsoleta de Contraforte corrigida somente no ID da arma. Luna7/198 PASS, real128 checks e regressões; recibo DF08C9795B2CF32D9BC8FCB78E201A45C6961C963659BEDAC60E680E66C7EB31, logs recuperados/conferidos. Catálogo/digest/flavor não mudaram,20 direções táticas continuam pendentes. Usuário escolheu [eco e vértices fixos](e06_spatial_policies.md); demais quatro propostas não autorizadas.


## Primeiro lote espacial entregue, 12/10/2026

[Eco e vértices fixos](e06_spatial_policies.md) ENTREGUES / VALIDADOS TECNICAMENTE. Usuário autorizou somente essas duas transformações da proposta. Sol implementou a capacidade fechada, captura de onda/reserva e consumidores reais; Luna completou dois nomes/flavors e supervisionou a regressão. Seleção final 18/200 PASS; novos testes 123 + 153 checks. Sol conferiu os hashes de todos os logs e 65 Resources, além do manifesto de fontes. [Recibo](e06_spatial_validation.json), SHA256 A577ED233E6AB659A1A26722C37EFA54D0E63BD0BE0F639349C9B3F0CBA7D3D9. Não houve nova integral ou revisão Astra rotineira.

[Prévia](../../../content/authoring/spatial_preview.md) e bundle separado de 65 receitas, com os 63 textos anteriores preservados. Duas comparações A recebem as políticas; as dez B permanecem sem elas. Vinte composições válidas não equivalem a vinte direções táticas concluídas. As quatro outras transformações, integração no catálogo ativo, progressão/rates, UI e playtest continuam posteriores. Não iniciar por efeito deste fechamento. Mesmo checkout isolado; preservar os logs até integração.

Vínculo da entrega: commit `2e0f13bc2491e4daa86c4adf99af65dce9cbb598`, árvore Git `f720b7a0398545acca47e874a76accb2b40f6a23`, branch `codex/e06-inventory`. Checkout limpo após o commit. Este vínculo posterior é documental: fontes, receitas, editorial e recibo validados não mudaram; não exige reexecutar a seleção. Base do recibo continua `ecfe13dbd9a80bf8ed36c55c275fba02de996bb8`, com candidato sujo identificado pelo manifesto durante a execução.
