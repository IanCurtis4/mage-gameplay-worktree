# E05 — checkpoint único do Espiritualista

## Autorização, base e divisão de trabalho — 29/09/2026

O usuário aprovou o Elementalista no candidato `ce87065` e liberou a evolução
`spiritualist` do Mago, com entrega de skills uma a uma e checkpoint único da
classe. Astra cuida do atlas e dos sprites/animações das skills, em arquivos
visuais próprios; Sol é dono de runtime, dados críticos, testes, integração e
deste checkpoint. Sem handoff/gate por microtarefa. Revisão de Astra somente
após o escopo completo, seguida de playtest do usuário. `codex/playtest` só
pode avançar após aprovação técnica de Astra; `master` aguarda aceite de
produto explícito. Não começar Arqueiro ou próximo épico.

Base `ce87065`, branch `codex/e05-evolutions`. Contratos: E00_MVP_CLASS_CONTRACT,
ADR_E00_01_CHARACTER_PROGRESSION, MVP/ARCHITECTURE e WORKFLOW. Origem persistente
`mage`; sete exclusivas nos jobs 20/23/25/28/31/34/37; primeira ativa R1
gratuita sem autoequip; carteiras base19/evolução20, cinco ativas e dois
passivos equipados. Herança do Mago segue comprada. O kit precisa de duas builds
legais e loop em boss solo. `content_ready=true` após integração validada.

## Kit finito — escolhas de implementação dentro do contrato

Inspiração do brainstorm: Maldição do Eco, Drenagem canalizada e Procissão de
espectros, não uma especificação de números. Identidade nova: fixar uma maldição
de oportunidade, decidir qual golpe a consome, sustentar ou interromper a
canalização e lançar manifestações curtas sem cadáveres/summons permanentes.
Fraquezas: janela de canal exige ficar imóvel e alvo/linha estáveis; maldição
precisa de segundo golpe positivo; trocar de alvo ou errar perde eficiência.
`Assombro`/`Barreira Fantasma` da base continuam herdadas e não são rebatizadas.

| Gate e skill | Contrato R1; ranks seguintes | SP R1→R5; CD/cast |
|---|---|---|
| 20 ativa gratuita `spiritualist_echo_curse` — Maldição do Eco | Alvo único até 380, impacto direto mágico `0,85/1,00/1,12/1,22/1,30 × ATQM` por rank. Após HP positivo num sobrevivente marca por 5 s; reaplicação renova, sem acumular. Próximo acerto direto positivo elegível do jogador nesse alvo (exceto nova Maldição e Dissipação) consome marca e agenda um único eco de `0,35/0,42/0,49/0,55/0,60 × ATQM` capturado no gatilho, após 0,35 s. Eco é secundário, revalida existência do alvo, sofre mitigação atual e não gera procs/cura/novo eco. Erro/escudo não consome. | `18/20/22/23/24`; 6 s / 0,35 s |
| 23 passiva `spiritualist_echo_recovery` — Recolhimento | Quando a marca produz um eco por dano direto elegível, restitui `2/3/4 SP`; uma vez por emissão e uma vez por segundo por jogador, até SP máximo. Não depende do dano posterior do eco, nem dispara por DoT/secundário. | Sem SP/CD |
| 25 ativa `spiritualist_soul_drain` — Drenagem Espiritual | Canal de alvo até 350 por 2 s, quatro ticks a 0,5/1,0/1,5/2,0 s. Cada tick causa `0,36/0,42/0,48/0,54/0,60 × ATQM` capturado no commit e cura 15% do HP real removido, com teto agregado de 5% do HP máximo do jogador por canal. Só o primeiro tick é raiz direta (pode consumir maldição); demais são secundários. Revalidar vivo/range/LoS a cada tick. Movimento, outro comando de cast, controle, dano recebido ou morte interrompem próximos ticks; SP/CD já gastos não retornam. Nenhum tick em alvo inválido. | `22/24/26/28/30`; 10 s / preparo 0,30 s + canal 2 s |
| 28 ativa `spiritualist_spectral_veil` — Véu Espectral | Zona de ponto até 250, raio 110, duração `3/3,5/4/4,5/5 s`. Uma por jogador; recolocar substitui. Inimigos dentro recebem redução de dano causado de 15% por fonte, renovada enquanto dentro, sem dano nem obstáculo. Reutiliza canal/teto do AttributeDebuffState; boss solo recebe enfraquecimento, não exige adds. | `20/22/24/25/26`; 12 s / 0,25 s |
| 31 passiva `spiritualist_channel_focus` — Foco do Além | Completar os quatro ticks válidos de uma Drenagem sem interrupção gera uma carga por 5 s, no máximo uma. Próxima Maldição ou Dissipação válida consome no commit para adicionar `0,20/0,30/0,40 × ATQM` bruto ao primeiro impacto direto; falha/cancelamento não consome. Não amplia ecos, ticks ou DoT. | Sem SP/CD |
| 34 ativa `spiritualist_procession` — Procissão de Espectros | Três aparições para um alvo único até 380, nas saídas 0/0,20/0,40 s, cada uma com viagem visual e impacto 0,22 s após saída. Cada impacto `0,45/0,50/0,55/0,60/0,65 × ATQM` capturado no commit; primeiro é direto, dois seguintes secundários. Revalidar alvo/LoS a cada impacto e cancelar restantes se inválidos. Um boss sozinho recebe as três; não exige morte/cadáver nem deixa companion permanente. | `24/26/28/29/30`; 10 s / 0,40 s |
| 37 ativa `spiritualist_dissipation` — Rito de Dissipação | Ponto até 330, raio 100, cast 0,60 s. Uma raiz direta por alvo de `0,85/1,00/1,12/1,23/1,32 × ATQM`; alvo previamente amaldiçoado recebe +`0,55 × ATQM` bruto no mesmo pedido e só perde a marca após HP positivo. O rito não gera eco da própria marca. Após dano positivo em sobrevivente aplica redução de dano causado de 20% por 2 s, mesmo canal do Véu (maior fração prevalece). Sem marca, ainda atinge normalmente. | `27/29/31/32/33`; 14 s / 0,60 s |

