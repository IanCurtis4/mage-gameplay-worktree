# F9 — snapshot denso e retomada da colina

Data: 28/10/2026. Papel da evidência: supervisão Luna; resultado ainda pendente de correção e repetição da prova de retomada. Checkout: `.tools/map-editor-m5`. HEAD congelado e preservado durante as execuções: `fac5db2f228d1f5bf11cf31a17e0b89709e730d8`. Godot 4.7.2 standard (`Godot_v4.7.2-stable_win64.exe`, SHA-256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`). Fixture única: `.godot/verification/e07_f1/fixture_project`; ambas as etapas usaram `-SkipImport`. O runner registrou `head_before == head_after` e confirmou igualdade dos hashes de cada input entre source e fixture.

## Resultado deste lote

| Etapa | Resultado | Escopo |
|---|---:|---|
| SnapshotDensity | PASS 33/33 | Grafo metadata com mil células; transporte estrutural sem compressão; wire v1/v2; compatibilidade, identidade, tipos e teto físico |
| RoundedResume | FAIL, 7/9 verificações alcançadas; resultado final contém 9 checks | Processo novo abriu e retomou a sessão e restaurou mapa/posição/corpo; pick e movimento falharam com `ambiguous_surface` |

A execução parou na primeira falha real, sem modificar inputs, runtime ou expectativas. Não houve `SCRIPT ERROR`, `Parse Error`, `ERROR` ou timeout. O teste não chegou às verificações de caminhada concluída, captura visual, resuspensão e métrica final do checkpoint. Por isso não existe captura PNG desta tentativa de retomada.

### SnapshotDensity 33/33

O teste verificou o limite de 4 MiB sobre o envelope estrutural antes do DEFLATE e manteve separada a métrica do payload lógico `var_to_bytes`. A amostra de mil células passou; o grafo recuperado manteve arrays/dicionários tipados, ciclo, aliases repetidos, distinção entre arrays iguais porém independentes e colisão de fingerprint sem fusão. O payload anterior permaneceu imutável após nova captura.

Os cinco casos adicionados também passaram: leitura wire v1 com descriptors de dicionário expandidos para pares inline, rejeição de referência de key layout fora do intervalo, aridade divergente, chave duplicada e versão de wire 99. Mantiveram-se os testes de wire v2, checkpoint formato 2, checkpoint legado formato 1, integridade/digest, payload inválido e rejeição de grafo acima do limite.

Runner e logs:
- `density_final/runs.json` — PASS, exit 0, timeout false, 33/33.
- `density_final/geometry.output.log` e `density_final/geometry.engine.log`.

O teste atesta o cumprimento do teto, mas não imprime os tamanhos medidos para o grafo sintético. A referência da sessão real já persistida, obtida da execução anterior com o mesmo runtime, é checkpoint formato 2 com `byte_count=3,594,152` (abaixo de 4,194,304) e digest do payload descompactado `2e49aa6f9dd809fcd3c512fca0eeed78ccf55d339352034ee935257de5c914f8`. O arquivo de perfil/sessão não foi editado manualmente.

### Retomada da sessão real — falha

A prova usou um processo Godot novo e a sessão descartável existente em `.godot/verification/e07_f1/fixture_project/.godot/map_authoring/play/sessions/8c010985fe04154b212ead28/session.bin`. SHA-256 registrado pelo runner: `5727A4E632DCDFA49C045B32E4039499FC5AC148184074EF8C09CFEDDC3D8898`.

Passaram os checks de caminho fornecido, abertura da sessão no processo novo, retomada, igualdade de candidato/geometria (536 superfícies, 828 conexões), posição elevada salva (`XZ 760/780`, dentro da tolerância), corpo original 20×32 e suporte elevado próximo. Falharam:

- `resumed_authored_view_picks_raised_support`: false.
- `resumed_player_accepts_canonical_short_walk`: false; retorno `{"error_code":"ambiguous_surface","geometry_revision":1,"ok":false}`.

Tempos parciais, em ms: `app_open_ms=50,883.205`, `resume_start_ms=28,615.491`, `movement_request_ms=4.314`. A medição de movimento refere-se somente à requisição rejeitada; não houve amostra de frames de caminhada. Os tempos de abertura/início incluem preparação da aplicação e não são desempenho médio nem FPS.

Evidência da falha:
- `resume/runs.json` — falha, exit 1, timeout false, mesmos `head_before/head_after`.
- `resume/geometry.output.log` e `resume/geometry.engine.log` — checks, retorno e marcador final.

## Evidência anterior reutilizada

O runtime não mudou em relação ao freeze `44a0b36439de030ab48a64aff2a26adc856fbadd`; as mudanças deste delta são testes/documentação. Por isso, conforme o plano de impacto, foram reutilizadas sem repetição:

- RoundedNative PASS 20/20 em `snapshot_encoding/native_pooled/`: gameplay real da colina, GUI/AX, apply/undo, pick/caminhada, corpo 20×32 e captura. Medidas reportadas na execução: preparação compile 3,253 ms, publicação do mapa 27,949 ms, abertura App 50,196 ms, início 30,614 ms, pedido de movimento 44.128 ms, caminhada in-game 3,112 ms; 120 amostras de frame (p50 17.421 ms, p95 27.479 ms, máximo 136.137 ms). Escopo: uma peça publicada, uma rota do App e uma caminhada; não representa FPS geral. Capturas e SHAs estão junto à evidência Native anterior.
- Seleção de quatro testes oficiais PASS em `snapshot_encoding/official/`: F3 snapshot (50), F3 continuation (2,743 checks/30 cenários), F3 lifecycle (90) e F6 snapshot (40), seleção de 4/299.

Esses resultados anteriores não demonstram a retomada em processo novo; essa prova permanece falha até a correção de Sol e nova execução autorizada.

## Histórico de diagnóstico estrutural

- Em `2180fef...`, SnapshotDensity encontrou rejeição de base64 inválido que gerava `ERROR`; Sol adicionou validação canônica antes do decode.
- Em `399058...`, truncamento de stream DEFLATE válido em base64 ainda gerava erro nativo; Sol adicionou digest obrigatório do conteúdo comprimido no transporte v2, mantendo v1 legado.
- Em `9a32ca...`, o envelope passou o teste unitário, mas o snapshot real excedia 4 MiB (4,680,008 bytes). Sol adicionou pool de layouts de chaves sem eliminar conteúdo, identidade ou ordem.
- Em `44a0b3...`, SnapshotDensity 28/28 e RoundedNative 20/20 passaram, incluindo a sessão real com 3,594,152 bytes no teto original. O wire v1/v2 passou compatibilidade neste lote com 33 checks.

As falhas históricas de transporte foram corrigidas no runtime antes do freeze atual; nenhuma representa o resultado da etapa atual. O bloqueio atual é a resolução ambígua da superfície no pick/movimento após a retomada.

## Limites e próximo passo

Este relatório não fecha F9 global nem declara o candidato tecnicamente validado. A retomada da sessão densa continua pendente; a prova interrompida não confirma caminhada, captura ou resuspensão. Também permanecem limites do escopo anterior, incluindo carregamento/preparação de 50–30 segundos, que precisa continuar identificado separadamente dos frames reais. A execução Native e os quatro testes oficiais foram reutilizados porque o runtime permaneceu idêntico; não foi repetida a suíte completa.

Próximo passo: Sol corrigir a causa de `ambiguous_surface` dentro do runtime/contrato e autorizar uma nova execução de RoundedResume. Não reduzir forma, corpo, geometria, limites, timeouts ou verificações.

## Identidade dos inputs congelados

Para os arquivos de teste e runtime abaixo, os SHA-256 registrados pelo runner na etapa Density coincidem com os arquivos copiados para a fixture; o manifesto inclui todos os inputs do runner e marca ambos os HEADs como `fac5db2f228d1f5bf11cf31a17e0b89709e730d8`.

| Arquivo | SHA-256 |
|---|---|
| `tests/map_editor_snapshot_density_test.gd` | `71852A1C0AB6BF9CF0CD93DE1B745742B4B5664C575378B686C965EDEC4E2B48` |
| `tests/map_editor_rounded_hill_resume_test.gd` | `B0F545ED1FCF18D008E81736BC1196B6FE857FBD9868C8DCB2FA5ECE4DD25D0F` |
| `scripts/core/expedition/snapshot/snapshot_graph_encoding.gd` | `2FA782D31AFD5A314A8CD677025A42E385B0E531C457318E5F826C8289F6F4FC` |
| `scripts/core/expedition/snapshot/snapshot_registry.gd` | `88C08D27608088172DF0FE4FA889322FC777EB7E257B29CF5A4DB4B13D7CA32E` |
| `scripts/core/expedition/persistence/expedition_checkpoint_codec.gd` | `D87F84413100B5AFEA0F958F32F799140C696075B03F55F05AE0B8C7A4FAD14B` |
