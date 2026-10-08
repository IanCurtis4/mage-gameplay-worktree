# E05 — Caçadora: checkpoint consolidado

08/10/2026. Contrato: [E05_HUNTER_PLAN.md](E05_HUNTER_PLAN.md).
Autorização humana conferida no chat Astra, turno `01a11b69-b678-74d0-a9e5-c8efff3d17f0`.
Branch `codex/e05-hunter`, base `3d452fa2e4455f4c8636f4fb319a2d0607d08582`.

## Estado

H1–H7 implementados, em commits granulares internos; fechamento técnico de Astra pendente.
Contrato57bb3ef, catálogo650ee87, núcleo4bf832d; candidato efetivo é o commit que contém esta
atualização (confirmar HEAD e assinatura no CLI antes de reutilizar evidência).
Caçadora habilitada somente no candidato integrado (`content_ready=true`).
Nenhuma aprovação de Astra, publicação ou aceite de gameplay desta classe.
Playtest habitual limpo na base3d452fa, sem alteração nesta entrega.
Atributos já revisados/publicados por Astra; cabeçalho antigo do checkpoint de
atributos antecede essa decisão. Ícones aee3e18/revisão35901f6 separados e não
integrados. Master não foi alterado. Incidente de isolamento do save habitual
detectado emH5 e descrito abaixo; não afirmar ausência de escrita pessoal.

## Camadas / evidência

- H1: contrato/IDs/tuning/consumidores/builds; catálogo de seis ativas/duas
  passivas com gates/caps/entrada grátis declarados, ainda `content_ready=false`.
  HunterTuning/SkillDefinition/ProfileCatalog não mudam carteiras ou save.
  Luna executou catálogo fechado; Sol corrigiu/reproduziu e integrou internamente.
- H2 concluído para mecanismos existentes: HunterOpeningState/HunterMath e
  integração PlayerActor/main. Laço e Explosiva abrem a presa após armar;
  próximo tiro próprio positivo reivindica snapshot físico secundário e Passo.
  INT isolada para recompensa/Explosiva Hunter; Arqueiro/Sentinela mantêm fórmulas.
  Claims por emissão/vítima e trap/vítima, limites, cópias, pausa, letal e limpeza.
  Passo usa fonte canônica de velocidade, sem HP/SP/cooldown implícitos.
  Hunter revalida LoS na colocação/gatilho/vítimas; callback opcional de PlayerTrap
  deixa as bases inalteradas. Explosiva revalida vítimas após callbacks destrutivos.
- H3 implementado: Congelante/Piche/Espinhos, campo limitado e Piche→Explosiva.
  HunterMath captura INT efetiva/poder bruto; Congelante usa canal mágico e
  presa única, Espinhos área física85/bleed secundário renovado por fonte,
  Piche área100 sem dano. Só ativação inicial abre a presa; reentrada/entradas
  tardias não renovam janela. Campo único por dono, fonte exclusiva de slow,
  residual0,4s; consumo/substituição/limpeza removem a fonte antes dos impactos.
  Explosiva usa callback opcional antes do loop, escalar capturado uma vez
  para todas as vítimas, sem mutar pedido original/recompensa ou detonar traps.
  Execução/mira/preparo revalidam terreno/LoS, três modos de cast e cobrança única.
  Novos atores entram em listas limitadas de mecanismos/campo Hunter ativos.
  Snare/Explosive recebem guard explícito de pausa/delta, sem mudar tuning base.
- H4 implementado: Marca, Tiro de Cobertura e camuflagem territorial com limite
  compartilhado. Snapshot de Marca na ativação; recuo completo revalidado e tiro
  emitido da origem anterior; budget puro3s, revelação1,25s e recarga comum18s
  canônica. Cobertura Total125/graça1s, Abrigo110 sem graça adicional. Uma área
  por dono; IA Hunter caminha à última posição visível, sem ataque oculto.
- H5 implementado: Disciplina/Presa Fácil automáticas com snapshot no arco,
  pedido secundário único sem crit; catálogo8/schema2/ruleset inalterado,
  migração7 explícita, menu/HUD e duas builds legais com reload/recompensa/retorno.
  Admin e produção continuam respeitando `content_ready=false`.
