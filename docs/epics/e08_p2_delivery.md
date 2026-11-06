# E08 P2 — serviço de áudio e configuração local

6/11/2026. Sol Áudio, validação autoral. Autoridade: [plano aprovado](e08_approved_plan.md),
[contrato](e08_p0_contract.md), [posse/dispatch](e08_dispatch.md) e [API P1](e08_p1_delivery.md).

## Candidato e posse

- Base completa recebida: `61d91a65d6673f12bfc8915061668d1d56b6c770`.
- Dependência P1: runtime `04c77c9c36f5ee86a89a266b0d3a3a07e74fccac`,
  recibo `d84991e52bf724284f0bf8310de525104f563b81`, validados antes deste dispatch.
- Runtime, testes e evidência P2: `2f72322a3b419eb04eef92a83cbba15ba40214d3`.
- Branch: `codex/e08`.
- Checkout único de escrita: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
- Este recibo recebe commit documental posterior; seu SHA final pode ser resolvido
  com `git log -1 -- docs/epics/e08_p2_delivery.md` e consta da resposta de entrega.
- Estado: ENTREGUE com validação autoral e limitação herdada discriminada abaixo.
  Conferência P0 e supervisão Luna pendentes; nenhum aceite artístico/auditivo ou de produto.
- Após o commit deste recibo, posse de escrita devolvida a P0. P2 para de escrever;
  correções retornam a este chat. Não arquivar por efeito da entrega.

## Comportamento e APIs

`PresentationAudioService`, em `scripts/presentation/audio_service.gd`, é um Control
`PresentationEvents/PresentationAudio` filho da ponte. Todas as vozes ficam nesse
subgrafo já excluído pelo SnapshotRegistry; nenhum campo, omissão ou schema novo de
persistência. RunController expõe `presentation_audio()->PresentationAudioService`
e conserva `presentation_events()`. Não há variável de áudio nova no controller.

| API | Resultado e contrato |
|---|---|
| `configure(bridge: PresentationEventBridge, preferences_path: String = "user://audio.cfg") -> void` | Instala quatro buses privados e exatamente 32 AudioStreamPlayer; binding repetido à mesma ponte/path é idempotente. Trocar path relê configuração sem replay. |
| `set_volume(channel: StringName, linear: float) -> Error` | Limita valores finitos a [0,1], aplica ao bus e tenta gravar. Canal desconhecido/NaN/INF retorna ERR_INVALID_PARAMETER. |
| `set_muted(channel: StringName, muted: bool) -> Error` | Mute independente, aplicado e salvo; não apaga volume. |
| `clear_stage() -> void` | Encerra vozes anteriores de todos os canais e contexto de ambiente pendente. |
| `dispose() -> void` | Desconecta somente assinaturas próprias, libera vozes/streams/buses; idempotente. Reconfigurar depois não acumula recursos. |
| `confirm_ui(cancelled: bool = false) -> bool` | Publica ui_confirm/ui_cancel na ponte após confirmação/cancelamento real. Captura época sincronicamente; não representa cast, impacto ou input tentado. |
| `install_streams(streams: Dictionary) -> bool` | Injeção de fixture por ID conhecido/AudioStream; não modifica definições. Produção carrega paths do catálogo automaticamente, sem precisar desta API. |
| `diagnostics() -> Dictionary` | Cópia de capacidade, contagem ativa por canal, played/dropped, samples ausentes, retenção dedup, época e estágio. |
| `preferences_changed` / `configuration_error(operation: StringName, error: int)` | Atualização da UI e erro observável de load/save. Preferências também expõem load_error, save_error e invalid_config. |

Canais lógicos: `general` (Geral), `effects` (Efeitos), `interface` (Interface),
`ambience` (Ambiente). Buses físicos `E08_<instance_id>_<channel>` são privados,
sem alterar Master: filhos enviam ao general próprio, e general envia a Master.
Volume linear inicial 1 e mute false por canal. `AudioPreferences` usa ConfigFile
local em `user://audio.cfg`, seções com os IDs acima, chaves `volume` e `muted`.
Arquivo ausente usa defaults; dados inválidos usam defaults seguros no canal
inválido e sinalizam erro. Erro de load integral também mantém defaults. Gravação
falha retorna Error/sinaliza e mantém valor vivo, com mensagem explícita no painel;
novo ajuste tenta salvar novamente. Nenhum acesso ao save de gameplay.

