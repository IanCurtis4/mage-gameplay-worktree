# F10 — estudo de escala dos campos do Ragnarok Online

2/11/2026. Estudo de Sol (Claude Opus) pedido pela pessoa: "precisamos repensar o
tamanho das peças contíguas de campo [...] Quero que estude alguns mapas de campo
do Rag usando esse site como base, para poder entender o que faz eles serem
memoráveis e bem estruturados." Base: o banco de mapas do
[divine-pride](https://www.divine-pride.net/database/map/prt_fild02). Este documento
é referência de estrutura e escala para F10, não uma licença para copiar
layouts ou assets do Ragnarok Online (ver [PRODUCT_DIRECTION](../../PRODUCT_DIRECTION.md)).
Completa a seção "Escala dos mapas grandes" de
[f10_phase_architecture](f10_phase_architecture.md).

## Método

- Oito campos: `prt_fild02`, `prt_fild08`, `pay_fild01`, `pay_fild04`,
  `mjolnir_02`, `gef_fild10`, `moc_fild07` e `cmd_fild01`.
- Por mapa, as páginas do banco: monstros e quantidades, NPCs, saídas e suas
  coordenadas.
- A imagem de andabilidade que o site publica (`/img/map/raw/<mapa>`): 400×400 px,
  1 px por célula. Branco é andável, bege é estrada (também andável), escuro é
  bloqueado e azul é água.
- Métricas calculadas no próprio navegador sobre essa imagem:
  - fração andável;
  - folga, a distância de Chebyshev até a célula bloqueada mais próxima: uma
    folga *f* cabe num corredor de cerca de 2*f*−1 células;
  - ilhas de obstáculo (bloqueios que não tocam a borda);
  - distância percorrida entre saídas, por BFS em 8 vizinhos.
- Inspeção visual do minimapa (`/img/map/original/<mapa>`) de seis mapas e do
  visualizador 3D (relevo, objetos, sobreposição de andabilidade, wireframe).

**Limites do método:**

- Os arquivos do visualizador 3D (`gat`/`gnd`/`rsw`) vêm ofuscados pelo site. Não
  os decodifiquei, então as alturas foram avaliadas só no visual. O tamanho
  400×400 de `prt_fild02` também bate com o tamanho do arquivo de andabilidade
  (14 + 400·400·20 bytes).
- A BFS em 8 vizinhos conta a diagonal como 1 passo, então a razão rota/reta sai
  um pouco baixa.
- As coordenadas de algumas saídas caem fora do andável (marcadas "—").

## Medidas

| Mapa | Forma | Andável | Estrada (% do andável) | Folga mediana / p90 / máx | Ilhas (≥200 células) | Saídas | Rota entre saídas (células) | Monstros (espécie dominante) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| prt_fild02 | malha de bosquetes com estradas | 59% | 23% | 6 / 11 / 22 | 207 (18) | 6 | 136–365; rota/reta 0,8–1,4 | 273 (Stainer 188) |
| prt_fild08 | prado aberto em terraços, rio a leste | 60% | 5% | 6 / 18 / 50 | 393 (2) | 6 | 156–361 | 146 (Poring/Lunatic/Fabre) |
| pay_fild01 | vales ramificados entre paredões | 52% | 19% | 5 / 10 / 21 | 216 (2) | 5 | 170–400; até 2,5× | 264 (Willow 181) |
| pay_fild04 | areais e lagos em bolsões | 30% | 2% | 4 / 10 / 21 | 244 (3) | 2 | 672; 2,9× a reta | 222 (Poporing 141) |
| mjolnir_02 | serpentina de terraços, pontes | 45% | 30% | 5 / 10 / 21 | 490 (0) | 4 | 273–360 | 234 (Elder Willow 154) |
| gef_fild10 | planalto com rio e ponte central | 47% | 2% | 5 / 11 / 23 | 145 (9) | 4 | 198–350 | 270 (Orc Warrior 179) |
| moc_fild07 | deserto aberto | 63% | 3% | 6 / 13 / 25 | 638 (3) | 2 | 194 | 321 (Drops 214) |
| cmd_fild01 | muitos bolsões e passagens estreitas | 55% | 17% | 4 / 8 / 18 | 610 (4) | 6 | 56–346; até 2× | 278 (Grove 202) |

Todos os oito têm 400×400 células.

## O que os torna memoráveis e bem estruturados

1. **Uma forma legível por mapa.** Cada campo se reconhece pelo minimapa:
   - malha de bosquetes (`prt_fild02`);
   - prado em terraços com rio (`prt_fild08`);
   - vales em árvore (`pay_fild01`);
   - serpentina de terraços (`mjolnir_02`);
   - planalto cortado por um rio com uma ponte (`gef_fild10`).

   O arquétipo é global. A variação fica no grão local.
2. **Metade do quadrado é borda e obstáculo.** De 45% a 63% andável (30% no
   mapa de lagos). As bordas são grossas e orgânicas: paredões, mata densa,
   água. O mapa nunca parece uma sala retangular.
3. **Corredores largos, poucos gargalos.** A largura típica do espaço andável é
   de 7 a 11 células (folga mediana 4–6). Os 10% mais abertos chegam a 15–35
   células, e o prado de `prt_fild08` tem uma praça de quase 100. Os gargalos
   ficam nas pontes, nas rampas e nas saídas.
4. **Grão fino com poucos estruturantes.** Há centenas de obstáculos pequenos (de
   1 a 4 células: árvores, pedras, flores) e, no máximo, algumas dezenas de massas
   grandes que desenham os caminhos. A densidade dá textura sem bloquear a rota.
5. **Orientação por estrada ou por marco.** Onde há estrada (17% a 30% do
   andável), ela costura as saídas. Onde não há, o rio, a ponte, os paredões e
   os terraços dão a direção.
6. **Rota global quase direta, desvio local.** Entre saídas opostas a rota fica
   perto da reta (0,8–1,3×). Só os mapas de bolsões e de lagos forçam desvios de
   2 a 3 vezes. O labirinto está na escala de algumas telas, não no mapa inteiro.
7. **Saídas nas bordas, em pares.** São de 2 a 6 por mapa, muitas vezes duas
   próximas levando ao mesmo vizinho (as três saídas oeste de `prt_fild02`).
   Entradas de dungeon e NPCs ficam em marcos (a aldeia orc de `gef_fild10`; a
   mina, a Kafra e a villa de `mjolnir_02`).
8. **População com uma espécie dominante.** De 150 a 320 monstros por mapa: uma
   espécie fica com 64% a 73% do total (o prado de `prt_fild08` é a exceção,
   repartido entre Poring, Lunatic e Fabre), há de 2 a 4 secundárias e de 1 a 3
   chefes ou variantes raras ("Elusive", "Ringleader", MVP). A densidade é de
   cerca de 1 monstro a cada 300–600 células andáveis.
9. **Altura como borda e como rota.** Terraços e paredões separam regiões. As
   rampas e as pontes são as passagens (`mjolnir_02`, `prt_fild08`,
   `gef_fild10`). A altura quase nunca é obstáculo isolado no meio do caminho.

## Escala comparada com o RagRPG

| Medida | Ragnarok Online | RagRPG hoje |
| --- | --- | --- |
| Tamanho de um campo ou peça | 400×400 células | peça do Bosque: 21×21 amostras a 64 = 1280×1280 unidades; o mapa tem 2 peças, 2560×1280 |
| Velocidade base | 150 ms por célula, cerca de 6,7 células/s ([fonte](https://annieruru.blogspot.com/2019/01/the-meaning-behind-value-of-movement.html)) | `move_speed` 220 unidades/s (`stat_calculator.gd`) |
| Travessia em linha reta | cerca de 60 s | uma peça em 5,8 s; o Bosque em 11,6 s |
| Uma tela | cerca de 29×29 células (área de visão de 14 células do servidor, aproximada) | 1280×720 com a projeção (0,85; 0,425): cerca de 1500 unidades em x−z e 1700 em x+z; uma peça ocupa cerca de 1,3 tela |
| Campo em telas | cerca de 14×14 telas | uma peça ocupa cerca de 1×1 tela |

**Conversão proposta para aprovação.** A meta humana é "pelo menos metade da área
em pixels²" dos campos do RO, ou seja, a mesma área em telas.

- Metade de 400×400 dá cerca de 283×283 células, ou 9,8 telas de lado.
- Na tela do RagRPG, uma célula equivale a cerca de 39 unidades. Por esse
  critério, um mapa de campo teria **~11.000 unidades de lado** (~120 M u²).
- Pelo tempo de travessia dá quase o mesmo: 283 células levam 42 s no RO;
  42 s a 220 u/s são ~9.300 unidades.
- A faixa de **9.000 a 11.000 unidades de lado** (de 40 a 50 s em linha reta,
  de 50 a 65 s pela rota) atende às duas leituras. É de 7 a 8,6 vezes o lado da
  peça atual, de 50 a 75 vezes a área, e de 25 a 37 vezes a área do Bosque
  inteiro.

**O formato já comporta isso numa peça só.**

- Uma camada aceita até 257×257 amostras (`source_schema.gd`).
- O terreno aceita até 65.536 quads (`terrain_compiler.gd`, `MAX_GRID_QUADS`).
- A 64 de espaçamento, uma camada de 11.000 unidades tem cerca de 172×172 quads
  (29.600), dentro dos dois limites. O limite está no desempenho, não no formato.

**O que falta medir** (orçamento de F10):

- No Bosque (duas peças de 1280), a compilação do mapa leva ~28 s e o
  `prepare()` da certificação leva ~80 s.
- Num campo com 25 a 37 vezes essa área, a compilação, a certificação, a
  navegação, o desenho no jogo e o diário precisam ser por região, incrementais
  e em segundo plano. Sem isso, a autoria agêntica não fica fluida.
- Os tetos atuais vão restringir o conteúdo:
  - `MAX_PROPS` 512 por borda;
  - `MAX_SLOTS` 512 no diário;
  - pacote de 4 MiB.

  Nenhum será reduzido. Aumentar algum exige justificativa e medida.

**População.** Na densidade do RO (1 monstro a cada 300–600 células andáveis),
metade de um campo daria de 75 a 160 monstros. Como a primeira jogada exige
limpeza total e uma fase tem pelo menos dois mapas, essa densidade tornaria a
primeira jogada longa demais. Proposta: de 40 a 70 monstros por mapa de campo,
com uma espécie dominante, 2–3 secundárias e um guardião do objetivo. A ser
medida contra a duração-alvo da run.

## Regras de autoria derivadas (para a Terra no modo AX e para o gerador)

1. Escolher um arquétipo de forma por mapa e dizê-lo no pedido: malha, prado em
   terraços, vales em árvore, serpentina, planalto com rio ou bolsões.
2. De 45% a 60% de andável, com bordas grossas e orgânicas.
3. Corredores típicos de 300 a 450 unidades (de 7 a 11 células); praças e
   clareiras de 600 a 1500. Gargalos só em pontes, rampas e saídas.
4. Muitos props pequenos (de dezenas a algumas centenas) e de 5 a 20 massas
   estruturantes; nenhum prop grande isolado no meio do caminho principal.
5. Estrada ou marco que costure as saídas. Rota entre saídas de 1,0 a 1,5 vez a
   reta (até 3 vezes num mapa de bolsões, de propósito).
6. De 2 a 4 saídas nas bordas; marcos para entradas de dungeon, santuários e o
   guardião.
7. Altura como terraço e borda; rampas e pontes como passagens.

## Fontes

- [divine-pride: prt_fild02](https://www.divine-pride.net/database/map/prt_fild02),
  [prt_fild08](https://www.divine-pride.net/database/map/prt_fild08),
  [pay_fild01](https://www.divine-pride.net/database/map/pay_fild01),
  [pay_fild04](https://www.divine-pride.net/database/map/pay_fild04),
  [mjolnir_02](https://www.divine-pride.net/database/map/mjolnir_02),
  [gef_fild10](https://www.divine-pride.net/database/map/gef_fild10),
  [moc_fild07](https://www.divine-pride.net/database/map/moc_fild07),
  [cmd_fild01](https://www.divine-pride.net/database/map/cmd_fild01)
- [Velocidade de movimento no RO (Annieruru)](https://annieruru.blogspot.com/2019/01/the-meaning-behind-value-of-movement.html)
