# E06 — contrato de composição, efeitos e inventário

08/10/2026. Arquitetura documental v1 sobre
`51b5fabc8fcc7bb74f1b45479cdfe1aa090be4bc`; implementação não iniciada.
Índice: [e06.md](e06.md). Execução: [tarefas](e06_tasks.md).
Norma operacional: [WORKFLOW](../WORKFLOW.md).

## 1. Autoridade e decisões

E00 aprovado em `73f7a03`: [índice](../E00_CONTRACT.md),
[ADR](../ADR_E00_01_CHARACTER_PROGRESSION.md),
[dados/save](../E00_03_DATA_SAVE_CONTRACT.md),
[stats/procs](../E00_02_STATS_CONTRACT.md).
Sobreposições posteriores: [atributos](../STAT_THRESHOLDS_PLAN.md) e
[barras/passivas](../SENTINEL_ACTION_BARS_PLAN.md), além dos contratos das classes.
Não reintroduzir custo antigo de atributos, limite runtime 5+2 ou passivas por slot.
O schema atual é 2, catálogo 8, ruleset `stat_thresholds_v1`.

Decisões humanas recebidas diretamente neste chat em 08/10/2026:

| ID | Pergunta / decisão | Consequência |
|---|---|---|
| D1 | Cobertura: **dez identidades jogáveis, com opções próprias** das evoluções e do Geômetra | Catálogo e provas atendem dez; não habilitar kits futuros |
| D2 | Papel: **equipamentos e cartas também transformam habilidades** | As três origens usam a mesma composição tipada, conflitos e limites; não restringir cartas/equips a stats |
| D3 | Repetições: **uma cópia por tipo na run, sorteio sem repetição** | Carta tem propriedade única; um encaixe por equipamento; remoção/transferência fora do encontro |

Alternativas apresentadas: D1 apenas gerais/bases herdados; D2 equipamentos com
stats/cartas com passivos; D3 cópias acumuláveis por equipamento. Não foram escolhidas.
Não restam decisões humanas pendentes nesta versão. Tuning, nomes e distribuição
exata do catálogo serão trabalho de conteúdo dentro dos limites abaixo; mudança
de fantasia, duração de propriedade ou regras de combinação volta ao usuário.

Mantidos: coleção de equipamentos compartilhada e sem cópias; seleção por
personagem/preset; três slots; cartas/augments efêmeros; coleta no chão; até três
opções por escolha; numéricos até três stacks, transformações únicas; pausa fora
do encontro; snapshot por emissão; aquisição salva imediatamente; troca sem cura.
Sem crafting, lojas, raridades, monetização, retomada de combate, novos kits,
novos tipos de arma/auto ou novo aprendizado de skills por item.

## 2. Base auditada e delta real

Inspeção estática, não reprodução de testes nesta rodada:

| Fronteira | Existe no candidato | Delta E06 |
|---|---|---|
| Catálogo de augments | `scripts/core/run_state.gd` cria 5: vitality, keen_edge, battle_rhythm, extra_fire_spear, extra_ice_spear | Extrair catálogo imutável; identidade/skill/efeito tipados; novos pools; conservar os cinco IDs |
| Elegibilidade | `scripts/data/augment_definition.gd`: origem class_id e teto | Contexto completo com evolução pronta, biblioteca aprendida, handler disponível e conflitos |
| Oferta | RunState guarda stacks, contador e current_offer; até 3 sem reposição, confirmação revalida | IDs de escolha/oferta e replay; esgotamento consome uma pendência com aviso; manter oferta ao fechar/reabrir |
| Coleta | `scripts/world/reward_pickup.gd` e `scripts/main.gd`: cristal depois do encontro; coleta confirma XP antes de liberar escolha | Fila de coletas/pendências; lote idempotente incluindo item/carta; UI de múltiplas escolhas; esgotamento sem travar |
| Modificadores | `StatCalculator` aceita primary_flat/flat/increased; `BuildSnapshot` injeta passivas; RunState tem fontes hardcoded | Compositor de fontes únicas de item/carta/augment e regras de skills, sem segundo cálculo de dano/stats |
| Procs | `DamageRequest.emission_id/is_secondary`, `CombatMath` e `HealthState` bloqueiam secundários; ledgers específicos E05 | Contexto raiz/evento/profundidade, orçamento global16, claims antes de callbacks e adaptação das fronteiras existentes |
| Equipamento | ProfileCatalog aceita metadata por injeção; codec/fachada/CharacterState/snapshot já guardam coleção e equipped; menu tem seletores | Catálogo de produção com efeitos, inventário legível, transação entre encontros e composição no snapshot |
| Produção de itens | `ProfileCatalog.pilot()` não registra equipamento padrão; `ProfileRewardResolver.pilot_progression()` concede apenas XP | Starters/loot reais; versão de catálogo/migração conservadora; tabela de recompensa declarativa |
| Cartas | Codec explicitamente proíbe cards/card_sockets no save; nenhum CardDefinition/inventário/encaixe runtime | Catálogo, pool único da run, encaixes por item, UI, efeitos e descarte |
| Recursos | HealthState e PlayerActor preservam déficit via clamp na recalculação comum | Validar troca extrema ANTES do save; ledger de déficit involuntário para não perder dívida ao diminuir máximo |
| Fluxo/menu | Main termina piloto após2 encontros; update_preset rejeita run ativa | API restrita de equipamento entre encontros; preservar alocação/ranks; separar coleção persistente da mochila da run |