- H6 implementado: atlas próprio32 células, oito ícones exclusivos preparados,
  mecanismos/campo de chão e observador cosmético de Marca/abertura/consumo/Passo.
  Prova nativa controlada solo/grupo/boss claro/escuro; sem publicação ou ícones
  globais integrados. Revisão visual independente e combate ativo ainda H7.
- H7: IA/navegação/flight ativos30/60/144, builds legais e variantes sem passivas
  tardias, fluxo real menu→arena→retorno, correção de referências removidas,
  prova nativa com HUD/obstáculos e readiness no candidato. Integral/pacote único
  devem estar vinculados ao HEAD limpo final; sem publicar playtest.

Evidência dirigida reproduzida por Sol em Godot4.7.2: catálogo619 checks,
abertura674 e integração41, zero falhas. Roster66 e catálogo Sentinela749 também
PASS após atualizar expectativas históricas de nome/kit vazio para o novo catálogo
parcial. Os testes preservam explicitamente o bloqueio Hunter e as outras classes.
Logs: `.godot/verification/hunter_catalog.log`, `hunter_opening.log`,
`hunter_core.log`, `hunter_roster.log` e `hunter_sentinel_catalog.log`.
Relógios puros exercitados em30/60/144Hz; integração é dirigida com IA desligada,
não evidência de viabilidade solo/performance. Boss estacionário com controle
resistido, erros/zero/escudo/secondary/fonte alheia/letal, substituição e callbacks
destrutivos foram exercitados. Death/end removem estado, sem refill.

`tools/verify.ps1` foi executado: primeiras tentativas interrompidas exclusivamente
em expectativas antigas do roster e do teste de catálogo Sentinela, corrigidas e
reproduzidas acima. Não registrar essas execuções interrompidas como PASS integral.
A primeira execução CLI integral foi interrompida ao detectar um UID de teste
gerado pela importação depois do commit; registro `20261008-094324-84d94f65`
permanece incompleto e não é evidência reutilizável. UID acrescentado ao Git.
Após o commit deste lote, executar CLI `all/implementer` no HEAD limpo e consultar
o relatório emitido em `.godot/workflow` pelo status: exigir `current_inputs=true`
para reutilizar. Resultado posterior de verificação do lote não conclui H3–H7,
não habilita a classe e não é aprovação/reprodução de Astra.

Nenhuma execução anterior dos atributos é evidência desta classe. CLI externo
autorizado: `menu-tabs/tools/workflow/workflow.py`, origem0c008d4,
SHA256 `e642dbe882cd7ea3cd687da51ed978bdecc93675fbb31d08d26626a0b40a1bae`;
sempre `--project` no d066, derivando seleção do verify.ps1 local.
Engine `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe`,
4.7.2standard. Evidência de implementador e reviewer permanecem separadas.

## Evidência H3

Teste `e05_hunter_traps_integration_test.gd`:181 checks, zero falhas em Godot4.7.2.
Log `.godot/verification/hunter_h3.log`. Modos CONFIRM/RELEASE/INSTANT exercitam
input/intenção/dispatch reais com ponteiro determinístico; não são prova manual
de mouse. IA desligada, como H2. Campo/reação em30/60/144Hz; negativos de terreno
alterado durante preparo, pausa, LoS por vítima, snapshot após alterar INT,
boss com CC resistido, FIFO, ausência de abertura por manutenção/bleed,
reentrada/ocupante tardio, remoção de fontes antes de hits e morte do dono.
Callback destrutivo revelou referência liberada passada a helper tipado;
revalidação antecipada corrigida e caso reproduzido sem erros. Primeira execução
também encontrou fixtures inválidas (atributo fora do cap, método de mira errado,
tick de IA invocado em teste dirigido); corrigidas, não contam como PASS.
Conferência de limpeza acrescentou teste de expiração natural seguida de fim:
fonte de Piche agora é identificada por dono, permitindo retirar o residual
mesmo depois de o nó visual ser liberado, sem retirar controle de outra fonte.
`tools/verify.ps1` terminou com exit0, incluindo regressões de bases/classes e
smoke. Foi iniciado antes dessa última correção (H3 então tinha177 checks);
por isso não substitui a execução CLI integral posterior no candidato final.
Os181 checks de H3 foram repetidos após a correção, sem falhas/erros.

