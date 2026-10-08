# E05 — Caçadora: checkpoint consolidado

08/10/2026. Contrato: [E05_HUNTER_PLAN.md](E05_HUNTER_PLAN.md).
Autorização humana conferida no chat Astra, turno `01a11b69-b678-74d0-a9e5-c8efff3d17f0`.
Branch `codex/e05-hunter`, base `3d452fa2e4455f4c8636f4fb319a2d0607d08582`.

## Estado

H1–H5 implementados, em commits granulares internos.
Contrato57bb3ef, catálogo650ee87, núcleo4bf832d; candidato efetivo é o commit que contém esta
atualização (confirmar HEAD e assinatura no CLI antes de reutilizar evidência).
Caçadora permanece indisponível. Nenhuma revisão/aceite de gameplay desta classe.
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
- H6: atlas/ícones/VFX e provas nativas solo/grupo/boss.
- H7: integral no HEAD limpo e pacote único para revisão, sem publicar playtest.

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

Passivas e consumidores persistentes/menu concluídos emH5; arte final pendente.
Congelante R1 e novas traps funcionam em fixtures isoladas, mas o fluxo inicial
de evolução continua bloqueado até o kit completo. IDs novos
não são selecionáveis numa evolução de produção. Versionamento do catálogo e
migração fechados emH5; produção continua bloqueada atéH6/H7. Não gravar estado de
aberturas/fields. Não declarar classe jogável, leitura visual ou desempenho.
Próximo passo: H6 (atlas/ícones/VFX e provas nativas), atualizar este checkpoint com commits,
resultados e pendências. Nenhum gate por microtarefa nem mensagem a outros chats
por efeito das skills. Só escalar bloqueio ou divergência relevante do contrato.

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