Pools: **24 Efeitos + 4 Interface + 4 Ambiente = 32 vozes**, max_polyphony=1.
Escolhe primeiro slot livre; saturado, a menor prioridade é vítima, empatando pela
sequência mais antiga. Prioridade nova menor que a vítima é descartada; igual pode
substituí-la. `finished` libera slot e referência ao stream. Nenhum indicador visual
essencial é limitado por esses caps. Catálogo não tem estado de run: dados constantes,
`definition(id)` entrega cópia profunda, e `ids()/for_kind(kind)` publicam identificação.

Consome exclusivamente `event_confirmed`, preservando `payload.presentation_epoch`
recebido. Rejeita callbacks de época/estágio antigo; não troca o token pelo atual.
Dedup FIFO de 2.048 IDs por época, preservada em configure/rebind da mesma ponte;
não promete dedup eterna depois da janela. Troca de estágio encerra sons anteriores
e inicia apenas o ambiente atual. Binding tardio/retomada não reexecutam casts,
launches, áreas ou impactos históricos. Não há fila de transientes durante pausa.

Vozes de mundo nascem PAUSABLE; Interface nasce ALWAYS. O sinal de pausa também
sincroniza stream_paused, inclusive quando configure ocorre já pausado. Despausar
continua sons congelados; retomada de snapshot inicia um ambiente novo do estágio atual.
A configuração de áudio/UI permanece utilizável com a batalha pausada.

**Fronteira de staging recebida da coordenação:** snapshot install pode chamar
attach enquanto snapshot_passive=true, antes de congelar os modos. O serviço verifica
host passivo, host DISABLED e capacidade de processamento antes de iniciar qualquer
voz. Conserva somente contexto atual pendente; drops de transientes/UI durante staging
não são filas. Espera do writer, estado incerto e abort não soam. Ativação real permite
um único ambiente no próximo processamento de apresentação, sem relógio de gameplay.
Teste sintético cobre host passivo antes do freeze, árvore desativada, espera,
ativação idempotente e abort; regressões F3 cobrem o install/activate real existente.
Não foi alterado SnapshotRegistry nem o writer.

## Catálogo estável para P3

Diretório de produção reservado: `res://assets/audio/e08/`. Os **12 paths exatos**
abaixo são carregados automaticamente. Todos são WAV; nenhum sample de produção
foi criado neste P2. O mapeamento é genérico por kind, sem seleção por skill/RNG,
sem panning/consulta física ou novo cálculo de geometria. Pitch e ganho da voz são 1;
volumes vêm dos buses. P3 conserva fonte/receita/proveniência e importa os samples.

| ID | Kind | Canal | Prioridade | Path exato |
|---|---|---|---:|---|
| `world.cast_start` | cast_start | effects | 20 | `res://assets/audio/e08/world_cast_start.wav` |
| `world.cast_cancel` | cast_cancel | effects | 30 | `res://assets/audio/e08/world_cast_cancel.wav` |
| `world.projectile_launch` | projectile_launch | effects | 10 | `res://assets/audio/e08/world_projectile_launch.wav` |
| `world.impact` | impact | effects | 40 | `res://assets/audio/e08/world_impact.wav` |
| `world.area_start` | area_start | effects | 20 | `res://assets/audio/e08/world_area_start.wav` |
| `world.area_end` | area_end | effects | 20 | `res://assets/audio/e08/world_area_end.wav` |
| `world.teleport` | teleport | effects | 50 | `res://assets/audio/e08/world_teleport.wav` |
| `world.death` | death | effects | 60 | `res://assets/audio/e08/world_death.wav` |
| `world.revive` | revive | effects | 60 | `res://assets/audio/e08/world_revive.wav` |
| `ui.confirm` | ui_confirm | interface | 50 | `res://assets/audio/e08/ui_confirm.wav` |
| `ui.cancel` | ui_cancel | interface | 50 | `res://assets/audio/e08/ui_cancel.wav` |
| `ambience.stage` | stage_enter/contexto atual | ambience | 0 | `res://assets/audio/e08/ambience_stage.wav` |

**Loop de ambiente garantido pelo serviço para o WAV contratado.** Se o
AudioStreamWAV importado vier com LOOP_DISABLED, o serviço duplica o recurso e
ativa LOOP_FORWARD de 0 até o número de frames da amostra inteira. O recurso
original permanece intacto. Se o WAV já trouxer loop autorado válido, conserva-o.
P3 não precisa habilitar loop no `.wav.import` para o caso padrão; pode autorar
pontos de loop no WAV/import, mas precisa validar a costura/audibilidade no piloto.
Não substituir esse ID por stream de outro formato sem devolver mudança de contrato
à Sol. Os outros 11 WAVs devem ser one-shot, com loop desativado na importação.
Teste usa WAV sintético de 100 ms inicialmente sem loop, verifica a cópia, continua
além da duração, congela e retoma sem segunda voz. Ausência atual de samples não
é usada como prova de continuidade de ambiente nem de qualidade sonora.

