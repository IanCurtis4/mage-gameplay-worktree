# E06-T2 — manifesto estável de APIs e DTOs

Base F1: `96a081aa346479450a18bd21bfd9bc53a95dbc15`. Fundação T1+T2 para R1.
O recibo `e06_t2_validation.json` identifica o commit executado e as árvores.
Estas APIs são internas ao processo; a UI usa os DTOs e intenções descritos abaixo.

## Fonte única de conteúdo

`BuildContentLoader.definitions(origin: StringName) -> Array[Resource]` lê cópias dos
`.tres` em `resources/build_effects/{equipment,card,augment}` em ordem estável.
`load_catalog() -> Dictionary` registra tudo em BuildEffectCatalog, preserva os
cinco augments legados quando não substituídos por dados, e retorna `ok/catalog`
ou o erro do validador T1. `pilot() -> BuildEffectCatalog` exige catálogo válido.
ProfileCatalog deriva metadata de equipamento dos mesmos Resources. A injeção
explícita de metadata não vazia continua disponível para fixtures legadas isoladas.

12 equipamentos e 6 cartas têm IDs/slots/restrições reservados pelo §8. Receitas
vazias são deliberadas nesta fundação não publicada. T3 preencherá efeitos/textos/
ícones sem alterar essas identidades. Cartas vazias não são sorteáveis. Os efeitos
reais usados nas provas pertencem às fixtures, com handlers aprovados de T1.

## Intenção de build e autoridade

`RunBuildService.new(controller: RunController)` captura controller, ator e RunState
canônicos. `context() -> Dictionary` devolve `runtime_revision`, `build_version`,
`profile_revision` (−1 em fixture/treino sem fachada). Nunca enviar `encounter_active`,
stats, efeitos ou posse como autoridade da UI.

`preview_change(intent: Dictionary) -> Dictionary` exige:

- `request_id: String` não vazio, até ProfileFacade.MAX_REQUEST_ID_LENGTH;
- as três revisões inteiras atuais obtidas em `context()`;
- `kind`: `equip`, `unequip`, `socket`, `unsocket` ou `transfer`;
- `equip`: `slot` e `item_id`; `unequip`: `slot`;
- `socket`: `item_id`, `card_id`; `unsocket`: `item_id`;
- `transfer`: `from_item_id`, `item_id` de destino, `card_id`.

IDs aceitam String/StringName. Sucesso retorna `ok`, `error_code`, `request_id`,
`intent` capturada por valor, `equipped`, `inventory`, `before`, `after`, `hp_after`,
`sp_after`, `sources`, `inactive`, `skill_rules`. `before/after` são os valores do
StatBreakdown canônico. `intent` recebe `resource_state` (dívidas e buffs) e
`inventory_revision`; não se deve editar esse DTO antes de confirmar.
Preview não altera save, RNG, coleção, ator ou versões.

`commit_change(intent: Dictionary) -> Dictionary` recebe a `intent` devolvida pelo
preview. Revalida contexto, sessão/personagem, posse/slot/identidade, oferta aberta,
revisões, recursos e composição inteira. Equipamento confirma o save antes de
publicar; carta é somente runtime. Publica nova cópia do snapshot/inventário, e
incrementa build_version/runtime_revision uma vez. Preserva dívida, cooldowns,
ranks, barras e emissões já capturadas. Sucesso inclui as revisões atuais.

`reconcile_change(request_id: String) -> Dictionary` consulta a mesma transação
incerta; `commit_change` com a mesma intenção encaminha para essa recuperação.
Payload/request diferente não substitui a pendência. A run e as ofertas ficam
congeladas enquanto o resultado for incerto. Commit confirmado publica uma vez;
ausência confirmada libera a run sem publicar, permitindo retry da mesma intenção.
`has_pending_transaction() -> bool` inclui execução síncrona e resultado incerto.

Erros relevantes: `invalid_request_id`, `invalid_intent`, `preview_required`,
`missing_snapshot`, `invalid_session`, `actor_dead`, `encounter_active`, `offer_open`,
`stale_revision`, `stale_resources`, `item_not_owned`, `invalid_slot`, `no_change`,
`hp_deficit`, `sp_deficit`, `replayed_request`, `save_in_progress`, `result_uncertain`.
Erros adicionais de composição/identidade/handler preservam código e `detail` de T1.
Falhas do Store/Facade preservam seus códigos e `read_only` quando aplicável.
Não renderizar códigos/detalhes técnicos diretamente ao jogador.

## Cartas e recursos

`RunCardInventory.describe() -> Dictionary`: `owned`, `free`, `sockets` e
`inventory_revision`, todos por valor. `copy_inventory()` e `sockets()` também
copiam. `owns(card_id) -> bool`; `grant(card_id, catalog) -> Dictionary` é API interna
de aquisição e deduplica (`already_applied`). Não usar grant como botão de UI.
`preview(intent, equipped) -> Dictionary` cria inventário candidato isolado;
o serviço valida a composição antes da publicação. Desequipar libera a carta,
transferir remove o host anterior e rejeita destino ocupado. `clear()` descarta
propriedade/encaixes. Erros: `card_not_owned`, `socket_item_not_equipped`,
`socket_occupied`, `invalid_transfer`, `socket_empty`, `unknown_definition`.

