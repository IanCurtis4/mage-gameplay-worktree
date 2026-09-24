# E05-S2-SP0 — proposta de kit: Defendente e Berserker

Estado: **proposta documental para gate de Astra**. Base `5a83037`, branch
`codex/e05-evolutions`. Autorização: [E05_S2_SP_START.md](E05_S2_SP_START.md).
Não há IDs jogáveis novos, tabelas de produção ou alteração de código nesta entrega.

## Contrato recebido e fronteira da proposta

Já estão aprovados: origem fixa `swordsman`; identidades puras `defender` (2-1)
e `berserker` (2-2); primeira escolha em base 10/job 20; uma ativa exclusiva
R1 gratuita ao escolher; 19 pontos da base e 20 da evolução em carteiras
separadas; cinco ativas/dois passivos equipados; compra e equipagem manuais;
troca no menu com reembolso exclusivo e normalização de presets. O catálogo
de produção ainda declara ambos como `content_ready=false`. Referências:
[E00 elenco](E00_MVP_CLASS_CONTRACT.md),
[ADR de progressão](ADR_E00_01_CHARACTER_PROGRESSION.md) e
[E05-S1B](E05_S1B_HANDOFF.md).

A biblioteca base efetiva é a de E04: Corte, Investida, Parede de Escudos,
Provocar, Perseverança, Grito Perfurante, Fúria, Golpe Brutal, Raiva
Concentrada, Grito Aterrorizante; Resistência, Vigor e Sede de Sangue. Os
exemplos “Guarda breve/Frenesi” do [brainstorm](CLASS_ROSTER_BRAINSTORM.md)
não substituem essas skills. Tudo que segue, inclusive IDs, números e
sequências, é **proposta nova**, ainda sem aceite de identidade ou tuning.

Proponho cinco ativas e duas passivas exclusivas por destino. A entrada é a
única gratuita (`free_rank=1`, até R5 com quatro compras); todas as demais
começam em R0. Desbloqueios: ativa no job 20, passiva 23, ativas 25 e 28,
passiva 31, ativas 34 e 37. Cada compra custa um ponto da carteira de
evolução; ranks superiores exigem o rank anterior, sem outro gate de job.
Nenhuma skill nova exige comprar uma skill base. Isso mantém a entrada útil
mesmo quando o jogador chega a job 20 com a carteira base pouco investida.

## Defendente — ler a frente, manter corredor, responder

Loop solo: atacar com Contraforte e abrir uma janela curta de guarda; ler um
impacto frontal para preparar o próximo contra-ataque; fixar Marco de Guarda
num corredor; usar Trava de Linha para conter a aproximação e Avanço de
Muralha para realocar. A Onda troca o token de contra-ataque por cobertura em
área. Contra boss, impacto frontal ou projétil interceptado fornece token sem
adds; root/empurrão obedecem às imunidades do boss, enquanto dano, zona e
reposicionamento continuam úteis. Fraqueza real: flanco, ataques de área e
obrigação de sair do Marco quebram a eficiência defensiva; o kit não dá
mitigação omnidirecional nem cura em combate.