Inventário visual conferido pela skill de arte: atlas Arqueiro/CharacterAnimation
existentes; não há atlas Hunter nesta camada. Novos desenhos procedurais reutilizam
PlayerTrap/BattleIndicators e a área física, com sinais distintos de mecanismo;
não houve geração raster nem execução de packers fora do escopo. São provisórios:
sem prova no renderer/aceite de leitura, ativação/abertura/Passo finais ficam emH6.

Após consolidar este lote, conferir relatório CLI all/implementer no HEAD limpo
em `.godot/workflow` e exigir `current_inputs=true`. O PASS integral H2 acima é
histórico e fica incompatível com o delta H3; não é evidência reutilizável do novo
candidato. Verificação do lote não conclui H4–H7 nem libera revisão/playtest.

## Limitações e próximo passo

H1–H7 integrados no candidato, incluindo evolução normal, compras e reload,
menu/arena/HUD/retorno reais. Catálogo8/schema2/ruleset preservados no fechamento.
As seções H1–H6 abaixo/acima são evidências históricas, não o estado vigente de
readiness. Não gravar estado de aberturas/fields. Ícones globais continuam fora
do escopo; os oito exclusivos Hunter estão preparados, sem integração global.
Revisão técnica/visual final de Astra e aceite humano continuam pendentes.
Não declarar publicada a classe, nem DPS/FPS/diversão por provas dirigidas.
Próximo passo: revisão integrada do candidato limpo e relatório all compatível;
envio a outro chat exige autorização humana específica, não decorre desta skill.
Depois da aprovação técnica, Astra prepara/revalida a composição no playtest;
merge somente após aceite do usuário. Nenhuma outra classe/épico iniciado.

## Evidência H4

`e05_hunter_cover_integration_test.gd`:302 checks, zero falhas/erros na execução
dirigida final, Godot4.7.2standard. Log `.godot/verification/hunter_h4.log`.
Ranks1–5, prioridade única/expiry/remoção, Marca pré/pós ativação, snapshot sem
retroatividade/mutação, duplicata, LoS/range/cancelamento sem custo, ranks0/6,
input CONFIRM/RELEASE/INSTANT e cobrança única. Projétil real GEOMETRY/crítico
normal (roll forçado só na fixture), exploração secundária/Passo e clocks de auto
preservados; origem anterior ao recuo, range520/speed880, root, segmento com parede
mesmo com endpoint livre, preview coerente e pausa.

Camuflagem: três segundos efetivamente oculta, fronteiras parciais de revelação e
graça em30/60/144Hz, sem ganho por reentrada/substituição/alternância. Colocação paga
renova somente após ambas recargas; limpeza sem HP/SP/CD refill, offense fora da
área, remoção sem apagar reveal, base sem graça, observer interno, morte/fim/pausa.
IA ativa dirigida por delta em30/60/144Hz segue última posição, não a presa oculta;
boss preserva HP/contagem e projétil hostil já emitido ainda atinge o jogador.
Demais inimigos/player/fields têm processamento automático desligado na fixture;
isso não comprova solo, gameplay ou desempenho. Arte de Folhagem/preview existente
parametrizada, sem novo raster/atlas e sem aceite no renderer (skill ragrpg-art).

Primeira execução dirigida passou289 checks com diagnóstico ambiental de
certificados sob sandbox; reprodução no ambiente normal removeu esse diagnóstico.
Ampliação do teste encontrou observador de dano conectado ao ator em vez de
HealthComponent: script interrompeu a rotina apesar de exit0. Corrigido para a
fronteira canônica, preservando resultado secondary aninhado; reprodução301
sem erros completou a rotina. O302º check revalida fim de encontro disparado
no callback de remoção durante substituição, impedindo nova área após cleanup.
Nunca usar exit0 isolado como PASS.