`HealthState.hp_deficit() -> float`, `heal(amount) -> float` e
`PlayerActor.sp_deficit() -> float`, `recover_sp(amount) -> float` preservam dívida
real, inclusive acima de máximo involuntariamente reduzido. Retorno de cura é o
valor realmente recuperado. Dano/custo aumenta dívida real; projeção visual nunca
reconstrói a dívida. Troca rejeita max_hp <= dívida e max_sp < dívida.
Morte por redução involuntária é terminal, emitida uma vez; aumentar máximo não
revive. Setters de current_hp/current_sp permanecem para inicialização/fixtures;
os escritores de gameplay usam heal/recover ou o ledger. `resource_state()` copia
as dívidas e `temporary_stat_sources()` usadas pelo compositor.

## Fachada persistente

`run_mutation_status(run_id, character_id) -> Dictionary` confere sessão,
seleção atual, gravação/pending/read-only. `equip_between_encounters(request_id,
expected_revision, controller, intent) -> Dictionary` só aceita commit ativo do
serviço vinculado à mesma fachada e refaz sua validação. Atualiza apenas equipped
e o preset selecionado, no mesmo save. O outro preset, alts, barras24, XP,
alocações e ranks ficam preservados.

`reconcile_transaction(request_id) -> Dictionary` relê a mesma dupla antes/candidato;
usa a recuperação existente do Store, sem inventar novo payload ou gravação.
Reabertura em outro processo continua usando as regras existentes de pending,
backup, migração e fechamento de sessão interrompida.

Schema2 e `stat_thresholds_v1` preservados; catálogo auditado8 → 9. Migrações1..6
mantêm validação/conversão histórica antes da união de starters; 7/8 já usam o
orçamento atual. Slots nulos de equipped e dos dois presets recebem starters da
origem; seleções válidas não nulas e extensões são mantidas. Revisão/backup do
Store continuam únicos. Cartas, encaixes, augments, tickets, dívida e revisões
transitórias não são campos persistentes.

## Recompensas e terminal

`RunRewardService.new(controller)` vincula a autoridade real e cursor da sessão.
`issue(event_id: String, reward_id: StringName, stage_reward: bool = false)` é API
do produtor de evento do mundo. Só emite fora do encontro com ator vivo. Repetir
o evento devolve o ticket original sem sortear novamente. Na etapa, escolhe um
item legal não starter (duplicatas permitidas) e uma carta útil ainda não possuída
ou reservada por outra coleta. Utilidade vem do compositor T1. Pool vazio avisa.
XP continua 100/80 no encontro1 e 150/100 no encontro2.

`ticket(ticket_id) -> Dictionary` devolve cópia com `request_id/ticket_id`, `event_id`,
`reward_id`, `sequence`, `payload` (XP/itens/contadores), `item_id`, `card_id`,
`stage_reward`, `delivered`, `message`, `ok/error_code`. Nenhuma alteração no DTO
muda a recompensa. `eligible_cards() -> Array[StringName]` é consulta sem RNG.

`collect(ticket_id: String) -> Dictionary` aceita somente ticket emitido, na ordem
da fila; chama `ProfileFacade.grant_run_ticket(controller, ticket_id)` internamente.
A UI nunca envia XP/item como payload. Confirma equipamento e XP no mesmo commit,
marca entrega antes de callbacks e concede carta/uma pendência de escolha uma vez.
Retry conserva request/seq/payload/RNG; resultado incerto congela e reconcilia.
Sucesso inclui `persistent`, `applied_reward`, `card_id`, `message`; replay inclui
`already_applied`, sem repetir publicação. `has_pending_transaction()` e
`has_uncollected()` protegem transições. Erros incluem `invalid_reward_event`,
`invalid_reward`, `invalid_reward_sequence`, `invalid_session`, `encounter_active`,
`offer_open`, `save_in_progress`, `result_uncertain` e erros persistentes originais.

Main emite o ticket no fim real do encontro, conserva pickup até confirmação e
usa F8 para retry/abrir escolhas. Somente o encontro2 é etapa demonstrativa. Ao
resolver/esgotar todas as escolhas, o botão Encerrar demonstração fica disponível;
não encerra automaticamente. Morte/fim descarta cartas/augments/pendências e cancela
ledger. Reinício conserva item/XP confirmados e fecha sessão abandonada, sem
reconstruir efeitos transitórios. Treino/fixtures sem fachada não gravam perfil.

## Apresentação e provas

`BuildPresentation.describe(controller) -> Dictionary` separa coleção permanente
(`equipment`) e cartas da run (`cards`, `inventory`), com `equipped`, `context`,
`stats`, `sources`, `inactive`, `skill_rules` e rótulos pt-BR. Equipamentos incluem
id/nome/descrição/slot/selected/allowed; cartas id/nome/descrição/free.
`compare(service, intent)` acrescenta mensagem pt-BR ao preview; `error_text(code)`
traduz os bloqueios. Valores e proveniência vêm do compositor; não há fórmula UI.
T4 implementará seleção, ícones, comparação visual e apresentação rica de conflitos.

Fixtures: `e06_inventory_fixture.gd`; testes `e06_inventory_resources_test.gd`,
`e06_inventory_test.gd`, `e06_rewards_test.gd`, `e06_migration_test.gd`.
Saves ficam explicitamente em `.godot/verification/e06_t2`, sem perfis pessoais.
Receitas reais de testes cobrem HP/SP, transformação de Fire Spear e exclusividade
cruzada; estrutura de catálogo é copiada antes de qualquer alteração da fixture.
R1 independente e integração F2 pendentes; dados/UI finais dependem desse gate.
