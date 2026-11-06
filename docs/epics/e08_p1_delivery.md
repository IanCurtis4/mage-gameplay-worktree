# E08 P1 — entrega da fronteira de apresentação

5/11/2026. Executor: Sol Apresentação; validação autoral. Contrato:
[e08_p0_contract.md](e08_p0_contract.md), propriedade:
[e08_dispatch.md](e08_dispatch.md), autorização:
[e08_approved_plan.md](e08_approved_plan.md).

## Candidato e posse

- Base completa P0: `f1f53693823ce5a97518a25fa7bd831874161261`.
- Base integral F10: `c8b80b13d29c468afb7f2ad7ba75eec838e7df32`.
- Runtime/testes/evidência entregues: `04c77c9c36f5ee86a89a266b0d3a3a07e74fccac`.
- Branch: `codex/e08`.
- Checkout: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
- Este recibo recebe commit documental posterior, sem delta nos inputs executados.
  O SHA final do recibo é informado na resposta de entrega e pode ser resolvido por
  `git log -1 -- docs/epics/e08_p1_delivery.md`.
- Estado: ENTREGUE, validação autoral concluída; conferência P0 e supervisão Luna
  pendentes. Não há aceite de produto nem integração em master/playtest.
- Posse de escrita devolvida à coordenação após o commit deste recibo. P1 para de
  escrever; correções podem retornar ao mesmo chat. Não arquivar por esta entrega.

## Implementação e APIs executáveis

`PresentationEventBridge` está em
[scripts/presentation/presentation_event_bridge.gd](../../scripts/presentation/presentation_event_bridge.gd).
Entrega as cinco assinaturas P0: `bind_controller(Node)`,
`begin_stage(String, bool=false)`, `emit_confirmed(Dictionary)->bool`,
`clear_stage()` e `dispose()`, além do sinal `event_confirmed(Dictionary)`.

APIs auxiliares para P2/P3:

| API | Comportamento entregue |
|---|---|
| `RunController.presentation_events()->PresentationEventBridge` | Retorna o filho `PresentationEvents`; pode ser null antes da configuração de mundo. Criação na configuração legada e no attach da vista espacial. |
| `bridge.current_epoch()->int` | Token transitório que invalida callbacks/eventos da época anterior, inclusive ao retomar o mesmo stage_id. |
| `bridge.current_state()->Dictionary` | Cópia de `actors`, `areas` e `projectiles` vivos; conjuração atual/tempo restante, geometrias e posições disponíveis. Não é histórico de eventos. |
| `bridge.world_paused()->bool` | Estado imediato da pausa da árvore. |
| `bridge.world_time: float` | Relógio exclusivamente visual; congela na pausa e reinicia na época. |
| `world_pause_changed(bool)` | Notifica transição no próximo processamento da ponte. |
| `world_advanced(float)` | Emite somente delta visual positivo/finito, fora da pausa. UI pode usar processamento ALWAYS separado. |
| `CombatActor.presentation_health_ready(HealthState)` | Permite observar atores configurados depois de entrar na árvore e substituir a assinatura de HealthState. Não altera dano. |
| `PlayerActor.presentation_cast_context()->Dictionary` | Copia alvo/âncora/direção disponíveis do preparo/commit canônico; legado traz alvo 2D identificado. Sem query física. |

A ponte é um `Control` sem desenho, com mouse ignorado, dentro da exclusão de
apresentação **já existente** do SnapshotRegistry. Não foram acrescentadas variáveis
persistentes a RunController/atores, nem modificados schema, codec ou save. O
snapshot não guarda ponte, relógio, dedup ou assinaturas. A retomada recria esse
subgrafo no attach espacial; `snapshot_passive` marca `resumed=true`.

### Fontes e significados dos eventos

- `cast_start` observa início de preparo confirmado, sem afirmar impacto. Foi
  completado o hook ausente na preparação espacial do jogador e nos casts de mobs.
- `cast_cancel` observa cancelamentos existentes; mobs também notificam os caminhos
  de controle, retorno, alvo trocado e recusa na validação final. Nenhuma regra de
  recusa/pagamento/cooldown foi alterada.