`tools/verify.ps1` terminou com exit0, incluindo bases, classes entregues,
persistência/input/UI, smoke e admin. A execução começou antes do302º check e
da revalidação terminal de substituição; H4 nela tinha301 checks. Os302 foram
repetidos sem erros, e a execução CLI integral após commit deve validar o delta
final e o vínculo ao candidato limpo, não reaproveitar essa execução intermediária.

Após consolidar o lote, conferir CLI all/implementer no HEAD limpo e assinatura
`current_inputs=true`. Relatórios anteriores vinculados aH3 tornam-se históricos,
não comprovam H4. Validação H4 não habilita a classe nem conclui H5–H7; nenhuma
mensagem a Astra/publicação no playtest por efeito da retomada.

## Evidência H5

`e05_hunter_passives_test.gd`:613 checks, zero falhas/erros, Godot4.7.2standard.
Todos os ranks legais e inválidos, seis emissões reais de arco, passivas sem slot,
gates28/34, outras identidades sem bônus, cópias durante voo, Marca e Presa Fácil
somente na parcela INT, Disciplina somada depois, uma mitigação/rounding sem crit,
duplicatas/reabertura, payload inválido sem claim, miss/zero/escudo/secondary/letal.
Controller real confirma root/stun/fear/slow anteriores e Marca, exclui weaken e
o slow do próprio primeiro tiro; boss com CC resistido mantém Presa Fácil.
Fixtures alteradas após emissão comprovam ausência de leitura tardia de stats/rank.

`e05_hunter_catalog_migration_test.gd`:112 checks, zero falhas/erros. Migração
7→8 explícita sem mudar schema2/stat_thresholds_v1 ou persistir estado da run;
investimentos legítimos acima de87 incrementos não usam orçamento antigo.
Identidades/XP/counters/ranks/grants/slots24/presets/equipamentos/extensões/seleção
e sessão de recompensa conservados; backup fonte byte-exato, revisão única,
primeira alocação posterior/respec/reload, todos os estágios de falha de escrita,
pending/futuro/incompatível preservados e recuperação conservadora de backup.
Testes históricos de catálogos anteriores só atualizam expectativa atual8;
oráculo independente de atributos continua identificado como catálogo7 e ligado
ao ruleset inalterado, sem reescrever seus números.

`e05_hunter_builds_test.gd`:422 checks, zero falhas/erros na reprodução de Sol.
Luna escreveu apenas teste/UID; implementação e evidência final são de Sol.
Preparadora e Emboscadora compram ranks pela fachada e respeitam carteiras19/20
e custo canônico de atributos. Evolução/menu real, ranks/gates, compras, tooltips
atuais/próximos, Abrigo18s apenas Hunter, passivas aprendidas automáticas além dos
dois slots antigos, biblioteca além de cinco ativas, edição slot24, save/reload,
snapshot de run, recompensa/fim e retorno ao menu. Override de readiness apenas
nas fixtures; produção/start/admin/training continuam bloqueados para Hunter.
São transações dirigidas, não uma prova de combate solo ou de IA ativa.

Logs em `.godot/verification/e05_hunter_passives_test.log`,
`e05_hunter_catalog_migration_test.log`; builds reproduzidas pelo verify integral.
Primeiras execuções dirigidas detectaram propriedades/fixtures inválidas dos
novos testes (nome do slot passivo e mapa de atributos incompleto); corrigidas e
rotinas completas repetidas sem SCRIPT ERROR. Exit0 dessas tentativas não é PASS.

Após commit, executar CLI `all/implementer` no HEAD limpo e consultar o relatório
emitido pelo status com `current_inputs=true`; relatórios H4 tornam-se históricos.
Este lote não habilita a classe nem conclui H6/H7. Nenhuma publicação, merge
ou mensagem a Astra nesta camada.

### Isolamento da verificação / incidente H5

