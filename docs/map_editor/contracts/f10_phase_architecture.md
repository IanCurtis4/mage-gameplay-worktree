# F10 — arquitetura de fase (decisões humanas)

31/10/2026. Registro de Sol/Astra (Claude Opus) das respostas humanas ao estudo
de fase do checkpoint38 (Torghast/Thanator, Ragnarok Online, Super Mario World e
Wario Land 3). É direção aprovada para F10, não implementação: nenhum código de
F9 muda por este registro. Termos de [PRODUCT_DIRECTION](../../PRODUCT_DIRECTION.md)
(fase, estágio, mapa, parte) continuam valendo.

## O que substitui o registro anterior

| Antes (PRODUCT_DIRECTION, 17–18/10) | Agora (31/10) |
| --- | --- |
| Desbloqueios de fase por perfil | Desbloqueios **sempre por personagem**, para estimular alts |
| Portais abrem quando todos os inimigos forem derrotados (toda jogada) | Limpeza total só na **primeira jogada** de cada fase |
| Término antecipado por quest não concede bônus por padrão | Término antecipado (quest ou sorte) concede bônus **proporcional ao que foi feito** |
| Tamanho um pouco abaixo de `pay_fild01`, `prt_fild08`, `moc_fild01`, sem conversão | Pelo menos **metade da área em pixels²** dos campos do RO, se possível |

As demais decisões de PRODUCT_DIRECTION seguem em vigor (relógio da fase, bosses
sem respawn na mesma expedição, morte volta ao último portal, retorno a estágios
anteriores permitido).

## Estrutura mínima de uma fase

1. Uma fase tem **no mínimo dois mapas distintos**: mapas de fase e, ao fim, um
   **mapa de boss** (uma peça com o boss no final). Na primeira jogada esse é o
   caminho obrigatório. (Não estava explícito no trabalho com Astra; registrado
   agora.)
2. **Mapas de fase** e **mapas de dungeon** são categorias separadas. A fase
   sempre começa por mapas de fase.
3. Em jogadas seguintes, a fase pode ganhar **caminhos alternativos** e
   **dungeons temáticas geradas algoritmicamente** dentro dela. O fundo e a
   temática de uma dungeon seguem a própria dungeon, não o tema geral da fase.
4. Objetivos de fim de fase não precisam ser boss kill.

## Portais e limpeza

- **Primeira jogada de cada fase:** limpar o mapa abre os portais (regra atual).
- **Jogadas seguintes:** portais podem já estar abertos ou abrir por condições
  do próprio mapa ou fase: um switch, um raro, etc. A limpeza total deixa de ser
  exigida.
- O registro "primeira jogada concluída" é **do personagem**, como todo
  desbloqueio.
- **Refinamento de 2/11:** nas jogadas seguintes vale **só o objetivo**; quando o
  objetivo tem chefe ou guardião, é preciso derrotá-lo antes. Ver
  [inserções de 2/11](f10_insertions.md).

## Término antecipado

- Pode vir de quest ou de **sorte**. Exemplo humano: um caminho divergente com
  uma caverna pequena, um elite raro com adds e um baú atrás. Matar os mobs e
  abrir o baú dá a opção de encerrar a run mais cedo.
- O bônus de conclusão é **sempre proporcional ao que já foi feito** na run.
  Um atalho rápido rende menos que um caminho longo com mais inimigos ou
  inimigos mais difíceis.
- Continua valendo: baú final não garante equipamento, e objetivos
  intermediários não concedem o bônus inteiro.

## Desbloqueios

Todo desbloqueio, dentro da fase ou entre fases (fases novas, caminhos, dungeons,
portais abertos), pertence ao **personagem**, nunca ao perfil. A intenção é
estimular ao máximo a criação de alts.

## Fundo em parallax

Cada mapa mostra um fundo em parallax com a temática do que está exposto naquele
momento. Numa dungeon, o fundo segue a dungeon. Em F9 (checkpoint39) o fundo usa a
arte dos mapas por bioma (`scripts/world/expedition_backdrop.gd`). O tema por
dungeon depende do catálogo de dungeons de F10.

## Escala dos mapas grandes

- Referências: os campos em volta das grandes cidades do Ragnarok Online
  (`prt_fildxx`, `pay_fildxx`, `gef_fildxx`) e as dungeons deles.
- Não precisa chegar a esse tamanho. A meta é **pelo menos metade da área em
  pixels²**, se for viável.
- Antes de fixar o número, F10 precisa converter célula de RO, unidade de mundo
  e projeção do jogo. Um campo típico do RO fica na ordem de 300×300 a 400×400
  células, mas a conversão para a área visível em pixels nunca foi aprovada. Também precisa
  medir o custo de navegação, população e snapshot nessa escala (o grafo, as
  rotas em segundo plano e o diário de F9 são a base).
- Estudo de 2/11 com a conversão proposta: [escala dos campos](f10_field_scale_study.md).

## Pendências para o contrato de F10

- Como medir "o que foi feito" para o bônus proporcional (mortes por dificuldade,
  mapas visitados, tempo), sem abrir farming de atalho.
- Persistência por personagem do "primeira jogada concluída" e dos portais
  abertos, e como isso aparece no lobby.
- Catálogo e gerador de dungeons temáticas (entrada, densidade, mobs próprios).
- Conversão de escala e orçamento de desempenho para mapas na metade do tamanho
  dos campos do RO.
- Perguntas ainda com o tester (documento de síntese): o estado dos inimigos
  vivos após uma queda, entre outras.
