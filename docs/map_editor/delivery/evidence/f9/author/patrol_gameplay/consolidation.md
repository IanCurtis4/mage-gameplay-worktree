# F9 checkpoint30 — patrulha do Bosque e abertura no jogo

30/10/2026. Consolidação Sol (Claude Opus). Terra = Claude Sonnet (autoria AX);
Luna = Claude Haiku (teste CandidateBatch e supervisão). Checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`, branch
`codex/map-editor-f9`. Engine `.tools/godot/Godot_v4.7.2-stable_win64.exe`,
SHA256 AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424.
Fixture única `.godot/verification/e07_f1/fixture_project`; perfil descartável.

## Commits

| SHA | Conteúdo |
|---|---|
| 0bef9d53 | base (checkpoint29) |
| e5fddf84 | população atualizada, patrulha nova, evidência Terra area_patrol e compile_02 |
| 01ffd228 | GameplayCandidate em lote, teste CandidateBatch(+UID da engine), runner, ownership |
| posterior | este recibo, checkpoint30 e evidência de abertura no jogo |

## Autoria AX (Terra) — evidence/f9/terra/area_patrol

Pedidos montados por Terra (`build_requests.py`, conferência estática
`check_requests.py`/`check_output.txt`, `delivery.md`), executados por Sol com o
wrapper síncrono `author/encounter_authoring/run_ax_request.py` (360s, mapa
protegido conferido antes/depois). Nenhuma fonte escrita à mão.

| Etapa | Ações | Tempo | Resultado |
|---|---|---|---|
| compile_02 (checkpoint29) | open+compile | 234,363s | PASS, pacote 543a1256… |
| population_update_preview | open, brush/upsert, slot/upsert, preview | 167,725s | proposta 3e4bb09c…; diff 7 preservados, 0 adicionados/alterados/removidos |
| population_update_apply | mesmas + apply + save | 161,708s | fonte 1404da19… (bytes 7D3B76FB…) |
| patrol_author | new, population/import, map/query, route/upsert, save | 43,021s | fonte 58df5d63… (bytes 504E58E9…) |
| patrol_compile_01 | open, compile | 211,333s | PASS, pacote f3cdb460… |
| patrol_launch_01 (nativo) | open, compile, gameplay/launch | 308,673s | janela lançada, HEAD 01ffd228 |

Decisão de autoria: `demo_chaser` não declara aggro_radius (0); PatrolCompiler
recusa com `patrol_unsupported`. O slot fixo `alley_guard` e o brush
`alley_patrol` usam `pilot_bulwark_species`/normal/trial_stage_1 (aggro 420,
leash 850 pelo catálogo de gameplay). Rota `alley_watch` ping_pong, mesmo apoio
`overpass/c_e33596bc5a5c9222_0_0_4_10`: alley_north [1640,0,840] espera 2,5s,
alley_south [1640,0,1100] espera 2,0s. Folgas calculadas por Terra: borda 152,
sólido mais próximo 87,4, slot do grupo 64; o compilador canônico validou corpo,
trechos e leash.

## Código (Sol) e testes (Luna)

`GameplayCandidate.prepare` chamava `_both` (dois `WorldGeometry.path`) por
objetivo, portal e home de slot; no Bosque, entrada→santuário não retornava em
120s. A preparação exige só existência: `_round_trips` faz position_query por
item, um `connectivity_batch` com os pontos legais (outward E inward), agrupa
slots por estágio e perfil inteiro e relata o primeiro item falho na ordem
original. Erros operacionais do lote (stale/budget/cancel) não viram negativo;
`complete=false` → `navigation_budget_exceeded`. `_both` permanece como referência.
Validação de rota de patrulha, movimento, leash, ataque e fórmulas inalterados.
Limite: a união do lote pode admitir positivos que um path individual não
encontraria (mesma propriedade do Planner); não é custo mínimo.

| Etapa | Checks | Resultado |
|---|---|---|
| CandidateBatch (author run, antes da UID na fonte) | 18/18 | PASS |
| CandidateBatch | 18/18 | PASS |
| GameplayWindow | 33/33 | PASS |
| GameplayCli | 18/18 | PASS, prévias fechadas |
| GameplayControls | 29/29 | PASS |
| GameplayNative | 52/52 | PASS, 3 capturas |

Supervisão Luna (`evidence/f9/luna/gameplay_candidate_batch/report.md`): exit0,
sem timeout/abort, sem SCRIPT ERROR/Parse Error/ERROR, marcador presente, HEAD
igual antes/depois, engine conferido, 2063 inputs com hashes iguais nas cinco
etapas. Luna marcou FAIL formal no critério "failed vazio" para quatro etapas
porque testes anteriores não emitem o campo `failed`; Sol confere que todos os
checks são ok e as contagens batem com o runner, que não exige o campo. Não é
falha de execução. Supervisão não é auditoria semântica.

Hashes: gameplay_candidate.gd E16DF110…; teste A72CD2D3…; UID 69D81AAA…;
run.ps1 84B47F4C….

## Bosque no jogo

Janela "RagRPG · Teste descartável · 9597a8323d", candidato 9597a832…,
Espadachim, GTX1080/OpenGL3.3. Estado `ready` 107,6s e `active` 138,4s após o
retorno do AX (preparo inclui inicialização, mapa e população). engine.log sem
erros. Sete inimigos vivos nos homes/planos esperados; `alley_guard` em z921 ao
ativar e no primeiro ponto z840 depois — patrulha executando no runtime.

Achado: sem jogador no controle, o personagem morreu na entrada em ~2min
(hp0, estado `recovering`). Os 3 `demo_chaser` da clareira nascem a 140–280 da
entrada e, sem aggro, perseguem desde o início. Comportamento de conteúdo/espécie;
mudar espécie, brush ou distância é decisão de produto, não correção de engine.

## Limites e pendências

Não houve partida humana, combate jogado até o fim, objetivo `shrine_completion`
concluído, restart ou medição de FPS/frame time. Preparo 108–138s ainda é longo.
Compilar população/patrulha pelo botão da GUI usa worker editor com 180s; a
compilação inline AX leva ~200s, logo a GUI provavelmente estoura até otimização.
Busca individual (f9_navigation_relaxation) sem implementação. Matriz F9 integral
continua aberta: reconciliação, síntese regional, assets/export/release, UX final,
recuperação e responsividade. Sem playtest pessoal, save, master, push ou F10.