Não confundir o comentário “card” da barra de skills com carta de equipamento.
Não existe `ResourceState` no candidato; SP está em PlayerActor. Qualquer extração
de componente deve substituir seus escritores e provar os consumidores existentes.

### Identidades verificadas

Bases: `swordsman`, `mage`, `archer`. Evoluções com content_ready=true:
`defender`, `berserker`, `elementalist`, `spiritualist`, `sentinel`, `hunter`
e `mg_ar` (Geômetra). Total 10, em ProfileCatalog/ClassCatalog.

`sp_mg`, `mg_sp`, `sp_ar`, `ar_sp`, `ar_mg` têm identidade registrada, mas
kit indisponível. Sem pool exclusivo executável para elas; testes negativos
mantêm content_ready=false. Afinidade não concede biblioteca da outra origem.
Geômetra conserva origem Mage e ID mg_ar. “Caçadora” conserva hunter.

Isso não encerra E05: seu alvo histórico era15. Aprovação técnica Hunter e
publicação foram confirmadas no último turno do chat histórico, mas aceite
humano/balanceamento/merge continuam pendentes. E06 depende de E03/E04 e pode
prosseguir sobre este candidato sem fabricar um aceite de E05.

## 3. Donos e pipeline único

Catálogos guardam definições imutáveis. ProfileState guarda IDs de itens obtidos;
CharacterState guarda preferências válidas. BuildSnapshot guarda cópia por valor
da build inicial e versão; atualização de equipamento cria outra cópia. RunState
guarda augments, cartas, encaixes, escolhas, RNG e revisão transitória. Atores
guardam HP/SP/ações; ledger/proc são estado da run. Nenhum catálogo recebe stacks,
revisão de inventário, timer ou referência a Node.

Fluxo:
`catálogo + snapshot + estado da run → BuildEffectComposer → fontes/regras → StatCalculator + SkillEffectResolver → snapshot da emissão → CombatMath/HealthState → EffectProcLedger`.

**Novos nomes abaixo são APIs propostas, não componentes já existentes.**
A implementação publica assinaturas exatas e fixtures antes de liberar consumidores.
Permanecem as únicas autoridades StatCalculator, CombatMath, HealthState,
ProfileFacade/ProfileStore; não introduzir EventBus global nem outro writer de save.

