# Direção de produto — campanha, exploração e economia

Decisões humanas de 17/10/2026, atualizadas pelas rodadas de respostas de 18/10/2026.
Direção aprovada para documentação. Abertura de E07 posteriormente autorizada em
[registro próprio](epics/e07_launch_queue.md), com contratos antes de consumidores;
economia, quests completas e multiplayer não são liberados por inferência.
Produto existente: [MVP](MVP.md). Fluxo: [WORKFLOW](WORKFLOW.md).
As decisões de 18/10 substituem as formulações incompatíveis anteriores.
Propostas do assistente abaixo são pendências, não aprovações.

## Campanha, fases e ramificações

**31/10/2026:** as decisões de fase em
[f10_phase_architecture](map_editor/contracts/f10_phase_architecture.md)
substituem neste documento: desbloqueios por perfil (agora por personagem),
limpeza total para abrir portais (agora só na primeira jogada de cada fase),
término antecipado sem bônus (agora bônus proporcional ao que foi feito) e a
referência de tamanho (agora pelo menos metade da área dos campos do RO).

Lobby → selecionar fase desbloqueada → explorar e limpar estágio → escolher
portal → próximo estágio → conclusão e retorno ao lobby.

**Fase** é a coleção de mapas/estágios selecionada no lobby; **estágio** é uma
etapa percorrida da fase; **mapa** é seu espaço explorável; **parte** é um módulo
usado pelo gerador. A nomenclatura não renomeia APIs existentes.

Campanha desbloqueia fases repetíveis, com desbloqueios por perfil. Toda fase
exige nível mínimo; algumas também exigem quest, attunement, chave ou sacrifício
de itens. Ainda definir se os requisitos adicionais são permanentes ou cobrados
por entrada e como se aplicam aos alts.

Cada run mantém a temática, variando layouts e quests/encontros. Caminho não
necessariamente linear: um estágio pode ter um ou mais portais, escolhidos pelo
jogador, que mantêm ou mudam o bioma. **Retorno a estágios anteriores é permitido**
para exploração; não exige visitar todos os ramos. Acessos de miniboss/tesouros
escondidos são menores e visualmente distintos de portais de avanço. Separar
acesso local, viagem entre estágios e saída final. Fases têm destinos definidos;
caminhos podem estender
significativamente a run, com ramos dentro de ramos, becos sem saída e múltiplos
objetivos numa mesma run. Boss ao fim de um ramo e tesouro em outro são exemplos
de destinos, não quota de conteúdo. Saídas principais/alternativas/secretas são
referência de estrutura, não cópia literal de Super Mario World.

Algumas quests de campanha podem encerrar a run ao concluir o objetivo, antes
do destino final convencional. **Por padrão, isso não concede bônus de conclusão
da fase.** Pode haver exceção específica se a quest gerar um desafio que justifique
esse término; nenhuma quest concreta recebeu tal exceção ainda. Contrato deve
distinguir objetivo concluído, conclusão da fase e encerramento antecipado.
Não assumir que baú garante equipamento por ser destino final, nem conceder
o bônus inteiro por cada objetivo intermediário. Retorno preserva estado dos
mapas, mortes e recompensas, respeitando reposições pelo relógio da fase; não
recria um mapa como novo nem reconcede escolhas de entrada.

**Portais abrem quando todos os inimigos forem derrotados.** Isso substitui a
proposta anterior de objetivo localizado e a orientação de não exigir limpeza.
Tesouros, unlockables e objetivos de quest não são requisitos adicionais para
abrir portais. Fechar contabilização de população, respawn, invocações e encontros
antes do consumidor; não mudar silenciosamente o significado de todos.
Inimigo memorável presente também bloqueia o portal até ser derrotado.
Spawns administrativos seguem sem crédito de produção.

Quest ativa destinada à fase deve ter seu objetivo gerado ou indicar o caminho
para onde ele aparecerá; o jogador decide segui-lo. Geração não pode sortear a
run inteira sem possibilidade do objetivo e chamar isso de garantia. Antes do
código, fechar captura de quests na entrada, conflitos entre objetivos, ramos
mutuamente exclusivos e indicação dos destinos dos portais.

## Mapas modulares e elevação

Mapas grandes e labirínticos são montados algoritmicamente de partes conectáveis,
com entradas/saídas específicas. Autoria define conectores, bioma, rotas e
restrições; montagem combina. Sorteio de spawns no mesmo retângulo não basta.

