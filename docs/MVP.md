# Produto vigente e limites da entrega

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
consumíveis. Modelo de carteira, preços, estoques, quests e detalhes de combate
entre alturas precisam de contratos próprios antes de implementação.

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