| Contrato proposto | Entrada → saída / responsabilidade |
|---|---|
| BuildEffectCatalog | get/validate/copy por ID; EquipmentDefinition, CardDefinition, AugmentDefinition e EffectDefinition; registros conhecidos de handlers |
| BuildEffectComposer.compose(snapshot, run_effects, temporary_sources) | Resultado ok/error, fontes únicas, regras de skill e proveniência; puro, cópia profunda |
| SkillEffectResolver.preview/capture(skill_id, rank, composed_build) | Mesmos valores e geometria usados por tooltip, mira, custo/commit e emissão; preserva timing particular do kit |
| EffectProcLedger.claim_batch(context, candidates) | Ordenação, deduplicação e quotas antes de emitir efeitos; retorna claims aceitos com IDs |
| RunBuildService.preview_change(intent) / commit_change(intent) | Equipar/remover/encaixar/transferir; valida contexto, recursos, revisão e conflitos, publica só após confirmação necessária |
| ProfileFacade.equip_between_encounters(...) | Operação restrita à sessão/personagem, revisão e preferência de equipamentos; save antes de publicação runtime |
| RunRewardService.collect(ticket) | Mesmo evento/payload em retries; persistência primeiro, grant transitório uma vez; fila serializada |
| RunState.open_offer/confirm_offer/consume_empty_offer | IDs monotônicos da run, revisão e revalidação; oferta estável, sem RNG na renderização |
| BuildPresentation.describe/compare | DTOs pt-BR com atual/próximo/efeito efetivo/conflito e fontes; nenhuma fórmula na UI |

Operações retornam `ok, error_code, request_id` e revisões pertinentes. Falha
não muda parcialmente estado, RNG, saldo, pendência ou save. DTOs não expõem
coleções mutáveis internas. Serviços recebem o encontro canônico de Main e sessão
real; um bool enviado pela UI não autoriza equipar durante combate.
Contadores transitórios e tokens não vão ao save.

## 4. Definições e composição de transformações

EffectDefinition: ID estável, family_id, handler_id enumerado, tipo
(stat/skill_rule/proc), alvos de skill por IDs ou tags registradas, requisitos
de rank/identidade, parâmetros finitos tipados, unidade, limite, grupo de conflito,
stacking_mode, trigger e orçamento quando aplicável. Sem código em strings,
expressões arbitrárias ou Callable vindo de dados.

EquipmentDefinition: id, nome/descrição/ícone, slot, allowed_origins,
allowed_evolutions opcional, starter, lista de efeitos.
CardDefinition: id, textos/ícone, allowed_slots, restrições e lista de efeitos;
unicidade por ID no inventário da run.
AugmentDefinition: id, textos/ícone, restrições, max_stacks (1..3), lista de
efeitos e preview. Transformação discreta tem max_stacks=1; evolução numérica
explícita usa curva até 3. Campos legados dos5 augments recebem adaptador único.

Oferta de augment e sorteio de carta exigem origem correta, evolução legal/pronta
quando especificada, handler implementado e **ao menos um efeito útil**; uma
transformação de skill exige alvo aprendido em rank>0. Auto/intrínseco listado
pode ser alvo sem rank comprado. Não exigir skill na barra: biblioteca/ranks são
a autoridade. Geral de stats/auto continua elegível para barra vazia.

Aquisição de equipamento só exige ID conhecido no catálogo: coleção é compartilhada
e pode conter item de outra origem. Equipar valida posse, slot, identidade e conflito;
não aprende skill. Efeito de skill ainda não aprendida fica inativo, com motivo na
UI; efeitos úteis restantes funcionam. Respec não apaga item/preferência legal por
falta de rank. Pool de loot da etapa prioriza itens legais da identidade atual;
duplicata continua sem cópia/compensação. Essa separação evita confundir validade
persistente de item com utilidade transitória de uma oferta de augment/carta.

Composição:
1. Identificar fontes: equipamento por slot/item; carta por ID/item; augment por
   ID/stack; passiva pelo ID; buff temporário pela instância. Duplicata de source_id
   é erro, não bônus extra. Recalcular substitui fontes, nunca acumula cópias.
2. Primários efetivos e marcos, flat/increased e caps seguem StatCalculator.
   Percentuais de primários seguem proibidos. Não modificar cap por fora.
3. Regras de skill usam eixos permitidos: quantidade/espalhamento de projéteis,
   alcance/área/duração, custo/cooldown dentro dos limites canônicos, e efeitos
   secundários declarados. Primeira transformação em cada eixo exige handler e
   prova de mira/execução. Alterar elemento, targeting ou fluxo intrínseco exige
   extensão específica do contrato; não inferir de texto livre.
4. Escalares compatíveis: somar flats, somar increased e aplicar uma vez na ordem
   documentada por eixo; cap único final. Transformações exclusivas usam
   conflict_group compartilhado entre as três origens, sem prioridade oculta
   de equipamento sobre carta/augment ou de “último equipado”.
