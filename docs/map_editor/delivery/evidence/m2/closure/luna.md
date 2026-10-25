# Supervisão automatizada Luna — fechamento F2

Papel: supervisão de execução automatizada delimitada conforme `docs/WORKFLOW.md` e contrato `docs/map_editor/contracts/m2_closure.md`. Confirma conclusão, expectativas registradas, erros, timeouts e hashes; não é revisão semântica independente.

Candidato congelado: `163c509de8a47f60523196aeaea76e9b08b3e471`, branch `codex/map-editor-m2`. HEAD antes e depois da execução permaneceu nesse SHA.

Comando executado no checkout dedicado, com acesso elevado ao armazenamento de certificados do Windows:

`tools/map_editor_terrain/run.ps1 -GodotPath C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe -EvidenceDirectory docs/map_editor/delivery/evidence/m2/closure/luna_run -ReuseFixture .godot/m2_luna_01/fixture -Native`

Engine Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`. Início `2026-10-25T00:10:29.6999663Z`; fim `2026-10-25T00:12:37.0049867Z`. Resultado global `M2_ALL_PASS`.

- Importação: concluída, exit 0, sem timeout.
- Terreno: 102/102 checks aprovados.
- CLI A/B padrão: ambos aprovados; hashes de saída do processo iguais (`13E61215E2E459D73E0D52DEE8BC33A5B32520A7E44E2A7912809C743B08174E`); hash do pacote compilado igual (`d8a9591ab0b0c05ebddd189eb196af3c0150b2cf8b37df1dc4e9d0f3b12b4f34`), coincidente com o hash do teste de origem `terrain`.
- Escala: 46/46 checks aprovados; inclui a verificação de equivalência fonte visual/pacote. Mediu grades 33×33, 65×65 e 129×129, cada uma como uma peça contínua; a maior gerou 16.641 amostras, 32.768 triângulos visuais e 3 suportes.
- CLI A/B grande: ambos aprovados; hashes de saída iguais (`8853AA7889E51111D5D0C198D573A3EC8F5D5D197D858B1047E9769877949672`); hash do pacote grande igual (`25f1722af88b1c0a1420a5589a1aea505f9b5bd6ede47bb0ceac2b5affccca78`), coincidente com o hash do teste de origem `terrain_scale`. Na UI, `native_headless_equivalent=true` compara o worker da UI com `Compiler.compile` usando a mesma fonte nativa pequena; `native_large_bake=true` confirma bake grande bem-sucedido e três suportes. A evidência não compara diretamente o hash do bake grande da UI com os processos CLI.
- Regressão documental: 70/70 checks aprovados.
- UI nativa: 45/45 checks aprovados, incluindo as capturas de terreno regular, área grande, detalhe e declive.

Todas as nove etapas terminaram com exit code 0, sem timeout; todos os marcadores e checks retornaram sucesso. Logs não contêm `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Os hashes do engine e dos 46 inputs conferem com o manifesto; os hashes correspondentes da fixture também conferem com os inputs registrados.

Avisos observados: a importação relata o projeto aninhado conhecido em `tools/map_editor_probe/hosting` e informa que a pasta será ignorada. A regressão documental emite `WARNING: Exponent too high` ao exercitar limites decimais. Ambos são avisos; não houve erro fatal ou marcador de erro proibido.

Hashes dos artefatos desta rodada:

- `manifest.json`: `300B4BAA2251AA120CE39B658EB2561396C821D63B16CA004AC8F638330A5996`
- `runs.json`: `4FF445AF2B6D42659FDDD488ABDBE56438E3D4361A18559D45BBFC7DA9C1F5B9`
- Capturas: `terrain.png` `B8FB04D2776BA0854471C5A67BF174698B29819E6CC09F81073EEFF965AB2449`; `large_terrain.png` `CD7D1FC82CEBD9DC2320E568D81FA6C3CC235684B8EDD4E5F3B68C359D1C3F90`; `terrain_detail.png` `57DFAC1A8AA904F3EA061619B649A8A29DF1FA73D971401D0CDCD2F924BB0E6F`; `steep_terrain.png` `B47A94A3000A1219BE0845B3E27B3F1BDB40D99E082C60860DE8C9D0CAE394F5`.
- Métricas: `terrain_measurements.json` `B7896FA9FEBD345D17718E62CDD3D884CA93D3EA27BCD8BF5E5BAC73CFB7F86A`; `terrain_scale_measurements.json` `50B0DDC4B1A01EA2A88A1713B8B174CE8CC379456C5B4E334E4905EB1426CEFF`.

Limite: esta supervisão verifica a seleção contratada e suas expectativas; não prova cobertura total do contrato, avaliação visual qualitativa, FPS, balanceamento ou aceite humano. Nenhuma fixture foi copiada para a evidência versionável.