Todas as distâncias usam a geometria única de runtime/previews. Cast é ajustado
pela DES pelas regras compartilhadas. Acerto direto usa DamageRequest e
StatCalculator; nenhuma fórmula de dano é duplicada no ator/UI. Ticks/eco não
alimentam procs; uma emissão não cria cascata. Marca/carga/zona/canais são
estado da run, nunca Resource de catálogo nem save. Cancelamentos, pausa,
morte, fim de encontro e reload removem estado e nós temporários. Efeitos do
mesmo canal por fontes diferentes usam máximo, nunca soma. Ao entrar com
catálogo novo, migrar aditivamente catalog_version5→6, mantendo saves reais
inalterados até o próprio jogador fazer uma operação; pré-flight/backup do
ProfileStore e testes de versão futura continuam obrigatórios.

## Brief para os assets do Astra — bloqueio visual apenas, não de regras

Atlas `spiritualist` 4 colunas × 8 linhas de células 64×64, pivô lógico
`(32,58)`, 32 poses nos estados de CharacterAnimation: frente idle/walk/cast,
costas walk/idle/cast, frente/costas hurt/death. Passos distintos, botas no
chão, transparência genuína e silhueta do Espiritualista puro (não ranger do
mood antigo). Fenômeno pálido/prata/azul-cinza/carvão, tecido ritual, névoa,
véus e crescentes; não recolorir Elementalista. O pacote final do Astra está
em `649db5e`, com atlas, quatro famílias VFX e pranchas. As texturas já foram
importadas no Godot 4.7.2; Sol integra o atlas e conecta os VFX aos eventos.

Sprites/VFX necessários, com âncoras/tempo autoritativos:

- Maldição: glifo compacto sobre o alvo ao impacto, marca sutil por 5 s e
  fratura espectral após eco disparado em +0,35 s; alvo visual pés/corpo.
- Drenagem: vínculo caster(peito −24 px)→alvo(corpo −18 px) durante canal 2 s,
  quatro ondas em 0,5 s; interromper/dissipar sem fantasma remanescente.
- Véu: círculo no chão de raio 110 e névoa/tecido rítmico por 3–5 s; não
  ilustrar bloqueio de navegação, dano ou área maior que o teste real.
- Procissão: três aparições sem corpo persistente em 0/0,20/0,40 s, trajeto
  caster→alvo e impacto em 0,22/0,42/0,62 s; dissipação rápida, boss solo.
- Dissipação: crescente/anel ao ponto, raio 100, com segunda leitura se marca
  consumida após HP positivo; manter legível sob sprite e telégrafos inimigos.