Referência humana de tamanho: um pouco abaixo de `pay_fild01`, `prt_fild08` e
`moc_fild01`, como experiência, sem conversão aprovada em pixels/área/minutos.
Futuramente distinguir mapas abertos de dungeons menores, mais fechadas/densas,
com mobs próprios e mais desafiadores. Não copiar assets/layouts.

Cenários incluem natureza, construções e marcos, além de texturas/paredes.
Inimigos memoráveis aparecem em lugares temáticos memoráveis, como santuário
ou fundo de gruta. Reservar local compatível na montagem; não sortear o inimigo
em qualquer chão disponível. A gruta pode ter acesso por portal, cujo papel
local deve ser distinguido de portal de avanço: não exigir derrotar um inimigo
atrás de passagem fechada pela própria limpeza. Ambientação 3D low-poly inspirada
no Rag tem [gate separado](gates/low_poly_environments.md), sem implementação agora.

Elevação continua afetando rotas, rampas, pontes e acesso entre alturas. A decisão
de 18/10 exclui bônus/penalidades próprios de high/low ground; não revoga acesso
funcional. Desnível conta para distância de alcance. Linha de visão segue a
referência de experiência do WoW, que não especifica toda a geometria do RagRPG.

Contrato deve fechar superfícies/níveis, colisão/oclusão, distância com altura,
clique, navegação, projéteis, áreas, corpo a corpo, dash/teleporte e AI. Visual,
colisão e validação de ataque devem concordar. Não inferir tiro através de ponte,
piso ou parede pela projeção 2D. Exceções de habilidades precisam ser explícitas.

Critérios de entrega a concretizar:

- Seed, versão de receita/partes e entradas da geração (incluindo quests)
  reproduzem montagem e população; identificar alterações dessas entradas.
- Entrada segura, conectores transitáveis para os raios dos atores e caminho
  até saída, inimigos contabilizados e objetivos obrigatórios.
- Caminho testemunha, seeds adversas e falhas limitadas; sem retry infinito
  ou teleporte silencioso para mascarar regiões desconectadas.
- Travessia real, seleção de superfície, sobreposição visual e combate corretos.
- Área total, população e orçamento ativo são distintos; medir carregamento e
  desempenho antes de prometer escala. Exemplos não são atores simultâneos.

Não há algoritmo, dimensão ou duração final aprovados. Prova inicial pequena
deve exercitar conexão, altura e ramificação reais.

## Populações, respawn e recuperação

Mapas vizinhos do mesmo bioma compartilham espécies com picos/concentrações que
mudam gradualmente; outro bioma pode romper a distribuição. Exemplo humano:
100 géis/50 lunáticos → 60 géis/80 lunáticos, ilustrativo, sem quota/nome final.
Avaliar distribuições em múltiplas seeds, não proporções idênticas em cada run.

Mapas avançados têm inimigos temáticos mais fortes por origem de campanha, sem
escala automática com o jogador. Espécie, ocorrência, nível/origem, densidade e
comportamento são eixos distintos. Escala do vendedor não altera mobs.

Respawn só faz sentido após período longo. Abates subsequentes de mobs respawnados
têm rendimentos decrescentes em todas as recompensas aplicáveis: EXP, gold,
probabilidades de drop e demais ganhos. Taxas podem diferir por recompensa e
serão balanceadas; não fixar um multiplicador universal. **Somente concluir a
fase restaura o rendimento**, substituindo a decisão anterior de reset por mera
nova run. É permitido entrar, procurar drop específico e sair, preservando ganhos;
a fase permanece “maculada” até ser concluída. **Conservar a mesma expedição até
concluí-la**, incluindo montagem/seed, progresso de mortes, portais abertos,
objetivos, augments e recompensas confirmadas. Sair/reentrar não gera outro layout nem
rerrola encontros. Reposição de inimigos segue as regras abaixo. Não bloquear
entrada nem retirar loot já ganho. Não há estoque finito de loot table.

Conclusão permite encerrar essa expedição e iniciar outra montagem com rendimento
restaurado. Contrato deve identificar fontes/ondas dentro da expedição preservada
e definir quando a redução começa e se afeta toda a fase ou apenas recompensas
repetidas; não aplicar redução indiscriminada antes dessa decisão. Escopo por
personagem/fase é proposta coerente com posses individuais, ainda a confirmar.
Encerramento antecipado por quest não é conclusão automaticamente: definir se
alguma exceção de quest também limpa a mácula, além de conceder bônus.

