# E04-SW2 — Provocar

Base: `bddb478`. Escopo: Provocar e infraestrutura mínima de debuffs por
fonte/atributo prevista no pacote do Espadachim. Sem alterações em master ou
playtest.

## Design

Alvo único em até 300 unidades, ativação instantânea, ação defensiva compatível
com Parede de Escudos. O alvo persegue e ataca o jogador por duração de rank;
arqueiros deixam de manter distância/fugir. Fear e stun prevalecem, root impede
movimento, sem apagar ataques/projéteis já emitidos. O alvo também perde 25% da
DEF física e 30% da FLEE por 4 s, em canais independentes. Essas frações não
escalam com rank. Recarga base: 10 s, iniciada na ativação.

| Rank | Provocação | SP |
|---|---:|---:|
| R1 | 2,0 s | 14 |
| R2 | 2,4 s | 16 |
| R3 | 2,8 s | 18 |
| R4 | 3,2 s | 19 |
| R5 | 3,6 s | 20 |

R0 não equipa. Ranks são recursos de catálogo imutáveis; estado temporário
fica no ator. HUD, menu, mira e slots usam a mesma definição persistente.

## Debuffs por fonte

`AttributeDebuffState` guarda cada aplicação por atributo e fonte, com duração
própria. A maior fração ativa prevalece sem soma; expirada, a fonte mais fraca
continua pelo próprio tempo. Reaplicar a mesma fonte substitui somente sua
instância. Limites: DEF física/mágica 60%, FLEE/movimento/ASPD/dano causado/
dano recebido 50%. `StatCalculator.runtime_reduced_value` aplica limites dos
stats derivados; defesa não fica negativa. Dano recebido compõe uma cópia de
`DamageRequest` no impacto, sem alterar o snapshot emitido. Assombro, Barreira
Fantasma, Lança de Gelo e Flecha Entorpecente agora informam IDs de fonte.
Cada instância da Barreira Fantasma usa seu próprio ID runtime, preservando
durações independentes de duas barreiras simultâneas.
DoT, marcas e hard CC permanecem separados.

## Evidência e limite

`tests/e04_swordsman_provoke_rank_integration_test.gd` cobre R0/R1/R5/R6,
custos/recarga, postura defensiva via classificação, perseguição do arqueiro,
pausa/limpeza e precedência/durações dos canais. `tools/verify.ps1` completo
passou no Godot 4.7.2, incluindo regressões dos três kits. Balanceamento e
legibilidade do indicador aguardam playtest. Boss não tem rotina especial de
IA neste runtime; a provocação não introduz cancelamento de padrões especiais.
