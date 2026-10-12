# E06-TX — contrato DX e manifesto da expansão

11/10/2026. Contrato documental em elaboração; APIs abaixo são propostas até implementação e prova da etapa correspondente. Não consumir como API já entregue. Precedência: decisões humanas atuais → itemization_execution.md → este delta técnico → v1 histórica do e06_contract.md. R1 avalia somente v1; RX avaliará TX1–TX3.

## Decisões humanas desta retomada

- Cada aquisição nova gera exemplar próprio, inclusive repetição de definição/configuração. Não fundir nem substituir aquisições.
- Migração preserva um exemplar por ID realmente registrado no save antigo; não inventa duplicatas descartadas no passado. Arma → main_hand, armadura → torso, acessório → accessory_1.
- Coleção compartilhada: diferentes personagens e presets podem referenciar o mesmo exemplar. Dentro de uma build, o exemplar ocupa uma única posição. Uma única run ativa continua sendo a fronteira existente.
- Encaixes apenas em armaduras reais, armas e escudos. Ombros são armadura. Pescoço e quatro acessórios não recebem cartas. Foco secundário não recebe encaixes, por resposta humana explícita.
- Uma arma de uma mão pode combinar com escudo/foco compatível. Arma de duas mãos ocupa main_hand e exige off_hand vazio. Duas armas simultâneas ficam fora do escopo atual.
- Retirada/transferência gratuita fora de encontros conserva a regra anterior: a carta volta à mochila da run; desequipar libera todas as cartas daquela peça. Cartas continuam efêmeras, inclusive quando encaixadas. Não foi autorizada destruição na retirada.

## Auditoria de impacto e autoridades

| Fronteira atual conferida no código | Delta necessário | Autoridade preservada |
|---|---|---|
| IdentityIds.equipment_slots, CharacterState._empty_equipment e BuildEffectCatalog.SLOTS usam weapon/armor/accessory | Uma lista canônica de14 posições, adaptador explícito dos três nomes históricos | IdentityIds para IDs; regras de equipamento num único módulo |
| EquipmentDefinition não tem qualidade/origem/ilvl/capacidade; posse é lista de IDs em ProfileState | Separar definição imutável de exemplar adquirido, que retém metadata sorteada | Resources + ProfileState, sem inventário paralelo |
| ProfileCodec valida schema2/catalog9 e exatamente três posições; ProfileStore grava pending/primary/backup | Envelope estrutural novo, mapa de migração completo e retry/reabertura conservadores | ProfileCodec/Store, único writer |
| ProfileFacade.create_character e _grant_reward_payload deduplicam pelo definition_id | Starter aditivo sem repetição automática; aquisição nova cria exemplar uma vez por ticket | ProfileFacade/RewardResolver e sequência da sessão |
| BuildSnapshot.equipped contém definition_id; compositor usa equipment:slot:item | Referências instance_id, metadata capturada por valor e fontes por exemplar | BuildSnapshot/BuildEffectComposer |
| RunCardInventory deduplica card_id; sockets é item_id→card_id | Carta por exemplar da run; socket por equipamento e índice; repetição sem sobrescrita | RunCardInventory/RunBuildService |
| RunBuildService valida posse/revisões/dívida e persiste antes de publicar | Resolver exemplar e matriz inteira de mãos/slots/encaixes antes de save | Mesmo serviço/fachada/HealthState e dívida SP existente |
| BuildEffectCatalog valida STAT/SKILL_RULE/PROC; só range/projectile_count/HIT_DAMAGE concretos | Classificar capacidade da receita por handler/semântica, tags e restrições por origem | Mesmo catálogo/resolver; nenhum código em dados |
| EffectProcLedger usa cap16, dedupe família/alvo/raiz e exceções E05 | Proposta causal separada, sem teto de fontes da build | Mesmo ledger/contexto, adaptadores intrínsecos preservados |
| DamageRequest captura procs; skill_id não comprova uso de arma | Capturar uso real de arma e IDs de exemplares na emissão | PlayerActor/DamageRequest/resolver; projéteis retêm captura |
| RunRewardService.issue sorteia item/carta por etapa; ProfileRewardResolver deduplica equipment_ids | Payload congelado de exemplares, depois loot por ocorrência com tabelas parametrizadas | RewardService/Facade/Store; nenhuma concessão direta da UI |
| EnemyActor contém arquétipo/runtime; não existe ficha mob-base/loot declarativa nas autoridades auditadas | Definições de espécie e ocorrência separadas; stats fixos, skill adapters explícitos | Novo catálogo de mobs consumido pelo ator; combate canônico |
| CharacterMenu usa três seletores e consulta weapon | Adaptação mínima de compatibilidade precisa de pacote declarado; UI final14 é T4 | Menu observa DTOs, sem nova lógica de validade |