5. Dois efeitos exclusivos no mesmo grupo rejeitam **a mudança inteira**; oferta
   de augment filtra conflito. UI mostra origem conflitante e alternativa possível.
   Remover equipamento/carta conflitante permite outra escolha; augment já escolhido
   não pode ser vendido/removido. Não sobrescrever silenciosamente efeitos.
6. Ordem da lista, sequência de equipar e origem do efeito não mudam o resultado.
   Sem multiplicação irrestrita de projéteis ou procs: quantidades inteiras/caps
   declarados e orçamento de emissão antes de cobrar recursos.

A oferta aberta bloqueia mudanças de equipamento/cartas até ser resolvida,
mesmo se fechar sua janela; aviso explícito. Pendências ainda sem oferta permitem
troca. Evita invalidar a oferta para obter novo sorteio. Se a validação encontrar
catálogo/revisão inconsistente, falha informada sem reroll ou consumo.

Aplicação de novos stats/regras não altera projéteis, DoTs, campos ou ações já
capturados. Mira/preview usam exatamente o resultado que o commit revalida.
Não alterar contratos Hunter/Sentinel/Geômetra de snapshot, claim, CC ou recursos.
Transformação não ensina skills, eleva rank persistente ou troca origem.

## 5. Causalidade e orçamento de efeitos

Cumprir E00: root_event_id/event_id/profundidade/flags; dano secundário não produz
outro secundário; família trata cada alvo no máximo uma vez por raiz; até 16
aplicações secundárias por raiz, excedentes descartados, ordem determinística
por IDs. Não substituir esse limite por um ICD inventado por item.

- Ação paga/auto cria raiz. Projéteis múltiplos, perfurações e cópias conservam a
  mesma raiz; impactos têm event_id próprios. emission_id existente é preservado
  para os ledgers E05, com relação explícita para a raiz.
- Eventos candidatos de um impacto são ordenados por family_id, source_id e
  target_id; eventos de uma emissão têm IDs determinísticos. Ordem temporal de
  colisões permanece física. Uma aplicação/alvo custa1 do orçamento, inclusive
  absorvida ou alvo invalidado depois do claim. Sem reembolso após callback.
- Claim (root,family,target) e decremento acontecem antes de callbacks. Reentrada,
  listener duplicado, morte/remoção durante callback ou sinal atrasado não repetem.
  Fontes da mesma família compatíveis compõem magnitude antes de um único claim.
- Trigger de hit exige dano HP positivo canônico, fonte própria e elegibilidade;
  miss/zero/escudo integral não disparam. on_kill usa killed real, jamais procura
  HP em cadáver para reconstruir o evento. on_cast/encounter_end são tipos próprios,
  não dano falso. Todas as chances recebem RNG explícito da run.
- Filhos usam secondary=true, profundidade1, sem crítico/nova rolagem HIT e sem
  novos procs de dano/cura/controle. Evento secundário não vira primário ao copiar,
  reenviar ou atravessar outro handler. Custos de HP não são hits.
- Ações periódicas explicitamente contratadas têm evento/raiz por tick agendado
  e orçamento próprio, preservando a marca secundária/ancestralidade e snapshot.
  Isso não autoriza proc→novo timer→proc. Instalar DoT e ticks seguem o contrato
  existente: mesma fonte/dono/skill renova maior prazo sem somar DPS; até 4/alvo.
- Ledger da raiz vive enquanto houver projétil/efeito pendente, com referências
  limitadas pelos budgets do mundo; não expirar deduplicação por TTL antes de um
  impacto tardio. Saturação rejeita novos efeitos de modo determinístico.
  Pausa congela relógios; morte/fim de run cancela fila e solta referências.
- Quotas específicas de identidade continuam. Integrar gatilhos que concorram
  na mesma raiz ao orçamento comum; não criar um segundo teto 16 para cada
  equipamento/carta/augment. Efeitos intrínsecos já contratados, como cura
  Sede de Sangue em morte por DoT, mantêm exceção explícita e não geram novos danos.
  Identificar esses adaptadores no relatório T1; não apagar exceções por refatoração.

