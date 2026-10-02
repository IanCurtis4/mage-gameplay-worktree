# Geômetra — contrato consolidado das semânticas G0

02/10/2026. Base:91b5f63. Este documento distingue semânticas aprovadas de tuning
inicial ainda sujeito a playtest. Astra aprovou o design em02/10/2026 com os ajustes incorporados
abaixo. Isso fecha G0; não constitui aceite técnico ou de balanceamento da classe.

## Base já aprovada e interfaces

Identidade `mg_ar`, origem Mago. Seleção direta intrínseca F/G/R; Traçado é
especial e separado do auto. Até três âncoras estáticas/móveis; dois elementos
distintos formam parede; dois iguais preparam; três formam triângulo conforme
rank1/3/5 de Triangulação. Paredes atuam na aresta; triângulos só na área.
Suspensão conserva relógios; morte deposita a âncora sem renovar sua duração.

Interfaces de implementação para manter os donos claros:

- `GeometerGeometry`: limites, validação e hit-test em coordenadas da arena,
  usados pelo preview e execução; não projeta duas vezes o chão.
- `GeometerConstructionState`: elemento selecionado, reservas ordenadas por
  disparo, vértices, identidade da construção, relógios e suspensão. Sem Nodes,
  dano, SP ou save. Impactos fora de ordem aguardam os anteriores; falhas são
  descartadas nessa mesma ordem, sem trocar a receita.
- `GeometerTraceProjectile`: entrega impacto de chão/alvo, com intenção e
  elemento congelados. Alvo morto durante voo não cria âncora no cadáver.
- `GeometerField`: observa construção e aplica eventos reais pelo resolver
  central; gerencia apenas cadências/dedup da mesma construção.
- Camada de chão: vértices/figura/preview sob os atores. Reações de impacto
  acima; a área visível coincide com a área do hit-test.

IDs previstos: `geometer_trace`, `geometer_incidence`, `geometer_translation`,
`geometer_triangulation`, `geometer_vector_memory`, `geometer_collapse`,
`geometer_rewrite`. Catálogo só declara biblioteca pronta no fechamento.

## Máquina de estados e transições

| Estado | Condição | Transição autorizada |
|---|---|---|
| Vazio | Nenhum vértice | Traçado válido cria A |
| Vértice | Apenas A | Traçado válido cria B |
| Preparação | A/B do mesmo elemento | Triangulação válida cria C, conforme rank |
| Parede | A/B distintos | Triangulação válida cria C e encerra os efeitos de parede |
| Triângulo | A/B/C válidos | Edição explícita ou Colapso; nenhum quarto Traçado |

Suspensão é uma condição da construção, não uma nova receita. Invalidade móvel
desliga efeitos, mas continua consumindo os prazos. A retomada não dispara C.
Edição inválida conserva tudo; edição válida mantém identidade e prazo da figura.
Limpeza explícita, expiração de qualquer vértice ou expiração da figura volta a
Vazio e invalida reservas antigas. Pausa da run congela todos esses relógios.
Reservas são processadas por ordem de comando, inclusive falhas e timeouts;
somente impacto confirmado pode acrescentar um vértice.

## Decisões críticas aprovadas (uma rodada agrupada)

1. **Direção:** a ordem A→B define receita e direção de transporte ao longo da
   linha. Travessia de ator funciona em ambos os sentidos; não acrescentar
   uma segunda orientação perpendicular escondida. F/G atuam ao cruzar a
   faixa; F na saída produz uma detonação pequena no ponto de travessia.
   Movimento da própria parede sobre ator parado não conta como travessia.
2. **Projéteis:** condução/desvio atuam somente em projéteis próprios elegíveis,
   excluindo Traçado e secundários. Condução R leva o projétil ao vértice B sem
   teleporte, conservando distância/vida e colisão; sai na direção original.
   Condução começa no ponto real de interseção, sem teleportar para A.
   Desvio R altera direção uma vez para o inimigo vivo mais próximo de B,
   com alcance/LoS, sem criar novo projétil nem ricochete recursivo. Saída G
   intercepta projétil hostil na linha e o dissipa, sem convertê-lo em aliado.
   Saída F confere detonação ao próximo impacto elegível, inclusive G→F.