## TX1 — identidade, posições e migração

IDs canônicos, ordem estável:
head, neck, shoulders, arms, torso, cloak, legs, feet, main_hand, off_hand, accessory_1, accessory_2, accessory_3, accessory_4.

Acessórios compartilham categoria accessory, mas cada posição é distinta. A definição declara categoria e compatibilidades; slot visível não determina sozinho elegibilidade de carta. Um foco em off_hand tem capacidade zero; um escudo em off_hand pode ter0–4. Armadura inclui head/shoulders/arms/torso/cloak/legs/feet. Pescoço é joia. Descrições traduzidas não participam de validade. Restrições atuais de origem/evolução permanecem.

Proposta de tipos:
- EquipmentDefinition: identidade estável, textos/ícone, categoria/posição compatível, subtype, hand_usage, allowed_origins/evolutions, starter, efeitos imutáveis. Sem estado sorteado de aquisição.
- EquipmentInstance (RefCounted por valor): instance_id, definition_id, origin_id, item_level, quality_id, socket_capacity. Não contém carta, cooldown, HP, stacks nem Node. Origem/ilvl/qualidade/capacidade pertencem à aquisição congelada, não são recalculados ao equipar.
- ProfileState: equipment_instances e next_equipment_counter passam a ser a autoridade persistente; equipped/presets apontam instance_id. Não manter equipment_collection como segunda fonte de verdade. DTOs legados derivam de instâncias quando estritamente necessários.
- BuildSnapshot: cópia dos exemplares referenciados, além das posições. Lookup por instance_id sem referência mutável ao perfil. BuildEffectComposer resolve definição e metadata dessa captura.
- RunCardInventory: card_instance_id→definition_id e host_instance_id→array de encaixes; comprimento exatamente socket_capacity, null quando vazio. Cada carta ocupa no máximo um encaixe; a mesma definição pode aparecer várias vezes.

Migração proposta: schema2/catalog1..9 suportados → schema3/catalog10, conservando ruleset stat_thresholds_v1. Versions são proposta técnica, sem alteração runtime nesta etapa. Primeiro validar o legado com seu contrato/versão/slots; depois converter. Não trocar a lista de slots global antes de decodificar o formato antigo. Revisão durável avança uma vez pelo Store. Future schema/catalog/ruleset, pending incerto, backup incompatível e extensões continuam protegidos.

Criar mapeamento determinístico definition_id→instance_id para os IDs conhecidos realmente registrados, sem RNG. Reusar esse mapeamento em equipped e ambos os presets de todos os personagens. Preservar preferência nula;11 posições novas vazias; não preencher automaticamente14 posições. Starters ausentes seguem união aditiva vigente, sem criar exemplar novo por reabrir/migrar/criar alt. XP/ranks/alocações/barras24/configurações/contadores/reward_session/legado não resolvido/extensões permanecem.

O usuário recusou metadata desconhecida no legado e aprovou a tabela explícita abaixo para os12 IDs atuais. Todos têm item_level=1 e origin_id=demo_arena, rótulo Arena demonstrativa. Cinco starters são common; outros sete rare. Armas/armaduras conservam capacidade1; acessórios têm0. Efeitos/stats atuais preservados; qualidade não aplica multiplicador implícito nem inventa fórmula de poder. Novas aquisições guardam a metadata real do payload congelado. Catálogos exclusivamente injetados em testes precisam declarar sua própria fixture; não extrapolar a tabela para IDs de produção desconhecidos.

Intenções propostas RunBuildService:
- equip: slot + equipment_instance_id; unequip: slot.
- socket/unsocket: equipment_instance_id + socket_index; socket inclui card_instance_id.
- transfer: from_equipment_instance_id + from_socket_index + equipment_instance_id + socket_index + card_instance_id.
- Mantêm request_id e revisões profile/runtime/build/inventory capturadas; commit usa intent devolvida por preview. UI não envia capacidade, qualidade, stats ou autorização de encontro.

