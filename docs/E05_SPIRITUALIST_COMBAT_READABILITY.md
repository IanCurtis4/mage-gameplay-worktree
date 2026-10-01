# Espiritualista — almas que comunicam estado e reação

## Ajuste de densidade solicitado no playtest — 01/10/2026

Com a propagação coletiva, o usuário observou excesso de fantasmas na tela e
pediu um efeito branco de halos sobrepostos no chão, com pequenos espíritos nas
bordas e um fantasma maior voando acima do conjunto. Esta direção substitui,
para a Maldição/Eco em grupos, a receita abaixo de duas almas grandes por alvo,
convergência de múltiplas silhuetas e cópias do corpo a cada explosão. Os demais
estados/skills continuam seguindo o vocabulário visual aplicável.

Cada alvo realmente marcado ou pendente recebe seu próprio halo translúcido;
as interseções acumulam opacidade, formando uma área contínua sem disco opaco.
Halos e espíritos pequenos de borda pertencem à camada do chão, sob os corpos;
a alma elevada e os pulsos de impacto ficam acima dos atores.
Alvos com halos que se tocam compartilham uma única alma grande acima do grupo;
um isolado mantém uma própria. O agrupamento é estritamente cosmético: não cria
marca, dano, alcance, linha de visão nem transmissão. Eco pendente contrai e
clareia apenas os halos correspondentes; impactos efetivos geram pulsos locais,
sem duplicar o sprite dos inimigos. Vínculos de propagação são pequenos e breves.
O teste de jogo pelo usuário ainda decide se a densidade e o contraste bastam.

## Direção revisada por Astra — 30/09/2026

O usuário considerou a primeira rodada funcional, mas simples e dependente
demais de texto. Esta revisão substitui a receita anterior de sigilos pequenos,
avisos e painel como principal explicação. Preservar correções de estado/faixas
já validadas; o aceite visual anterior fica superado por esta solicitação.
Referências conceituais: marca presa ao alvo e reação do W de Ezreal; presença
persistente e resposta por alvo da passiva/E de Twitch. São referências de
causalidade visual, sem copiar assets ou importar suas regras de gameplay.

Objetivo: ver uma alma se prender, reagir ao gatilho e se desprender no resultado.
Forma, posição e movimento explicam a relação entre ações, sem depender de ler
mensagens, números ou um painel lateral. Sol integra esta direção artística de
Astra usando os bitmaps existentes. Continua um único checkpoint por classe,
sem handoffs por skill. Não mudar dano, duração, custo, alcance, procs, save ou
progressão; não iniciar Arqueiro nem fazer merge master.

## Vocabulário visual

Reutilizar spiritualist_soul_wisp.png: rosto pálido com olhos, cauda ondulada e
contorno violeta. O rosto precisa ser reconhecível na escala normal do jogo.
Usar os quatro frames, curvas e transformações do sprite aprovado. A solução
não consiste apenas em aumentar círculos/ícones abstratos.

- Alma vinculada: rosto aponta ao corpo; cauda contorna parte da silhueta.
  Movimento lento, assimétrico, sugere assombração persistente.
- Preparação: as mesmas almas mudam de movimento e convergem. Essa continuidade
  mostra que a marca gerou a reação.
- Impacto: contração rápida seguida de expulsão e vestígio espectral do corpo,
  com mais contraste e deslocamento que a manutenção de um debuff.
- Enfraquecimento: almas baixas puxam para fora/para baixo e retornam, distintas
  da marca no torso; sem correntes rígidas que sugiram root.
- Benefício: retorno dirigido alvo → jogador; recepção no corpo quando HP/SP
  realmente aumenta. Foco permanece como uma alma-companheira.

Paleta aprovada: núcleo marfim frio, corpo cinza-azulado, borda violeta escura.
Contraste local por contorno/núcleo, sem disco opaco que esconda o inimigo.
Como ponto inicial de tuning, duas almas de 26–36px na marca comum e ampliação
moderada no boss. Conferir área opaca real: tamanho do quad não equivale ao rosto.
Âncoras de pés/torso/cabeça usam sprite_visual_scale; offsets fixos não devem
enterrar efeitos no boss. Preservar pose, barra de HP e telegraphs do chão.

## Receita por estado/skill