A entrada CharacterMenu pode ser instanciada pelo runner headless mesmo com
`--script`. Foi detectada abertura do perfil habitual: primário migrou7→8 e
revisão+1 em08/10/2026 15:06:59, backup7 preservado. Comparação estrutural de todos
os campos contra backup: só catálogo/revisão diferentes; personagens, progressão
e demais dados iguais. Usuário foi informado e autorizou explicitamente restaurar
o backup anterior. Primário restaurado byte-exato ao backup7; backup original
preservado. Cópia recuperável do primário8 anterior em
`.godot/verification/h5_profile8_before_restore_20261008.json` (ignorada pelo Git).
Hashes revalidados antes de copiar; nenhuma escrita se arquivos tivessem mudado.
Conferências posteriores devem conservar ambas as assinaturas restauradas.
Não tratar esse
incidente como publicação/aceite nem afirmar que o save permaneceu intocado.

Primeiro verify H5 foi interrompido preventivamente antes de concluir; não é
PASS integral. CharacterMenu agora resolve o perfil padrão headless em
`res://.godot/verification/headless_menu_profile`, antes de abrir o store.
Diretórios/fachadas explícitos de fixtures e execução gráfica continuam intactos.
`verification_profile_isolation_test.gd`:5 checks, zero falhas/erros. Toda nova
verificação integral deve repetir com essa proteção, incluindo smoke de entrada.

Segunda execução completa de `tools/verify.ps1`:exit0, sem erros/falhas, incluindo
as quatro suítes novas, bases/classes, persistência/UI/input, smoke e admin.
Ao final, hashes do primário e backup habitual permanecem exatamente os da
restauração autorizada. A execução CLI integral após commit deve vincular o
resultado ao HEAD limpo; conferir assinatura pelo status, sem editar relatório.

## Evidência H6 — apresentação

Retomada de53a884d, árvore inicialmente limpa; H5 all167 estava current_inputs=true.
Escopo Hunter autorizado prevalece sobre cabeçalho antigo Defendente, conforme
autorização humana referenciada no contrato. Nenhum novo marco/épico iniciado.

Atlas próprio original integrado pelo CharacterAnimation/PlayerActor:32 células
64×64, pivô32,58, frente/costas, espelhamento, idle/walk/ação/hurt/morte.
Fonte imagegen preservada e prompt integral em hunter_prompts.md; preparador
Godot derivado do Geômetra só normaliza alpha/escala/pés, sem reescrever bases.
Oito SVGs exclusivos com IDs estáveis preparados/importados; UI global continua
fora do escopo. Inventário/provas/limites: docs/art/hunter_h6/README.md.

HunterGroundArt é helper puro: Congelante mandíbulas/cristal, Piche pote/resina,
Espinhos estacas/mola. Preparo segmentado/progressivo e armado fechado/discreto;
campo ativado tem borda dupla no raio real100, sem mecanismo aguardando.
HunterPresentation observa estado de run e IDs sem reter alvos/payloads; Marca
diamante e abertura entalhada se combinam num marcador por presa. Claim aceito
gera impacto breve; Passo real gera rastro curto dos pés. Cosmético até16 bursts
e6 amostras de rastro, pausa/TTL próprios, clear/death/end sem órfãos. Nenhuma
fórmula, custo, timer de gameplay, colisão ou semântica das skills foi alterada.

Pacotes internos separados: subagentes entregaram receitas de chão+teste e
atlas-test/probe; Sol inspecionou/reproduziu, criou fonte/atlas/ícones/observador,
integrou e corrigiu o palco/limpeza do probe. Não é reprodução independente Astra.
Testes dirigidos: ground575, atlas158, presentation25, todos zero falhas/erros.
Presentation cobre ausência de dano/custo/claim/timer causado por VFX, limites,
pausa, subpassos de rastro, alvo removido, limpeza, callback único e morte.
H3regressão181 passou; verify integral também cobre H1–H5, Arqueiro/Sentinela,
outras classes, save/UI/input, editor import, smoke e admin. tools/verify.ps1
completo terminou exit0/sem erros; apresentação então tinha22checks e os três
casos adicionais foram repetidos dirigidamente PASS25. CLI all após commit
deve reproduzir o arquivo final e vincular evidência ao HEAD limpo.

