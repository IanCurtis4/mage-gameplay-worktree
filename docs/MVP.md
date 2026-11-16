# Produto vigente e limites da entrega

## Aceite e transição — 5/11/2026

E07 e o estágio posterior F10/editor receberam aceite de produto com ressalvas:
[recibo e candidato](epics/e07/e07_closure_2026_11_05.md). Permanecem picos,
latências e tarefas humanas não reproduzidas, sem falsa certificação de fluidez.
Integração operacional continua separada. [E08](epics/e08_opening_2026_11_05.md)
inicia arquitetura/inventário de arte, animações e feedback, com contratos antes
de produção. Os estados de aceite pendente abaixo descrevem as entregas antes
dessa decisão. E08 foi aceito em 16/11; o [E09](epics/e09.md), autorizado na mesma data,
acrescenta quatro híbridas, ainda não implementadas. E10+ continuam reservados.

## Editor F10 — 5/11/2026

F9 foi integrada em 2/11 com aceite parcial. F10 acrescentou a fase de floresta
em três mapas amplos; Q5 revisa o editor e o consumo no jogo. Pincéis temporais,
diário cheio e apresentação da fase passaram nos testes dirigidos, sem aceite
final ou certificação de fluidez. A continuação reduziu trabalho de retomada e
navegação e corrigiu leitura dos portais, incluindo títulos sem espaços.
[Checkpoint e limites medidos](map_editor/delivery/f10.md),
[matriz Q5](map_editor/delivery/f10_q5_matrix.md). Entrada e portais ainda levam
dezenas de segundos/minutos; não há certificação de fluidez. A abertura E08
acima é documental, sem consumidores novos.

O [teste Windows atualizado](map_editor/delivery/f10_terrain_performance.md) inclui
minimapa quadrado do mapa atual inteiro, inimigos vermelhos, seta dourada com
direção do jogador e zoom de câmera independente da interface. O perfil de
teste desta versão é separado; checkpoints antigos permanecem no build anterior.
O relevo agora usa a triangulação e o declive canônicos; a apresentação evita
redesenhos e recortes de sombra repetidos. Preparação em até duas lanes e
handoff interno de pacotes validados reduzem trabalho antes de entrar na fase.

## Candidato técnico E07 —23/10/2026

[F8 validada tecnicamente](epics/e07/delivery/f8.md) compõe F0–F7: geometria com
altura, bens por personagem/schema8, migração com confirmação humana, expedições
com suspensão/retomada e amostra ramificada de 4 estágios/5 slots. 87 IDs únicos PASS
por impacto e Windows release nativo validado. Checkpoints síncronos custam 8–15s;
sem certificação de fluidez/escala ou aceite de gameplay. [Roteiro](epics/e07/f8_playtest.md).
Aplicada em codex/playtest; importação/smoke e preservação no [checkpoint](epics/e07/f8_checkpoint.md).
O inventário de 17/10 abaixo é histórico nas fronteiras substituídas. Migração
pessoal, master/push e E08+ dependem de autorização própria.

Consolidado em 17/10/2026. Este documento substitui o antigo escopo do piloto
como entrada de produto. Histórico: [versão anterior](MVP.history_2026_10_17.md).
As decisões explícitas posteriores prevalecem sobre E00 apenas nos deltas
documentados. Fluxo: [WORKFLOW](WORKFLOW.md); contratos: [ARCHITECTURE](ARCHITECTURE.md).

## Candidato existente

Windows single-player offline; ação 2D isométrica, câmera acompanhando o jogador,
navegação por clique, combate em tempo real e interface pt-BR. Godot 4.7.2 standard.

- Personagens persistentes e alts, XP Base/Job, atributos, aprendizado com
  dependências, evolução e presets. Barra configurável de 24 atalhos;
  passivas aprendidas legais são automáticas. Não restaurar o limite antigo 5+2.
- Dez identidades jogáveis: Espadachim, Mago, Arqueiro, Defendente, Berserker,
  Elementalista, Espiritualista, Sentinela, Caçadora e Geômetra. As outras cinco
  híbridas do elenco inicial não estão implementadas; isso não encerra E05 inteiro.
- Equipamentos são exemplares persistentes compartilhados pelo perfil, com
  qualidade, origem, ilvl, encaixes e conjuntos conforme os contratos atuais.
  Há 14 posições; não restaurar a coleção sem cópias ou os três slots do piloto.
  Esse compartilhamento descreve o candidato existente: decisão posterior de
  18/10 exige bens por personagem, com migração ainda não implementada.
- Cartas também são exemplares permanentes. Cópias iguais podem ocupar encaixes
  distintos; os encaixes permanecem na peça ao desequipar e ao terminar a run.
  Cartas são passivas, podendo modificar habilidades conforme a espécie de origem.
- Augments e escolhas pertencem somente à run: coleta, escolha manual fora de
  encontro e efeito atual/próximo. Equipamentos/cartas vêm do loot de mobs;
  escolhas de augment permanecem por etapa, sem transformar cada morte em escolha.