3. **Resolução do triângulo:** terceiro elemento resolve uma vez na formação.
   Colapso consome a figura e repete essa resolução como finalização explícita
   com coeficiente próprio. Expiração só desfaz; edição/suspensão/retomada não
   repetem resolução. Assim as27 receitas funcionam antes de aprender Colapso.
   Colapso de parede emite um único pulso na faixa atual com dano próprio/LoS,
   sem simular travessia, interceptação ou Teorema. Um vértice ou preparação
   de dois iguais não permite Colapso. Parede→triângulo conserva o prazo da
   figura; não reabrir para repetir a resolução.
4. **Contenção G:** dano mágico menor + root curto via `HardControlState`,
   respeitando resistência/orçamento de boss já existente. Sem aprisionamento
   físico pela borda nem novo controle permanente.
5. **Edição móvel:** Translação conserva elemento do último vértice, mas a mira
   explícita escolhe novo vínculo (chão solta; inimigo prende). Reescrita remove
   o mais antigo e acrescenta o novo no fim: B,C,D vira a nova sequência. Ambas
   preservam duração restante da figura e identidade/cadências. Apenas o
   vértice substituído recebe seu prazo normal. Não reativam a resolução.
6. **Custo/expiração:** validar geometria/slot/alvo antes do disparo pago. Se
   alvo se invalida ou geometria muda durante voo, perder o disparo já lançado
   sem refund; não cobrar novamente no impacto. Falha de edição instantânea
   não cobra. Expiração de qualquer vértice desmonta a figura inteira em vez
   de reordenar silenciosamente os sobreviventes; limpar invalida voos antigos.
   Toda reserva tem timeout finito; um projétil perdido não bloqueia a fila.
7. **Obstáculos:** uma área que cobre obstáculo, mesmo inteiramente dentro do
   triângulo, é inválida. Não recortar terreno nem permitir dano através dele.
   Mesmo validador no preview, formação, edição e suspensão móvel.

## Seis paredes — gatilhos e resultados

Faixa de12 unidades de meia largura; contato contínuo de ator/projétil,
sem barreira de navegação. Ator exige seu próprio deslocamento atravessando
a linha atual. Janela por alvo2s por construção, compartilhada entre entrada
e saída e entre vítimas de detonações vizinhas: vários cruzadores não burlam
cadência no mesmo boss. Ficar no segmento ou oscilar não cria ticks. Nas paredes com saída
F, o pulso afeta alvos em raio45 do cruzamento com LoS, uma vez cada.

| Receita | Ator inimigo cruzando | Projétil próprio elegível | Projétil hostil |
|---|---|---|---|
| F→G | Dano mágico de entrada | Sem transformação | Dissipado na aresta |
| F→R | Dano mágico de entrada | Desvio dirigido a partir da aresta | Sem transformação |
| G→F | Slow2s + detonação local na saída | Próximo impacto detona localmente uma vez | Sem transformação |
| G→R | Slow2s | Desvio dirigido | Sem transformação |
| R→F | Detonação local na saída | Condução A→B + detonação no próximo impacto | Sem transformação |
| R→G | Sem dano/controle de ator | Condução A→B | Dissipado na aresta |

Condução/desvio/Teorema não renovam alcance, vida, piercing ou alvo já atingido.
Registros de transformação são por projétil/instância e compartilhados entre
parede e triângulo da mesma construção. Dano adicional é
secundário, não ativa efeitos genéricos nem reaplica a própria gramática.
Teorema recompensa interação efetiva de parede: bônus moderado no dano de
travessia/pulso ou próximo impacto transformado; interceptação hostil devolve
pequeno SP com cooldown interno2s, apenas se houve capacidade a recuperar.
Nunca recompensa preview, editar, retomar ou usar projétil Traçado.

## Triângulos — composição exata

Uma camada por função, sem herdar efeitos de parede. Todos os alvos passam por
LoS e pelo mesmo teste de círculo versus triângulo. Dano usa snapshots de
skills, defesa atual no resolver e efeitos secundários limitados. O jogador
nunca recebe dano/controle das próprias construções. Nenhum aliado/NPC novo.

| Função | Fogo | Gelo | Raio |
|---|---|---|---|
| Fundação A | Brasas: dano baixo a ocupantes, cadência1s | Geada: slow10% dentro, residual0,6s | Condutor: projétil próprio atravessando recebe pequeno componente mágico, uma vez por construção |
| Regra B | Pulso: dano de área a ocupantes, cadência1s | Lento: slow20% dentro, residual0,6s; com geada vale o maior, sem somar | Condução: primeiro impacto de projétil próprio após atravessar emite1 arco secundário para outro ocupante a<=110 com LoS |
| Resolução C | Explosão: dano de área no fechamento/Colapso | Contenção: dano menor + root0,7s no fechamento/Colapso | Descarga: dano a até3 ocupantes, partindo do mais próximo do terceiro vértice, por elos<=110 com LoS |

