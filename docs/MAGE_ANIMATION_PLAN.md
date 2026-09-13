# Bloco autorizado — Mago inicial e animações

Aceite do piloto `d76e7d3` recebido em 12/09/2026; integrado em master.
Novo bloco autorizado pelo usuário: animações e segunda classe. Em esclarecimento,
usuário escolheu começar por Bola de Fogo, Parede de Fogo, Lanças e Teleporte.
Bola de Fogo: crítico garantido enquanto o alvo estiver queimando.

## Entregas em sequência

1. Registrar contratos e catálogo do Mago, mantendo dados separados do estado da run.
2. Implementar e testar o kit jogável, seleção de classe e controles para cinco
   ações (lança de fogo e de gelo são variantes selecionáveis separadas).
3. Produzir spritesheets de animação e integrar caminhada, idle, ataque/conjuração,
   dano/morte com pivô estável. Começar pelo Espadachim e Mago; validar o ciclo antes
   de ampliar os inimigos. Primeiro passe direcional limitado, registrado no resultado.
4. Revisar interações e renderização, preparar rebase/FF no playtest fixo e aguardar
   aceite do usuário antes do merge. Cada passo terá commit e evidências de retomada.

## Regras de partida deste piloto

Valores são iniciais para playtest e devem ficar em catálogo, sem fórmulas na UI.

| Ação | Comportamento inicial |
|---|---|
| Auto do Mago | Projétil mágico em alvo selecionado, alcance médio e perseguição assistida |
| Bola de Fogo | Direcional, velocidade 680 u/s, alcance máximo 700; primeiro inimigo ou parede interrompe; crítico garantido se queimando no impacto |
| Parede de Fogo | Quatro pilares, perpendicular à direção da mira, centro a 180 u do jogador; fica no chão após lançar, dura 5 s; atravessável; aplica queimadura por 3 s |
| Lança de Fogo | Alvo único assistido, alcance 360; segue alvo e colide com parede; +50% dano se queimando no impacto |
| Lança de Gelo | Mesmo contrato de alvo; lentidão de 30% por 2 s ao atingir |
| Teleporte | Ponto de chegada até 320 u, atravessa obstáculos; chegada bloqueada/inválida rejeita sem gastar recursos; cancela caminhada/perseguição anteriores |
| Investida do Espadachim | Dash em movimento visível, preservando o limite de 270 u e colisão com obstáculos |

DoT renova duração sem multiplicar ticks pela sobreposição dos quatro pilares.
Ticks são secundários, sem crítico e sem cascatas. Precisão/crítico/dano continuam
em CombatMath. Queimadura e lentidão são estado de cada ator e congelam em pausa.
Nova aplicação de slow não multiplica reduções indefinidamente.

Lanças começam com uma unidade. Contagem deve aceitar modificador por ID e um
augment do Mago demonstra +1 lança por stack. Níveis de skills ficam no estado da
run com padrão 1, sem tela de aprendizado ou progressão neste bloco.

Mage usa atributos 2/5/5/9/7/2 do contrato e passiva simples de regeneração de mana.
Espadachim mantém a resistência. A troca de classe inicia uma run nova, explicitada
na UI, e limpa projéteis, paredes, efeitos, augments, recursos e cooldowns.
Mapeamento proposto: Q/W/A/S/D para as cinco ações; E continua augment e R reinício.
O modo padrão continua selecionar e confirmar por clique. Soltar/smart cast e
cancelamentos mantêm os contratos atuais. Nenhuma classe recebe a skill da outra.

## Futuro registrado, fora deste bloco

- Parede de Gelo: obstáculo temporário bilateral; integrar navegação dinâmica,
  impedir nascer sobre atores, recalcular rotas na criação/expiração, testar quinas.
- Assombro: cone com fear e redução de dano; duração, resistência e comportamento
  de fuga serão definidos no bloco correspondente.
- Barreira Fantasma: bloqueia projéteis; atravessável por atores, aplica slow e
  redução de dano a inimigos; jogador imune. Definir interação com tiros aliados.
- Classes expandidas/híbridas, aprendizagem/níveis de skill, passivas compostas,
  equipamentos/cartas/save e restante do Marco 2 exigem escopo próprio.
- Chão 3D e ice physics continuam posteriores.

## Validação necessária

Colisão contínua e ordem do primeiro contato (alvo antes/depois de parede), burn
ativo/expirado no impacto, renovação sem dano quadruplicado, slow sem alterar stats
base, multi-lanças com custo único, alvo morto/inválido, teleporte através de parede
com destino livre e rejeição de destino sólido, dash bloqueado, pausa e reset limpos,
troca de classe e regressão do Espadachim. Rodar `tools/verify.ps1` e revisar sprites,
miradores, HUD e eventos de animação no renderer real.