- Passivas: feedback breve e discreto no caster para restituição real de SP
  ou carga obtida/consumida; não sugerir buff/proc quando não aconteceu.

Assets de arte não mudam hitbox, tempo, custo, regra ou RNG. Sol pode usar
desenho temporário code-native nas fixtures, mas não gerar/editar bitmaps do
Astra. Contrato de apresentação deve expor eventos reais do runtime, com
fila finita, pausa e limpeza. Testar redução na resolução nativa, piso claro
e escuro, frente/costas e sobreposição com HUD.

## Duas builds legais de referência no job 40

Rank efetivo da Maldição inclui R1 gratuito; valor entre parênteses é gasto.
Cada build equipa cinco ativas e duas passivas; resto da biblioteca fica
disponível para compra futura, sem compra/equipagem implícita.

| Build | Base ≤19 pontos | Evolução ≤20 pontos | Equipados |
|---|---|---|---|
| Assombração e canal em boss | Impacto das Almas R5(5), Barreira Fantasma R5(5)=10 | Maldição R5(4), Drenagem R5(5), Procissão R3(3), Recolhimento R3(3), Foco R3(3)=18 | Maldição, Drenagem, Procissão, Impacto, Barreira; Recolhimento, Foco |
| Campo e ruptura | Parede de Gelo R5(5), Regeneração de Mana R3(3)=8 | Maldição R3(2), Véu R5(5), Procissão R3(3), Dissipação R5(5), Recolhimento R2(2)=17 | Maldição, Véu, Procissão, Dissipação, Parede; Mana, Recolhimento |

## Plano e retomada

1. **Contrato/checkpoint e migração segura**, depois catálogo ainda indisponível.
2. **Maldição do Eco** ponta a ponta: alvo/impacto/marca/consumo/eco retardado,
   boss solo, hit nulo, cancelamento, pausa e limpeza.
3. **Recolhimento**, deduplicação de emissão e SP real.
4. **Drenagem canalizada**, interrupção e cura limitada.
5. **Véu**, canal de debuff compartilhado e expiração da zona.
6. **Foco do Além**, carga por canal completado e consumo em cast válido.
7. **Procissão**, três aparições/impactos sem companion persistente.
8. **Rito de Dissipação**, consumo por dano positivo e interação de fontes.
9. **Integração visual do Astra**, catálogo content_ready apenas com kit completo;
   duas builds, migração, menu→run, boss, regressões e verify.ps1 integral.

Commits pequenos e testes dirigidos ao fim de cada item; revisão Astra somente
no fechamento. Registro de hash/resultados abaixo será atualizado conforme
execução. Tempo/tokens por skill só se houver medição atribuível real, não
estimativa inventada. As sete skills, dois presets de personagens distintos,
menu→run e boss solo estão implementados. `content_ready=true`. O teste
integrado revelou e corrigiu o cabeçalho que mostrava “Mago” mesmo usando o
Espiritualista; agora toda evolução pronta usa o próprio nome. A primeira
revisão consolidada de Astra (`docs/REVIEW_E05_SPIRITUALIST_ASTRA.md`) encontrou
quatro ajustes de integração, corrigidos em rodada única: canal interrompido
solta a pose de cast sem apagar um novo cast, halo usa pivô de chão `(48,63)`,
ticks de Drenagem e restituição real de SP têm wisps alvo→caster em fila
finita, e as duas builds executam loops determinísticos contra boss solo.
O redraw cobre também o frame em que o último efeito expira. Astra aprovou
tecnicamente o delta `a4c34f3` após inspeção e 153 checks independentes.
O candidato foi preparado em `codex/playtest` no projeto fixo, com 208 checks
dirigidos PASS no destino. Aguarda playtest do usuário. A inspeção de legibilidade
e FPS com muitas skills simultâneas continua dependente do playtest.

Renderização com Godot 4.7.2 standard/OpenGL real: o probe opcional
`tools/spiritualist_renderer_probe.gd` gerou
`.godot/verification/spiritualist_renderer_probe.png` (halo/ritual) e
`.godot/verification/spiritualist_return_renderer_probe.png` (wisp em trânsito).
Inspeção visual confirmou a âncora do halo no círculo autoritativo e o pulso
entre alvo e caster. O modo `--headless` usa renderer fictício e não serve
para capturar a imagem; rodar o probe com `--rendering-method gl_compatibility`
sem `--headless` quando necessário. Capturas são locais/ignoradas pelo Git;
o usuário ainda precisa avaliar a leitura na partida.

