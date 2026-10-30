# F9 checkpoint31 — botão "Iniciar teste" e carregamento fora da thread principal

30/10/2026. Sol/Astra (Claude Opus). Reexecuções em `evidence/f9/luna/…` feitas pelo
executor de Sol; Luna não foi acionada nesta rodada.
Base 7452c2fc, branch `codex/map-editor-f9`, checkout `.tools/map-editor-m5`,
fixture única `e07_f1`, Godot 4.7.2 SHA AB1824F8…. Código em commit próprio.

## Pedido humano

O teste parecia travado carregando, o personagem aparecia já morto e "Reiniciar"
deixava a tela preta. Pedido: um botão "Iniciar" para carregar tudo antes do
teste começar, e verificar em paralelo se a causa era o carregamento ou o debug.

## O que mudou

- `gameplay_app.gd`: resolução e `Candidate.prepare` em `Thread`
  (`open_async`/`open_window_async`, `_load_job` estático sem acesso à árvore);
  rótulo "Carregando o mapa… Ns" com relógio; `_finish_open` comum.
- Portão: com `hold_start` (ou `--f9-hold-start`), `start()` monta o mundo,
  pausa a árvore, status `held` e mostra "Iniciar teste". `begin()` só aceita
  `held` (`preview_not_held` caso contrário). `_hold_pending` evita o status
  passar por `active` antes de `held`. Suspender a partir de `held` despausa antes.
- `restart` usa `open_async` + portão: a janela não congela mais.
- Diagnóstico por janela: `timings.json` (resolve/prepare/start/primeiro
  quadro/boot→mundo/begin) e `metrics.jsonl` (1 linha/s, teto 7200).
- Launcher/Tools/CLI aceitam `hold_start`; protocolo ganhou `begin`;
  `window_state` relê o status 3× (corrida com escrita atômica).

## Evidência

- GameplayGate24 (novo): gate_import_01–03 PASS (import), luna `*_03` PASS.
- Regressão pós-mudança (043): GameplayWindow33, GameplayCli18,
  GameplayControls29, GameplayNative52, GameplayEditorNative22, CandidateBatch18 PASS.
- Bosque real com portão (bosque_hold_01): `prepare_ms` 93.483 em thread;
  `start_ms` 31.772 e primeiro quadro 31.883 ainda na thread principal;
  boot→mundo 144.988; `begin` 148.012. Em jogo ativo: 18–24 FPS, quadro pior
  136 ms (combate local).

## Causa da lentidão

Não é o modo debug: o mesmo probe no template release ficou ≤1,3× mais rápido.
A causa é `WorldGeometry.path` em rotas longas que cruzam a emenda (55–87 s cada,
sem reuso) chamada por replanejamento de IA. Diagnóstico e opções em
`contracts/f9_runtime_navigation.md`; o usuário escolheu o grafo reutilizável.

## Pendências herdadas

`start()` ~31,8 s na thread principal; validação duplicada do candidato dentro de
`prepare` (~18 s); grafo reutilizável (multi-sessão); aceite humano.
