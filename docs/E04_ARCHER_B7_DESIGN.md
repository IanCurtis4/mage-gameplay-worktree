# E04-AR-B7 — decisão de design da Armadilha de Laço

Base técnica: runtime compartilhado de armadilhas entregue em `b8b195c`. Este
pacote adiciona somente `snare_trap` e a primitiva comum de hard CC necessária
ao root. Armadilha Explosiva, Flecha Entorpecente, ocultação e passivas ficam
fora do escopo.

## Tabela autorizada

| Rank | Root base | SP |
|---|---:|---:|
| 1 | 1,4 s | 18 |
| 2 | 1,8 s | 19 |
| 3 | 2,2 s | 20 |
| 4 | 2,6 s | 21 |
| 5 | 3,0 s | 22 |

Recarga de 8 s, alcance de colocação de 360, raio de acionamento de 52,
armação de 0,6 s e permanência armada de 12 s são fixos. Cast e dano são
zero. O rank aumenta somente a duração base do root e o custo: do R1 ao R5,
a duração cresce 114% e o custo 22%; área, alcance, recarga, armação e
permanência não crescem. Mira Estendida não altera colocação de traps.

A posição é limitada ao alcance e precisa ser caminhável; falha ocorre antes
de custo e recarga. Depois de armada, a trap escolhe o ator vivo elegível mais
próximo e usa o instance ID como desempate. O raio de colisão do alvo participa
do contato. Acionamento consome a trap uma vez, inclusive contra alvo imune, e
nunca causa dano.

## Root e imunidades

`HardControlState` é a autoridade compartilhada de durações de hard CC. Root
físico usa `physical_cc_resistance` e impede deslocamento sem alterar stats,
impedir ataques ou causar dano. Aplicações da mesma família não somam: mantêm o
maior tempo restante. Inimigos comuns respeitam o teto de 3 s.

Boss recebe no máximo 1 s por aplicação e compartilha 2 s de hard CC em cada
janela fixa de 10 s. Famílias sobrepostas cobram somente o intervalo novo em que
o boss permanecerá controlado; a última aplicação pode ser truncada ao saldo e
novas tentativas falham quando ele chega a zero. `Unstoppable` é verificado antes
de qualquer aplicação ou consumo. Pausa congela todos os relógios; morte e
limpeza removem o estado.

O contrato vale também para o jogador: root zera inércia, bloqueia caminhada,
Investida e Teleporte, mas não silencia ataques ou skills sem deslocamento.
