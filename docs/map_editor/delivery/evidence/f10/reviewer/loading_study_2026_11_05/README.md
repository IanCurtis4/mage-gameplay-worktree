# Sonda de caminhos — 5/11/2026

Estudo: [opções de carregamento](../../../../../studies/f10_loading_options.md).
Base `8c38ea8fd5a15189aece64a9e814d176a3848d58`, engine standard 4.7.2 com
SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
`study_binding.json` confronta os 2.218 inputs com fonte e fixture; nenhum mudou.

O script foi arquivado como `.gd.txt`, com os mesmos bytes do processo medido.
`proof.bin` é dado passivo de diagnóstico, não pacote aceito pelo jogo. O
verificador não oferece decoder/validação completos de um loader de produção.
O normal_load do coletor e os tempos de componentes do verificador não são
operações equivalentes: ver o estudo antes de comparar números.

Coleta e verificação usaram processos separados, headless, a mesma fixture e
APPDATA/LOCALAPPDATA descartáveis. Não se esvaziou cache de arquivos do SO.
Os wrappers originais limitaram coleta a 360 s e verificação a 180 s, aguardaram
saída, capturaram stdout/stderr, pesquisaram erros e amostraram WorkingSet64 a
cada 500 ms. `*_process.json` registra resultado/tempo/pico/script/engine/HEAD;
os demais JSONs e logs preservam dados completos. Zstd foi usado só para medir
tamanho em memória, sem caminho de leitura comprimido.

## Reprodução delimitada

Usar a fixture já importada, sem outro processo Godot e sem alterações de
fontes durante o ensaio. Preparar os diretórios abaixo sem sobrescrever um
ensaio que queira preservar. Não usar o perfil pessoal nem o checkout habitual.

```powershell
$sourceRoot = 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\map-editor-m5'
$fixture = Join-Path $sourceRoot '.godot/verification/e07_f1/fixture_project'
$archive = Join-Path $sourceRoot 'docs/map_editor/delivery/evidence/f10/reviewer/loading_study_2026_11_05'
$privateScriptFolder = Join-Path $fixture '.godot/loading_study_2026_11_05'
$output = Join-Path $sourceRoot '.godot/loading_study_reproduction'
$engine = 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe'
New-Item -ItemType Directory -Path $privateScriptFolder
New-Item -ItemType Directory -Path $output
Copy-Item -LiteralPath (Join-Path $archive 'probe.gd.txt') -Destination (Join-Path $privateScriptFolder 'probe.gd')
$env:APPDATA = Join-Path $fixture '.godot/loading_study_profile'
$env:LOCALAPPDATA = $env:APPDATA
& $engine --headless --path $fixture --script 'res://.godot/loading_study_2026_11_05/probe.gd' -- collect $output
if ($LASTEXITCODE -ne 0) { throw 'Coleta falhou' }
& $engine --headless --path $fixture --script 'res://.godot/loading_study_2026_11_05/probe.gd' -- verify $output
if ($LASTEXITCODE -ne 0) { throw 'Verificação falhou' }
```

A coleta volta a executar o loader normal; leva cerca de dois minutos nesta
máquina. A verificação exige o arquivo daquela coleta e o mesmo pacote. Um
resultado positivo aqui não aprova uma integração, save ou fase completa.