| Job / ID / nome propostos | Tipo e comportamento | R1→R5: parâmetro principal | SP R1→R5; recarga |
|---|---|---|---|
| 20 `defender_counterstroke` — Contraforte | Ativa de entrada, direção, alcance 120. Golpe direto de ATQ corpo, depois guarda frontal por 1,2 s com 15% de redução. Um evento frontal válido concede **um** token por 8 s; o próximo Contraforte o consome para bônus de dano. Funciona sem token. | Peso do golpe `1,05/1,25/1,42/1,56/1,68`; bônus com token `0,30/0,40/0,50/0,60/0,70` × ATQ corpo. | `16/18/20/21/22`; 6 s |
| 23 `defender_watch` — Vigília | Passiva: golpe melee direto que causa HP positivo aplica redução de dano causado ao alvo por 2,5 s, por fonte. Não dispara em DoT, escudo absorvido ou eco secundário. | `8/11/14%` em R1→R3. | Sem SP/recarga |
| 25 `defender_anchor` — Marco de Guarda | Ativa de ponto até 150 unidades; uma zona por dono, raio 100. Enquanto o jogador está dentro, fonte de +10% DEF física/mágica; inimigos dentro sofrem slow de 20%. Zona não é obstáculo. Nova colocação substitui a anterior. | Duração `4/4,5/5/5,5/6 s`. | `20/22/24/25/26`; 12 s |
| 28 `defender_line_lock` — Trava de Linha | Ativa direcional, faixa de 170 × 44 unidades; um pedido direto de `0,70 × ATQ corpo` por alvo e root físico após dano positivo. Boss segue teto/orçamento de CC; imune conserva o dano. | Root base `0,5/0,6/0,7/0,8/0,9 s`. | `18/20/22/23/24`; 9 s |
| 31 `defender_guard_return` — Resguardo | Passiva: evento frontal válido de guarda devolve SP uma vez por janela interna de 2 s, sem proc de dano. Exige evento real, não botão pressionado. | `2/3/4 SP` em R1→R3. | Sem SP/recarga |
| 34 `defender_wall_advance` — Avanço de Muralha | Mobilidade curta na direção escolhida, até um alvo por percurso, impacto direto de `0,80 × ATQ corpo`; empurra normais 35 unidades. Durante o trajeto dá 20% de mitigação frontal; boss não desloca. Navegação valida todo o segmento. | Distância máxima `80/95/110/120/130`. | `22/24/26/27/28`; 10 s |
| 37 `defender_reprisal_wave` — Onda de Represália | Ativa ofensiva: pulso de raio 130 no Marco ativo, ou no jogador se não houver Marco. Um pedido direto por alvo; token de guarda, se presente, é consumido para bônus e knockback de normais. Boss recebe bônus, sem deslocamento. | Peso `0,60/0,73/0,84/0,93/1,00` × ATQ corpo; token soma `0,35 × ATQ corpo`. | `24/26/28/29/30`; 12 s |

**Token de guarda proposto.** Apenas o evento frontal com dano direto
efetivamente mitigado por Contraforte/Parede de Escudos/Avanço, dano frontal
absorvido por Perseverança, ou projétil interceptado por Parede de Escudos,
concede token. Um mesmo impacto concede no máximo um; impactos adicionais
apenas renovam os 8 s, sem somar. O token não causa dano e não alimenta procs.
Contraforte e Onda o consomem no commit, após SP/alvo/geometria válidos; falha
ou cancelamento de cast não consome. Expiração, morte, fim de encontro ou troca
de run limpam. O evento de projétil bloqueado é booleano: não se resolve dano
hipotético uma segunda vez para precificar o token.

Contraforte e Onda são ofensivas e encerram Parede de Escudos antes de emitir
dano; o token capturado anteriormente permanece para esse commit. Marco e
Avanço são respectivamente defensiva e mobilidade: mantêm a postura, cuja
frente continua fixada conforme SW1. A mitigação frontal de Avanço e
Contraforte usa a maior fração frontal ativa, não soma à redução de 30% da
Parede; o bônus de DEF do Marco entra no cálculo canônico de stats. Vigília
usa o canal existente de **dano causado** do SW2: a maior redução por atributo
prevalece, até o teto de 50%, cada fonte com seu próprio prazo. Slow segue o
limite existente de 50%. Nenhuma skill do Defendente melhora Provocar ou
Perseverança de graça.

## Berserker — marcar, insistir, executar sob exposição

Loop solo: Ruptura abre uma ferida no alvo; golpes melee diretos seguintes
elevam a marca até três cargas; reativar Ruptura ou usar Execução converte as
cargas em dano. Salto e Fenda ampliam alcance/pressão; Arrancar Fôlego
fornece recuperação limitada contra alvo marcado sem depender de abate. Boss
acumula cargas com o mesmo loop e recebe o finalizador. Fraqueza real: as
janelas de Fúria e o custo de HP da Execução expõem o personagem; trocar de
alvo, errar golpes ou perder a janela da marca reduz o dano, e o kit não ganha
invulnerabilidade nem cura gratuita por ataque vazio.

