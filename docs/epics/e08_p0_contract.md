# E08 — contrato operacional P0–P7

5/11/2026. Autoridade: [plano aprovado](e08_approved_plan.md), posterior ao
[brief](e08_opening_2026_11_05.md), e [WORKFLOW](../WORKFLOW.md).
Sol Integração P0/P7 coordena execução; Astra mantém arquitetura/guias.
Roteamento histórico Claude de F9 não rege E08. P1/P2 Sol 6.1 high;
P3 Terra 6.1 high; supervisão Luna low. Não há gate Astra rotineiro.

## Base, preservação e sequência

Base integral `c8b80b13d29c468afb7f2ad7ba75eec838e7df32`, runtime F10
`2ff1c00f923e3811b0aa7ebcbeddafe7731d640f`. Branch `codex/e08`, checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
São dois checkouts; principal `codex/playtest` em
`fba777b3822356a10e7f6e050971e54ab1a9819b` fica preservado. Nenhum master/push.
Backups e plano original: [recibo P0](e08_p0_receipt.md).

Uma pessoa/agente escreve por vez neste checkout. P0 entrega posse a P1;
P1 devolve após commit/recibo; P0 confere e congela inputs; Luna supervisiona;
P0 consolida, depois despacha P2. Mesma sequência até P3. Nenhum chat P4–P6
antes do aceite humano do piloto. P7 reutiliza esta coordenação com esforço alto.
Criar chat não equivale a entrega. Correções voltam ao mesmo executor.

## Fronteira de apresentação entregue por P1

Preservar `CharacterAnimation.configure/observe/play/draw_on/death_copy`,
`CombatAnimationState.trigger/advance/revive`, CELL(64,64), PIVOT(32,58),
32 poses, frente/costas/espelhamento, caminhada por deslocamento e anexos.
Usar `CombatActor.presentation_action`, `HealthState.damage_applied`,
`actor_died`, `PlayerActor.world_cast_status/world_cast_anchor`, campos e
projéteis confirmados. Pedidos de ataque não equivalem a impacto confirmado.
Não reexecutar query física para decidir um impacto cosmético.

P1 entrega `PresentationEventBridge` em `scripts/presentation/presentation_event_bridge.gd`:
`bind_controller(controller: Node)`, `begin_stage(stage_id: String, resumed: bool=false)`,
`emit_confirmed(event: Dictionary) -> bool`, `clear_stage()`, `dispose()`;
sinal `event_confirmed(event: Dictionary)`. Binding repetido é idempotente.
Evento copiado: `event_id: String`, `kind: StringName`, `stage_id: String`,
`actor_id: String`, `skill_id: StringName`, `position: Vector3`,
`surface_id: String`, `duration: float`, `essential: bool`, `payload: Dictionary`.
Usar IDs de instância somente dentro da sessão/época; identidade não entra no save.
`kind`: cast_start, cast_cancel, projectile_launch, impact, area_start, area_end,
teleport, death, revive, stage_enter, stage_exit, ui_confirm, ui_cancel.
Copiar raio/forma/altura/alvo do resultado confirmado no payload quando aplicável;
nunca inferir raio pelo sprite. Posição legada 2D é identificada no payload e
não tratada como ponto 3D canônico. Ausência de informação não autoriza inventá-la.

Rejeitar false sem emissão para evento inválido, duplicado, estágio antigo,
posição/duração não finita ou duração negativa. Retenção de dedup limitada à época,
com descarte determinístico dos cosméticos antigos; documentar limite real.
Indicadores essenciais existentes nunca são descartados por esse limite.
Bridge é observador: nenhum DamageRequest novo, fórmula, timer de simulação,
alcance, LoS, cooldown, recompensa, RNG de gameplay ou dado persistente.

Pausa congela relógio e efeitos de mundo. UI continua responsiva. Cancelamento,
morte/revive e troca de estágio não deixam referências/nós pendurados.
Retomada reconstrói o estado visual atual sem reproduzir impactos históricos;
entrada em estágio emite somente o contexto atual. Eventos aguardando callbacks
do estágio anterior são ignorados. Assinaturas auxiliares concretas e capacidades
ficam no recibo P1 antes de qualquer consumidor P2/P3.

## Áudio P2

Consumir somente bridge confirmado e eventos de interface. Serviço
`scripts/presentation/audio_service.gd`, catálogo imutável
`audio_event_catalog.gd`, preferências `audio_preferences.gd`.
API pública: `configure(bridge, preferences_path)`, `set_volume(channel, linear)`,
`set_muted(channel, muted)`, `clear_stage()`, `dispose()`.
Geral/Efeitos/Interface/Ambiente; valores lineares [0,1], mute independente,
ConfigFile local `user://audio.cfg`, fora de perfil/snapshot de gameplay.
Config inválida usa defaults seguros; erro de gravação deve ser observável.
Mundo pausável, Interface processa durante pausa; limpar mundo ao trocar estágio.
Retomada reinicia ambiente, sem impactos passados. Sem música.
Limite inicial 32 vozes cosméticas (24 efeitos, 4 UI, 4 ambiente), prioridades
determinísticas e liberação de vozes terminadas. Sons são complemento dos
indicadores visuais essenciais. Catálogo inicial pode ficar sem samples até P3,
mas precisa de teste com stream sintético de fixture, sem alegar áudio final.
P2 publica IDs, parâmetros e integração da UI antes da transferência a Terra.