As cadências de A/B compartilham agenda de1s, com um pedido somado por alvo
quando ambas causam dano. Não há catch-up após pausa longa/suspensão; no
máximo um tick por avanço válido. Campo deslocado não percorre e acerta toda
a região varrida. R pode atuar em projétil que nasce dentro da área, mas uma
saída/reentrada do mesmo projétil não concede outra transformação.

Matriz explícita: A/B são manutenção; C é resolução. Os nomes são composicionais,
mostrando as três funções no tooltip, sem inventar27 habilidades independentes.

| Receita | Manutenção | Resolução | Rank mínimo |
|---|---|---|---|
| FFF | Brasas + pulsos | Explosão |1|
| FFG | Brasas + pulsos | Contenção |3|
| FFR | Brasas + pulsos | Descarga |3|
| FGF | Brasas + slow reforçado | Explosão |3|
| FGG | Brasas + slow reforçado | Contenção |3|
| FGR | Brasas + slow reforçado | Descarga |5|
| FRF | Brasas + arco de projétil | Explosão |3|
| FRG | Brasas + arco de projétil | Contenção |5|
| FRR | Brasas + arco de projétil | Descarga |3|
| GFF | Geada + pulsos | Explosão |3|
| GFG | Geada + pulsos | Contenção |3|
| GFR | Geada + pulsos | Descarga |5|
| GGF | Geada + slow reforçado | Explosão |3|
| GGG | Geada + slow reforçado | Contenção |1|
| GGR | Geada + slow reforçado | Descarga |3|
| GRF | Geada + arco de projétil | Explosão |5|
| GRG | Geada + arco de projétil | Contenção |3|
| GRR | Geada + arco de projétil | Descarga |3|
| RFF | Condutor + pulsos | Explosão |3|
| RFG | Condutor + pulsos | Contenção |5|
| RFR | Condutor + pulsos | Descarga |3|
| RGF | Condutor + slow reforçado | Explosão |5|
| RGG | Condutor + slow reforçado | Contenção |3|
| RGR | Condutor + slow reforçado | Descarga |3|
| RRF | Condutor + arco de projétil | Explosão |3|
| RRG | Condutor + arco de projétil | Contenção |3|
| RRR | Condutor + arco de projétil | Descarga |1|

## Tuning inicial proposto (não balanceamento aceito)

Traçado:8SP, intervalo0,4s, preparo0,12s variável, alcance600, velocidade900,
impacto mágico0,30→0,50 MAG. Parede entrada F0,35→0,55 MAG; saída F0,30→0,50;
entrada Gslow20→30%. Triângulo A-F0,12→0,20 e B-F0,18→0,30 MAG/s. A-R
adiciona0,12→0,20 MAG; B-R arco0,20→0,35. Resolução F0,80→1,20, G0,30→0,50,
R0,60→1,00 por alvo; Colapso escala por seus próprios ranks e não acumula
explosões anteriores. Memória+1/+2/+4s de vértice e+1/+2/+3s de figura,
sempre teto12. Teorema+10/15/20% somente em sua interação; restituição2/3/4SP.

Translação12SP/CD4s/instantânea/alcance600; Reescrita14SP/CD5s/instantânea;
Colapso18SP/CD8s/instantâneo. Triangulação é ativa equipável explicitamente
selecionada para disparar o terceiro vértice pela mesma gramática de mira,
pagando somente seu custo16SP/CD3s. Traçado coloca primeiro/segundo; com dois,
informa a disponibilidade de Triangulação, sem trocar seleção nem lançar.
Terceiro impacto válido fecha a área automaticamente, sem ativação posterior.

RRR exige ataques próprios durante manutenção; validar auto/projétil base da
Geômetra concretamente no boss solo, sem duplicação artificial do arco num
único alvo. Desempates de desvio são determinísticos. Caminhada real atravessa
parede; teleporte/reposicionamento instantâneo não conta. Resolução e cadências
não se renovam por edição, suspensão ou movimento mínimo da parede.

## Próximo trabalho independente

Validadores de pontos/linhas/áreas, consulta de obstáculos da navegação,
seleção/reservas ordenadas e snapshots de âncoras. Não publicar o candidato
parcial no projeto habitual. Sem novo gate por camada: revisão integrada ao
fecharG7; escalar apenas novos bloqueios/decisões fora do contrato consolidado.
