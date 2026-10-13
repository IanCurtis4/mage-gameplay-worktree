# Primeiro lote espacial do piloto

O usuário escolheu duas transformações sobre as regras existentes, sem novo botão: posição fixa do eco da Espiritualista e vértices de chão do Geômetra. As63 receitas/textos anteriores permanecem preservadas, formando um bundle separado de65 Resources. Nenhuma receita foi publicada no catálogo ativo.

| Nome Luna | Descrição mecânica gerada | Flavor Luna |
|---|---|---|
| Vértice de Chão Firme | Traçado e Triangulação fixam vértices no ponto do impacto, sem acompanhar o alvo. Requer rank 1 na habilidade afetada. Não combina com outra transformação do mesmo grupo.<br>Acumula até 1 vez(es). | No impacto confirmado, o ponto fica marcado no chão; Traçado e Triangulação mantêm seus vértices onde o disparo realmente alcançou. |
| Eco no Ponto Marcado | Eco resolve no ponto onde o portador foi agendado, com espera, dano e alcance da habilidade. Requer rank 1 na habilidade afetada. Não combina com outra transformação do mesmo grupo.<br>Acumula até 1 vez(es). | Quando agendado, o eco guarda aquele ponto no espaço; o portador precisa permanecer vivo para que a onda se resolva ali, sem seguir o alvo. |

## Efeito observável

Ao agendar um eco com a primeira política, a onda guarda o ponto ocupado pelo portador. Se ele se afastar, o eco continua naquele ponto: pode atingir o grupo que ficou ali e deixar o portador escapar da área. A morte do portador cancela o eco como antes. O raio, espera e dano continuam os da habilidade; portadores da propagação finita guardam seus próprios pontos quando agendados. Retirar o augment depois do lançamento não muda a ação capturada.

Com a segunda política, Traçado/Triangulação continuam mirando e acertando normalmente. Só após confirmar o impacto o vértice fica no chão. Ele permanece no ponto real do impacto quando o inimigo se move ou morre. Entregas fora de ordem guardam ponto e idade enquanto aguardam a anterior; a gramática e as regras de fechamento continuam atuais. Retirar o augment durante o voo conserva a política daquele disparo.

As comparações A da Espiritualista e do Geômetra incluem essas políticas; B conserva a alternativa anterior. O relatório continua declarando tactical_validated=false para o conjunto de20 comparações: este lote comprova essas duas decisões espaciais, não todas as direções de T3.

## Evidência e limites

Testes reais usam a cena/atores/projéteis existentes e métodos de lançamento, com movimento, propagação, morte, pausa, obstáculo, cancelamento e retirada em voo. Testes de FIFO usam progressão manual por consumidor; não representam avaliação visual de concorrência/cadência. Ainda há roteiro de playtest humano e integração futura.

Progressão e taxas permanecem adiadas. Inscrição por Drenagem, mecanismo seletivo, exploração distribuída e Colapso pelo primeiro elemento são somente propostas futuras. A base racional fica com Sol; nomes/flavor ficam com Luna.