Renderer nativo Compatibility: PASS282 checks/33 capturas, inspecionadas em
docs/art/hunter_h6. Preparadora/Emboscadora legais19/20, solo/grupo/boss, piso
claro/escuro, preparo/armado/acionado/campo/Marca/abertura/consumo/Passo/Cobertura
e limpeza terminal real. Primeira rodada técnica PASS278 tinha oclusão do palco
e clear parcial; não é a prova final. Palco foi desobstruído, com câmera fixa,
HUD oculto apenas no probe, navegação/arte sem obstáculos. IA/input congelados,
SP/CD e deslocamento preparados para snapshots. Não certifica HUD, navegação
sob obstáculos, combate ativo30/60/144Hz, FPS/DPS/diversão ou aceite humano.

Sandbox de shell/patch estava com falha ambiental; comandos autorizados usaram
execução escalada e patches pelo executor nativo. Não houve gravação direta de
código nem desvio de aprovação. Probe usa cena posicional explícita, sem
CharacterMenu/ProfileStore/fachada e controles isolados. Hashes do primário e
backup habitual permaneceram byte-exatos à restauração H5 durante esta rodada.
Playtest codex/playtest/3d452fa limpo; sem publicação, merge ou mensagem Astra.

CLI externo autorizado: menu-tabs/tools/workflow/workflow.py, SHA256
e642dbe882cd7ea3cd687da51ed978bdecc93675fbb31d08d26626a0b40a1bae;
origem checkout0c008d4843d13f772aa2b69be22d24d2300b80a1, arquivo ainda não
versionado naquela árvore (assinatura explícita acima). Não copiado para este
checkout. Conferir status --contract docs/E05_HUNTER_PLAN.md
e relatório all/implementer current_inputs=true no commit que contém H6.
Essa prova integral não fecha H7. Próxima rodada: combate ativo/integração final,
readiness com evidência completa e um único pacote para revisão de Astra.

## Evidência H7 — fechamento integrado

Retomada de bf615b1 limpo; H6 all/implementer170 estava `current_inputs=true`.
Escopo humano Hunter prevalece sobre cabeçalhos históricos Defendente. Readiness
agora true para somente Hunter completo; placeholders futuros permanecem false.
Testes de catálogo/roster/Sentinela/atlas atualizam expectativas históricas,
conservando negativos com override false e metadata completa. Não muda tuning,
schema2, catálogo8 ou stat_thresholds_v1; não publica em codex/playtest.

H7 active combat: PASS12768 checks/16 cenários, zero falhas/erros, Godot4.7.2.
Subagente escreveu exclusivamente teste/UID; Sol inspecionou e reproduziu na suíte
integral. Duas builds19/20 em solo/defesa ×30/60/144 deltas, mais quatro variantes
legais sem Disciplina/Presa Fácil a60 (16/14evol, saldo não gasto). IA real,
pathfinding, preparo variável/commit, mecanismos, flight e colisão real de
flechas. Boss de treino canônico50.000HP/dano0,18, sem HP artificial ou refill:
andou385–386px, atacou6solo/18defesa; defesa recebeu7 hits de flechas e a onda8s.
Um consumo de abertura/recompensa/Passo por emissão; SP auditado frame a frame
contra regen e pagamentos canônicos. Pausa conserva IA/SP/CD/Marca/projéteis;
fim solo e morte real por DamageRequest letal em defesa limpam claims/fields/
mecanismos/cobertura/VFX. Delta dirigido não é benchmark de FPS, balanço ou vitória.
Primeiras fixtures tiveram contagem indevida de flight por delta automático após
emissão; congelamento imediato corrigido. Não confundir tentativa com PASS final.

H3 ampliado: PASS186, zero falhas/erros. A primeira prova nativa ativa revelou
`Trying to assign invalid previously freed instance` em refresh de Piche, após
morte/remoção de uma presa. Guard dentro de loop tipado era tardio: a atribuição
falhava antes da validade. Runtime agora revalida/pruna índices/Variants antes
de converter atores vivos, também em cleanup do campo e ativação de traps de
área. Regressão libera nós reais, conserva slow da presa sobrevivente e aciona
Espinhos após remoção, sem impacto extra ou mudança na fórmula.