- `impact` vem exclusivamente de `HealthState.damage_applied` com `landed=true`.
  Não usa `attack_requested`, `projectile.hit` nem reconsulta LoS/colisão. Copia os
  dados escalares/geométricos disponíveis do resultado, sem context/ledger vivo.
- `death` vem de `actor_died`; `revive` observa a transição real de saúde no
  processamento visual, inclusive durante a pausa. Não cura/revive o ator.
- `teleport` observa a emissão visual existente no legado e o novo hook depois do
  teleporte espacial bem-sucedido. Recusa não emite evento.
- `projectile_launch` observa a entrada de projéteis já configurados no controller
  e seus descendentes: PlayerProjectile e derivados Mage/Sentinel/Geometer, além
  de ArrowProjectile. Copia posição/cilindro/direção do WorldProjectileMotion,
  velocidade, alcance, origem, alvo e identidade local disponíveis.
- `area_start/area_end` adaptam ArrowRain, FoliageShelter, PlayerTrap e derivados;
  em mundo espacial também FireWall, LightningWall, PhantomBarrier e IceWall, via
  descrição já confirmada de WorldFieldView. Raio/forma/altura/apoio/centros/tempos
  vêm dessas autoridades. Remoção encerra a área com duração zero.
- `stage_enter` publica contexto atual e `resumed`; `stage_exit` encerra a época.
  Scans iniciais/reconstrução não reproduzem launches, áreas iniciadas ou impactos.
- `ui_confirm/ui_cancel` são aceitos pela API explícita durante a pausa; a ligação
  aos controles e o serviço de áudio pertencem a P2.

`actor_id` é o alvo nos impactos e a origem disponível nos launches/áreas.
`payload.target_id`, `source_id`, `entity_id` e `projectile_id` distinguem os papéis.
Informação não disponível fica vazia/explicitamente marcada: posições legadas são
`legacy_position_2d` com `position_unavailable=true`, sem transformar pixels em
pontos 3D. Impactos usam âncora atual do alvo e
`contact_position_unavailable=true`; não alegam conhecer o ponto exato da colisão.

## Validação do DTO, época e limites

Todos os campos P0 são obrigatórios, com `kind`/`skill_id` StringName, posição
Vector3 finita, duração numérica finita não negativa e payload somente de dados
copiáveis. Payload rejeita objetos/callables/resources vivos, números não finitos
e profundidade acima de 16; aceita arrays empacotados de geometria copiados.
Inválidos retornam false sem emissão. Dicionários são copiados profundamente na
fronteira; consumidores devem tratá-los como somente leitura.

**Delta concreto para consumidores P2/P3:** produtores explícitos devem incluir
`payload.presentation_epoch = bridge.current_epoch()` no momento da confirmação.
A época deve ser capturada antes de um callback assíncrono e conservada nele;
nunca substituir o token velho pelo atual ao executar o callback. Evento com
época/estágio antigo retorna false. Eventos automáticos já carregam esse token.
Nenhuma mudança aos documentos P0 foi feita; este é o contrato executável auxiliar
publicado antes dos consumidores, conforme o dispatch.

Dedup retém os últimos **2.048 IDs por época**, FIFO determinístico. O teto limita
memória de identidades, não número de eventos/indicadores: eventos essenciais
novos continuam sendo emitidos quando a janela está cheia. IDs descartados não
possuem dedup eterna. Impactos têm ainda baseline/sequência monotônica de
HealthState por ator: sequência anterior à nova assinatura não reaparece após a
retomada. Binding repetido é idempotente; troca de época desconecta assinaturas;
saída de ator/projétil/campo remove registros e referências fracas. Não há fila de
impactos para tocar depois da pausa. Pausa recusa novos efeitos mundiais; permite
UI e eventos de limpeza/lifecycle.

Para P2, hospedar serviço/vozes sob o subgrafo de apresentação preserva a exclusão
existente do snapshot. Não acrescentar estado de áudio ao schema de gameplay por
inferência. Consumidor configurado depois de stage_enter pode ler stage_id e
current_state para reconstruir ambiente sem solicitar replay de eventos. Definir
process_mode PAUSABLE para vozes do mundo desde a criação; Interface pode ser
ALWAYS. O sinal de pausa da ponte não substitui essa configuração inicial.