| Item concluído | Commit | Testes | Próximo |
|---|---|---|---|
| Contrato do kit | `c129fb0` | conferência documental | 1 — migração |
| Migração aditiva 5→6 | `8a38869` | 14 checks novos + 34 regressões anteriores | 2 — Maldição |
| Arte fonte e atlas Astra | `649db5e` | importação Godot 4.7.2 sem erro; inspeção Astra documentada | integração visual após regras |
| Maldição do Eco | `2f868d5` | 29 checks novos; catálogo de evolução 65 checks | 3 — Recolhimento |
| Recolhimento | `ff8f99b` | 16 checks novos + 29 de Maldição | 4 — Drenagem |
| Drenagem Espiritual | `1a01628` | 24 checks novos + catálogo de evolução 65 checks | 5 — Véu |
| Véu Espectral | `067447f` | 19 checks novos + catálogo de evolução 65 checks | 6 — Foco |
| Foco do Além | `2c0b9ed` | 17 checks novos + regressões Drenagem e catálogo | 7 — Procissão |
| Procissão de Espectros | `9f94f6e` | 18 checks novos + catálogo de evolução 65 checks | 8 — Dissipação |
| Rito de Dissipação | `07e71e9` | 18 checks novos + catálogo de evolução 65 checks | 9 — fechamento |
| Fechamento integrado | `f8c59f0` | 72 checks de builds/menu→run/boss + 18 visuais; `tools/verify.ps1` integral | revisão técnica Astra |
| Ajustes da revisão Astra | `a4c34f3` | Drenagem 28, visuais 23, integração 86 checks; renderer real e nova regressão integral | playtest do usuário |

## Adendo de playtest — treino de boss e evolução fixa (30/09/2026)

Solicitação posterior ao candidato `08c7817`, ainda não incorporada ao
`codex/playtest` até revisão técnica consolidada. No menu, o modo admin de testes
agora abre um treino com a build salva do personagem em foco, sem criar sessão de
recompensa, incrementar contadores ou escrever no perfil. A arena contém um
Guardião de Treino com 50.000 HP, silhueta ampliada usando o sprite existente e
barra de vida legível. A cada 8 segundos ativos entram até dois reforços de
1.500 HP, alternando melee/ranged e limitados a seis simultâneos. Posições são
validadas contra navegação, obstáculos, jogador e outros inimigos. Pausa, morte,
vitória, saída e reinício encerram ou reiniciam o agendamento; não há pickup,
XP ou augments no treino. O menu oferece saída e reinício antes e após o combate.
O dano recebido no treino usa multiplicadores de cenário de 0,18 no boss e 0,15
nos adds para permitir observar rotações longas; a resolução central de dano não
é alterada. Os valores são constantes explícitas da cena.

A primeira evolução continua no fluxo normal. Após escolhida, outra identidade
fica bloqueada tanto na lista quanto na API transacional comum. A troca existe
apenas como operação explícita do modo admin: confirmação atual → nova, aviso de
reembolso/slots dos dois presets e a mesma transação atômica pré-existente.
Fechar o modo admin, cancelar, mudar personagem ou falhar por estado inválido
descarta a intenção. Saves anteriores não são migrados nem alterados por essa
regra. O ADR E00.1 registra a substituição da permissão antiga de troca livre.

Validação deste adendo: `tests/e05_training_boss_test.gd` (menu→cena real,
snapshot isolado, pausa, reforços/cap, navegação, vitória sem recompensa e
reinício), testes E05 de catálogo/transação/menu e `tools/verify.ps1` completo.
A legibilidade visual e o ritmo de combate ainda dependem do playtest do usuário.

Revisão Astra do commit `812a49f`: a suíte independente passou, mas identificou
um P2 visual — `CharacterAnimation.draw_on` substituía a transformação do
`CombatActor`, anulando a ampliação do sprite vivo. A correção compõe escala e
flip no próprio desenho da animação, com padrão 1 para todas as outras classes.
`tools/training_boss_renderer_probe.gd`, executado com renderer OpenGL real,
mediu a área opaca do sprite em 45×50 px (normal), 81×90 px (boss) e 81×90 px
(boss espelhado), com a borda dos pés preservada em até 1 px. Capturas ficam
somente em `.godot/verification/`, ignoradas pelo Git. Esta evidência não
substitui a avaliação visual e de ritmo do usuário durante a partida.

