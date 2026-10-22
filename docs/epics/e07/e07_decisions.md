# E07 — decisões humanas antes dos consumidores

Atualização22/10/2026: **as decisões consumidas por F1–F6 foram aprovadas nos
chats executores e estão integradas**. A proposta arquitetural de18/10 é mantida
abaixo como histórico, incluindo alternativas não escolhidas; suas marcações
antigas de pendência não revogam os aceites posteriores deste quadro.

| Decisão | Aceite efetivo e limite | Registro prevalecente |
|---|---|---|
| D01 | Migração assistida com destinos e confirmação completos; gold legado zero. Não autoriza migrar save pessoal. | [F2](f2_dispatch.md) |
| D02 | Uma pendência/personagem e locks de lobby; alts livres. Estágios ausentes congelam ações locais; relógio global ativo continua; suspensão total congela tudo. Quest antecipada suspende a mesma expedição sem bônus. | [F2](f2_dispatch.md), [F3](f3_dispatch.md), [F5](f5_dispatch.md) |
| D03 | Ondas900s, trash normal/elite elegível, bosses/raros/memoráveis únicos; fatores0,70/0,60/0,50 por geração; EXP por abate. Gold de mob não criado. | [F5](f5_dispatch.md) |
| D04 | Última chegada/entrada;50%HP/25%SP; penalidade120s; tabela específica de cancelamento por identidade. | [F5](f5_dispatch.md), [tabela aprovada](f5_death_policy_proposal.md) |
| D05 | Regras espaciais e apresentação2,5D aprovadas, inclusive clique/marcador e oclusão. | [entrega F1](delivery/f1.md) |
| D06 | Saída5s e ameaça completa1x dano/0,5x cura, limiar estrito110%, provocar e identidade/replay conforme contrato. | [F5](f5_dispatch.md), [F6](f6_dispatch.md) |
| D07 | Amostra pequena de4 estágios ramificados, nível1 sem custo/chave, bônus100gold/300EXP Base/200EXP Job sem item. Expansão de área/densidade/taxas não é implícita. | [F5](f5_dispatch.md) |

Delta adicional aprovado: [troca ativa transacional](f5_build_delta_proposal.md),
fora de combate na mesma expedição, com perfil/build/mundo no mesmo commit;
locks de lobby/suspensão preservados. Não significa transferência entre alts.
[F1–F6 integradas](f1_f6_integration.md); [despacho F7](f7_dispatch.md).
Não perguntar novamente as aprovações acima. Escolhas novas continuam próprias.
Fonte aprovada: [PRODUCT_DIRECTION](../../PRODUCT_DIRECTION.md).
Contrato: [E07](../e07_contract.md). Resposta humana futura deve registrar data,
texto/escopo aprovado e revisão do contrato; silêncio não aprova defaults.

Não reabrir: bens por personagem sem transferência, unlock por perfil, conservação
da expedição/build/relógios, retorno entre estágios, limpeza total com memoráveis,
ondas globais pós-limpeza, bosses sem respawn, dois augments iniciais, bônus final
gold/EXP sem equipamento garantido e quest antecipada sem bônus por padrão.

## D01 — migração dos bens existentes

**Proposta:** migração assistida uma vez, com prévia por exemplar. Peça referenciada
por um único personagem é sugerida a ele; referências por vários alts e bens sem
referência exigem escolha explícita. Cartas encaixadas acompanham a peça; cartas
soltas recebem destino explícito. Todas as sugestões precisam de confirmação no
resumo antes de gravar. Não duplicar exemplares. Presets que apontem para bens
atribuídos a outro alt mostram a remoção da referência na prévia. Preservar todos
os IDs/metadados e recibos; nenhuma perda de save autorizada.

Alternativa: usuário escolhe explicitamente um único personagem para receber todo
o acervo legado, com relatório das referências removidas dos demais. É mais simples,
mas retira equipamento utilizável dos alts. Não inferir essa opção do personagem ativo.

Decisão necessária: política e tratamento de todos os grupos acima. Não é pedido
de atribuir itens reais agora: o pacote futuro monta mapa completo, validado e
revisável do save antes da confirmação de aplicação. Bloqueia F2 e migração real;
não bloqueia schema de fixtures novas ou F0/F1. Gold inicial legado não existe
como saldo canônico observado: proposta zero, sem compensação inventada.

## D02 — quantas expedições e o que se pode fazer no lobby

**Proposta inicial:** uma expedição pendente por personagem, em uma fase por vez;
outros personagens continuam livres para suas próprias expedições. Um personagem
com expedição suspensa pode consultar o lobby, mas não alterar build/equipamento,
gastar bens ou iniciar outra fase até concluir. Ganha-se conservação exata sem
duas cópias divergentes do personagem; perde-se flexibilidade entre visitas.