## Arquivos próprios efetivamente alterados

1. `scripts/presentation/presentation_event_bridge.gd` e `.uid`.
2. `scripts/actors/combat_actor.gd`, `player_actor.gd`, `enemy_actor.gd`.
3. `scripts/main.gd`.
4. `tests/e08_presentation_test.gd` e `.uid`.
5. `tools/verify.ps1`, somente registro do novo teste.
6. `docs/epics/e08_evidence/p1/{inputs.json,hashes.json,raw_logs.zip}`.
7. `docs/epics/e08_p1_delivery.md` (este recibo).

Não foi necessário pedir arquivo adicional. CharacterAnimation,
CombatAnimationState, atlas/anexos, assets, geometria, RNG, fórmulas, saves e docs
P0 não foram editados. Textos UTF-8 originais dos cinco arquivos existentes
alterados foram confrontados com a base: linhas com caracteres não ASCII foram
preservadas. Corrigida a recodificação acidental de player_actor e um comentário
de enemy_actor durante desenvolvimento, antes da rodada final.

## Evidência autoral e reprodução

Engine standard da **mesma instalação autorizada** no principal:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`.
Versão `4.7.2.stable.official.ed1daf0bf`; SHA256
`ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
A execução direta foi expressamente autorizada pela coordenação após diagnóstico
do wrapper console dessa instalação. Nenhum download ou alteração de engine.

Uma fixture preexistente foi sincronizada somente por deltas:
`.godot/verification/e07_f1/fixture_project`. Configuração conserva a única diferença
VCS autoload true→false. O runner verificou os hashes de todas as fontes dos dois
lados antes de iniciar. Manifesto da fixture SHA256:
`d2f874cd87f9efc71c1a79ccedc72d028627b9f82a23e1a56bd7eb751a45a674`.
APPDATA foi isolado em `fixture_project/.godot/e08_user`; sem perfil pessoal.

Importação compatível passou na rodada `e08_p1_dev3`; alterações posteriores eram
somente fontes GDScript já registradas, compiladas pelos testes. Rodada final em
`.godot/verification/e08_p1_final`: **12/12 etapas selecionadas passaram** entre
308 disponíveis; exit 0 em todas, zero erros, zero timeouts. Limite 300 s por etapa.
Não se certificam as etapas omitidas da suíte.

| Etapa | Checks | Resultado |
|---|---:|---|
| combat_animation_test | 39 | PASS |
| e08_presentation_test | 2.122 | PASS |
| mage_gameplay_test | 52 | PASS |
| e04_teleport_rank_integration_test | 29 | PASS |
| e06_rx_mob_ai_test | 4 | PASS |
| e07_f7_presentation_test | 27 | PASS |
| e07_f3_action_matrix_test | 2.004 / 21 cenários | PASS |
| e07_f3_lifecycle_test | 90 | PASS |
| e07_f1_actor_integration_test | 193 | PASS |
| e07_f1_cast_test | 113 | PASS |
| e07_f1_fields_test | 499 | PASS |
| e07_f1_presentation_test | 39 | PASS |

O novo teste cobre DTOs positivos/negativos, cópia, dedup limitada sem perda de
essenciais, assinatura após setup tardio, limpeza de 30 projéteis, liberação da
assinatura de HealthState, morte/revive pausados, relógio/UI, callbacks de época
anterior, baseline de impactos na retomada, cast/cancel reais, teleporte aceito e
recusado, launches e campos com geometria canônica, contexto sem replay e estágio
antigo. A matriz/lifecycle exercitam a persistência existente com a ponte excluída.

[inputs.json](e08_evidence/p1/inputs.json) registra SHA256 dos bytes executados,
testes, runner, engine, manifesto/config da fixture e quatro backups. Também traz
SHA256 dos blobs Git dos nove inputs próprios, pois core.autocrlf diferencia bytes
de checkout e blob. [hashes.json](e08_evidence/p1/hashes.json) registra os hashes
brutos dos outputs, plano e checks. [raw_logs.zip](e08_evidence/p1/raw_logs.zip)
conserva **os bytes originais** dentro de ZIP binário para impedir normalização
Git de CRLF. SHA256 do ZIP:
`99e99dc7b18cca9c2b36fdd4b3cab4ab19546a4b8aceb634c64fb4bd28dae54e`.
Evidência durável total: aproximadamente 16 KiB, sem cópia de projeto/cache.

