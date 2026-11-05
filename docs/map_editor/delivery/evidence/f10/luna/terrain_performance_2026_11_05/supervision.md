# F10 Q5 — supervisão parcial de terreno, atores e preparação

Data: 2026-11-05  
Worktree: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`  
Branch: `codex/map-editor-f10`  
Base/HEAD observado: `f06a383782078eb2030cb1fc2ecccea2bb11662e`  
Estado: checkout com alterações não commitadas; runtime congelado durante a seleção final.  
Fixture: `.godot/verification/e07_f1/fixture_project`  
Engine: Godot 4.7.2 standard, `Godot_v4.7.2-stable_win64.exe`, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.

Este recibo é supervisão de execução: conclusão, códigos de saída, timeouts,
logs e hashes. Não é auditoria semântica independente, nem valida por si só
correção de gameplay ou desempenho.

## Histórico de seleção automatizada

As primeiras tentativas de `stage_minimap_test` e `bounded_preparation_test`
terminaram com erro de inferência de tipo GDScript nos próprios testes
(`mesh` e `listing`, respectivamente). A etapa `stage_minimap_test` passou na
tentativa seguinte; após a anotação dos tipos nos dois testes, `bounded_preparation_test`
passou na rodada final. As correções foram declarações de tipo; nenhuma mudança
de expectativa foi feita. As falhas e reexecuções permanecem nos recibos locais
`verify_01` e `verify_02`, mas não são contadas como checks aprovados.

Fatias únicas aprovadas, sem somar tentativas repetidas:

| Etapa final | IDs concluídos | Checks aprovados |
| --- | ---: | ---: |
| `verify_01` — animação e retomada F4 | 2 | 130 |
| `verify_02` — minimapa, dados e apresentação de atores | 3 | 71 |
| `verify_03` — preparação, fluxo, população, recuperação, snapshot, atores e regressões | 9 | 489 |
| **Total distinto** | **14** | **690** |

Na rodada final `verify_03`, os nove processos selecionados concluíram com
`exit_code=0`, `failed=false` e `timed_out=false` (timeout configurado: 300 s):

| ID | Resultado do log de saída |
| --- | --- |
| `e06_gameplay_ai_test` | 76 checks, 0 falhas |
| `e07_f4_compatibility_test` | 16 checks, 0 falhas |
| `e07_f6_threat_test` | 43 checks, 0 falhas |
| `bounded_preparation_test` | 13 checks, 0 falhas |
| `e07_f7_flow_test` | 23 assertions, PASS |
| `e07_f5_population_test` | 40 checks, 0 falhas |
| `e07_f5_recovery_test` | 33 checks, 0 falhas |
| `e07_f3_snapshot_test` | 52 checks, 0 falhas |
| `e07_f1_actor_integration_test` | 193 checks, 0 falhas |

Os dois logs iniciais aproveitados sem repetição na contagem foram
`combat_animation_test` (39 checks) e `e07_f4_resume_staging_test` (91 checks).
Em `verify_02`, `stage_minimap_test` passou com 21 checks, `stage_minimap_data_test`
com 38 e `actor_presentation_test` com 12. Reexecuções posteriores desses IDs
não aumentam o total de 690.

## Integridade e recibos

O `plan.json` da seleção final registra os nove IDs, fonte `f06a383…`, 305 etapas
no runner, `-SkipEditorImport`, timeout de 300 s e o caminho da fixture. O
`source_hashes.json` da fixture contém 2.247 arquivos; a comparação somente de
leitura com as fontes do checkout encontrou 0 divergências e 0 ausências.
Conforme coordenação, as fontes do runtime permaneceram idênticas desde
`import_02`; esta supervisão não iniciou engine nem teste.

| Recibo | SHA256 |
| --- | --- |
| `verify_03/plan.json` | `6FC1CB0E2FD9E2F3EB4E105E408FB094652E533D0421A9D0EE9304B7F1A0806D` |
| `verify_03/checks.jsonl` | `3AFE41D5444107A1A5701F738D0D3B812DFA133ED7A82E6B41904AE2502B313B` |
| Runner `tools/verify.ps1` | `04B2E74F1C349DF86D9D5061A69C074A6C115DB20FAB094FB2D38C119DB47555` |
| Executável Godot | `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424` |

Os hashes de cada saída individual estão em `checks.jsonl`; os logs `.engine.log`
e `.output.log` correspondentes ficam em
`.godot/verification/terrain_performance_2026_11_05/verify_03/`. A busca pelos
marcadores `ERROR`, `SCRIPT ERROR`, `Parse Error`, `Failed` e `Cannot` nos logs
da rodada final não encontrou ocorrências. Os erros de tipagem das tentativas
anteriores estão preservados e identificados acima.

## Fatias nativas e de preparação compatíveis

As etapas abaixo terminaram antes da inclusão tardia das duas guardas de tamanho
de Candidate. O delta posterior toca somente `_create_approved` e
`_prepare_approved` e tem seu próprio teste dirigido; as evidências abaixo
continuam limitadas aos respectivos inputs congelados. São fatias independentes,
sem repetir a contagem das regressões acima.

| Etapa | Resultado | Recibo `runs.json` SHA256 |
| --- | --- | --- |
| `GameInterface` em janela nativa, incluindo minimapa e zoom | 31/31, `ok=true`, exit 0, sem timeout/abort | `603B708B4269D5ABA9CF7710CBBA14C717AB369EEED9143722519D99AA828568` |
| `PreparationProofs` | 23/23, `ok=true`, exit 0, sem timeout/abort | `864BB709D3C3347CA03CB91090711FB05E300FA2F3F82A5CBC18DDEA2763E697` |
| `PhaseRelease` | 11/11, `ok=true`, exit 0, sem timeout/abort | `154E93811F1B3AEA6BEDC5A20759CCC4BD635EE906CCBA9D4828394C4D5DBCAC` |

Os três recibos registram a mesma base antes/depois (`f06a383…`), Godot
4.7.2 standard e fixture. `GameInterface` cobriu projeção/rumo do marcador,
zoom, bloqueio de clique e retomada; `PreparationProofs` cobriu certificados,
limites, cancelamento, invalidação, fallback e preservação do estado; `PhaseRelease`
registrou `prepare_ms=60,969`. Nenhum dos três logs de engine/output contém
`ERROR`, `SCRIPT ERROR`, `Parse Error`, `Failed`, `Cannot` ou `WARNING`.

Os logs detalhados e imagens ficam em `interface_01/`, `preparation_proofs_01/`
e `phase_release_01/` sob `.godot/verification/terrain_performance_2026_11_05/`.
As comparações de crowd `crowd_before_01`/`crowd_after_01` ainda não são
conclusivas: o lado anterior usou o PCK c9a3673f e o lado posterior usou a
fixture. A comparação fica fora deste recibo até haver repetição do mesmo lado
com o PCK final.

## Delta final de handoff e sombra

O executor registrou o candidato final no commit
`2ff1c00f923e3811b0aa7ebcbeddafe7731d640f`. O contrato acrescentou dois
checks de limite de 5 MiB no handoff de Candidate e um fast path de sombra
restrito a projeção canônica, pegada retangular em um só quad horizontal,
ambos triângulos caminháveis, mesma altura/revisão/superfície/raios e cache
limitado a 128 malhas por raios. Negativos de borda, emenda, rampa, declive,
projeção incompatível, revisão/altura/raios diferentes e saturação usam o caminho
anterior. Esta supervisão verifica os recibos e não reavalia a semântica do código.

| Seleção/etapa | Resultado de execução | SHA256 do recibo |
| --- | --- | --- |
| `verify_04`: `candidate_handoff_limits_test` | 4 checks, exit 0, sem timeout | incluído em `verify_04/checks.jsonl` |
| `verify_04`: primeira `ground_shadow_cache_test` | 18 verificações reportadas, exit 1 por erro no valor de projeção esperado; não contar como PASS | `plan.json` `C8B90694B070F80845F17DE03F0A67ED68F6A4B82D7D1A31A08E40671AA70BC0`; `checks.jsonl` `40181D55CA849A17E46941EB539937EA95B3526BEDBFFD1069A72B3A7DFC11A1` |
| `verify_05`: `ground_shadow_cache_test` + `e07_f3_snapshot_test` | 18/18 e 52/52, ambos exit 0, sem timeout | `plan.json` `A24C401060F825209A9AFEDEC69CEED62C4529AB772AE7A77052146860C81D60`; `checks.jsonl` `495F830588876A3834B2E23F04EF25994546DD896CC5A899A40E7394F6DC4CE3` |
| `Shadows` | 28/28, `ok=true`, exit 0, sem timeout/abort | `runs.json` `92A5F64F6F64C5A1BA6C9B6803BD8D6E8A1F0DB601AF3D3640370C728AE1EB23` |
| `HeightGridWorld` | 15/15, `ok=true`, exit 0, sem timeout/abort | `runs.json` `C75C318143852092261596C20832202A80013599523CB41A9B1CB3D9B5E56626` |
| Comparação externa de imagens da sombra | 6/6; 0 bytes diferentes e 0 delta de canal em piso, movimento, borda, emenda, rampa e coordenadas grandes | `shadow_pixels_02/result.json` `2C098D474185F2B0AA79EF5ABEB3676DBD5A958D9594A5BE6603A10182E563DD` |

A falha original em `verify_04` foi `flat footprint uses exact canonical linear
projection`: a expectativa do teste usava eixos `(1, 0.5)`, mas a projeção
canônica existente usa `(0.85, 0.425)`. O executor corrigiu somente os valores
esperados do teste e a tolerância de comparação f32, sem alterar runtime. A
reexecução `verify_05` passou; o erro original continua preservado e
`verify_04` não é apresentado como lote integralmente aprovado. O snapshot F3
52/52 dessa repetição já estava contado nos 690 checks anteriores e não é somado
novamente.

As imagens de referência e do cache têm 3.648 bytes cada, alpha máximo 80 e
3.567–5.924 pixels visíveis conforme o caso. Os logs das etapas finais não têm
erros, timeout ou processo abortado. Os planos `verify_04`/`verify_05` registram
307 etapas, Godot 4.7.2 standard com SHA256
`AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`, e runner
SHA256 `44628731733E9F84CA41A870378B86A3BD3C9EBA14D09DCF219152BFC05B1136`.

O perfil de 96 atores móveis no mundo, 288 draw calls e janelas de cerca de
3 segundos passou em `world_crowd_after_01`: mediana de frame médio 8,478 ms e
p95 11,793 ms, comparada à mediana 22,628 ms/p95 26,417 ms de
`world_crowd_before_01`. Essa comparação era provisória porque o lado anterior
usava PCK c9a3673f e o posterior a fixture. A repetição pareada no PCK final
está registrada abaixo.

## PCK final, atores e preparação

O checkout terminou em HEAD
`2ff1c00f923e3811b0aa7ebcbeddafe7731d640f`. O build Windows foi exportado,
inspecionado, inicializado, abriu o menu e carregou a Floresta do Santuário;
os cinco processos no `validation/runs.json` tiveram exit 0 e `timed_out=false`.
O recibo de mapa com o PCK exportado passou 15/15. O modo foi
`standard_engine_with_exported_pack`, separado do boot do executável normal.
Foram observados 46.078 triângulos caminháveis e 5.122 íngremes, 62/62 monstros,
entrada 49,213 s, suspensão 9,033 s e retomada 23,481 s. Sol conferiu a captura
de terreno e minimapa; essa conferência visual não é uma auditoria Luna.

| Artefato/recibo | SHA256 / resultado |
| --- | --- |
| `build_manifest.json` | `FCE69CD64FA9C4BE0B7087567A51907F9F81ADD383417D89434BF9A6BF4BEA96` |
| `validation/runs.json` | `B45495141AD9F19D34A656CA54375F3EE4FA206E79B855DA4853493C1F8AF35A` |
| Fixture `source_hashes.json` (2,251 paths) | `BF3179E85F457899DBBFC85C2394299A3B31BABF79D32DF42122310BF52FC3D9` |
| EXE, 109.127.680 bytes | `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668` |
| PCK, 94.914.128 bytes | `136D35E0D059572B633E2D743FBA839E97273B1AAA11D7F41C28AD9B0B9DEE3A` |
| Godot 4.7.2 standard | `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424` |

O hash do PCK calculado do arquivo exportado confere com `build_manifest.json`.
O `source_hashes.json` final contém 2.251 caminhos; comparei cada arquivo de
fonte e fixture com o registro: 0 divergências, 0 arquivos ausentes e 0 pares
fonte/fixture diferentes. O build declara a mesma contagem de 2.251 entradas.
O manifesto `import_04` predecessor tinha 2.250 entradas e ficou anterior à
correção do teste `ground_shadow_cache_test` e à geração de seu `.uid`; esse
hash obsoleto foi sincronizado antes dos recibos finais e não é tratado como
prova da fixture final.

### Comparações com o PCK anterior

As mesmas sondas externas foram executadas no PCK final do commit `2ff1c00f`.
Ambos os lados mantêm 96 atores e 288 draw calls, com janelas próximas de 3 s.

| Sonda | PCK anterior `c9a3673f` | PCK final `2ff1c00f` |
| --- | ---: | ---: |
| Atores móveis no mundo: mediana do frame médio / p95 | 22,628 / 26,417 ms | 9,572 / 14,013 ms |
| 96 atores parados: mediana do frame médio / p95 | 5,661 / 9,110 ms | 3,594 / 5,876 ms |
| Perfil da floresta: entrada | 72,952 s | 52,382 s |
| Perfil da floresta `natural_all_on`: frame médio / p95 | 15,571 / 19,831 ms | 14,654 / 21,769 ms |

O perfil de atores parados no PCK final incluiu um pico isolado de 156,011 ms
em uma amostra; está preservado, sem exclusão ou reclassificação. O perfil da
floresta não mostra melhoria uniforme: a entrada foi menor e o frame médio
`natural_all_on` caiu, mas o p95 subiu. As medições não comprovam um ganho
universal de fluidez em toda a floresta.

### Preparação no PCK final

`preparation_pack_final_01` foi executado pelo engine com PCK exportado, em modo
nativo com renderizador normal, não pelo controle headless antigo. Com duas
lanes, o processo frio totalizou 17,077 s e o processo quente 11,167 s; ambos
retiveram o mesmo digest de manifesto (`12271a4e…`) e regras (`369eaa4b…`). A
preparação fria teve 14 hits de prova e zero buscas; após o lote quente, 24 hits
cumulativos e zero buscas. Os controles anteriores serial (39,381 s) e paralelo
(24,429 s) usaram headless e PCK c9a3673f, portanto são evidência histórica, não
um par de comparação direta com o perfil nativo final.

Recibos dos quatro perfis finais: `world_crowd_pack_final_01/result.json`
SHA256 `A24BE9BBD3AB36C06B09DEAD2279CF4DE08553D408A54E1C4D9837A0DA68015D`,
`crowd_pack_final_01/result.json` `C64B314479A6FBBE4371B1F55E62D2B2E423933BBF0960143BB682EF3D5C5BEE`,
`forest_profile_pack_final_01/result.json` `6F7B022DD038768D51C0F2EAB9AFC51E0AF535ED7AACC867B6F795FAC88A1AA6`,
e `preparation_pack_final_01/result.json`
`BA0216443FC79A4BAF106338986A67A456BBE72BECE0F7E0AB21D148AEF3FF90`.
Todos indicam `ok=true`, exit 0; logs de engine/output sem marcadores de erro.

## Escopo ainda pendente

A supervisão de execução e recibos deste pacote está concluída. Checks, perfis e
exportação confirmam apenas os comportamentos e cenários descritos; não são uma
avaliação de produto ou prova de fluidez universal. Q5 segue aberto até revisão
e aceite humano do candidato. Não há merge ou push implícitos.