Alternativa: uma por personagem/fase, com regras explícitas de reconciliação de
build, consumos e bens; exige arquitetura adicional antes do código. Guardar um
mapa de expedições no schema não aprova essa multiplicidade.

Quest que encerra cedo: proposta retornar ao lobby como suspensão da mesma
expedição, objetivo marcado, sem bônus nem limpeza da mácula; continuar depois
até a saída final. Se a intenção for encerramento definitivo, será necessária
uma regra explícita para montagem/augments/mácula subsequentes. Nenhuma quest
com exceção de bônus/limpeza é proposta nesta amostra.

Também requer escolha: estágios sem jogador congelam suas ações locais enquanto
o relógio global ativo continua e registra ondas pendentes? Proposta sim, com
reposições registradas em dados. Alternativa é simulação lógica de todos os
estágios, mais cara; não fingir que descarregar Nodes define essa regra.
Bloqueia lifecycle de produção, F3/F5/F7; F0 só modela políticas obrigatórias.

## D03 — respawn e mácula

**Proposta inicial:** propriedade da expedição/mácula por personagem/fase; reduzir
somente recompensas de gerações repostas, desde a primeira reposição. Abates
iniciais de ramos ainda não visitados mantêm taxas originais. Contador por slot
de origem, incrementado na reposição efetiva. A conclusão encerra os contadores;
saída, morte, quest antecipada comum e troca de personagem não os limpam.

Proposta de elegibilidade: normais e elites explicitamente marcados como trash
reaparecem; raros, elites raros e memoráveis são únicos na amostra; bosses nunca.
O tier não decide sozinho: receita registra a política por slot. Extras de augment
de memorável nunca se repetem. O animal finito do Mestre conserva seu contrato
E06, sem loot/XP próprio nem bloqueio da limpeza; outras invocações precisam de
contrato antes de entrar na amostra.

Proposta numérica **para primeiro playtest**, não fórmula aprovada: intervalo de
onda 15 minutos ativos; para geração g≥1, EXP = base × 0,70^g, gold = base ×
0,60^g, probabilidades de equipamento/carta = base × 0,50^g; quantidades inteiras
arredondadas para baixo, sem piso positivo. g=0 usa tabela original. Não adiciona
gold de mob: fator gold só opera sobre fonte previamente autorizada. Não diminuir
qualidade/ilvl junto da chance. Conclusão usa bônus próprio, não esse fator.
Alternativa: curva global da fase que também atinja abates iniciais posteriores;
muda significativamente a exploração e precisa ser escolhida expressamente.

Segurança proposta: reservar zona de chegada sem população e adiar slot cuja
posição de origem está ocupada pelo jogador/colisão, mantendo no máximo uma
reposição pendente. Sem relocação arbitrária nem duplicação em ondas seguintes.
Raio da zona e telegraph devem ser medidos na amostra D07.
Bloqueia F5 e tabelas de produção; não impede provar deduplicação com política fixture.

I0 confirmou que mobs atuais concedem zero EXP e a demonstração paga EXP por
etapa. Proposta adicional a decidir: em E07, EXP por abate em tabela por origem,
retirando a EXP fixa de etapa; bônus final permanece separado. Alternativa: EXP
de primeira limpeza e zero nos abates/respawns. Não ativar curva sobre valor
inventado. Tabelas de origem ficam em D07 antes de produção. Garantias atuais de
item de raro/elite raro/boss permanecem nas fontes iniciais; se essas categorias
passarem a repor, contratar como a redução afeta a garantia antes de habilitá-las.

## D04 — morte, retorno e recursos

**Proposta inicial de playtest:** último portal de viagem entre estágios
efetivamente atravessado, no lado de chegada; porta local não altera âncora.
Antes da primeira viagem, entrada inicial. Zona segura visível do mapa, sem
teleporte silencioso para outro local. Penalidade de 120 segundos do restante
da onda, limitada a zero; zero produz uma onda e rearma 15 minutos. Morte antes
da primeira limpeza não inicia nem acumula dívida de onda. Mortes distintas
reaplicam a penalidade; retry do mesmo death_event_id não.

Proposta de recursos: reviver com 50% HP e 25% SP, remover controles e efeitos
temporários do jogador (favoráveis e desfavoráveis), manter cooldowns e augments.
Ações emitidas pelo morto são canceladas sem reembolso; estados de classe ligados
à vida têm reset explícito em tabela por kit. Inimigos/loot conservam seu estado.
Isso altera produto: **não implementar sem resposta**, inclusive os resets por kit.
Alternativa de recuperação total é mais permissiva; preservar todos os efeitos
gera riscos de morte imediata. Nenhuma perda de EXP/gold/item é proposta.
Bloqueia revive em F5 e adaptadores de morte; suspensão nunca usa essa regra.