Toda posição/mão/posse/índice/carta/elegibilidade/conflito é validada na build inteira, em ambos os presets persistentes pertinentes. Rejeitar conflito sem desequipar, destruir ou substituir silenciosamente outro item/carta. Não converter duas mãos em transação parcial. Mudanças de cartas são somente runtime; preferências de equipamentos vão ao save antes da publicação. Reconcile usa mesmo request/payload e IDs, sem criar novo exemplar em retry.

Fontes propostas: equipment:<slot>:<instance_id>; card:<host_instance_id>:<socket_index>:<card_instance_id>. IDs de fonte não são display_name nem definition_id isolado. Cada exemplar legal contribui uma vez. Efeito cumulativo soma pela política da receita; transformação exclusiva continua protegida pelo grupo canônico, sem tratar cada cópia como família causal nova para escapar do dedupe.

Erros adicionais propostos: unknown_equipment_instance, duplicate_equipment_instance, invalid_equipment_instance, invalid_hand_configuration, invalid_socket_capacity, invalid_socket_index, socket_not_allowed, card_instance_not_owned, card_instance_already_socketed. Erros existentes de save/revisão/identidade/composição/dívida continuam propagados. Todas as coleções/DTOs devolvidos por valor.

## TX2 — capacidades de receita e composição

Proposta de fronteira explícita a fechar antes dos consumidores:

| Capacidade | Exemplo | Regra de origem |
|---|---|---|
| stat | +VIT, +DEF física, +MDEF, +ASPD, +FLEE pelos canais canônicos | Incomum aceita apenas essa capacidade; não só os seis primários |
| skill_buff | Alterar um escalar de skill já existente, mantendo targeting/elemento/componentes/fluxo | Carta de base normal/rara pode usar; handlers/eixos precisam ser suportados de fato |
| transformation | Novo projétil/componente, mudança de elemento/targeting/fluxo | Apenas carta de base elite+; equipamento raro+ quando elegível |
| proc | Ativação automática declarada, inclusive secundário ao acertar | Carta de base elite+; nunca botão de jogador; anti-cascata obrigatório |
| active_grant | Fonte de acesso a ação acionável | Somente colar/acessório elegível; nunca carta ou incomum |

O kind SKILL_RULE atual não basta para distinguir buff e transformação: range e PROJECTILE_COUNT são ambos SKILL_RULE. Validador usa capacidade conhecida do handler/eixo, não campo livre de texto que permita declarar proc como buff. Resposta humana desta retomada: projétil adicional é transformação e fica restrito a cartas de base elite+. Eixos ainda sem consumidor não são liberados por enumeração.

Tags: IDs estáveis registrados, múltiplos por efeito/skill; rótulos pt-BR separados. Exemplo de vocabulário documental: echoing/Ecoante, bleeding/Sangrento, energizing/Energizante, freezing/Congelante, flaming/Flamejante, renewing/Renovador, ethereal/Etéreo. Esses nomes são proposta de vocabulário; significado operacional ainda precisa de definição por receita. Tags não aplicam bônus, não ativam triggers e não são equivalência/exclusividade. Evitar restringir um efeito ao kit por interpretar uma tag vaga.

Exclusividade de equipamento: chave estável unique_effect_id para o efeito com mesmo nome semântico; dois equipamentos diferentes com essa chave rejeitam a transação inteira. Bônus genéricos de stats não são presumidos como efeito nomeado exclusivo. Acessório com mesmo definition_id também rejeita, mesmo que instance_id/qualidade sejam diferentes. Não confundir unique_effect_id com family_id causal, tag ou tradução. Decidir explicitamente esse alcance de stats antes de receitas.

Conjunto: definição imutável própria com set_id e thresholds; contar peças legais equipadas, um limiar gera uma fonte set:<set_id>:<threshold>. Peças não replicam o efeito do conjunto. Validar conjunto vestível, contribuição única e incompatibilidades, preservando incomuns somente stats. Fontes de conjunto e conflito cross-origin são contratadas antes de receita; não inventar prioridade de origem. Sem obrigar toda armadura a ter conjunto.