Esclarecimento humano: respawn somente após limpeza completa do estágio, em
massa, com portais já abertos. Nunca repor população antes da primeira limpeza;
respawn não fecha portais nem revoga limpeza já registrada. **Timer de respawn
pertence à fase, não a cada estágio.** Viajar entre mapas não reinicia esse relógio.
Primeiro estágio limpo inicia o relógio. A cada intervalo longo, uma onda global
repõe os inimigos elegíveis mortos nos estágios já limpos, sem acumular novas
cópias dos que ainda estejam vivos. Estágios nunca limpos ficam fora da onda.
**Bosses não respawnam na mesma expedição; trash retorna com o tempo.** Esse é o
modelo inicial aprovado. Respawn individual por inimigo é possibilidade futura,
sem implementação ou substituição do relógio global autorizadas agora.

Expedição suspensa fica congelada, inclusive relógios: não acumula respawns por
tempo fora dela. Morte tem penalidade explícita sobre o tempo de respawn, conforme
seção de continuidade. Contratar intervalo, mapas descarregados, segurança de spawn
em mapa ocupado e categorias de inimigo elegíveis. Memorável/raro/elite não é
automaticamente boss: definir explicitamente quais reaparecem sem duplicar
recompensas únicas. Nenhuma reposição cria um novo boss derrotado.
Respawn não é nova entrada de estágio e não reconcede bônus de conclusão.
Memoráveis contam na limpeza; tratamento de invocações ainda exige contrato.
Definir contador de reincidência (exemplar/origem/onda), piso/curvas e recompensa
de augment em respawn antes de implementar rendimentos decrescentes.

Regen comum fora de combate deve ser fraca; passivas de classe, como de magos e
espadachins, podem melhorar recuperação. Escolhas desejadas: parar/sentar para
recuperar, usar poção gradual (mais recuperação total, mais cara, ao longo do
tempo) ou avançar com recursos incompletos. Sentar, interrupção e taxas exigem
contrato. Healers ajudam muito, especialmente com tank, mas não são imprescindíveis.
Isto não implementa multiplayer ou novas passivas.

## Combate e consumíveis

Saída de combate: ausência de aggro no jogador por X segundos; X ainda aberto.
Referência humana: aggro/combate do WoW, previsível, mapeável e controlável.
Confirmado: healers consideram envolvimento/aggro do grupo e potencial de serem
atacados; tank assumir o alvo não tira os aliados participantes do combate.
Separar alvo atual, ameaça e estado de combate. Isso não aprova um único valor
numérico compartilhado de ameaça para todos os membros.

Modelo de ameaça aprovado:

- Lista própria por inimigo, com valores individuais por participante; estado
  de combate considera participação do grupo, não soma única de ameaça.
- Habilidades podem gerar ameaça diferente do dano; ferramentas de aumento
  e redução ativa permitem controle deliberado de alvo.
- Troca de alvo exige vantagem suficiente, evitando alternância por diferença
  mínima; limiar e regra de empate ainda serão contratados.
- Provocar fornece controle imediato/previsível; reduzir ameaça não equivale
  automaticamente a sair de combate.
- UI comunica alvo atual e quem está próximo de assumir o alvo.

Definir fórmulas, habilidades concretas, cura/suporte, dano periódico, pets,
alcance, LoS, leash, morte, entrada/saída de grupo e reset antes dos consumidores.
UI usa a mesma autoridade de ameaça. Aprovação do modelo não implementa kits ou
multiplayer nem fixa percentuais, duração de provocar ou X segundos fora da luta.

HP e SP têm uso separado. Após usar poção, reutilização da categoria exige
**ter saído daquele combate E ter terminado o CD longo**. Sair cedo não zera CD.
Não renovar acesso por menu, troca, portal ou reconstrução da UI. Morte/fim de
run, relógio/pausa e reentrada precisam de contrato específico.

| Situação após uso | Reutilização da categoria |
|---|---|
| CD terminou, mas não saiu daquele combate | Não |
| Saiu do combate, mas CD não terminou | Não |
| Saiu do combate e CD terminou | Sim, se estoque e demais condições forem válidos |

Intenção futura: instantâneas/graduais, buffs fortes curtos, elixires fracos
longos e apetrechos com efeitos distintos. Drops de consumíveis devem combinar
com a temática do mob. Profissões são possibilidade, não sistema aprovado.
Variantes HP/SP, uso em combate, interrupção, buffs, categorias e produção passam
pelo [gate separado de consumíveis e profissões](gates/consumables_professions.md).
Não usar nomes diferentes para contornar o bloqueio da categoria. Consumo/efeito
precisam de transação coerente, sem aplicação dupla por retry. Durações, receitas
e tabelas de drops ainda não foram aprovadas.