## D05 — altura, combate e leitura visual

**Combate APROVADO expressamente em18/10/2026.** Após “F0 acabou. Pode começar F1”,
o usuário respondeu “Aprovar essas regras” ao conjunto apresentado: ataques de
chão se propagam pela superfície e conexões dentro do alcance; pisos sólidos
bloqueiam ataques entre andares; dash segue caminhos transitáveis; teleporte
mantém a travessia de obstáculos planos existente, exige destino legal e não
atravessa lajes sólidas. Altura conta para alcance, sem bônus de high ground,
como já aprovado na direção humana. Alcance direto euclidiano 3D, na mesma
unidade horizontal; movimento mede a rota transitável.

Implementação técnica: mundo lógico Vector3 com superfícies explícitas e
geometria comum. Explosão aérea usa volume próprio e oclusão declarada; inventariar
as exceções de todos os kits antes de alterar comportamento. Não impor LoS
universal ao teleporte e assim revogar sua exceção plana E06. Novas escolhas de
produto que o inventário revelar continuam exigindo resposta específica.

**Apresentação PENDENTE de resposta à pergunta enviada em18/10:** preservar
atores/sprites e câmera atuais na primeira amostra 2,5D; clique escolhe superfície
visível sob o ponteiro, mostra marcador e rejeita destino oculto/ambíguo; ponte e
chão inferior têm seleção distinta. Ocultação visual de teto para legibilidade
não remove colisão. Alternativa híbrida 3D precisa do gate low-poly e de aprovação
visual. A ausência de resposta não aprova renderer/projeção.

F1 pode iniciar a lógica espacial aprovada e testes independentes; integração
visual/clique multialtura e conclusão do pacote aguardam a parte visual. Ver
[despacho F1](f1_dispatch.md). F0 já integrado não depende dessa escolha.

## D06 — fronteira de ameaça

**Proposta de pacote separado:** ledger individual por inimigo e participação
em combate, adaptando somente habilidades existentes. Dano efetivo gera 1×
ameaça; cura efetiva gera 0,5× dividido entre inimigos engajados do grupo;
overheal não gera. Troca normal só acima de 110% do atual; empate conserva atual,
sem atual desempata por identidade estável. Provocar mantém duração/imunidades
atuais de cada habilidade e eleva ao maior valor da lista, com fixação temporária.
Redução ativa usa parâmetro de efeito, mas sem inventar botão/skill nova.
Proposta de saída: 5 segundos sem vínculo hostil de qualquer participante do grupo.

São valores e semânticas para discussão, não herdados do WoW. Pets/companheiros
hostis e cura precisam de atribuição de fonte explícita. Sem multiplayer ou grupo
de jogadores real nesta entrega; testes sintéticos provam várias fontes. UI não
deve prometer healer/tank cooperativos em produto offline. Bloqueia F6; nenhuma
implementação de consumível depende deste pacote neste E07. A escolha mínima
sobre vínculos/atraso de saída de combate destrava F5; pode ser respondida antes
das fórmulas completas de ameaça. F6 é opcional com dispatch próprio, sem impor
tabela completa como pré-requisito de geração ou campanha.

## D07 — amostra de campanha e requisitos

**Proposta inicial:** uma fase de prova com quatro estágios em grafo ramificado,
um ramo opcional com retorno, um destino final e um memorável em local temático
alcançável antes de limpar. Partes suficientes para duas montagens distintas,
rampa e ponte sobre outra rota. Fixtures de objetivo garantido demonstram o
contrato; quests de produção ficam fora até pacote próprio. Não fixa tamanho
final nem transforma quatro estágios em quota universal.

Proposta de entrada: fase inicial aberta, nível mínimo 1, sem chaves/sacrifícios.
Requisitos extras ficam representáveis mas indisponíveis; custo consumível não
é cobrado sem política aprovada. Proposta de bônus de teste: 100 gold, 300 EXP
Base, 200 EXP Job na conclusão, sem item; números serão avaliados no playtest.
Povoamento usa espécies existentes e origens explicitadas, sem copiar géis/lunáticos
como quota humana. Quantidades/área são aferidas pelo pacote de amostra e submetidas
antes da expansão; não prometer 60 FPS ou tamanho Ragnarok a partir de uma fixture.
Bloqueia conteúdo de produção F7/F8; geração puramente técnica não exige esse aceite.

## Ordem útil de resposta

D01 e D02 destravam propriedade/persistência; D05 destrava interação real com
altura. D03/D04 fecham o ciclo de risco; D07 fecha a primeira entrega jogável.
D06 pode ser decidido separadamente. O contrato F0 permite trabalho técnico
independente enquanto essas decisões são discutidas, após dispatch autorizado.