## Aceite técnico do adendo e candidato de playtest — Astra, 30/09/2026

Candidato de runtime aprovado: `8214162`, sobre `812a49f`. A revisão inicial
confirmou isolamento do treino e bloqueio da troca normal na fachada, mas
identificou que CharacterAnimation sobrescrevia a escala externa do boss.
A correção compõe escala e espelhamento dentro do desenho da animação,
preservando o pivô dos pés e escala padrão 1 para as demais classes.

Astra reproduziu a suíte integral em `812a49f` (exit 0, log local ignorado
`.tools/training_astra_verify.log`). A suíte integral do delta `8214162`
passou na execução do implementador. Astra reproduziu independentemente o
probe OpenGL real: sprite normal 45×50, boss 81×90, espelhado 81×90,
borda inferior 181/182 px, PASS; também repetiu treino integrado17.

Projeto habitual estava limpo em `08c7817`; referência de backup
`codex/backup-training-pre-playtest-20260930` preserva o candidato `8214162`.
Base já ancestral, sem necessidade de reescrever commits. Avanço fast-forward
para `8214162`; importação Godot4.7.2 sem erros. No destino, treino17,
transação51, menu25 e admin12 passaram (105 checks). Checkout limpo antes
deste registro exclusivamente documental. Master continua `ce87065`.

Para testar: abrir projeto habitual, recarregar se solicitado, F5, destacar
personagem e ativar Modo admin de testes → Treinar contra boss e reforços.
Boss50.000HP, adds1.500HP a cada8s (até6 vivos), reiniciar/sair disponíveis.
Primeira evolução permanece normal; troca posterior exige admin e confirmação.
Treino não concede XP/recompensas. Não foram usados saves reais como fixtures.

Aceite técnico não substitui avaliação de ritmo, legibilidade e balanceamento
pelo usuário. Espiritualista/adendo aguardam aceite de produto; Arqueiro não
foi liberado e nenhum merge em master foi realizado.

## Adendo de legibilidade de combate — candidato para revisão Astra

O playtest apontou que os efeitos do Espiritualista eram bonitos, mas não
permitiam distinguir com segurança a marca, o Eco preparado e o dano do Eco.
O pacote conserva fórmulas, durações, custo, slots, persistência e bitmaps. A
Maldição agora apresenta anel de duração e elo aberto; o acerto direto troca a
marca por arcos convergentes e aviso `ECO PREPARADO`; somente dano efetivo do
Eco produz `ECO! N` e pulso duplo. Absorção completa informa `ABSORVIDO`, sem
falso sucesso. Rito positivo rompe a marca com fragmentos e `MARCA DISSIPADA`,
sem armar Eco. Expiração focada é discreta e não usa pulso de impacto.

Drenagem expõe ticks resolvidos `N/4`, interrupção e cura efetiva; Foco usa
losango/temporizador no personagem, com feedback de concessão/consumo. O
enfraquecimento mostra somente a fonte efetiva mais forte de dano causado,
com tempo restante, sem somar fontes. O painel contextual compacto mostra o
alvo focado e estados reais, com transições recentes quando o texto de mundo
fica encoberto. As rotas expandidas aparecem apenas para ações equipadas e
passiva de Foco instalada. Textos de combate ganham contorno e empilhamento
somente em runs do Espiritualista; outras classes mantêm sua apresentação.

Evidência: `tests/e05_spiritualist_readability_test.gd` cobre 38 checks de
marca, preparo, absorção, múltiplos alvos, Rito, debuff, pausa, expiração,
Drenagem 0/1/3/4 ticks, Foco, limpeza, conversão dentro do `_process` por
Drenagem/Procissão e ausência de dereferência em run piloto sem snapshot.
Uma revisão Astra de `ca2f66c` detectou que a sincronização ao fim do frame
confundia consumo da marca com expiração e que números/status competiam pela
mesma posição. O ajuste anuncia expiração imediatamente após o avanço temporal
da marca, antes de qualquer impacto de skill no frame. Números e estados agora
compartilham até três faixas finitas por ator, com remoção do aviso mais antigo
sob pressão. Durante o fade, avisos do Espiritualista permanecem fixos nas
faixas para não convergir sobre os vizinhos; o painel não é necessário para
decifrar o texto no mundo. O probe ignorado
do Astra (`.godot/verification/astra_readability_probe.gd`) passou 32 checks
após as correções; os casos relevantes estão cobertos no teste versionado.

