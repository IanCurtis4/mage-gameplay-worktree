# E07 — população, portais, recompensas e ameaça

Arquitetura v1,18/10/2026. [Contrato](../../e07_contract.md),
[decisões](../e07_decisions.md). Policies de produção dependem de D03/D04/D06/D07.

## População em dados antes dos atores

MobDefinition descreve espécie; MobOccurrence já distingue occurrence_id,
mob_base_id, category_id e origin_id. MobCatalog/MobTierRules resolvem nível e
categoria. Reutilizar essas autoridades. E07 acrescenta slot persistente e geração:
`occurrence_id` é derivado de expedition/stage/slot/generation, validado pelas
restrições existentes de IdentityIds. Um spawn não ganha ID pela ordem de Nodes.

PopulationRecipe fixa revisões, bioma/origem por estágio, pesos/concentrações,
densidade e orçamento. Compartilhar espécies entre vizinhos do mesmo bioma;
gradiente testado por lotes de seeds e distribuição espacial, não igualdade
exata por mapa. Origem de campanha fixa nível/loot; não usar nível do jogador.
Separar quantidade total, custo de simulação ativa e limite visual.

Resolver slots após montagem e antes de publicar expedição. Todo slot obrigatório
tem rota e espaço para seu raio. Memorável exige thematic_site compatível, com
acesso local aberto; não substituí-lo por chão aleatório quando faltar local.
`blocks_clear`, `respawn_policy_id` e `reward_policy_id` são explícitos e validados.
Boss não pode ter policy de respawn habilitada. Spawns administrativos têm origem
de teste e nunca entram no conjunto obrigatório/recompensas de produção.

Companheiro do Mestre mantém contrato finito E06, sem recursão/loot/XP próprio;
não impede limpeza. Dono morto resolve seu companheiro conforme regra existente.
Outras invocações precisam declarar se substituem slot, bloqueiam limpeza,
recompensam e persistem após morte do dono. Espécie sem regra falha validação.

## Estado e ondas

LifeState por slot: alive, dead, respawn_pending; generation inicia 0. Registro
de morte exige geração atual e claim causal ainda não usado. Inimigo sem Node
continua alive no estado. `cleared_once` consulta todos os bloqueadores válidos,
não apenas atores próximos. Nenhuma onda repõe estágio nunca limpo.

ClockState: started, remaining, interval_policy_revision, wave_index. Primeira
limpeza arma uma vez; delta ativo reduz remaining. Vencimento incrementa wave_index
e considera slots mortos elegíveis. Vivo não muda; pendente já existente não
ganha outra cópia. Reposição efetiva incrementa generation e registra wave/source.
Enquanto chegada bloqueada, manter uma intenção; quando segura, cumprir uma vez.
Não contar intenção como inimigo morto novo nem conceder nada por spawn.

Delta grande pode cruzar intervalos: processar fronteiras cronologicamente com
mesma semântica da execução parcelada; após primeira reposição viva, ondas
seguintes não empilham cópias. Não usar horário do sistema. Penalidade de morte
aplica transição própria e no máximo uma onda por evento, conforme proposta D04.
Timers congelam na pausa/suspensão; D02 decide clocks locais de estágio ausente.

## Portais e entradas

PortalDefinition: portal_id, kind(local/travel/final), source/destination
WorldPoint, graph_edge_id e condição. Local não pode depender da limpeza que
inclui seu próprio destino. Travel valida sessão, origem, alcance, estado,
destino e pendências de gravação. Token de portal contém revisão; UI antiga não
força viagem. Âncora de chegada recebe zona segura contratada; retorno não cura.

Primeira visita registra visited e claims de augment no mesmo candidato da
viagem. Primeiro estágio tem origens entry_run e entry_stage; seguintes apenas
entry_stage. Ao retomar/responder duas vezes ao portal, origens já registradas
não agendam escolhas. Oferta pendente não é descartada ao viajar; comportamento
da UI não concede uma nova. Escolha só fora de combate com token válido.

Portal de avanço abre na limpeza inicial e permanece aberto com trash reposto.
Retorno usa aresta percorrida/permitida do grafo e conserva estado. Chegada e
última âncora mudam apenas após commit; falha de construção de cena não muda o
destino durável sem recuperação consistente. Testar ida/volta por múltiplos ramos.

## Rewards e término

RunRewardService hoje registra atores/ocorrências em memória e valida coleta
fora de encounter_active; E07 precisa conectar esse comportamento ao combate
local/expedição, sem liberar grants arbitrários. Preservar MobLootResolver e
autoridade de stats. RewardSource determina ticket antes da apresentação.
EXP/gold/chance de item/carta usam fatores separados da policy D03. Ilvl/qualidade
não são reduzidos por outra fórmula paralela. Quantidade/XP inteira tem arredondamento
contratado; chance é limitada a [0,1]. Recurso desconhecido não recebe taxa default.

I0 confirmou EXP zero nos tickets de mob atuais e EXP fixa por etapa. D03 deve
escolher a fonte E07 antes de habilitar EXP por abate; não somar etapa e mob por
herança. FLOORS de MobLootResolver garante item de raro/elite raro/boss; não basta
multiplicar equipment_chance para reduzir essas garantias. A proposta inicial
não repõe essas categorias. Ampliar elegibilidade exige política explícita de
garantia e teste de extremos, preservando o comportamento de geração inicial.

CompletionPolicy exige destino/condição de fase; gerar bônus gold/EXP Base/Job
uma vez e unlocks no mesmo commit. Sem item garantido nem pagamento adicional
por cada ramo. Quest outcome distinto, sem exceção implícita de bônus/mácula.
Nenhuma loja, gold de mob, pilha misc ou consumível é criada por essa integração.

## Ameaça: fronteira separada

EnemyActor possui aggro/leash/taunt dirigido ao player, não lista individual
completa. Não chamar essa API de ThreatService pronta. Nova fronteira tem:
ThreatState por inimigo (valores por participante, alvo atual, fixação/taunt,
revision), CombatParticipation (vínculos hostis/grupo e timer de saída) e DTO de UI.
Alvo atual não é sinônimo de participante; reduzir ameaça não remove vínculo.

ThreatService.observe recebe evento de dano/cura/suporte aplicado, identificador
causal, valor efetivo, fonte/owner e policy; claim impede geração dupla por replay.
Observe não decide dano nem recalcula heal. Aplicação secundária/DoT segue sua
policy de geração e não duplica crédito por callbacks. Invisibilidade/LoS e
leash usam WorldGeometry. Provocar revalida alcance/LoS/imunidade conforme skill;
troca forçada e expiração são distintas do limiar normal. Leash não cura por
inferência; morte remove elegibilidade e preserva recibos.

D06 fecha valores e comportamento. Testes sintéticos com jogador, pet e curador
comprovam lista/participação; não implementam rede. Não adicionar skills de redução
para preencher API: usar efeito já contratado ou fixture. UI lê alvo/limiar reais,
inclusive taunt/imunidade, e não estima ameaça pelo dano mostrado.

## Provas de domínio

Testar raridade permitida da espécie, origens fixas, slots inacessíveis,
memorável/local circular, spawn admin, summon, morte duplicada e geração antiga.
Ondas: dois mapas limpos e um não limpo, vivos e mortos misturados, boss morto,
viagem, suspensão e morte exatamente no vencimento. Provar nenhuma duplicação,
nenhum fechamento de portal, nenhuma escolha extra e redução congelada em retry.
Separar fixture com rates extremos da tabela de produção. Gradiente exige lote
com intervalo estatístico declarado; uma seed favorável não basta.