| Estado real | Apresentação obrigatória sem texto |
|---|---|
| Maldição aplicada/mantida | Duas almas surgem junto ao torso, se agarram em lados opostos e orbitam parcialmente o corpo com fases diferentes. Sigilo pode sustentar, mas almas são o sinal dominante. Só persistem enquanto a marca existe. Miss/absorção que não consome marca mantém essa presença. |
| Marca convertida em Eco pendente | As almas vinculadas param a órbita, viram os rostos para dentro e comprimem a trajetória até o corpo durante os 0,35s reais. Caudas esticam para fora, criando antecipação. Seguir alvo móvel durante preparo. |
| Eco causa dano efetivo | Na resolução, vestígio espectral do corpo se destaca brevemente e 2–3 almas são expulsas antes de sumirem. Uma contração/liberação representa o mesmo impacto, sem sugerir ataques adicionais. Prioridade visual maior que marca/debuff. |
| Eco absorvido/inválido | Absorção total: reação amortecida na superfície, sem expulsão triunfal/vestígio de dano. Invalidação/morte: desfazer preparo e referências sem efeito de sucesso. |
| Marca expira | Almas soltam vínculo e sobem lentamente, perdendo opacidade; sem contração/expulsão de impacto. Consumo por Drenagem/Procissão nunca usa essa animação. |
| Rito consome marca | Em cada alvo com consumo real, almas são arrancadas radialmente junto ao pulso do Rito. Abertura imediata distingue Rito da compressão atrasada do Eco. Alvos não marcados podem receber impacto normal sem fingir consumo. |
| Enfraquecimento efetivo | Almas baixas puxam as laterais do corpo em ciclos suaves, mais arrastados que a marca. Persistem fora da área enquanto durar o debuff real. Fontes concorrentes do mesmo stat produzem uma única camada efetiva. |
| Véu e alvos afetados | Névoa baixa e poucas almas cruzam o chão dentro do raio real. Na aplicação do debuff, uma alma emerge junto ao alvo e adere à composição de enfraquecimento. Refresh não repete burst por frame. Entrada, manutenção e fim são visíveis no inimigo, não só no chão vazio. |
| Drenagem | Vínculo orgânico de caudas ondulantes. Nos ticks reais, uma alma é puxada do corpo do alvo e retorna ao jogador. Recepção de cura só quando HP aumenta; extração de dano e cura são resultados distintos. Cancelar desfaz vínculo sem finalização falsa. |
| Procissão | Wisps existentes mais reconhecíveis e reação local em cada impacto real. Primeiro impacto elegível pode comprimir marca e preparar Eco; posteriores não fingem novos procs. Não alterar dano/timing para coincidir com chegada cosmética. |
| Foco | Alma-companheira junto ao ombro/cajado distingue jogador energizado de inimigo assombrado. No consumo válido converge para origem da conjuração; na expiração apaga suavemente. Só aparece com carga real. |
| Recolhimento | Pequena alma retorna e se incorpora no jogador em restituição real de SP; recepção discreta, distinta da cura. Nenhum ganho visual quando SP está cheio. |

## Texto e HUD

Desligar por padrão avisos espirituais flutuantes e painel automático de leitura
espiritual nesta apresentação. Preservar caminhos úteis para depuração/testes
com uma opção interna de apresentação, sem criar menu/configuração persistente.
Números gerais de dano existentes podem permanecer, mas o teste visual também
os oculta para demonstrar que não carregam a explicação do combo. Tooltips e
HUD essencial permanecem. Texto de combate configurável é possibilidade futura.

## Integração e invariantes

Usar marcas/pending, actual_damage/absorbed_damage, ticks, carga Foco, recuperação
efetiva e fontes de AttributeDebuffState. Apresentação não calcula dano nem
inventa alvos afetados pela posição na tela. Participação no Véu vem da aplicação
autoritativa; a decoração não representa outra área de colisão.

Separar sinais persistentes e reações transitórias. Composição por alvo, limites
finitos de almas/eventos e prioridade Eco/Rito > marca > enfraquecimento. Almas
decorativas não representam stacks/cargas/ticks extras. Alvos não focados mantêm
a mesma linguagem, com densidade menor se necessário. Pausa congela animação;
morte, cancelamento, fim de debuff/run e reinício limpam referências. Troca de
alvo não apaga estados reais dos demais. Eventos simultâneos não se sobrescrevem.

Reutilização dos bitmaps com composição por código é suficiente nesta rodada;
Astra mantém direção/aceite visual. Se faltar silhueta para alguma receita,
escalar essa necessidade antes de gerar arte nova.

## Evidências e aceite

Testar manutenção/conversão/expiração, absorção, Rito, entrada/saída da área com
duração residual, fontes concorrentes, canal interrompido/completo, Foco,
recuperação, pausa/limpeza e múltiplos alvos. Não basta conferir chaves/labels.

Capturar sequências temporais no renderer real, sem painel/avisos/números:

1. Boss parado e móvel: sem marca → almas presas → convergência → Eco.
2. Marca expirando e consumida por Rito, para comparar movimentos.
3. Boss/adds atravessando Véu: aplicação, manutenção, saída e fim do debuff.
4. Marca + enfraquecimento simultâneos, Drenagem/Procissão e Foco no jogador.
5. Seis adds: limites de densidade e preservação da leitura de corpos/chão.

Preferir sequência animada ou frames com intervalos identificados à captura
única no pico de brilho. Mostrar escala de gameplay, piso claro/escuro e boss/add;
recorte ampliado não é evidência suficiente. Verificar limites no cenário denso;
não afirmar FPS validado sem medição. Rodar tools/verify.ps1 no fechamento.

Astra revisa o pacote integrado antes de preparar o projeto fixo. O usuário
avalia a semiótica em combate antes do merge. O pacote anterior não foi
publicado no playtest como resposta final a esta direção revisada.