Armas: ação/emissão captura weapon_instance_ids efetivamente usados. Proc de arma só pode observar esses IDs; spell genérica com skill_id da mesma origem não basta. A ação já emitida retém snapshot. Autos e tiros pagos da Sentinela exigem adaptador explícito; Rede/efeitos de INT não ganham uso de arma por serem de Arqueiro. Escudo/foco passivo não é arma usada por suposição. Não alterar fórmulas dos kits para criar compatibilidade.

Ativas: learned_ranks persistentes e item_grants runtime separados. Resposta humana: rank efetivo é max(aprendido, concedido pela receita), sem soma; cooldown compartilhado por skill continua após remover/trocar fonte; captura já emitida preservada; perda da última fonte desabilita a ação e cancela preparação não lançada. Ativas de outra classe são permitidas somente com compatibilidade declarada e execução concreta validada, sem conceder o resto do kit. Resposta humana adicional: disponibilidade na biblioteca enquanto equipado, organização manual sem atribuição automática; conservar atalho desabilitado na mesma posição após perder a última fonte. Reequipar restaura acesso sem resetar recarga. Codec/layout precisam preservar essa referência sem conceder aprendizado ou disponibilidade. Não comprar rank, gravar aprendizado, repovoar barra ou resetar cooldown silenciosamente. Runtime de0→1 fonte requer adaptador concreto para cada ação suportada; metadata não cria executor universal de skill.

Proteção causal: substituir cap16 apenas após proposta reproduzível, com fontes finitas da emissão, claims família/alvo/raiz antes de callbacks, dedupe e exceções E05 contratadas. Não usar número substituto arbitrário, ICD inventado ou truncamento lexical de fontes. A prova deve incluir >16 fontes úteis sem cascata, multi-alvo, reentrada, eventos tardios, cancelamento e memória/limites de projéteis existentes. Sem remover proteções mundiais/kit por interpretar efeitos simultâneos ilimitados.

## TX3 — espécie, ocorrência e loot

Tipos propostos: MobDefinition imutável com id, nível fixo, stats/skills, base_category e allowed_occurrence_categories; MobOccurrence com occurrence_id/mob_base_id/category_id e origem espacial; loot profile parametrizado com pesos explícitos por categoria e RNG injetado. Categorias normal, rare, elite, rare_elite, boss. Não escalar mob pelo nível do jogador nem iniciar mapas/campanha E07.

Carta aponta mob_base_id. Validador consulta a base declarada no catálogo, jamais a dificuldade da ocorrência. Base normal/rara mantém carta simples em ocorrência elite; ocorrência difícil afeta chance, não receita, qualidade ou ativa. Stats/dano de mob continuam pelo pipeline existente com adaptadores concretos das skills.

Loot: qualidade e capacidade de encaixes sorteadas por eixos separados, respeitando subtipo; lendário só boss; normal/elite sem lendário; raro garante incomum, elite raro garante raro, boss garante épico. Resposta humana: um item com qualidade mínima garantida; resultado superior substitui o mínimo, sem segundo item automático. Sem percentuais finais, orçamento de poder ou multiplicador inferidos. Taxas fixtures identificadas e não usadas como produção. Raridades operacionais de catálogo/cores fora das cinco principais ainda aguardam delimitação.

Issue por evento de mob congela RNG, exemplares/origem/ilvl/qualidade/capacidade/carta e ticket. Retry/replay nunca rerrola ou reconcede. Coleta mantém durabilidade/pending da fundação. Resposta humana: loot por mob substitui equipamentos/cartas da etapa; XP e escolhas de augment por encontro permanecem. Tabelas de fixture são exclusivas dos testes; taxas de produção ficam para conteúdo posterior. Wiring de produção não usa taxas inventadas.

## Validação por impacto e dependências

TX1: migração determinística sem perda/fusão, versões/pending/backup/falhas de gravação, compartilhamento entre alts/presets, preservação dos nulos e barras, instanciação por aquisição/retry,0/4 encaixes, cartas repetidas em peça e fontes únicas, mãos ilegais, oferta/combat lock, transação sem gravação parcial, dívida/HP/SP e snapshot em voo. Usar verify com testes dirigidos e invariantes novas; registrar seleção exata/inputs/hashes.