T1 deve produzir matriz de produtores/consumidores de DamageRequest e resultados,
com todos os pontos secundários das identidades disponíveis. Nenhuma alegação de
conformidade global se um caminho não preserva contexto/cotas. Testar raízes
combinando passive+augment+equipment+card, não só procs novos isolados.

## 6. Inventário, cartas, snapshot e durabilidade

Coleção é conjunto persistente de IDs compartilhados; duplicata de equipamento
não cria cópia, moeda ou reroll obrigatório. Restrições são por identidade/slot.
Dois alts podem selecionar o mesmo desbloqueio. Presets continuam2; trocar item
atualiza equipped e o preset selecionado atomicamente, conservando o outro preset,
action_slots24, ranks, XP e alocações.

RunCardInventory contém IDs únicos e `card_sockets[item_id] = card_id`;
um item equipado tem um encaixe; carta não ocupa dois itens.
Ao desequipar item, sua carta volta à mochila da run e o encaixe é removido.
Transferência entre itens é atômica, valida slot/restrição/conflito dos dois lados.
Remover carta é gratuito, fora do encontro, e passa pela mesma proteção de recursos.
Draw sem reposição exclui cartas já possuídas, inclusive encaixadas; pool vazio
produz aviso, sem travar ou conceder duplicata. Não apagar carta para renovar pool.
Início/encerramento de run cria/descarta inventário e encaixes; nada disso é save.

Troca voluntária:
1. Exigir ator vivo, encontro encerrado, sessão/personagem corretos, nenhuma
   gravação/resultado incerto nem oferta aberta, revisões runtime/persistente atuais.
2. Construir cópia candidata, conferir posse, todas as restrições e efeitos,
   gerar stats/regras e medir déficits reais de HP/SP. Sem mutar ator ou perfil.
3. Rejeitar se novo max_hp <= déficit HP, ou novo max_sp < déficit SP (E00.3).
   Exemplo: HP max100/atual70 → max80 dá50; max30 rejeita. SP max100/atual10
   → max80 rejeita, max90 dá0. Reequipe não devolve dívida descartada.
4. Equipamento: persistir preferência pela fachada em uma operação serializada;
   só após confirmação publicar snapshot/runtime. Falha mantém ambos anteriores;
   resultado incerto congela operação e usa recuperação existente para reler
   commit antes de prosseguir. Não gerar outro request_id/payload no retry.
5. Carta: transação somente runtime, mas mesma validação/revisão/atomicidade.
   Não usar save para persistir por acidente o resultado de preview.
6. Atualizar build_version/runtime_revision uma vez. Conservam déficits,
   cooldowns em curso, identidade/recursos e snapshots emitidos.

Mudança involuntária de máximo (buff expirando) usa ledger de déficit que pode
exceder novo máximo; cura/regen diminui dívida, dano/custo real aumenta dívida.
HP projetado zero segue o caminho terminal de morte uma vez. SP acima da dívida
volta disponível só após regen/cura explícita. Não usar clamp como fonte de verdade
para reconstituir dívida. T2 audita todos os escritores de HP/SP existentes.
Pausa/troca não inicia regen extra nem reinicia cooldown. Transição de fase pode
ter cura explícita prevista no piloto, separada da recomposição.

ProfileCatalog passa a derivar metadata de equipamento do mesmo catálogo de
BuildEffectCatalog, evitando IDs/restrições duplicados. Persistir novos IDs requer
nova catalog_version, escolhida sobre a base efetiva (8 na auditoria), com migração
aditiva explícita; schema 2 e ruleset stat_thresholds_v1 permanecem.
Versão concorrente exige reconciliar antes de implementar, não usar “9” cegamente.
Preservar todos os campos conhecidos/extensões, backups/pending, recibos, ranks,
origens e action_slots. Não reaplicar migração antiga de orçamento de atributos.

Novos personagens recebem starters declarados via create_character. Personagens
existentes podem receber apenas os starters de sua origem na migração, união
idempotente da coleção; preencher slot vazio só se definido como starter padrão,
sem substituir seleção válida ou normalizar/apagar legado desconhecido.
Migração tem tabela explícita de IDs e prova de revisão única/backup intacto.
Cartas/augments/causalidade jamais entram em ProfileState/ProfileCodec.

## 7. Coleta, ofertas e conexão com a campanha