## Gold, loot e vendedores

Drops são a principal fonte de equipamentos. Vendedores de lobby oferecem
equipamentos/consumíveis básicos, acompanhando avanço/força do jogador para não
ficarem defasados. Podem oferecer estoque limitado de uma ou outra peça rara
avançada conforme unlocks/quests. **Não vendem peças de conjunto, épicas ou
lendárias.** Sem reparo ou taxas/sistemas artificiais criados como gold sinks.

Indicador de avanço combina nível Base, Job, fases desbloqueadas e quests de
campanha concluídas. Pesos/faixas e o significado de Job na regra serão fechados
no contrato; não substituir a mistura por equipamento vestido. Desbloqueios do
perfil abrem catálogo, enquanto o personagem mantém requisitos próprios de uso.
Quantidades, reposição, preços e recompra permanecem abertos. Compartilhar um
unlock não concede automaticamente a todos recompensa material da quest.

Conclusão de fase concede bônus de gold e EXP, **sem drops garantidos por
conclusão**. Equipamentos garantidos podem vir de quests. Loot próprio de mobs
continua distinto do bônus; não converter chefe final em garantia de item da
fase. Valores e aplicação da EXP a Base/Job precisam de contrato.

Posses adquiridas e confirmadas permanecem na morte/saída/conclusão. Augments
permanecem vinculados à expedição, inclusive entre visitas e após morte, mas
não viram posses permanentes nem passam à próxima expedição. Consumíveis gastos
não retornam por sair, morrer ou voltar. Gold
vem ao menos de vendas e bônus de conclusão; gold direto de mobs/outras fontes
não foi decidido.

**Itens e gold pertencem ao personagem; unlocks pertencem ao perfil.** Isso
inclui equipamentos, cartas, consumíveis e misc. Substitui a direção anterior
de inventário compartilhado do E06, ainda presente no runtime atual. **Sem
transferências entre personagens no escopo atual**: cada personagem conquista
seus próprios recursos, sem banco/carteira compartilhados. Progresso/recompensa
de quest e elegibilidade de alts também
precisam distinguir conclusão compartilhada, nível e bens individuais.

Antes de código, contratar migração dos exemplares compartilhados existentes:
destinação de cada ID, peças equipadas/referenciadas por alts, cartas encaixadas,
contêineres, recibos e recuperação. Não duplicar para todos, apagar ou atribuir
silenciosamente ao personagem ativo. O save pessoal permanece inalterado até
pacote autorizado e política de migração aprovada. Armazenamento físico no arquivo
de perfil pode continuar; propriedade lógica passa a ser do personagem.

Compras/vendas usam autoridades atuais de perfil/inventário, um writer, validação
de quantidade/saldo, intenção estável e gravação atômica de item+gold. Retry ou
gravação incerta não rerrolam estoque nem duplicam transações. UI não calcula
preço próprio; migrações preservam posses.

## Inventário, quests e cartas

Inicialmente sem peso, desgaste/dano de equipamentos, limite de bagspace ou carga.
Pilhas de itens empilháveis não têm limite de gameplay; representação deve evitar
overflow sem inventar limite de bag. Equipamentos nunca empilham, mesmo com mesmo
nome, preservando metadados, slots/cartas e exemplar. Durabilidade não autorizada.

UX deve manter inventário legível, permitir quebrar pilhas e transferir entre
contêineres do mesmo personagem. Tipos desses contêineres ainda exigem definição;
isso não libera transferências entre personagens, comércio ou banco compartilhado.
Itens de quest não são
vendáveis. Classificar misc comum com uso em quest versus item protegido.

Confirmado: venda de equipamento com cartas **ainda encaixadas** mostra aviso
antes da confirmação. Se confirmar, cartas vão embora junto com o equipamento;
não são devolvidas automaticamente. Cancelar permite ir ao NPC de desencaixe
do lobby para preservá-las. Venda remove peça e cartas vinculadas na mesma
transação, sem órfãos/duplicação. Preço/risco de desencaixe, valor das cartas na
venda e recuperação por recompra ainda não foram definidos.

## Augments, pausa e continuidade

Um augment no início da run e um no início de cada estágio. Esclarecimento humano:
**dois augments no primeiro estágio**, um por cada origem; um nos seguintes.
Cada concessão ocorre uma vez pela primeira entrada naquele estágio da run;
voltar a estágio visitado não concede outro augment. Sem repetição por respawn,
retry ou reabertura de UI. Não conceder também no fim por herança do piloto.