Samples ausentes são silêncio explícito em `diagnostics().missing_samples`, sem
placeholder sonoro de produção. UI e indicadores visuais seguem presentes. Este
catálogo não inclui música, sound design final ou cobertura específica de cada kit.

## Painel e confirmações reais

`AudioSettingsPanel` é filho do conteúdo rolável existente de BattleControls,
com Geral/Efeitos/Interface/Ambiente, slider [0,1], porcentagem e Silenciar por linha.
Tab/setas funcionam; follow_focus conserva acesso na rolagem. PanelContainer se
ajusta à área disponível em UI120%; botão Voltar à batalha aceita foco por teclado.
Load inválido e falha de save têm texto pt-BR; binding/descarte não acumulam listeners.

Integração confirma abertura/fechamento real de configurações, ajuste de áudio,
captura de atalho efetivamente aceita/cancelada e organização de barra somente
depois da aceitação pelo controller/persistência. Pedidos recusados de skill/barra,
conflito de tecla e abertura/fechamento redundantes não se tornam impactos/confirm.
Não foram acrescentados sons indiscriminados a todo botão ou input do jogo.

[Captura nativa UI120%](e08_evidence/p2/audio_settings_ui120.png): viewport 1280×720,
OpenGL Compatibility/NVIDIA GTX1080, painel rolado até Áudio. Os quatro canais,
valores, mutes e status ficam legíveis e contidos; teclado alterou Efeitos durante
pausa. Inspeção autoral realizada sobre o PNG do renderer real, além dos bounds
assertados. Essa prova é do painel, não aceite visual/sonoro do piloto P3.

## Validação e evidência durável

Engine autorizada e pareada:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`,
`4.7.2.stable.official.ed1daf0bf`, SHA256
`ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
Não se repetiu o wrapper console com falha193 conhecido de P1.

Mesma fixture `.godot/verification/e07_f1/fixture_project`; sincronização de deltas,
sem projeto/cache/export adicional. APPDATA isolado em `fixture_project/.godot/e08_user`.
O confronto final conferiu **2.265 fontes** nos dois lados. Manifesto congelado SHA256
`dffd93370f03b0a1009b78cb14b5c6fc86ea76f24b45624379e27a996ab82dc7`.
A única diferença de project.godot continua VCS autoload true→false.

`tools/verify.ps1 -F1Fixture`: seleção contratada e UI afetada em `e08_p2_final`,
**9/9 etapas selecionadas PASS**, exit0, zero erros/timeouts, 300 s por etapa;
309 etapas disponíveis, omitidas não certificadas.

| Teste | Checks finais compatíveis | Resultado |
|---|---:|---|
| combat_animation_test | 39 | PASS |
| e08_presentation_test | 2.122 | PASS |
| e08_audio_test | 82 | PASS no delta final |
| battle_ui_test | 47 | PASS |
| action_bar_ui_test | 80 | PASS |
| e07_f7_presentation_test | 27 | PASS |
| e07_f3_action_matrix_test | 2.004 / 21 cenários | PASS |
| e07_f3_lifecycle_test | 90 | PASS |
| e07_f1_presentation_test | 39 | PASS |

A rodada de nove etapas tinha áudio com 78 checks. Depois mudou **somente** o
ramo de loop de WAV ambiente em audio_service e seu teste: reexecutado pelo runner
em `e08_p2_loop_final` (82 checks) e nativamente em `e08_p2_native` (83, incluindo
salvar captura), ambos sem erros/timeouts. As oito regressões conservam todos os
seus inputs e não têm samples para entrar no ramo novo; evidência composta, sem
somar repetições como cobertura independente. Editor import limpo em `e08_p2_ui_dev`
continua compatível: somente fontes GDScript já registradas mudaram depois.

[inputs.json](e08_evidence/p2/inputs.json) registra 23 inputs, 13 blobs próprios,
engine, fixture/config e quatro backups. [hashes.json](e08_evidence/p2/hashes.json)
e [raw_logs.zip](e08_evidence/p2/raw_logs.zip) preservam 63 membros com hashes,
logs/planos/checks, fontes pré-loop mínimas e manifesto/config da fixture; ZIP
mantém os bytes brutos apesar de core.autocrlf. SHA256 do ZIP:
`d8fc67e05955a498d6498c8fbb8cf51b82a33a496287204f4d8e002693f8d4ec`.
Todos os membros, checks concluídos e hashes de outputs finais foram reconferidos.
Dados duráveis totalizam aproximadamente 300 KiB, sem fixture inteira.