| Job / ID / nome propostos | Tipo e comportamento | R1→R5: parâmetro principal | SP R1→R5; recarga |
|---|---|---|---|
| 20 `berserker_rupture` — Ruptura | Ativa de entrada, melee alvo único até 110. Primeira ativação dá golpe direto e, se tirar HP, põe ferida por 8 s com uma carga. Golpes melee diretos posteriores que tiram HP acrescentam uma carga até 3 e renovam 8 s; segunda ativação na mesma ferida detona e limpa, sem outro golpe inicial. | Peso inicial `1,00/1,12/1,22/1,31/1,38`; detonação `0,40/0,52/0,63/0,72/0,80` × ATQ corpo **por carga**. | `17/19/21/22/23`; 5 s após cada ativação |
| 23 `berserker_obstinacy` — Obstinação | Passiva: com HP atual até 50% do máximo na emissão do golpe, melhora apenas dano melee direto. Não amplia DoT, detonação secundária ou custo de HP. | `8/11/14%` em R1→R3. | Sem SP/recarga |
| 25 `berserker_wound_leap` — Salto Cruento | Mobilidade ofensiva até 140 unidades; um golpe direto num alvo atingido. Se já estava ferido, o golpe adiciona uma carga pela regra comum, não uma segunda carga própria. Sem alvo acertado, continua deslocamento válido, sem marca nova. Segmento de navegação continua seguro. | Peso `0,80/0,96/1,08/1,17/1,24` × ATQ corpo. | `18/20/22/23/24`; 8 s |
| 28 `berserker_execution` — Execução | Ativa melee alvo único até 110. Gasta 3% do HP máximo atual da build no commit, somente se restar pelo menos 1 HP; o custo não é dano recebido nem dispara procs. Impacto com HP positivo consome as cargas **anteriores** da ferida e soma `0,40 × ATQ corpo` por carga, sem criar carga nova. Com HP do alvo até 35% **antes** do impacto, o dano direto total recebe +20%; boss usa a mesma regra sem exigir morte. Sem ferida ainda causa o golpe base. | Peso base `1,20/1,40/1,60/1,75/1,90` × ATQ corpo. | `22/25/27/29/30`; 9 s |
| 31 `berserker_pursuit` — Caça Persistente | Passiva: golpe melee direto que tira HP de alvo já ferido recupera SP, uma vez por segundo por jogador; não conta o primeiro golpe que cria a ferida nem ticks secundários. | `2/3/4 SP` em R1→R3. | Sem SP/recarga |
| 34 `berserker_blood_rift` — Fenda Sangrenta | Ativa direcional, faixa de 220 × 44 unidades, preparo variável de 0,3 s. Pedido direto de `0,90 × ATQ corpo` por alvo e, após HP positivo, bleed físico de 4 s. Ticks são secundários, sem carga de ferida nem nova cascata. | Dano por segundo do bleed `0,10/0,12/0,14/0,16/0,18` × ATQ corpo capturado no commit. | `21/23/25/26/27`; 9 s |
| 37 `berserker_breath_steal` — Arrancar Fôlego | Ativa melee alvo único até 110: golpe direto; se o alvo já estava ferido e **sobrevive**, cura o jogador por fração do dano real, limitada a 5% do HP máximo por cast. Sem ferida ou num abate, apenas dano. | Peso `1,00/1,08/1,16/1,23/1,30` × ATQ corpo; cura `15/18/21/24/27%` do dano real. | `18/20/22/23/24`; 12 s |

**Ferida proposta.** Uma marca por jogador/alvo, no máximo três cargas,
renovação de duração sem somar além do limite. Só dano melee direto com
`actual_damage > 0` aumenta a marca; auto e skills diretas valem uma vez por
pedido, inclusive contra boss. O golpe de criação começa em uma carga, sem
contar duas vezes; Execução e a reativação de Ruptura não acrescentam carga.
Um golpe que erra ou tira 0 HP não consome a marca, mesmo após um commit que
gastou recursos. Detonação é dano secundário sem proc, com mitigação física
normal; só uma conversão por marca/commit. Troca de alvo deixa a marca antiga
expirar; morte, fim de encontro e retirada do jogador limpam. O gasto de HP
de Execução não gera ferida, Tensão, efeitos de dano recebido ou cura. Se a
ação falha em SP, alcance, alvo ou HP mínimo, não gasta HP, SP, recarga nem
marca. A janela de 8 s comporta a recarga de 5 s de Ruptura.