Augments adicionais podem vir de inimigos memoráveis em quests específicas ou
monstros muito fortes para o mapa, como raros/elite raros que nem sempre aparecem.
Não tornar todo raro fonte garantida. Quantidade, limites, elegibilidade e
proteção contra farm por respawn exigem contrato. Concessão não significa abrir
escolha durante combate.

**A expedição é conservada como estado congelado em todos os sentidos.** Augments
escolhidos, stacks e pendências pertencem a ela e continuam entre visitas, sem
rerrolar ofertas ou reaplicar ganhos. Ao suspendê-la, estado e relógios ficam
congelados; ausência do jogador não avança combate, recargas ou respawn. Retomar
preserva o estado, sem resetar recursos/efeitos como atalho de recuperação.
Augments terminam com a expedição e não são progressão permanente do personagem.

Isso atualiza a direção anterior que mantinha a conservação exata em aberto.
Contrato técnico ainda deve especificar captura/restauração de atores, ações em
curso, recursos, relógios, RNG e recompensas. Implementação não autorizada aqui.
Arquitetura de salas/host/instância compartilhada continua para multiplayer;
não supor congelamento de mundo para outros jogadores ativos em uma sala futura.
Também fechar expedições simultâneas por personagem/fase e uso de personagem no
lobby sem deixar o estado suspenso duplicar consumo, equipamentos ou recompensas.

**Morte retorna o jogador ao último portal visitado e aplica penalidade sobre o
tempo de respawn dos inimigos.** Não encerra a expedição, não remove augments,
não limpa mácula e não desfaz mortes/loot confirmados. Objetivo humano é penalidade
moderada que renove o risco. Entrada para quem ainda não visitou portal, quais
portais qualificam, segurança do retorno, HP/SP, efeitos e recargas ao reviver
precisam de contrato; não inventar perda de EXP/gold/itens ou desgaste.

Penalidade confirmada: **reduzir o tempo restante até a próxima onda global de
respawn**, adiantando sua ocorrência. Se atingir zero, ocorre a reposição dos
inimigos elegíveis, sem duplicar vivos. Valor/fórmula da redução ficam para
balanceamento; tratamento de mortes repetidas e de morte antes da primeira
limpeza ainda precisam de contrato.
Preservar bosses derrotados e proibição de repor estágio nunca limpo. Nenhuma
morte/revisita concede novamente augments de entrada ou bônus de conclusão.

## Pendências prioritárias e sequência

Antes de consumidores: migração de bens por personagem; granularidade/persistência
da mácula e exceções de quest; elegibilidade de respawn; cálculo da penalidade de
morte e regras de retorno/recursos; captura/restauração do estado congelado;
números/habilidades
do contrato de ameaça e invocações; faixas do vendedor.
Sem transferências, retorno permitido, restauração apenas por conclusão e modelo
de ameaça já aprovados. Quest que encerra cedo não dá bônus por padrão.
Conservar expedição até conclusão e ondas globais iniciadas pela primeira limpeza
também aprovados; bosses não reaparecem nessa expedição, trash elegível sim.
Augments e relógios conservados no estado congelado; morte retorna ao último
portal e penaliza tempo de respawn, sem encerrar a expedição.
Respawn pós-limpeza, dois augments iniciais, memoráveis obrigatórios e venda
confirmada com perda das cartas já foram decididos. Balanceamento vem depois.

Planejamento: grafo/superfícies/objetivos → montagem navegável → populações →
portais/augments/conclusão. Economia tem trilha própria. Consumíveis avançados e
profissões e cenários low-poly passam por gates separados. Sem épico ou dispatch.
Exemplares/cartas permanentes e 14 slots continuam; compartilhamento de bens
do E06 foi substituído como direção futura por propriedade por personagem.
Piloto permanece executável, mas não define a campanha final.

## Referências de experiência e limites

WoW é referência solicitada, não contrato executável importado. A discussão
oficial de [ameaça](https://worldofwarcraft.blizzard.com/en-us/news/3300854/dev-watercooler-threat-level-midnight)
trata de controle de alvo por tanks; [correções de linha de visão](https://worldofwarcraft.blizzard.com/en-us/news/23973739)
mostram validações ligadas a habilidades. Essas fontes não fixam X segundos,
fórmula de distância ou todas as exceções do RagRPG. Contratos locais devem
especificá-los, sem presumir igualdade entre versões do jogo de referência.