- Roteiro de demonstração: seis etapas em três áreas predefinidas, com variação
  de posições por seed, tiers de mobs e progressão fixa por origem. Esse roteiro
  testa sistemas; não equivale aos grandes mapas modulares do produto futuro.
- Inventário, comparação, feedback de aquisição, ícones, anexos visuais e admin
  de playtest estão presentes. Abas Consumíveis/Misc vazias não são esses sistemas.

Versões observadas no candidato de 17/10: schema 7, catálogo 14,
ruleset `stat_thresholds_v1`. Conferir código e [checkpoint E06](epics/e06_checkpoint.md)
ao retomar, em vez de usar esses números como versão futura obrigatória.

## Direção futura aprovada, implementação ainda não liberada

A [direção de produto](PRODUCT_DIRECTION.md) substitui a restrição antiga a mapas
fixos e a exclusão definitiva de lojas internas. O lobby oferecerá seleção de
fases; estágios terão mapas grandes e labirínticos montados algoritmicamente de
partes conectáveis, elevação com efeito em rotas, conexões em pontos definidos e
portais que avançam ao estágio seguinte. Populações variam gradualmente entre
mapas do mesmo bioma, com dificuldade maior em partes avançadas da campanha.

Consumíveis HP/SP terão CD longo e bloqueio após uso até sair do combate;
as duas condições precisam ser satisfeitas. Itens trash/misc poderão servir
a missões ou venda. Vendedores no lobby usarão gold para equipamentos e
consumíveis. Carteira e itens serão por personagem; somente unlocks são por
perfil. Migração, preços, estoques, quests e detalhes de combate
entre alturas precisam de contratos próprios antes de implementação.

Decisões de 18/10: fases repetíveis ramificadas, desbloqueios por perfil e nível
mínimo; portais após derrotar todos os inimigos, com respawn tardio em massa
somente após limpeza e sem fechar portais. Dois augments no primeiro estágio,
um no início dos seguintes e extras de fontes memoráveis contratadas. Conclusão
concede gold/EXP, sem equipamento garantido; aquisições permanecem, augments não.
Vendedores acompanham progresso, com básicos e raros limitados por unlocks;
sem conjuntos/épicos/lendários. Inventário sem peso/capacidade, equipamentos por
exemplar, itens de quest não vendáveis. Altura conta para alcance, sem bônus de
high ground. Detalhes e pendências na direção; consumíveis avançados/profissões
têm [gate próprio](gates/consumables_professions.md), ainda sem implementação.

Complementos18/10: todas as recompensas de mobs respawnados sofrem redução,
com taxas próprias por tipo; fase permanece maculada até conclusão, sem reset
por mera nova run. Retorno entre estágios permitido, com relógio de respawn único
por fase e sem repetir augment na revisita. Montagem/progresso da expedição
são preservados até conclusão. Augments e demais estados/relógios ficam congelados
entre visitas. Morte conserva a expedição/build, retorna ao último portal e
reduz o tempo restante até a próxima onda de respawn (reposição ao atingir zero);
valor da redução e recursos ao reviver aguardam contrato.
Primeira limpeza
inicia ondas globais longas nos estágios já limpos, repondo somente mortos
elegíveis sem duplicar vivos; bosses não respawnam. Destinos finais e
saídas alternativas admitem caminhos longos, becos, múltiplos objetivos e quests
que encerram a run antecipadamente. Memoráveis bloqueiam portal e ocupam locais
temáticos. Cenários 3D low-poly têm [gate próprio](gates/low_poly_environments.md).
Ameaça deve ser previsível/controlável, com participação de healers no combate
do grupo. Lista individual por inimigo, geração diferenciada, limiar de troca,
provocar, redução ativa e UI legível foram aprovados como direção. Encerramento
por quest não dá bônus de conclusão por padrão; exceções exigem desafio justificado.
Sem transferência de bens entre personagens. Venda confirmada de peça com cartas
remove também as cartas encaixadas.

O pedido de 17/10 autoriza consolidar documentação e criar quatro skills de
entrega. Não inicia geração de mapas, economia, novas classes ou E07+.
Quantidade final de estágios, duração da run e densidade não são fixadas pelo
piloto de três áreas nem pelos exemplos de população do usuário.

## Aceite e exclusões

Playtest de gameplay, legibilidade e balanceamento permanece humano. A meta
histórica de 60 FPS/1080p exige medição; checks e caps não provam desempenho.
Persistência, preview e combate devem concordar; nenhuma aquisição se duplica
em retry e nenhuma troca produz cura ou reset de recarga.

Multiplayer, mobile, backend, monetização e crafting não foram autorizados.
Referências a Ragnarok e Torghast/Thanator expressam direção de experiência,
não cópia de assets, taxas, fórmulas ou promessa de mundo online aberto.
