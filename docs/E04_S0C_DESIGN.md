# S0-C — decisão de design do piloto

Usuário autorizou dano crescente e custo crescente côncavo, delegando a fórmula
a Astra. Decisão: Corte (`slash`) como primeiro consumidor; demais skills não
estão liberadas por esta tabela. Valores de balanceamento sujeitos a playtest.

## Regra de autoria

Para R ranks, custo inicial C1 e final CR:

`C(r) = round(C1 + (CR-C1)*(sqrt(r)-1)/(sqrt(R)-1))`

Usar r de 1 a R; para R=1, usar C1. Arredondar uma única vez na autoria da tabela.
Runtime, preview e HUD leem a mesma definição de rank, sem recalcular essa curva.
A normalização fixa as pontas e permite ajustar o custo por skill. A raiz entrega
aumentos marginais decrescentes; não obriga toda skill a compartilhar custos.

## Corte: tabela autorizada

| Rank | Poder sobre ATQ corpo | SP |
|---|---:|---:|
| 1 | 1.45 | 15 |
| 2 | 1.65 | 17 |
| 3 | 1.85 | 18 |
| 4 | 2.05 | 19 |
| 5 | 2.25 | 20 |

Cooldown 4 s, alcance 155, cast fixo/variável e pós-cast adicional 0 em todos.
Peso corpo 1, precisão/magia 0; projétil 0, sem efeitos novos. Preservar abertura,
geometria, crítico e interrupção atuais. Rank 1 gratuito; melhorias custam um ponto
cada, requisitos anteriores preservados. Não introduzir seleção de rank inferior.

Do R1 ao R5: dano bruto +55,17%, custo +33,33%, dano por SP +16,38%.
Eficiência por SP não diminui entre ranks mesmo após arredondamento. O incremento
de dano é linear absoluto; o percentual de ganho por rank não cresce. A sensação
de especialização vem do dano maior e da eficiência, sem promessa de crescimento
exponencial. Mais custo por uso pressiona SP mesmo sem investimento em INT.

## Próxima execução delimitada

Liberar somente S0-C: integrar Corte com seu rank do snapshot, incluindo dano,
custo debitado, bloqueio por SP, preview e HUD. Não migrar restantes das skills.
Verificar primeiro se S0-B oferece a consulta esperada; corrigir incompatibilidade
necessária sem alterar contrato silenciosamente. Testar R1/R5, insuficiênciaSP,
isolamento do snapshot, parâmetros preservados e consulta inválida.

Lanças terão decisão própria: quantidade de projéteis já multiplica dano total;
não aplicar também aumento integral de poder por projétil sem balancear o total.
Pontos limitados e carteiras do E00 permanecem intactos. S0-D aguarda entrega.