O probe OpenGL real
`tools/spiritualist_readability_renderer_probe.gd` reproduz boss e reforços
com capturas locais ignoradas em `.godot/verification/`, verificando onze
etapas (inclusive Eco após 0,18s, ajuda expandida, Drenagem, Foco,
enfraquecimento e dois alvos)
e ausência de sobreposição entre painéis
em 1280×720. `tools/verify.ps1`
integral passou com Godot 4.7.2 standard após a implementação. Permanecem
para o playtest humano a leitura em movimento, densidade de efeitos e FPS em
combate prolongado. Este adendo é do mesmo checkpoint de classe; não libera
outros épicos nem autoriza merge em `master` antes do aceite do usuário.

## Direção visual revisada — almas incorporadas ao combate

A direção de `E05_SPIRITUALIST_COMBAT_READABILITY.md` substitui o aceite visual
do adendo acima: avisos espirituais flutuantes e painel contextual ficam
desligados por padrão, preservados apenas por um interruptor interno de
depuração. A explicação principal agora é a alma de quatro frames já aprovada
(`spiritualist_soul_wisp.png`), com rosto legível, contorno local e movimento
preso ao estado real. Os números gerais de dano continuam disponíveis na
partida; o probe de renderer os desliga somente para comprovar a leitura sem
texto. Nenhuma fórmula, duração, custo, slot, save ou progressão foi alterado.

Duas almas orbitam o torso marcado e seguem o alvo móvel; as mesmas convergem
durante o Eco pendente. Eco efetivo desprende vestígio do sprite do alvo e
expulsa almas, enquanto absorção total é amortecida, expiração sobe sem pulso
de dano e Rito arranca almas radialmente. Enfraquecimento usa almas baixas,
reduzidas a uma quando a marca já ocupa a silhueta. Véu mantém wisps no chão e
sinaliza entrada/saída do alvo conforme a aplicação autoritativa, sem novo
burst em cada refresh. Drenagem liga os torsos com caudas ondulantes e só
apresenta extração/recepção quando há dano/cura reais; Procissão reage a cada
impacto real; Foco permanece como alma-companheira no ombro até consumo ou
expiração. A fila cosmética é finita e limpa no fim da run.

Evidência automatizada: `tests/e05_spiritualist_soul_presentation_test.gd`
cobre 26 checks em arena real, incluindo boss móvel, escudo, expiração,
Rito, Véu com entrada/saída/reentrada/fim e sem spam de refresh, Drenagem
com e sem cura, interrupção, Foco, seis adds, limite da fila, pausa e limpeza.
O teste de legibilidade anterior permanece, com texto de diagnóstico ativado
explicitamente, para proteger os contratos já corrigidos. O probe OpenGL real
`tools/spiritualist_soul_renderer_probe.gd` captura 22 estágios em
`.godot/verification/spiritualist_souls_*.png`, ignorados pelo Git, em
1280×720 e escala de gameplay, sem painel, avisos espirituais ou números.
As sequências incluem convergência temporal, expulsão, absorção, subida da
expiração, Rito, Véu e combate com seis reforços. O resultado é visualmente
inspecionável, mas FPS sustentado e clareza durante movimento livre ainda
dependem de playtest humano. Astra revisa este pacote integrado antes de
preparar o projeto habitual; não há aceite de produto nem merge em `master`.

## Aceite técnico de VFX corporais — Astra, 30/09/2026

Runtime aprovado para playtest: b204086, sobre a direção ad3b1db. Revisão de
código não identificou bloqueadores: composição consulta estados/resultados
reais, mantém filas finitas e não altera fórmulas/save/progressão. Almas no
torso comunicam marca/preparo; expulsão e vestígio distinguem Eco efetivo de
absorção/expiração. Enfraquecimento fica junto aos pés; painel e avisos
espirituais são opcionais internamente e ficam desligados por padrão.

Evidência independente Astra: apresentação26 PASS, renderer OpenGL real22
PASS e inspeção de marca/convergência móvel/expulsão/absorção/expiração/Véu,
Drenagem/Foco e seis adds, sem textos/números. tools/verify.ps1 integral em
b204086 estável terminou exit0, sem alterações concorrentes. Log local ignorado:
.tools/souls_astra_verify.log no projeto fixo. O implementador também relatou
suíte integral exit0; esta rodada foi reproduzida independentemente.