Reprodução a partir deste checkout (PowerShell 7):

```powershell
Set-Location 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5'
$env:APPDATA = Join-Path $PWD '.godot/verification/e07_f1/fixture_project/.godot/e08_user'
$engine = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe'
$selection = @('combat_animation_test','e08_presentation_test','mage_gameplay_test',
  'e04_teleport_rank_integration_test','e06_rx_mob_ai_test',
  'e07_f1_actor_integration_test','e07_f1_cast_test','e07_f1_fields_test',
  'e07_f1_presentation_test','e07_f3_lifecycle_test',
  'e07_f3_action_matrix_test','e07_f7_presentation_test')
./tools/verify.ps1 -F1Fixture -GodotPath $engine -Test $selection -CheckTimeoutSeconds 300 -VerificationDirectory (Join-Path $PWD '.godot/verification/e08_p1_luna')
```

Usar a mesma fixture sequencialmente; não bootstrap/copiar um projeto novo. Antes
de Luna, conferir inputs e manifesto congelados. Se houver necessidade de
sincronização posterior, copiar somente arquivos divergentes e atualizar seus
hashes no manifesto; não relaxar o confronto do runner. Conferir membros do ZIP
com os SHA256 em hashes.json. O plano registra HEAD=P0 com árvore então suja; o
commit de runtime acima incorpora exatamente esses inputs. Este recibo não muda
runtime e não justificou nova repetição da suíte.

### Falhas de desenvolvimento preservadas

- Wrapper console inicial: `CreateProcess failed, error 193`, exit -1, antes do
  jogo. SHA256 do wrapper em inputs.json. Continua limitação local conhecida;
  utilizou-se diretamente o standard pareado da mesma instalação.
- Primeira importação direta: exit 0, mas ERROR ao gravar editor_settings fora da
  área gravável; o runner recusou corretamente. APPDATA isolado corrigiu a execução.
- Teste novo inicialmente tinha alvo fora de alcance e um resultado sintético
  incompleto na tentativa de notificar outros listeners de HealthState. A fixture
  foi corrigida usando movimento canônico e chamada negativa diretamente à ponte.
- A seguir, o teste real revelou preparo espacial aceito sem cast_start. Corrigido
  o hook em PlayerActor; as mesmas expectativas de início/cancel permaneceram.
- Logs das falhas estão no ZIP, identificados por console_wrapper_failure,
  editor_settings_failure, development_fixture_failure e development_world_cast_failure.
  Nenhuma falha foi escondida com alteração de oráculo. Rodada final limpa acima.

## Limitações e preservação

Sem áudio, catálogo/samples ou produção raster neste P1. UI ainda não publica
confirmações por si; isso é P2. O bridge não promete novas receitas de VFX para
todos os kits: efeitos instantâneos/estados especializados que não estão na lista
de adaptadores mantêm seus indicadores atuais e seus impactos confirmados;
consumidores futuros devem usar dados canônicos/emit_confirmed quando precisarem
de geometria adicional. Não inferir raio/altura de sprite nem criar queries para
completar dados ausentes. HunterTarField e estados RefCounted especializados não
possuem adaptador area_start/area_end neste P1. Esta capacidade é explícita para P2.

P1 validou integração headless na cena nativa, sem certificação artística, auditiva,
zoom 50/100/160%, UI120%, export/PCK ou comparação mediana/p95/memória de F10.
Essas provas pertencem ao piloto/consolidação previstos; não se inventou controle
de memória nem se declarou superada a dívida de carregamento/portais de F10.
A supervisão Luna deste checkpoint ainda deve ser registrada separadamente.

Foram mantidos os dois checkouts, uma fixture e uma instalação de engine; nenhum
export inteiro, master, push, mudança do habitual, save pessoal ou backup foi
feito. Os quatro .bak continuam untracked e com os SHA256 de P0, registrados em
inputs.json. Fora eles, árvore rastreada limpa no commit de entrega. Não houve
limpeza recursiva de arquivos do usuário; o cache existente permanece para Luna.