### Falhas preservadas e limitação herdada

- Primeiro confronto recusou runner não sincronizado; corrigida a cópia delta de
  tools/verify e seu hash antes de executar. Nenhuma expectativa alterada.
- Desenvolvimento inicial tinha espaços inseridos em main com restante tabulado;
  import recusou parser. Corrigida indentação própria, sem recodificar textos.
- Primeira fixture assumia que slot0 era sempre o mais antigo depois de saturar
  o pool, e teclado começava em 25% sem estabelecer esse estado. Corrigidos os
  arranjos: vítima obtida por menor sequência e volume inicial explicitamente 25%.
- Espera fixa inicial de 0,4s para áudio real teve falha intermitente no startup;
  teste agora aguarda notificação efetiva de término com prazo de 3s, sem fingir
  liberação ou chamar finished artificialmente. Rodadas finais headless/nativa passam.
- **ui_layout_test FAIL 1/30**, `help remains visible at (1280, 720)`, na ampliação
  de UI. Reproduzido exatamente com main e BattleControls originais da base
  `61d91a65d6673f12bfc8915061668d1d56b6c770`, mesma fixture/engine/perfil.
  ZIP contém `e08_p2_ui_baseline/{baseline.json,engine.log,output.log}`, hashes dos
  dois inputs originais e restaurados; restauração ocorreu em finally antes da
  seleção final. Não é PASS nem regressão atribuída ao áudio. P0 recebeu prova e
  orientou preservar a falha herdada, sem ampliar pacote para refazer help/HUD.
  P0 avaliará essa limitação antes de liberar consumidor. Teste/oráculo intactos.

## Reprodução e preservação

PowerShell 7, a partir do checkout indicado, com os hashes congelados conferidos:

```powershell
$fixture = Join-Path $PWD '.godot/verification/e07_f1/fixture_project'
$env:APPDATA = Join-Path $fixture '.godot/e08_user'
$engine = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe'
$selection = @('combat_animation_test','e08_presentation_test','e08_audio_test',
  'battle_ui_test','action_bar_ui_test','e07_f7_presentation_test',
  'e07_f3_action_matrix_test','e07_f3_lifecycle_test','e07_f1_presentation_test')
./tools/verify.ps1 -F1Fixture -GodotPath $engine -Test $selection -CheckTimeoutSeconds 300 -VerificationDirectory (Join-Path $PWD '.godot/verification/e08_p2_luna')
# Inspeção nativa, sequencial, no mesmo ambiente isolado:
& $engine --path $fixture --script res://tests/e08_audio_test.gd -- --audio-native
```

Luna deve conferir evidência compatível antes de repetir suítes. Configuração,
manifesto e preloop_inputs estão no ZIP; fontes finais estão no commit candidato.
Não editar expectativas nem fonte durante supervisão. O runner verifica os hashes
antes de iniciar; o novo teste também chama Fixture.sources_current().

Somente os 13 arquivos de runtime/testes/UID/runner listados em inputs.own_files,
este recibo e quatro artefatos de e08_evidence/p2 foram alterados. Nenhum documento
P0, ponte P1, asset, projeto, registro de snapshot ou teste existente foi editado.
Linhas preexistentes com caracteres não ASCII de main/BattleControls foram
comparadas com a base e preservadas. Não se introduziram fórmulas, RNG, alcance,
LoS, dano, cooldown, recompensa, schema ou mudança de timing de gameplay.

Permanecem dois checkouts, uma fixture e a engine existente. Os quatro .bak
untracked mantêm hashes P1/P0; save pessoal, backups, habitual e master intactos.
Sem push, novo checkout/chat, export ou pacote P3. Fixture/cache/perfil de teste
isolado permanecem temporariamente para a supervisão sequencial Luna; não houve
limpeza recursiva de dados pessoais. Espaço livre ao fechar: aproximadamente 2,46 GiB.

Limites: sem samples/sound design finais, inspeção auditiva do piloto, export/PCK,
comparação de custo F10, mediana/p95/memória ou aceite humano. Áudio é não espacial,
genérico por kind; 4 slots Ambiente estão reservados, produção inicia um loop atual.
O teste de staging usa host com snapshot_passive mais regressões F3 reais; não
simula novo protocolo do writer. Dívida de help citada acima continua explícita.
