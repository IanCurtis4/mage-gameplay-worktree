# E04-AR-B1 — projétil de precisão e autoataque

Base técnica: contrato do Arqueiro em `2f3936d`. Este pacote adiciona somente a
classe mínima e seu autoataque; skills, perfil/menu, traps e ocultação ficam fora.

## Tuning do autoataque

| Poder | Stat | Alcance de engajamento | Velocidade | Distância do projétil |
|---:|---|---:|---:|---:|
| 1,00 | `precision_attack` | 340 | 880 | 520 |

O dano é físico, com HIT/FLEE contestado e crítico. A direção é capturada na
emissão; não há homing. O projétil colide continuamente com o primeiro inimigo ou
obstáculo e expira pelo alcance. Movimento do alvo pode esquivar. A cadência segue
exclusivamente `attacks_per_second` e a perseguição conserva as regras atuais.

`PlayerProjectile` passa a ser a autoridade compartilhada de deslocamento e colisão
dos projéteis do jogador. `MageProjectile` mantém somente modificadores de impacto e
apresentação do Mago sobre essa base. O limite de impacto é explícito e permanece 1
neste pacote; perfuração será implementada em E04-AR-B3.

O Arqueiro recebe `ClassDefinition` com biblioteca e passiva vazias. Isso permite
testar ator/auto diretamente, mas `ProfileCatalog` continua recusando a classe e o
seletor do piloto continua oferecendo apenas Espadachim/Mago até o gate aprovado.