Build/menu/save/arena/retorno: PASS426. Catálogo de produção sem readiness
override nos dois caminhos legais. Menu._start_run muda para main.tscn real;
HUD recebe slots24/biblioteca/atlas Hunter. RunController terminal retorna à
CharacterMenu real, fecha sessão uma vez e reabre fachada/save explícitos de
fixture antes de _ready. Perfil pessoal e controles de user:// não são gravados.
Gates/caps/carteiras/passivas automáticas permanecem; fixture false ainda rejeita
evolução/admin/start/training sem mutação.

Renderer nativo automático: PASS708 checks/36 capturas (236/12 em cada cap30,
60,144), zero erros após correção. IA/processamento automáticos, solo/defesa,
Preparadora/Emboscadora, HUD real, piso e três obstáculos preservados, origem do
atlas própria, mecanismo/opening/consumo/Passo/cobertura. Não há congelamento de
AI, refill de SP ou HP inflado; caps solicitados não são taxas medidas. Primeira
rodada60 também tinha contador de skill errado na fixture; corrigido para
hunter_exploit e todas as capturas regeneradas. Limites e procedimento seguro:
[docs/art/hunter_h7/README.md](art/hunter_h7/README.md). Inspeção representativa;
H6 mantém prova de atlas32/pisos claros-escuros/cenas densas. Não é review Astra.

tools/verify.ps1 completo terminou exit0, incluindo H7 PASS12768, builds426,
H3regressão186, bases/classes anteriores, persistência/UI/input, import, smoke
e admin; nenhuma falha ou SCRIPT ERROR. CLI all/implementer vincula o resultado
ao candidato final e continua obrigatório no fechamento. Validar
novamente após o commit que contém esta atualização e exigir `current_inputs=true`
no status, candidato limpo e seleção incluindo e05_hunter_active_combat_test.gd.
Não reutilizar relatório H6, não editar report e não executar approve em nome
de Astra. CLI externo/origem/SHA256 permanecem os explicitamente registrados
emH6; não foi copiado. Pacote de inspeção CLI contra base3d452fa deve ser emitido
em `.godot/workflow/hunter_h7_review.md` após consolidação; não é aprovação.
Usuário autorizou explicitamente o envio deste candidato completo ao Astra
nesta rodada, após a validação integral (resposta “Sim, enviar ao Astra”).

Conferência durante H7: perfil habitual primário e backup continuam byte-exatos
à restauração autorizada H5 (SHA256 FC96503BEE4A2BFE896CE2800A3FA198B9F66C48025E3249613360A9D846FB56).
Playtest permanece codex/playtest/3d452fa, limpo; master sem alteração. Guard
headless e entradas gráficas posicionais explícitas preservam o isolamento.

### Roteiro de playtest após aprovação técnica de Astra

1. Evoluir Arqueiro job20 em Caçadora: Congelante R1 grátis, origem preservada;
   comprar ranks pelos gates20/23/25/28/31/34/37, sem ultrapassar carteiras.
2. Preparadora e Emboscadora do contrato: salvar/reabrir, organizar mais de cinco
   ativas/slot24, conferir passivas automáticas; não exigir Espinhos/kit inteiro
   nem passivas tardias para abrir→atirar→Passo.
3. Testar confirmar/soltar/instantâneo, cancelar e alvo/parede novos durante
   preparo; comparar SP/CD antes/depois, tiro com recuo bloqueado sem cobrança.
4. Preparar mecanismos antes da chegada; distinguir preparando/armado/campo,
   controlar grupo/boss, marcar e consumir abertura uma vez, testar Piche→Explosiva.
5. Alternar Abrigo/Cobertura Total: budget3s/CD18 compartilhados, revelação1,25s,
   última posição da IA, saída/reentrada sem renovar budget; flechas já emitidas
   continuam válidas. Pausar durante preparo/flight/cobertura e retomar.
6. Conferir silhueta/pés/costas/arma, marcador combinado e rastro curto em pisos
   claros/escuros e perto dos obstáculos/HUD, especialmente combate denso.
7. Morrer/terminar/reiniciar/voltar ao menu sem órfãos ou estado Hunter salvo;
   comparar Arqueiro/Sentinela. Registrar leitura, recursos e prazer do ciclo;
   este roteiro não registra aceite humano automaticamente.