TX2: matriz stat/buff/transformação/proc/ativa por origem/qualidade/base, tags sem efeito implícito, exclusividade/conjuntos, composição reordenada, arma realmente usada, acesso/rank/remoção/CD, eventos em voo, caps canônicos e proteção causal reprojetada. TX3: garantias/RNG extremo, lendário só boss, mesma carta entre variantes, categoria restrita, origem/ilvl fixos, replay/save failure e eventos de mob versus etapa.

Uma validação integrada no fechamento que a exija e RX da fundação ampliada inteira antes de T3/T4. Não somar reexecuções nem reapresentar178/178 como evidência de HEAD. UI/chapéus finais aguardam FX; metadata de fixture não certifica balanceamento, apresentação ou diversão.

Pendências imediatas: concluir R1 e registrar pacote concreto TX1. Metadata legada definida pela tabela humana abaixo. Pendências seguintes são perguntadas antes do trecho dependente, sem bloquear documentação independente. Aprovação R1 não é aprovação RX, playtest, merge ou produto.

## Tabela de migração aprovada pelo usuário, 11/10/2026

| Definition ID preservado | Qualidade | Ilvl | Origem | Encaixes |
|---|---|---|---|---|
| starter_blade | common |1| demo_arena |1|
| starter_staff | common |1| demo_arena |1|
| starter_bow | common |1| demo_arena |1|
| traveler_vest | common |1| demo_arena |1|
| traveler_charm | common |1| demo_arena |0|
| riposte_blade | rare |1| demo_arena |1|
| ember_staff | rare |1| demo_arena |1|
| hunters_bow | rare |1| demo_arena |1|
| warden_mail | rare |1| demo_arena |1|
| channeler_robe | rare |1| demo_arena |1|
| trailcoat | rare |1| demo_arena |1|
| prismatic_charm | rare |1| demo_arena |0|

Nenhuma receita final ou stat adicional foi concedido pela tabela. As taxas de drop e cores/categorias adicionais não foram fixadas por essa resposta. Os IDs e números aqui são decisão humana explícita, não valores de fixture promovidos a balanceamento.

## APIs entregues em TX1, 12/10/2026

Esta seção é implementação atual de TX1; TX2/TX3 acima permanecem contratos a implementar. Schema3/catalog10; ruleset stat_thresholds_v1.

- EquipmentInstance.copy_instance/to_record/from_record/from_metadata:6 campos por valor (instance_id, definition_id, origin_id, item_level, quality_id, socket_capacity). Sem cartas/HP/CD no save. IDs de aquisição equipment_<counter> não se confundem com definition_id.
- EquipmentRules.empty_layout/validate_definition/validate_instance/validate_layout:14 posições, categoria accessory comum às4 posições, elegibilidade física de encaixe, identidade, uma referência por build, acessórios idênticos e duas mãos. DTOs puros; nenhuma fórmula.
- ProfileState.equipment_instances + next_equipment_counter são autoridade; equipment_instance_ids/first_instance_for_definition consultam por contador; add_equipment_instance muta somente a cópia candidata, sem gravação. equipment_collection é array derivado de IDs de instância, de leitura; append nele não altera coleção. ProfileFacade/Store conservam o único caminho durável.
- EquipmentDefinition.metadata e ProfileCatalog.all_equipment_metadata derivam/copiam somente dados Resource. Field slot é categoria (main_hand/torso/accessory etc.), hand_usage one_hand/two_hands/none e item_kind weapon/armor/shield/focus/jewelry. Resource imutável retém defaults da tabela aprovada; exemplar guarda metadata real congelada. Catálogo injetado exclusivamente de fixture recebe dados explícitos/valores de fixture, sem virar produção.
- BuildSnapshot.equipment_instances/equipment_records capturam por valor; from_character recebe instances opcional ao final. Composição exige os exemplares de equipped e devolve as mesmas fontes/regras canônicas. Nenhuma fórmula de stats/dano duplicada.
- RunBuildService intenções equip/unequip/socket/unsocket/transfer usam equipment_instance_id, card_instance_id, socket_index e from_equipment_instance_id/from_socket_index quando aplicável. Mantêm request_id e revisões profile/runtime/build/inventory/resource_state; preview e commit/reconcile preservam contratos T2. Não usar item_id/card_id de definição como referência de exemplar.
- RunCardInventory.grant(definition_id,catalog,acquisition_id opcional): novo exemplar por chamada sem acquisition_id; mesmo acquisition_id/definição retorna o exemplar original uma vez. Reuso do token com outra definição falha. describe inclui owned/free de IDs de exemplar, instances (exemplar→definição), sockets (host→array indexado de comprimento igual à capacidade) e revision. Retirada/transferência gratuita fora do encontro; desequipar libera todas as cartas do host. clear descarta propriedade e claims da run.
- RunState.effect_state inclui card_instances e card_sockets por valor; fontes card:<host>:<index>:<card_instance>. local_equipment_instances pertence só à run sem fachada; cópias do perfil suprem a sessão persistente. add_local_equipment usa mesma validação e não grava.
- ProfileRewardResolver preserva IDs repetidos numa recompensa como aquisições distintas. RunRewardService.issue congela equipment_drops com metadata; valida todos os candidatos antes do RNG; collect confirma persistentemente primeiro, publica cartas uma vez por ticket e permite repetição de definição. A tabela/cadência de mob nova ainda é TX3; não aplicar taxas de fixture à produção. lifetime_stats.equipment_unlocked conserva contagem de DEFINIÇÕES distintas, não cópias.
- BuildPresentation inclui instance_id/definition_id/origin/item_level/quality/socket_capacity e cada exemplar de carta em DTO copiado. Textos pt-BR e stats/regras continuam derivados do compositor.