Coleção de pickup usa ticket da run/evento, payload congelado ao gerar a recompensa
e sequência serializada de ProfileRewardResolver/ProfileFacade. A UI envia ID da
intenção, não valores livres de XP/item. Antes de confirmar disco, pickup permanece;
retry mantém item sorteado, seq, request_id e RNG. Persistência confirmada publica
item/XP; mesma coleta cria pendência/carta transitória uma única vez. Crash entre
save e grant transitório encerra run; não deve reconstituir cartas/augments no restart.

Preservar fluxo manual: fim real do encontro → pickup no chão → coleta →
pendência → abrir menu fora de encontro → pausar → confirmar → retomar.
Não abrir automaticamente por cronômetro/ausência de dano. F8/botão conforme
controles atuais; corrigir mensagens legadas que ainda dizem E. UI/overlay não
permite que clique de escolha dispare skill no mundo.

Escolhas possuem choice_id; oferta possui offer_id e revisão. Sorteio uniforme
sem reposição entre elegíveis, máximo3, menos quando faltar. Abrir/reabrir/renderizar
não consome RNG. Confirmar ID que não está na oferta, replay ou revisão velha falha.
Confirmar válido aplica um stack e consome uma pendência; se houver outras,
manter acesso para resolver próxima. Oferta vazia consome exatamente uma pendência
com aviso explícito; repetir não consome a seguinte usando o mesmo token.
Fim da fase/run espera fila resolvida ou esgotada, nunca softlock no pool vazio.

E07 continua dono da campanha de 3 fases/6 encontros/boss, XP e cadência final.
E06 fornece API de recompensa de etapa (um equipamento + uma carta por fase
normal) e prova de múltiplas pendências. Para integrar no piloto atual de 2 encontros,
o segundo fechamento funciona como única etapa de demonstração: equipamento/carta
são coletados e podem ser usados no intervalo antes do encerramento explícito.
Esse encerramento aguarda pendências; não iniciar nova fase/boss por E06.
No treino, usar catálogo/fixtures sem gravação; testes cobrem três chamadas de
etapa sem criar campanha real. Não antecipar valores de XP ou loot de E07.

## 8. Conteúdo e apresentação contratados

A hipótese histórica “12 gerais +8/base” não é compromisso. Manter alvo piloto
de 12 equipamentos (incluindo starters) e6 cartas como lote inicial de conteúdo;
contagem final de augments deriva da matriz de cobertura, não de preencher quota.
Alterar esses lotes por necessidade material deve ser registrado, sem reduzir a
cobertura humana D1. Não exigir arte nova fora do pipeline existente.

### Registro mínimo estável para a fronteira persistente

T2 não pode inventar IDs de migração antes de T3 decidir o conteúdo. Por isso,
esta arquitetura reserva os 12 IDs de equipamento abaixo; T2 cria metadata/arquivos
no catálogo único, e T3 preenche receitas/textos/ícones sem mudar IDs, slots ou
starters. São IDs técnicos, não nomes finais visíveis. T2 pode usar efeitos vazios
na fundação não publicada; R1 aprova o mecanismo, R2 exige conteúdo completo.
Nenhum candidato intermediário com catálogo incompleto vai ao playtest.

| ID | Slot / origem | Starter |
|---|---|---|
| starter_blade | weapon / swordsman | Sim |
| starter_staff | weapon / mage | Sim |
| starter_bow | weapon / archer | Sim |
| traveler_vest | armor / três origens | Sim |
| traveler_charm | accessory / três origens | Sim |
| riposte_blade | weapon / swordsman | Não |
| ember_staff | weapon / mage | Não |
| hunters_bow | weapon / archer | Não |
| warden_mail | armor / três origens | Não |
| channeler_robe | armor / três origens | Não |
| trailcoat | armor / três origens | Não |
| prismatic_charm | accessory / três origens | Não |

Evoluções herdam as restrições da origem; nenhuma dessas armas substitui o auto
ou o tipo de arma do kit. Starters: arma da origem + traveler_vest + traveler_charm.
Na migração de personagem existente, preencher apenas slots null do equipped e
dos presets com esses starters, conservando todas as seleções não nulas válidas;
união da coleção e revisão únicas. XP/ranks/alocações não mudam.