Base ad3b1db já ancestral; não foi necessário novo rebase. Backup
codex/backup-souls-pre-playtest-20260930 preserva a base anterior. Projeto fixo
avançado por fast-forward para b204086. No destino, apresentação26 PASS e
inicialização headless da cena principal PASS. Importação adicional do editor
registrou erro de cópia/carregamento da DLL do Godot Git Plugin local, com outro
editor aberto. Não houve parse error GDScript. A DLL temporária versionada
removida por essa importação foi restaurada exatamente de HEAD; configuração
e instalação do usuário preservadas. A árvore ficou limpa antes deste registro.

Para testar, parar a partida anterior, recarregar alterações no Godot e F5;
Modo admin de testes → Treinar contra boss e reforços com o Espiritualista.
Avaliar principalmente leitura dos estados em movimento e densidade de almas.
Capturas controladas não comprovam FPS sustentado nem aceite subjetivo do loop.
Master permanece ce87065; merge e classes do Arqueiro aguardam aceite do usuário.
Puxada de almas, contágio, intangibilidade e fantasmas homing são brainstorming
futuro e não foram incluídos nesta implementação.

## Próximo experimento autorizado — Maldição em área, 30/09/2026

Após testar VFX, o usuário redefiniu a Maldição como infestação propagável e
relatou tanto pouco dano no boss quanto poucas oportunidades de atacar. Pediu
avaliar primeiro a mudança AoE, antes de concluir se boss ou kit sufocam demais.
Este adendo autoriza mudar a regra da Maldição; substitui, nesse escopo, a
restrição anterior a alterações puramente visuais. Candidato anterior:4a0a4f9.

Pacote a implementar por Sol, com revisão integrada Astra:

- Maldição mantém seleção single target e aplica marca no alvo e nos vizinhos.
  Raio inicial de experimento:110 unidades, centralizado no inimigo, com geometria
  compartilhada e LoS contra obstáculos. Manter custo/CD/cast/duração/ranks e
  coeficientes atuais para observar primeiro a diferença estrutural.
- Impacto direto positivo de skill do jogador sobre marcado inicia uma onda.
  A própria Maldição pode ativar marca anterior; uma aplicação nova não detona
  a si mesma no mesmo impacto. Autos não iniciam a onda neste experimento.
  DoT, ticks secundários e efeitos secundários genéricos não iniciam ondas.
- Explosão de Eco no portador atinge a vizinhança real de raio110. Sobrevivente
  limpo atingido positivamente recebe marca; previamente marcado pode transmitir
  explosão. Cada portador explode no máximo uma vez na mesma onda, com IDs e
  fila finita. Reaplicar marca em sobreviventes não permite reentrar na onda.
- Preservar antecipação real de0,35s por explosão agendada e dano via resolver
  central. Propagação é exceção explícita e local do Eco; não habilitar cascatas
  genéricas de efeitos secundários. Um mesmo par origem/destino não resolve
  explosão duas vezes na onda. Inimigos podem receber explosões de origens
  diferentes: registrar essa sobreposição e testar limites no cenário denso.
- Todos os primeiros impactos elegíveis de uma mesma emissão/cast compartilham
  uma onda (skills AoE não criam uma onda inteira por alvo). Ticks secundários
  de Drenagem/Procissão não produzem novas ondas. Snapshot anterior ao impacto
  distingue marca preexistente de marca recém-criada; iteração não muda resultado.
- Rito passa a poder ativar a onda como outra skill ofensiva; preservar seu bônus
  direto por alvo previamente marcado e enfraquecimento, eliminando consumo
  duplicado/exclusão antiga. Documentar essa mudança nos tooltips e testes.
- Recolhimento continua limitado a uma restituição por emissão e seu cooldown;
  propagação não multiplica SP/cura/Foco. Escudo total/erro não simula dano ou
  consumo bem-sucedido. Revalidar vida/posição/LoS, e limpar ondas no fim da run.
- VFX mostram aplicação coletiva, progressão espacial da onda e almas novamente
  vinculadas em sobreviventes. Não depender de texto para ler a propagação.

Não adicionar agora crescimento numérico de Ressonância, mudar Drenagem/Foco,
reduzir boss, alterar slots/save ou implementar ideias de híbridos. Esses itens
não são necessários para isolar o efeito da propagação no próximo playtest.