Fúria permanece a fonte E04 de bônus melee/ASPD com penalidade fixa de 25%
nas duas defesas; nenhum bônus Berserker altera ou duplica essa fonte. Sede de
Sangue permanece conversão da VIT **investida** e cura por abate único. A
cura de Arrancar Fôlego só ocorre em alvo sobrevivente, de modo que o mesmo
golpe não recebe também cura por abate da passiva. Golpe Brutal e Provocar
continuam usando o canal de DEF existente; nenhuma skill exclusiva propõe
segunda redução de DEF. Grito Aterrorizante continua sendo a fonte de +20%
dano recebido; ferida não adiciona amplificação desse canal. DoT de Fenda
segue limite e substituição por dono/skill/alvo de E00.2.

## Quatro builds completas de referência, no job 40

Ranks abaixo são **compras** efetivas, não presets gratuitos. `Contraforte`
e `Ruptura` aparecem como rank efetivo; seu R1 não custa ponto. Valores não
listados permanecem R0. Os pontos não gastos ficam livres; não há obrigação
de maximizar a árvore. Cada linha equipa exatamente cinco ativas e duas
passivas e conserva o auto sem slot.

| Build / decisão principal | Carteira base (até 19) | Carteira evolução (até 20) | Cinco ativas equipadas; duas passivas |
|---|---|---|---|
| Defendente: segurar corredor e reagir a boss | Parede de Escudos R5 (5), Perseverança R5 (5), Resistência R3 (3) = **13/19** | Contraforte R5 (4), Marco R5 (5), Trava R4 (4), Resguardo R3 (3) = **16/20** | Parede, Perseverança, Contraforte, Marco, Trava; Resistência, Resguardo |
| Defendente: realocação e pressão móvel | Corte R5 (5), Investida R5 (5), Vigor R3 (3) = **13/19** | Contraforte R3 (2), Avanço R5 (5), Onda R5 (5), Vigília R3 (3) = **15/20** | Corte, Investida, Contraforte, Avanço, Onda; Vigor, Vigília |
| Berserker: pressão contínua e execução no boss | Fúria R5 (5), Golpe Brutal R5 (5), Sede de Sangue R3 (3) = **13/19** | Ruptura R5 (4), Execução R5 (5), Arrancar Fôlego R4 (4), Caça Persistente R3 (3) = **16/20** | Fúria, Golpe Brutal, Ruptura, Execução, Arrancar Fôlego; Sede de Sangue, Caça Persistente |
| Berserker: mobilidade, múltiplos alvos e risco de HP | Investida R5 (5), Raiva Concentrada R5 (5), Vigor R3 (3) = **13/19** | Ruptura R3 (2), Salto R5 (5), Fenda R5 (5), Obstinação R3 (3) = **15/20** | Investida, Raiva Concentrada, Ruptura, Salto, Fenda; Vigor, Obstinação |

A primeira build Defendente tem resposta a frontal/projétil e sofre ao ser
flanqueada ou obrigada a sair do Marco. A segunda sacrifica essa sustentação
para mover e escolher o centro da Onda. A primeira Berserker joga no alvo
único, abre e consome a marca com risco de HP; a segunda distribui dano na
faixa e não dispõe da Execução nem de cura em combate. As duas respostas
Berserker contra boss vêm de acertos no próprio boss, sem kills.

## Pacotes implementáveis após o gate

Sequência proposta, sem autorização automática. Um dono escreve cada arquivo
compartilhado em cada pacote; quando outro executor assumir o mesmo arquivo,
o pacote anterior precisa estar fechado.