Reservar cartas echo_card, ember_card, frost_card, precision_card, bulwark_card,
trail_card. Cada uma pode ocupar weapon/armor/accessory, uma por item, e as receitas
definem o alvo útil exigido no sorteio conforme §4. Não são itens persistentes.
T3 escolhe tuning e textos dentro dos handlers aprovados; mudança material de
ID/restrição/quantidade de equipamento retorna a T2 com mapa de migração revisado,
antes de alterar catálogo. Augment é run-only e seu ID final entra no manifesto T3.

Matriz mínima de intenções para autoria de receitas em T3:

| Identidade | Duas direções a diferenciar (sobre kit existente) |
|---|---|
| swordsman | golpe/pressão de área e proteção/contra-ataque |
| mage | projéteis elementais e controle/áreas |
| archer | tiros de precisão e preparação de armadilhas |
| defender | guarda/resposta e controle territorial |
| berserker | pressão sustentada e mobilidade/execução |
| elementalist | sequência elemental e cobertura de áreas |
| spiritualist | ecos/recuperação e canalização/drenagem |
| sentinel | tiros preparados e controle com munição/Foco |
| hunter | preparação de mecanismos e exploração da abertura/mobilidade |
| mg_ar | paredes/interações e triângulos/Colapso |

Duas builds legais por identidade devem mudar uma decisão de combate observável,
com fontes/skills necessárias identificadas; diferença apenas de percentual não
comprova isso. Evoluções recebem ao menos duas opções exclusivas com efeitos úteis
em rotas diferentes. Herança de origem continua filtrada por skills aprendidas.
Cada uma das três origens (augment/equipamento/carta) deve conter transformação
funcional demonstrada; D2 não fica só no schema. Compartilhar handlers, não IDs de
identidade. As6 cartas podem atender famílias de skills entre várias identidades;
não precisam6 versões específicas por classe.

T3 entrega manifesto de IDs/curvas/ranks mínimos/handlers/caps/conflitos,
atual/próximo e duas builds por identidade. Tuning é explícito, com testes nos
limites e exemplos; não inventar habilidade ausente para atender uma receita.
Se precisar handler/eixo não contratado, parar só essa receita e pedir alteração
contratual; não esconder código em catálogo. Quantidade definitiva e balanceamento
ficam registrados como resultado mensurável, sem prometer diversão.

UI: coleção persistente/menu e mochila da run claramente distintas; equipamento
selecionado, cartas livres/encaixadas, conflitos e indisponibilidade visíveis.
Oferta mostra stacks/limite, efeito atual→próximo e resultado efetivo no build
(inclusive cap: “sem ganho adicional”); não oferecer opção inteiramente inútil.
Tooltip de skill/mira/HUD consome a mesma composição. Inventário mostra antes/depois
e por que troca foi rejeitada, sem pedir “aceite técnico” ao jogador.
Textos pt-BR; IDs/códigos internos não aparecem como fluxo de produto.

## 9. Aceite e fronteiras de revisão

T1/T2: fixtures puras, snapshot antes/depois, ordem de fontes, reentrância,
16/17 aplicações, família/alvo/raiz, miss/zero/letal/escudo, delay tardio e pausa;
todos os adaptadores críticos E05; troca HP/SP extrema, buffs/regen/custos, cartas,
alts/presets, revisão stale, replay, falhas de disco/pending/backup/schema futuro,
migração e isolamento. Mesmos números no preview e combate.

T3/T4: matrizes de elegibilidade para 10 disponíveis e5 bloqueadas; pool<3/vazio;
oferta estável e duplo clique; acumuladas e impedimento de transição; conflitos das
três origens; uma carta não duplica; recurso inacessível não aparece disponível;
duas builds legais/identidade; UI no renderer com escala e textos longos.

Integração: tools/verify.ps1 completo, combate real/deltas 30/60/144 nas interações
novas de tempo, captura gráfica de oferta/inventário/transformações e casos densos.
Reprodução independente de fronteiras antes dos consumidores e do candidato final
por tarefa temporária R; correções nas tarefas autoras. Publicação operacional após
aprovação; playtest humano e merge separados. Esta arquitetura não declara PASS
de runtime, FPS, balanceamento, aceite de E05 ou produto E06.