Erros adicionais: invalid_equipment_definition/instance/counter/hand_configuration, unknown_equipment_instance, duplicate_equipment_instance, identical_accessory, invalid_socket_capacity/index, socket_not_allowed, card_instance_not_owned/already_socketed. Erros de sessão/revisão/recurso/composição/save continuam T2. Codec rejeita referências de catálogo desconhecidas e formato com duas autoridades de coleção, preservando arquivos incompatíveis.

Provas/reprodução: e06_tx_validation.json e checkpoint e06_tx.md;42 etapas distintas de seleção dirigida PASS, sem claim de suíte integral ou RX. Interfaces/receitas/chapéus finais não são entregues por esta seção.


## Contrato executável TX2 antes da edição

- EffectDefinition.capability deriva dos handlers: STAT_MODIFIER→stat, SKILL_SCALAR/range→skill_buff, PROJECTILE_COUNT→transformation, HIT_DAMAGE→proc; ACTIVE_SKILL→active_grant. Nenhuma string de capacidade fornecida pelo conteúdo. unique_effect_id é chave semântica estável exclusiva entre exemplares de equipamento; stat genérico pode omiti-la. tags são IDs registrados com rótulos pt-BR, múltiplos, sem bônus ou gatilho implícito.
- CardDefinition.mob_base_id referencia MobCatalog copiado/imutável. BaseCategory normal/rare/elite/rare_elite/boss, allowed_occurrence_categories separados. Receitas sem efeitos antigas podem manter origem vazia até conteúdo; carta com efeito exige base concreta. Normal/rare só stat/skill_buff. Todas as cartas rejeitam active_grant. Card copies ADDITIVE somam; cópias da mesma transformação EXCLUSIVE card/effect compartilham efeito idempotente, fontes continuam na provenance; definições/famílias distintas em conflito e carta/augment continuam rejeitando a mudança inteira. Sem precedência oculta.
- Common/uncommon só stat. EquipmentDefinition com nonstat ou conjunto exige qualidade rare+; metadata de aquisição incompatível é rejeitada antes de RNG/ticket, não suprimida na composição. Conjuntos somente armaduras reais rare+, declaração no catálogo próprio EquipmentSetDefinition(id, thresholds int→Array[EffectDefinition]). Contar definições de peça únicas, uma fonte set:<id>:<threshold> por limiar. Composição determinística primeiro acesso a ativas, depois modificadores.
- Active grants por efeito: granted_skill_id/rank1..5 + target base classes explícitas na receita. ItemSkillAdapters começa com fire_spear, ice_spear e teleport para as três bases, execução existente adaptada/provada; demais IDs são rejeitados até adaptador concreto. Não libera kits/evoluções/passivas. composed.item_grants/runtime_skill_ranks são separados de snapshot.skill_ranks persistentes. Effective=max(learned,grants). Biblioteca inclui fonte equipada; barra nunca preenchida automaticamente. Referências conhecidas dos adaptadores podem persistir desabilitadas em action_slots schema3; presets/slots antigos continuam exigindo aprendizado. Codec não concede ranks.
- DamageRequest.weapon_instance_ids captura main_hand só para ações explicitamente mapeadas: autos; golpes físicos diretos de Espadachim/Berserker/Defensor; arco direto Caçadora; tiros pagos Sentinela salvo net_shot (INT). Spells genéricas/traps/collapses não herdam arma. Procs guardam requisitos de exemplar e só observam uso capturado; agregação cross-origin preserva parcelas condicionais sem dar a parcela da arma a outro evento.
- RootBudget novo recebe plano congelado de famílias de proc e famílias intrínsecas concretas, IDs de alvos vivos presentes na emissão incluindo dono, e carriers elegíveis marcados. Orçamento=|famílias|×|alvos|+|carriers|×|alvos|; somente pares autorizados podem ser reclamados, um por família/alvo (echo por carrier/alvo). Claim antes de listener, apply_once, depth/proc_child/reentrada/cancelamento e weak roots512 continuam. Não trunca lista de fontes nem impõe número substituto arbitrário. Ticks finitos intrínsecos herdam o plano ao criar sua raiz conforme contratos E05. Fixtures antigas sem plano conservam cap16 explicitamente como modo de compatibilidade; producers vivos usam plano. Limite global128 projéteis/caps específicos de skills permanecem.