| Pacote | Executor e dono de escrita | Resultado verificável / dependência |
|---|---|---|
| SP1 — infraestrutura do primeiro kit | Sol; `ProfileCatalog`/`ClassCatalog`, dispatch por `evolution_id`, validação de compatibilidade | Revisar `catalog_version` e migração/aceitação de saves antigos **antes** de persistir o primeiro ID de skill de produção. Assentar a fronteira preview→snapshot→HUD→runtime; `content_ready` segue falso até fechamento. |
| SP2 — Contraforte e guarda | Sol; estado de evento frontal/token e aplicação canônica | R1 gratuito funcional, token único, orientação, mitigação sem soma, commit/cancelamento e boss. Este é o contrato novo crítico do Defendente. |
| SP3 — composição Defendente | Terra sobre APIs fechadas; arquivos de integração reservados no início do pacote | Marco, Trava e Avanço usando zona, geometria, debuffs e CC existentes; Onda usa o token aprovado. Se a zona ou a movimentação exigir nova fronteira compartilhada, voltar a Sol com reprodução mínima. |
| SP4 — ferida e Execução | Sol; estado da marca/raiz de dano e custo de HP | Ruptura R1, três cargas, segundo commit, boss, sem dupla contagem/cascata; Execução sem custo em falha. |
| SP5 — composição Berserker | Terra nas skills sobre primitivas aprovadas; Sol na cura por dano real se exigir novo contrato em `HealthState`/controller | Salto, Fenda, Arrancar Fôlego e passivas; preservar cura por abate de Sede de Sangue e limites de DoT. |
| SP6 — dados e fechamento do par | Luna em recursos de ranks/textos **separados** após handlers estáveis; condutor integra/testa, Astra revê o fechamento | Tabelas fechadas, duas builds por destino, troca/reload/presets, preview/snapshot/HUD/runtime e prova de boss. Só então afirmar `content_ready=true`; playtest e aceite de produto seguem o fluxo normal. |

Não passar cada skill por Sol, Terra e Luna em sequência. Sol concentra os
contratos novos, Terra compõe comportamentos quando as primitivas existem e
Luna registra dados fechados. A integração de `ClassCatalog`/`ProfileCatalog`
terá um dono por pacote para não editar o mesmo arquivo em paralelo.

## Casos de aceite e decisões do gate

- Job 20: um R1 gratuito utilizável por identidade, nenhuma compra/grant
  oculto; entrada não ocupa slot automaticamente. Job 40: quatro builds
  acima codificáveis e legais nas duas carteiras.
- Defendente: frente versus flanco; evento de projétil único; guarda+postura
  com orientação fixa; token consumido uma vez; Marco deslocado/substituído;
  root dentro do orçamento do boss; ausência de cura ou mitigação de área
  automática.
- Berserker: marca criada uma vez, três cargas máximas, expiração/troca de
  alvo, detonação ou Execução exclusiva por commit; HP próprio nunca abaixo
  de 1; dano secundário sem proc; boss sem adds; cura apenas em acerto válido.
- Ambos: R0/invalid, R1/R5, SP, cast/cancelamento, pausa, morte, limpeza,
  save/reload, troca de evolução, dois presets, snapshot isolado e paridade
  preview/HUD/runtime; nenhuma regressão dos 13 IDs base E04.

**Astra precisa decidir** se aceita (1) Contraforte como entrada híbrida de
golpe+janela frontal de 1,2 s com token booleano, (2) a ferida de três cargas
e o custo de 3% do HP máximo em Execução, (3) o pacote de cinco ativas/duas
passivas e os números iniciais, e (4) o critério de habilitação/versionamento
antes do primeiro save real. Essas são propostas de identidade e contrato;
nenhuma delas foi implementada ou promovida silenciosamente a regra vigente.

Validação desta etapa: leitura cruzada dos contratos E00/E03/E04/E05, dos
handoffs SW1/SW2/SW3/SW5/SW8/SW10 e do catálogo/runtime existentes; conferência
aritmética das quatro builds e dos limites de slot. Documento puro: não houve
importação ou suíte de Godot nesta etapa, conforme escopo S2-SP0.
