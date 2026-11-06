# E08 P1 — correções de fundação encontradas no piloto

6/11/2026. Sol Apresentação 6.1 high, no mesmo chat P1. Correções automáticas
dentro do [plano aprovado](e08_approved_plan.md), [contrato P3](e08_p3_contract.md)
e [WORKFLOW](../WORKFLOW.md); não abrem épico, catálogo ou arquitetura de produto.
Base executável/checkpoint incompleto de Terra:
`7f04830e01db0f49acefd47899c271b45b65adaf`, branch `codex/e08`, checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
[Recibo WIP P3](e08_p3_delivery.md) conserva limites e evidências; não é aceite.

## Dois defeitos concretos

1. Lobo e javali usam animal_companion, distinguindo-se só por cor. O javali
   continua com a silhueta de orelhas grandes. P3 precisa de atlas próprios sem
   trocar atlases compartilhados de classes/companheiros, nem acrescentar estado
   serializado ou editar campos privados durante desenho.
2. A captura real preenchida em UI120% mostra painel de estágio sobre a barra,
   inclusive em1280×720 e1920×1080. Pausar antes de atualizar HUD também gerou
   capturas técnicas vazias; esse segundo sintoma é do probe e não prova bug do
   gameplay. P1 corrige encaixe real, não a documentação ou o oráculo para ocultá-lo.

## API de atlas visual por instância

Entregar `CharacterAnimation.set_body_atlas(texture: Texture2D) -> bool`, usando
somente campos já existentes de atlas/base/offsets. Textura imutável de catálogo
com caminho de recurso persistível,256×512,32células64×64,pivô(32,58). Inválido
(null, dimensão errada ou recurso não persistível) retornafalse sem alterar estado.
Não ampliar enum de classe/animation_kind, esquema, codec, campos de instância,
fórmula, clock, HP/SP, hitbox ou IDs de espécie. Não mutar Texture2D compartilhada.

Aplicação preserva a MESMA CombatAnimationState: ação/tempo, caminhada, frente/
costas, espelhamento, hurt/death. Atualiza atlas base e offsets existentes para
que death_copy e captura/retomada conservem o corpo e contato com chão. Restaurar
o padrão pode usar configure já existente. Escopo consumidor inicial: inimigos
sem anexos de equipamento; caso de contrato de equipamento de jogador deve ser
recusado ou tratado explicitamente sem regressão, nunca selecionado silenciosamente
como weaponless antigo após aceitar uma variante. Documentar precondição efetiva.
Cache, se necessário, guarda somente definições imutáveis, não estado de run.

Terra produzirá fontes/atlas e fará a ligação por ocorrência DEPOIS desta entrega.
P1 testa com assets já existentes e não cria arte. O produtor confere persistência
pelos campos atuais, morte/cópia/revive e independência entre duas instâncias.
Snapshot não passa a carregar estado novo de apresentação. Nenhuma migração.

## UI120% utilizável

Manter preferência e escala efetiva120%, viewport/câmera e controles existentes.
Não reduzir escala, esconder botões/indicadores ou desabilitar input para fingir
encaixe. Calcular espaço entre HUD e barra e limitar/refluir/rolar painel conforme
necessário; controles continuam acessíveis por mouse/teclado, modal fecha e pausa
corretamente, janelas não acumulam handlers em resize/install/retomada.
Usar fontes normais e conteúdo completo. Não mudar progressão, portais ou save.
Preservar o mouse_filter que impede clique atravessar painel interativo e permite
clique atravessar informação não interativa. Corrigir também help fora de1280×720
se atingido pela mesma regra; FAIL anterior foi preservado no recibo P2.

Prova: HUD preenchido e painel de estágio real em floresta publicada, zoom/UI
especificados,1280×720 e1920×1080, sem interseção com barra/rodapé e controles
alcançáveis. Repetir resize e abertura/fechamento, além de sample técnico quando
útil. Capturas nativas inspecionadas. Não certificar UI só com PNG pausado vazio.

## Propriedade exclusiva e testes

P3 parou e commitou APENAS seu WIP. P1 é único escritor depois do dispatch P0:

- scripts/actors/character_animation.gd;
- scripts/main.gd (layout de apresentação, preservar glue P3);
- scripts/ui/gui_metrics.gd;
- scripts/ui/battle_controls.gd;
- scripts/ui/expedition/expedition_status_panel.gd;
- tests/e08_presentation_test.gd (adicionar casos de atlas, preservar os existentes);
- tests/e08_pilot_ui_test.gd e .uid;
- tools/verify.ps1 (somente registro de teste novo, preservar linhas P3/P2);
- docs/epics/e08_p1_pilot_corrections_delivery.md;
- docs/epics/e08_evidence/p1_pilot_corrections/ (evidência mínima própria).

Não editar arte, atlas existentes, WAVs, fontes/probe/recibo P3, áudio P2, mapa,
população, schema, outro teste/oráculo ou documento P0. Necessidade adicional
retorna com pausa/pedido delimitado. Commit somente próprios agora que WIP P3 está
preservado no Git; não marcar o piloto como entregue por efeito desta correção.

Seleção por impacto em tools/verify.ps1, mesma fixture e standard4.7.2 pareado:
combat_animation_test, e08_presentation_test, e08_pilot_ui_test, ui_layout_test,
battle_ui_test, action_bar_ui_test, e08_audio_test, e07_f7_presentation_test,
e07_f3_lifecycle_test. Acrescentar invariantes de variante em snapshot, offsets,
copy/death e API sem mudar expectativas dos testes antigos. Falha anterior de
ui_layout_test deve ser corrigida no código e conferida; não reclassificadaPASS.
Source/fixture sincronizam somente deltas e manifesto. Perfil descartável; sem
outro checkout/fixture/cache/export inteiro. Sem master/push ou save pessoal.

Recibo com base/SHA/API/donos, resultados/erros/timeouts, inputs/engine/logs/hashes,
PNG real/limites e próximo passo reproduzível. Luna low supervisiona checkpoint
congelado; P0 consolida e devolve Terra ao mesmo P3 com paths de arte exatos.
Sem Astra rotineiro; nenhuma nova decisão de produto requerida por estes ajustes.