Próxima proposta, ainda não implementada: substituir Drenagem canalizada por
terreno quadrado ao estilo desejado pelo usuário, com redução de dano causado,
slow e Ressonância após permanência por um tempo. O terreno persiste sem manter
canal. Ao desenvolver essa proposta, definir relação com Véu e origem de Foco:
o atual Foco depende de completar quatro ticks de Drenagem e não pode ficar
inalcançável após a substituição. Ressonância exigirá contrato próprio de
aplicação/consumo/limites; a Maldição atual não deve receber esse nome por atalho.

Validação: boss solo, dois alvos próximos sem ciclo infinito, grupo de seis,
alvo limpo versus marcado, impactos simultâneos/emissão AoE, reaplicação pela
própria Maldição, Rito, auto/DoT/secundário, escudo/morte/movimento/LoS,
restituição limitada, pausa/cleanup. Comparar dano por janela fixa e número de
explosões no boss solo e grupo; separar teste controlado de balanceamento humano.
Executar verify integral. Um checkpoint e um handoff no fechamento, commits
pequenos retomáveis. Playtest só após revisão; master/Arqueiro seguem bloqueados
até aceite do usuário. O terreno quadrado fica apenas como proposta documentada.

## Implementação do experimento de propagação — candidato para revisão Astra

A Maldição preserva seleção, custo, cooldown, cast, duração e coeficientes; um
acerto positivo no alvo marca também inimigos vivos em raio 110 e linha de visão.
A aplicação nova não detona a si própria. Reaplicá-la num portador anterior
ativa uma onda e renova a marca para a próxima ação. Apenas impacto direto
positivo de skill do jogador inicia onda; autoataque, DoT e ticks secundários
não iniciam. Rito mantém bônus direto no marcado e enfraquecimento, mas agora
ativa Eco após o acerto, sem o antigo consumo manual duplicado. As descrições
de progressão do menu foram atualizadas em pt-BR para as duas skills.

Cada emissão compartilha uma identidade de onda e um snapshot dos portadores
anteriores ao primeiro impacto elegível. O portador agenda uma explosão após
0,35 s; cada explosão usa o resolver central no próprio portador e em alvos
vivos no raio 110 com linha de visão revalidada. Alvo atingido que sobreviver
termina marcado; somente quem já estava marcado no snapshot pode transmitir
na mesma onda. Portador agenda no máximo uma explosão, e o par origem/destino
é reivindicado antes do dano. Filas de ondas/pedidos e VFX são finitas. Alvos
podem tomar dano de origens distintas: não há deduplicação global de dano,
apenas de transmissão e de vínculos cosméticos. A restituição de SP continua
limitada pela emissão/cooldown existente; o Eco secundário não invoca procs
genéricos. Limpeza de alvo e de run remove pendências e identidades.

`tests/e05_spiritualist_echo_spread_test.gd` cobre 31 checks de marca coletiva,
autoataque inerte, antecipação, duas gerações, rearmamento, par único, emissão
AoE compartilhada, marca criada após o snapshot, linha de visão na aplicação
e na explosão, entrada/saída móvel do raio, reaplicação da própria Maldição,
escudo, Rito, seis adds, limite visual e tooltips. Com pedido sintético fixo
de 100 de dano mágico para ativação, no mesmo boss de treino, a janela de
0,72 s produziu 10 HP de dano de Eco solo (1 explosão) e 30 HP com dois
vizinhos marcados (3 explosões). É comparação estrutural controlada, não
estimativa de DPS da build nem aceite de balanceamento. Testes anteriores de
Recolhimento, Drenagem/Procissão secundárias, morte, pausa, limpeza,
integração e apresentação foram migrados quando a expectativa antiga de
autoataque/Rito deixou de valer.

O probe OpenGL `tools/spiritualist_spread_renderer_probe.gd` captura 12
estágios em `.godot/verification/spiritualist_spread_*.png`, ignorados pelo
Git: marca coletiva, preparo, primeira propagação, segunda geração,
sobreviventes remarcados e seis adds. Vínculos transitórios aparecem uma vez
por alvo/onda para reduzir densidade, sem alterar o dano sobreposto. As cenas
ficam em escala real 1280×720, sem painel/avisos/números. Clareza em movimento,
FPS sustentado e pressão do boss ainda exigem playtest humano; nem o terreno
quadrado nem Ressonância numérica foram implementados. Revisão Astra precede
qualquer atualização do projeto habitual; `master` continua sem merge.
