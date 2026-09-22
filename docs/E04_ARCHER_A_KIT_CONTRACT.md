# E04-AR-A — contrato mínimo do Arqueiro base

Base técnica: kit piloto do Mago encerrado em `c7206f7`. Este pacote fecha a
fronteira do Arqueiro e a ordem de implementação; não adiciona gameplay.

## Estado encontrado

- `IdentityIds`, atributos, progressão e apresentação já reconhecem `archer`.
- `ProfileCatalog` não possui skills do Arqueiro e corretamente mantém a classe
  indisponível; `ClassCatalog` ainda não possui sua `ClassDefinition`.
- `PlayerActor` trata todo personagem não Mago como melee, usa `melee_attack` e
  aplica o autoataque imediatamente. Isso viola a autoridade aprovada de DES/
  `precision_attack` e não oferece flecha esquivável ou bloqueável por obstáculo.
- `MageProjectile` contém colisão contínua útil, mas está acoplado ao Mago e para
  no primeiro alvo. Não há política compartilhada de perfuração para o jogador.
- Não existem runtime de armadilha, root, ocultação ou aquisição de alvo contra
  ator oculto. Essas mecânicas não podem ser simuladas apenas por dados de rank.

## Biblioteca e IDs fechados

O Arqueiro possui oito ativas na biblioteca, cinco slots ativos, três passivas e
dois slots passivos. Personagem novo continua em R0; aprender não equipa.

| ID | Nome visível | Targeting | Benefício prioritário | Primitiva |
|---|---|---|---|---|
| `double_shot` | Disparo Duplo | direção | dano total; dois projéteis fixos | projétil de precisão |
| `piercing_arrow` | Flecha Perfurante | direção | dano; perfuração previsível | múltiplos impactos |
| `arrow_rain` | Chuva de Flechas | ponto | dano total; área inicialmente fixa | área anunciada |
| `extended_aim` | Mira Estendida | próprio ator | duração; alcance limitado | buff temporário |
| `snare_trap` | Armadilha de Laço | ponto | duração limitada do root | armadilha + root |
| `explosive_trap` | Armadilha Explosiva | ponto | dano físico em área | armadilha + área |
| `slowing_arrow` | Flecha Entorpecente | direção | duração; slow moderado | projétil + slow |
| `foliage_shelter` | Abrigo de Folhagem | ponto | duração | área de ocultação |
| `archer_precision` | Precisão | passiva | HIT | fonte de stat |
| `archer_cadence` | Cadência | passiva | ataques por segundo | fonte de stat |
| `trap_technique` | Técnica de Armadilhas | passiva | permanência das armadilhas | fonte de regra |

`Targeting.SELF` deverá ser introduzido somente com Mira Estendida; não representar
buff próprio como clique arbitrário no chão. IDs, nomes e eixos de crescimento ficam
fechados aqui. Custos, tempos, poderes e magnitudes R1–R5/R1–R3 serão decididos no
pacote de cada skill, preservando a regra de não crescer dano, área e controle juntos.

## Contratos das primitivas

### Projétil de precisão

- Dano do Arqueiro usa `precision_attack` capturado em `physical_damage`; defesa
  física, HIT/FLEE, crítico e multiplicadores continuam no pipeline canônico.
- A direção é fixada na emissão: não há homing. Movimento do alvo pode esquivar;
  geometria bloqueia; alcance expira. O impacto não recalcula stats do emissor.
- A colisão contínua deve ser compartilhada com os projéteis atuais, sem copiar a
  matemática. Política de impactos explicita `max_hits` e impede acertar o mesmo
  ator duas vezes. O auto e Disparo Duplo usam 1; Flecha Perfurante usa mais de 1.
- Dois projéteis do Disparo Duplo são duas emissões do mesmo custo, sem proc oculto
  adicional por haver duas flechas. Balanceamento considera o dano total do par.

### Armadilha e controle

- Armadilha tem dono, skill de origem, posição fixa, raio, tempo de armação,
  permanência e estados `ARMING`, `ARMED`, `TRIGGERED`, `EXPIRED`.
- Ativar ou substituir remove a instância uma vez, sem detonação/recompensa extra.
  Teto inicial: três armadilhas por dono entre todos os tipos; a quarta substitui
  a mais antiga. Pausa congela timers. Morte/fim da run limpa instâncias.
- Root impede deslocamento, não aplica dano e não altera stats. Slow continua usando
  o status existente. Duração contra boss e imunidades serão fechadas no pacote do
  Laço, antes de implementar o efeito.

### Ocultação

- Abrigo cria área no chão. Jogador dentro dela fica indisponível para nova aquisição
  de inimigos externos; inimigo dentro da mesma área ainda pode adquiri-lo.
- Ocultação não concede invulnerabilidade, não apaga dano já emitido e não atravessa
  colisão. Autoataque ou skill ofensiva revela temporariamente; duração da área e da
  revelação pertencem ao pacote do Abrigo.
- Aquisição, retenção de alvo e retorno após revelação exigem um estado explícito;
  não esconder apenas o sprite nem alterar IA por nome de skill.

## Ordem autorizável

1. **E04-AR-B1:** projétil compartilhado de precisão + autoataque básico do Arqueiro.
2. **E04-AR-B2:** Disparo Duplo usando a primitiva pronta e sua tabela R1–R5.
3. **E04-AR-B3:** política perfurante + Flecha Perfurante.
4. Chuva de Flechas; Mira Estendida; runtime de trap; cada trap; Flecha
   Entorpecente; ocultação/Abrigo; passivas; duas builds e integração.

Cada item após B3 continua um pacote separado. Arqueiro não entra no seletor nem
fica disponível em perfil antes de possuir ao menos duas ativas e uma passiva
funcionais, conforme o gate atual de `ProfileCatalog`.

## Próximo pacote proposto

E04-AR-B1 deve adicionar a `ClassDefinition` mínima do Arqueiro e generalizar a
colisão de projétil do jogador para suportar dano físico de precisão, preservando
integralmente Bola de Fogo, lanças e auto do Mago. O auto do Arqueiro usa
`precision_attack`, trajetória fixa, HIT contestado e crítico; alcance, velocidade
e poder serão registrados na decisão B1.

Aceite: emissão capturada, ausência de uso de `melee_attack`, esquiva por movimento,
bloqueio por obstáculo, expiração por alcance, primeiro impacto único, pausa/limpeza
e regressão dos projéteis do Mago. Perfil/menu continuam indisponíveis nesse passo.