Erros: capability_not_allowed, missing_mob_base, unknown_effect_tag, duplicate_unique_effect, invalid_set, unsupported_item_active, invalid_item_rank/compatibility. Novos testes: matriz origem/qualidade/base/instância; várias cópias e fontes/provenance; conjunto/copias/reordenação; cross-class real/cooldown/emissão/cancelamento/atalho/save; >16 famílias, múltiplos alvos, replay/reentrada/proc_child/plano capturado/echo/cancelamento.

TX2: a chave semântica de equipamento é unique_effect_id declarado; se ausente em receita não estatística, effect.id é a chave estável obrigatória já validada. Isso impede efeito interessante sem chave de escapar da exclusividade. Stats genéricos podem omitir; tags nunca substituem a chave. Conflito EXCLUSIVE conserva effect_conflict, demais colisões nomeadas retornam duplicate_unique_effect.


## Contrato executável TX3 antes da edição

- MobDefinition imutável: fixed_level, seis primary_attributes e fontes de stats canônicas explícitas, archetype/raio/animação existentes, skill_ids com skill_ranks e card_id. MobCatalog valida stats pelo StatCalculator e adaptadores suportados, preservando restrição de ocorrência. Nunca consulta nível do jogador. MobOccurrence.copy_occurrence captura occurrence_id, mob_base_id, category_id, origin_id; IDs técnicos, categoria permitida e origem obrigatória.
- MobSkillAdapters começa com fire_spear/ice_spear. EnemyActor reutiliza rank/cast/custo/CD/poder do catálogo de classe e fórmulas canônicas, executor single-target/projectile1 sem restante do kit. Metadata desconhecida não cria executor. Configure_occurrence valida antes de mutar ator, copia definição e stats. Primários/modificadores atuais da demo permanecem idênticos.
- MobLootTable.profiles é mapa categoria→row com equipment_chance/card_chance0..1, quality_weights (common..legendary), equipment_weights (definition IDs) e socket_weights (índices0..4). Pesos finitos positivos, soma finita; não há defaults de taxa. Resolver valida todas as saídas possíveis antes de RNG. legendary em non-boss é erro de tabela, não filtro tardio. Cada categoria configurada tem todas as referências conhecidas.
- Piso de qualidade rare→uncommon, rare_elite→rare, boss→epic; normal/elite sem garantia. Sortear qualidade e aplicar max(sorteada,piso), um único exemplar. Escolher definição entre receitas compatíveis com qualidade real; qualidade não multiplica stats implicitamente. Socket sorteado independentemente da qualidade, forçado0 só em peça fisicamente inelegível. metadata origin_id=ocorrência, item_level=fixed_level da base (rótulo sem fórmula nova de poder). Até1 item e1 carta por evento nesta fundação, sem quantidade extra automática.
- MobLootResolver.roll usa cinco uniforms explícitos0..1 (chance item, qualidade, definição, socket, chance carta), aceita extremos deterministicamente. Card ID vem só da base, receita/base constantes entre variantes; profile muda chance, não conteúdo da carta. Estado de RNG é consumido pelo serviço somente após validação; replay não lê RNG. Tabelas fixtures nunca são fallback de produção.
- RunRewardService.configure_mob_loot(table) valida/copía catálogo de efeitos/mobs e tabela antes de qualquer evento; não instala durante tickets pendentes. register_mob_actor captura ocorrência no spawn de ator próprio. issue_mob_drop aceita somente ator registrado, morto, pertencente ao controller e run atual; registra ticket/evento/sequência imutáveis. Eventos ainda em encontro podem congelar loot; collect continua fora de combate, com writer único/pending/reconcile e publicação de carta após durabilidade. Colheita de mob não cria escolha de augment nem XP presumido.
- Main associa ocorrência normal demo no spawn. Loot por mob fica desabilitado sem tabela de produção explícita; quando configurado, morte emite ticket por ocorrência, drop de equipamento/carta da etapa é substituído; XP e escolha de augment permanecem por encontro. Coleta existente de final de encontro drena tickets de mob anteriores em ordem durável antes do ticket XP/augment; o serviço também oferece coleta individual por ticket fora de encontro. UI visual de pickups individuais continua T4; nenhuma taxa inferida habilita o modo.

