# E05 — Caçadora: checkpoint consolidado

08/10/2026. Contrato: [E05_HUNTER_PLAN.md](E05_HUNTER_PLAN.md).
Autorização humana conferida no chat Astra, turno `01a11b69-b678-74d0-a9e5-c8efff3d17f0`.
Branch `codex/e05-hunter`, base `3d452fa2e4455f4c8636f4fb319a2d0607d08582`.

## Estado

H1 e primeiro núcleo H2 implementados, em commits granulares internos.
Contrato57bb3ef, catálogo650ee87; candidato efetivo é o commit que contém esta
atualização (confirmar HEAD e assinatura no CLI antes de reutilizar evidência).
Caçadora permanece indisponível. Nenhuma revisão/aceite de gameplay desta classe.
Playtest habitual limpo na base3d452fa, sem alteração nesta entrega.
Atributos já revisados/publicados por Astra; cabeçalho antigo do checkpoint de
atributos antecede essa decisão. Ícones aee3e18/revisão35901f6 separados e não
integrados. Master e saves pessoais não foram alterados.

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
- H3: próximo — Congelante/Piche/Espinhos, campo limitado e Piche→Explosiva.
- H4: Marca, Tiro de Cobertura, camuflagem territorial com limite compartilhado.
- H5: catálogo/passivas/builds/save/admin/menu e testes ponta a ponta.
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

## Limitações e próximo passo

Kit novo, Marca/passivas, camuflagem, input/mira específicos e arte ainda não
implementados. Congelante R1 de entrada está só declarada, não funcional no mundo;
portanto nem mesmo o fluxo inicial de evolução está liberado ao usuário. IDs novos
ainda não são compráveis numa evolução de produção. H5 deve fechar versionamento
do catálogo e migração antes de liberar compras persistentes; não gravar estado de
aberturas/fields. Não declarar classe jogável, leitura visual ou desempenho.
Próximo passo: H3 e demais camadas autorizadas, atualizar este checkpoint com commits,
resultados e pendências. Nenhum gate por microtarefa nem mensagem a outros chats
por efeito das skills. Só escalar bloqueio ou divergência relevante do contrato.