## Piloto e gate humano

P3 aplica [ragrpg-art](../DELIVERY_SKILLS.md) e pipeline existente a Mago,
espécies comuns/chefe já publicados da floresta, cenário e primeiros sons.
Preservar geometria, rotas, população e encontros; arte não cria espécie/kit.
Inspecionar antes; classificar asset adequado para preservar. Raster novo usa
imagegen e conserva fonte/prompt. Sons originais com receita ou fonte licenciada
e licença explícita. Não usar conteúdo de terceiros sem proveniência.
VFX só consome geometria/tempo canônicos. Não redesenhar renderer inteiro.

Aceite: equipamento, caminhada, cast, projétil, área e teleporte em piso claro e
escuro, rampa, ponte, vegetação, grupo e chefe; zoom 50/100/160%, UI 120%.
Entregar antes/depois identificados, release jogável, roteiro visual/sonoro,
hashes e limitações. P0 consolida aprovação técnica; usuário decide produto.
P4 personagens (médio), P5 mundo (médio), P6 feedback (alto) e P7 integração
ficam preparados, BLOQUEADOS_ACEITE_P3; suas bases/listas finais só no dispatch.

## Validação e orçamento comparativo

Runtime executa `tools/verify.ps1 -F1Fixture -Test ...`, engine standard 4.7.2
do principal `.tools/godot/Godot_v4.7.2-stable_win64_console.exe`, uma fixture
reutilizada em `.godot/verification/e07_f1/fixture_project`.
Seleção mínima P1: combat_animation_test, e07_f1_presentation_test,
e07_f3_lifecycle_test, e07_f3_action_matrix_test, e07_f7_presentation_test,
e08_presentation_test. Acrescentar fronteiras tocadas. P2 acrescenta
e08_audio_test e regressão P1. P3 acrescenta e08_pilot_test, conteúdo/export
e mesmas fronteiras. Luna confirma conclusão, erros/timeouts e hashes; Sol
confere contrato e compatibilidade. Não alterar oráculos para esconder falhas.

Controles F10 no [recibo](../map_editor/delivery/f10_terrain_performance.md):
96 móveis mediana 9,572 ms, p95 14,013 ms; parados 3,594/5,876 ms;
floresta AI média 14,654/p95 21,769 ms; entrada 52,382 s; preparação fria
17,077 s/quente 11,167 s; PCK 94.914.128 B. Amostras/modos distintos, não
combinar como um FPS universal. Dívida de portal/carregamento/picos permanece.
Reusar sondas F10 no mesmo hardware/driver, 3 janelas por controle e mesmo
roteiro; registrar mediana/p95/máximo/memória e frio/quente, delta de tamanho.
Investigar regressão reproduzível >10% em mediana/p95 ou >16 MiB de memória
retida após limpar estágio; limiares de triagem técnica, não aceite de produto.
Nenhum orçamento cosmético pode ocultar perigo/alvo/área essenciais.
Memória F10 não está certificada: medir controle antes de comparar, sem inventar.
Release conserva perfil descartável separado e PCK/exe pareados; sem migração.

P0 documental: valida código/referências/donos; não repete gameplay nem certifica
qualidade visual, som ou desempenho E08. CLI de resume versionado e
WORKFLOW_TOOLING não existem nesta base; diagnóstico Git/documental registrado,
sem copiar ferramenta de origem não autorizada.

## API P1 recebida — contrato auxiliar para P2/P3

[Entrega P1](e08_p1_delivery.md), runtime
`04c77c9c36f5ee86a89a266b0d3a3a07e74fccac`: evento explícito inclui
`payload.presentation_epoch = bridge.current_epoch()` capturado na confirmação;
callback conserva token capturado, nunca troca pelo atual. `current_state()`
copia atores, áreas e projéteis ativos sem replay. `world_paused()`,
`world_pause_changed(bool)` e `world_advanced(float)` são APIs de apresentação.
Dedup FIFO 2.048 IDs por época; impactos também conservam identidade de aplicação
confirmada. Áreas cobertas: ArrowRain, FoliageShelter, PlayerTrap/derivados e
paredes Fire/Lightning/Phantom/Ice por WorldFieldView. HunterTarField/estados
RefCounted especializados conservam indicadores atuais, sem novo adaptador de área.
Impacto tem âncora do alvo, com contact_position_unavailable explícito; não é
coordenada exata de colisão. Esses limites não autorizam geometria inventada.

Delta técnico áudio6/11: [correção de soma](e08_p2_mix_delivery.md) instala
AudioEffectHardLimiter nativo por instância no Geral privado. API/catálogo/caps
permanecem; Master não muda. Saída verificada≤−1dBFS com teto interno−1,01dB,
pré-ganho0 e release100ms. Capturas nativas WASAPI48k demonstram24impactos e32vozes
sem quadros fora da escala; impacto isolado preservado após atraso de áudio2,042ms.
Isso não altera timing de combate nem certifica toda placa/configuração de áudio.