Erros: invalid_mob_definition/category/stats/skill, invalid_occurrence, invalid_loot_table/weights/chance, legendary_requires_boss, empty_guaranteed_pool, invalid_mob_event, unknown_mob_actor. Provas: reprodução exata de stats demo e nível fixo contra jogador forte/fraco; catálogo copiado/variantes proibidas/skills reais; fronteiras0/1/garantias/superior substitui/socket independente/card base; ator vivo/estrangeiro/replay/RNG/falha save/reconcile/card ephemeral e XP/augment da etapa.


## APIs entregues TX2/TX3, 12/10/2026 — autor, RX pendente

Contratos executáveis acima agora implementados. BuildEffectCatalog.register_set/get_set/set_mob_catalog/mob_catalog/validate_equipment_quality, EffectDefinition.capability e EffectTags são autoridades copiadas. Composer devolve item_grants/skill_ranks efetivos/unique_effects, parcelas de proc condicionadas e provenance com tags. RunState.available_active_ids/effective_skill_rank/has_item_active preservam aprendizado/biblioteca; Actor usa capturas canônicas e adaptadores whitelist. ActionBarLayout.valid aceita retained_item_refs opcional; codec schema3 guarda referências conhecidas desabilitadas sem conceder rank. SkillEffectResolver.capture retorna tags copiadas.

RunState.causal_plan inclui famílias intrínsecas, componentes secundários/ticks concretos reservados, skills aprendidas e procs da composição, mais alvos/carriers congelados pelo produtor. EffectProcLedger.new_root recebe plan opcional ao final, application_limit consulta bound derivado; fixtures sem plano mantêm compatibilidade histórica16. Scheduled_tick herda plano. DamageRequest.weapon_instance_ids e resultado canônico copiam uso real; partes condicionais permanecem separadas em composição/ganho/callback.

MobCatalog.stats usa StatCalculator; MobOccurrence.copy_occurrence/validate, EnemyActor.configure_occurrence e MobSkillAdapters.capture seguem contrato fixo. MobLootResolver.create/validate_occurrence/roll/minimum_quality validam/copiam tabelas e usam uniforms explícitos; RunRewardService.configure_mob_loot/register_mob_actor/issue_mob_drop/collect_pending_mob_tickets ligam somente eventos próprios ao writer. Configuração bem-sucedida chama RunState.freeze_effect_catalog; set_effect_catalog passa a retornar catalog_frozen depois dessa fronteira. Ativas/mobs com adaptador não listado continuam rejeitados.

Current demo default é preservado: sem tabela de produção, modo mob loot desligado; fixtures não são fallback. Pickup individual visual/fórmula de poder por qualidade/rates finais ainda não entregues. SHA/provas/limites por etapa no checkpoint e recibos, sem claim de aprovação independente.
