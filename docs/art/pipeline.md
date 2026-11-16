# Pipeline de arte neutro

Escrito em 16/11/2026 (E09, tarefa T2, contrato C5 em
[e09_contract.md](../epics/e09_contract.md)). As ferramentas estão em
[`tools/art_pipeline/`](../../tools/art_pipeline/). A fila do que ainda falta gerar está em
[generation_queue.md](generation_queue.md).

O pipeline **não depende do gerador**. Codex, ComfyUI local, Hugging Face, fal, uma página web
(Gemini/Nano Banana) ou um desenho à mão entram pelo mesmo caminho: **folha-fonte → validação →
(remoção de fundo → normalização de escala) → registro de proveniência → seleção → arquivo**. O
empacotador do jogo só lê a seleção; nada aqui altera o runtime.

## 1. Fluxo em uma tela

```
gerador ──► arquivo PNG ──► record_generation.py ──► provenance.json (v2)
                │
                ├─ fundo chapado? ──► remove_background.py ──► PNG RGBA
                │
                ├─ validate_sheet.py / validate_batch.py ──► relatório JSON (só leitura)
                │       └─ vistas com altura diferente? ──► normalize_scale.py
                │
                ├─ escolher a versão ──► selection.py derive ──► selection.json
                │
                └─ lote pronto ──► archive.py copy ──► arquivo fora do Git + índice versionado
```

Regras que valem para tudo:
- **Fonte nunca é sobrescrita.** Cada ferramenta recusa escrever sobre a entrada e sobre uma saída
  existente com bytes diferentes (`--force` só onde está dito).
- **Cada passo é registrado.** O que uma ferramenta de imagem faz sai em JSON no formato de um
  passo `post` da proveniência (`tool`, `version`, `params`, `input_sha256`, `output_sha256`).
- **Os registros v1 do Codex (1114–1123) nunca são reescritos.** Eles são lidos e convertidos na
  memória; registros novos vão para um arquivo v2.

## 2. Como rodar

Python 3.14 com Pillow e numpy, as mesmas dependências dos `tools/prepare_e08_*.py`. Nenhum
pacote novo. Os comandos abaixo partem da raiz do repositório; todas as ferramentas rodam como
script ou como módulo:

```bash
python -I tools/art_pipeline/validate_sheet.py --help
python -I tools/art_pipeline/record_generation.py --help
```

`-I` (modo isolado) é o recomendado; o pipeline acrescenta sozinho a pasta de pacotes do usuário
(onde o Pillow está nesta máquina) quando precisa dele. As ferramentas de proveniência, seleção e
arquivo usam só a biblioteca padrão e rodam sem Pillow.

Os testes (89, sem rede e sem tocar em arquivos do usuário):

```bash
python -I -m unittest discover -s tools/art_pipeline/tests
```

Códigos de saída: `0` passou ou avisou; `1` falhou (validador, arquivo); `2` uso incorreto ou
arquivo ilegível. A saída JSON vai para a saída padrão em UTF-8; use `--out` para gravar em arquivo.

| Ferramenta | Para quê |
|---|---|
| `validate_sheet.py` | validar uma folha ou um conjunto de vistas |
| `validate_batch.py` | validar um lote em staging (`e08_codex_*`), escolhendo a versão marcada de cada vista |
| `remove_background.py` | tirar fundo chapado, com parâmetros registrados |
| `normalize_scale.py` | igualar a altura do corpo parado entre as vistas, sem suavização |
| `provenance.py` | ler (`show`), conferir (`check`) e converter (`upgrade`) proveniência v1/v2 |
| `record_generation.py` | acrescentar um registro v2 depois de gerar |
| `selection.py` | criar (`derive`), ver (`show`) e conferir (`check`) `selection.json` |
| `archive.py` | copiar um lote para o arquivo durável, conferir hashes e escrever o índice |

## 3. A folha-fonte `ragrpg_source_sheet_v1`

| `kind` | Conteúdo |
|---|---|
| `character_view`, `creature_view` | grade **4×4**, uma direção por folha (`south`, `east`, `west`, `north`). Linha 1 parado (4), linha 2 andando (4), linha 3 ação (4), linha 4 dano (2) e morte (2) |
| `equipment_row` | N objetos numa fileira, separados |
| `vfx_source` | grade 4×4 de quadros |
| `icon_source` | quadrado com lado ≥ 128 |

O fundo é **alfa real** ou **cor chapada declarada** (`#FF00FF`, `#00FF00`). O tamanho da folha é
livre: o empacotador recorta em células iguais (a mesma conta do
`tools/prepare_e08_directional_art.py`: `round(col × largura / 4)`). Alfa acima de **16** conta
como conteúdo; abaixo disso é o "véu" que alguns geradores deixam no fundo.

### Validar (`validate_sheet.py`, `validate_batch.py`)

Uma folha:

```bash
python -I tools/art_pipeline/validate_sheet.py east.png --kind character_view --direction east
python -I tools/art_pipeline/validate_sheet.py weapons.png --kind equipment_row --count 8
python -I tools/art_pipeline/validate_sheet.py gemini_east.png --kind character_view --background '#FF00FF'
```

Com fundo chapado declarado, o fundo é removido **na memória** (nada é gravado) e os parâmetros
aparecem no relatório em `sheet.background_removal`.

Um conjunto de vistas, com a comparação de escala:

```bash
python -I tools/art_pipeline/validate_sheet.py --kind character_view --reference south \
    --set south=south.png east=east_v2.png west=west.png north=north_v3.png
```

Um lote inteiro em staging (escolhe sozinho a versão `selected: true` de cada vista; um lote
posterior substitui o anterior vista a vista, como a 1122 sobre a 1121; aplica os
`crop_overrides` do registro v1):

```bash
python -I tools/art_pipeline/validate_batch.py \
    --art-root "C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/assets/art" \
    --batch e08_codex_1120 --batch e08_codex_1121 --batch e08_codex_1122 --batch e08_codex_1123 \
    --equipment-count weapons_h1=8 --equipment-count weapons_h2=8 --out relatorio.json
```

Se o registro **nunca** guardou `selected` (a rodada 1116), vale a maior versão `_vN`, marcada no
relatório como `inferred_latest_version`.

Cada achado é `{code, severity, message, details}`. `error` reprova a folha; `warning` aparece
mas não reprova (`--strict` reprova também os avisos).

| Código | Severidade | O que significa e o que fazer |
|---|---|---|
| `not_png`, `file_missing` | erro | arquivo ilegível ou ausente |
| `not_rgba` | erro | folha sem alfa onde se declarou alfa: exportar RGBA ou declarar o fundo chapado |
| `background_not_transparent` | erro | menos de 25% dos pixels transparentes (alfa ≤ 16): o fundo não é alfa |
| `flat_background_mismatch` | erro | cantos fora da tolerância da cor declarada: conferir a cor |
| `flat_declared_but_alpha_present` | aviso | a folha já tem alfa real; a remoção foi pulada |
| `empty_cell` | erro (aviso em `vfx_source`) | célula vazia; `details.cells` traz os índices 0–15 |
| `touches_cell_edge` | erro | conteúdo a menos de 1 px da borda da célula (`details.cells`: linha, coluna, lados) |
| `no_gutter_band` | erro | nenhuma faixa transparente separa as células nesse limite; `details.boundaries[].suggested_crop_override` é o corte `{row, boundary_after_column, x_px}` que o empacotador já aceita |
| `narrow_gutter` | aviso | faixa transparente menor que 8 px |
| `idle_height_spread` | aviso | as quatro poses paradas diferem mais de 15% em altura |
| `alpha_veil` | aviso | mais de 500 pixels de alfa 1–16 longe das figuras (o véu); limpar com `remove_background.py --veil-alpha 16` |
| `scale_mismatch` | aviso (erro com `--strict-scale`) | altura do corpo parado da vista fora de ±10% da vista de referência; traz `ratio`, `deviation_pct` e `suggested_scale` |
| `object_count_mismatch` | erro | equipamento: contagem diferente da pedida. Objetos que se encostam ou se sobrepõem em x contam como um só (faixa vazia menor que 2 px) |
| `touches_sheet_edge` | erro | objeto de equipamento ou ícone encostado na borda |
| `expected_count_unknown` | aviso | equipamento sem `--count` |
| `specks` | aviso | manchas menores que 64 px foram ignoradas como sujeira |
| `icon_not_square`, `icon_too_small`, `icon_empty` | erro | regras do `icon_source` |
| `reference_missing`, `reference_unmeasurable` | erro | o conjunto não tem a vista de referência ou ela não pôde ser medida |

**Altura do corpo parado.** É a mediana das alturas (caixa do alfa > 16) das quatro células da
linha 1, a mesma estatística do empacotador. Conferida contra o `idle_height_px` que o Codex
gravou nos registros de 1121 e 1123: a diferença é de no máximo 3 px (cerca de 1%).

**Tolerância de escala.** ±10% da vista de referência (`south`), ajustável com
`--scale-tolerance`. As classes aceitas do E08 ficaram entre 0,97 e 1,05; as diferenças de
até 30% (Sicário leste 0,71) estão acima do limite e são apontadas. É aviso, e não erro, porque o
normalizador (ou o `target_height` do empacotador) corrige.

### Tirar fundo chapado (`remove_background.py`)

```bash
python -I tools/art_pipeline/remove_background.py gemini_east.png east_rgba.png --key '#FF00FF' \
    --emit-post east_rgba.post.json
```

O que faz, por padrão (`--tolerance 48`, `--mode global`, `--edge-steps 1`):
1. todo pixel a menos de 48 de distância euclidiana (RGB) da cor-chave vira fundo; `--mode
   connected` remove só o que encosta na borda da imagem, para figuras que têm, de propósito, uma
   cor parecida com a chave;
2. **franja**: em cada anel junto ao fundo, o pixel mais próximo da chave que do corpo (menos de
   50% de figura) vira fundo, e os demais são repintados com a cor do vizinho mais "de figura", o
   que apaga a aura magenta/verde sem suavizar a pixel art. O alfa de saída é binário;
3. `--veil-alpha 16` (opcional) zera o alfa fraco.

O fundo vira RGBA `(0,0,0,0)`. A saída recusa sobrescrever a entrada. Se os cantos da imagem não
combinam com a chave, a ferramenta ainda grava, mas sai com código `2` e `corners_match_key: false`.

Cores já escolhidas: Tempestário magenta `#FF00FF` (traje verde); Magister verde `#00FF00` (traje
com violeta). Escolha uma cor que **não apareça** no traje.

### Igualar a escala entre vistas (`normalize_scale.py`)

```bash
# um conjunto: grava só as vistas que diferem mais de 2% (mesmo nome de arquivo)
python -I tools/art_pipeline/normalize_scale.py --set south=south.png east=east.png west=west.png \
    north=north.png --out-dir normalizadas/
# uma vista contra a vista de referência
python -I tools/art_pipeline/normalize_scale.py --reference south.png east.png east_norm.png
```

Escala a folha inteira para que a altura do corpo parado fique igual à da referência. O filtro é
**`nearest`** (sem suavização, sem cor nova); `--filter lanczos` existe e fica registrado como
`smoothing: true`, só para arte que não é pixel art. A folha muda de tamanho, mas a grade em
partes iguais continua valendo. Exige alfa real: tire o fundo antes. O relatório traz as alturas
antes e depois e o passo `post`.

## 4. Proveniência `ragrpg_art_provenance_v2`

Um registro por arquivo, num arquivo `provenance.json` (ou `provenance_v2.json` ao lado de um v1):

```json
{
  "schema": "ragrpg_art_provenance_v2",
  "path_base": "project",
  "records": [{
    "path": "assets/art/e09/characters/mg_dr/east_v3.png",
    "sha256": "…64 hex…", "width": 1254, "height": 1254, "kind": "character_view",
    "generator": {"name": "ComfyUI", "model": "qwen-image-edit-2511-Q4_K_M.gguf", "host": "local", "version": null},
    "request": "mg_dr / east", "prompt": "…o prompt exato…", "negative_prompt": null, "seed": 31,
    "params": {"steps": 4},
    "refs": [{"path": "assets/art/…/south_v4.png", "sha256": "…"}],
    "post": [{"tool": "art_pipeline.remove_background", "version": "1.0.0", "params": {"key": "#FF00FF"},
              "input_sha256": "…", "output_sha256": "…"}],
    "selected": null,
    "review": {"status": "pending", "date": null, "notes": ""},
    "terms": "licença/plano do gerador e uso comercial",
    "measurements": {"idle_height_px": [255, 254, 255, 254]}
  }]
}
```

- `path_base`: `project` (relativo à pasta do `project.godot`) ou `store` (relativo à pasta do
  próprio arquivo, para o que fica fora do projeto, como `D:/ComfyUI/ragrpg/out`).
- `kind`: `character_view`, `creature_view`, `equipment_row`, `vfx_source`, `icon_source`, `icon`
  ou `other`. Se omitido, vem do nome da pasta (`characters/`, `creatures/`, `equipment/`, `vfx/`).
- `generator.host`: `local`, `cloud` ou `manual` (desenho à mão, sem gerador).
- `selected`: `true`, `false` ou `null` (ainda sem decisão).
- `review.status`: `pending`, `approved`, `rejected` ou `needs_changes`.
- Campos sem valor ficam presentes com `null`, `[]` ou `{}`; nunca somem.
- **`terms`** é a nota de termos de uso: plano gratuito, licença do modelo, restrição de uso
  comercial. Um gerador novo só entra no projeto com isso preenchido.

### Ler registros v1 (Codex 1114–1123)

`provenance.py show arquivo.json` imprime qualquer arquivo (v1 ou v2) já no formato v2, sem
alterar o original. A conversão preenche só o que o v1 sabia: `generator.name` e o `host: cloud`
do Codex; `references` vira `refs`; `selected` fica `null` quando o v1 nunca o gravou (**1116**);
`idle_height_px` vai para `measurements`; `crop_overrides` e chaves desconhecidas vão para
`legacy`; `review.status` é `legacy`. Caminhos relativos à pasta do lote (1114 e 1115) também
resolvem. Para conferir os arquivos de um lote:

```bash
python -I tools/art_pipeline/provenance.py check assets/art/e08_codex_1118/characters/priest/provenance.json
python -I tools/art_pipeline/provenance.py check .../e08_codex_1123/characters/sp_ac/provenance.json --selected-only
```

Resultado por registro: `ok`, `missing`, `sha_mismatch` ou `size_mismatch`. Os 83 arquivos
`provenance.json` v1 das rodadas 1114–1123 carregam (56 em staging, com 339 registros, e 27 no
repositório, com 142), e todos os registros conferem por SHA256 e tamanho.

`provenance.py upgrade antigo.json novo_v2.json` grava uma cópia v2 **em outro caminho** e recusa
sobrescrever.

## 5. Passo a passo por gerador

Em todos os casos o final é o mesmo: `record_generation.py` (seção 6), validação, seleção.

### Codex (imagegen embutido)

Segue como nas rodadas 1114–1123: o Codex salva a folha RGBA e escreve o `provenance.json` v1
do briefing. Esses arquivos são aceitos como estão. Para um briefing novo, peça o v2 (campos da
seção 4) ou rode `record_generation.py` depois da entrega.

### ComfyUI local (`D:\ComfyUI\ragrpg\`)

Os scripts `qedit.py`, `faledit.py`, `hfedit.py` e `run_queue.py` **não são editados**. Cada
execução deixa `<nome>_s<seed>.png`, `<nome>_s<seed>_raw.png` e `<nome>_log.json`. O
`record_generation.py` entende esse log:

```bash
python -I tools/art_pipeline/record_generation.py D:/ComfyUI/ragrpg/out/1124/mg_dr_east_v3_s31.png \
    --from-comfy-log D:/ComfyUI/ragrpg/out/1124/mg_dr_east_v3_log.json --kind character_view \
    --terms "Qwen-Image-Edit-2511 (Apache-2.0) e LoRA Lightning; uso local"
```

Ele lê do log: gerador (ComfyUI, ou fal.ai/Hugging Face pelo campo `backend`), modelo (`unet`),
`host`, o nome do trabalho como `request`, o prompt e a semente da execução, os parâmetros (CLIP,
VAE, LoRA, passos, tamanho, máscara) e as referências na ordem em que foram enviadas (a folha
editada vem primeiro). Se existir `<nome>_s<seed>_raw.png` ao lado, acrescenta o passo `post` "pós-
processamento do script (recorte da chave e composição da máscara)" com os hashes do bruto e do
final. Sem `--store`, grava `provenance.json` na pasta do arquivo; como `D:\ComfyUI` não é um
projeto, o `path_base` é `store`.

Para registrar uma fila inteira depois de `run_queue.py` (PowerShell):

```powershell
$out = "D:\ComfyUI\ragrpg\out\1124"
foreach ($log in Get-ChildItem "$out\*_log.json") {
  $nome = $log.BaseName -replace '_log$',''
  foreach ($png in Get-ChildItem "$out\${nome}_s*.png" | Where-Object { $_.Name -notmatch '_raw\.png$' }) {
    python -I tools/art_pipeline/record_generation.py $png.FullName --from-comfy-log $log.FullName --kind character_view
  }
}
```

Registrar de novo o mesmo arquivo não faz nada (`unchanged`). Em Python, os scripts do usuário
podem importar a função (sem editar os existentes, num wrapper novo):

```python
import sys; sys.path.insert(0, r"C:/Users/João Pedro/Documents/ChatGPT/RagRPG/tools")
from art_pipeline.record_generation import record_file
record_file(png, generator="ComfyUI", model=UNET, host="local", request=job["name"], prompt=prompt,
            seed=seed, params={"steps": 4}, refs=[sheet, *refs], terms="…")
```

**Aviso.** Os scripts do ComfyUI redimensionam a saída com `LANCZOS` ao compor de volta na folha
original. Isso é pós-processamento do gerador (suaviza pixel art) e fica no passo `post`; quando a
pixel art importar, valide a folha final e olhe a franja.

### Hugging Face (páginas grátis) e fal.ai

Mesmo caminho do ComfyUI: `hfedit.py` e `faledit.py` escrevem o mesmo tipo de log, e
`--from-comfy-log` reconhece o campo `backend` (`host: cloud`). Preencha `--terms` com o plano
usado (ZeroGPU grátis; fal.ai pago por megapixel, que pede cartão internacional). O orçamento do
projeto é pequeno: `faledit.py --dry` mostra o custo antes de gastar.

### Gemini / Nano Banana e outras páginas web

Não há log. Baixe pelo botão de download (tamanho cheio), salve com o nome da vista (`east.png`,
`east_v2.png`…) e siga:

```bash
python -I tools/art_pipeline/validate_sheet.py east.png --kind character_view --background '#FF00FF'
python -I tools/art_pipeline/remove_background.py east.png east_rgba.png --key '#FF00FF' --emit-post east.post.json
python -I tools/art_pipeline/record_generation.py east_rgba.png --generator "Gemini Nano Banana" \
    --model "Pro" --host cloud --request "mg_dr / east" --prompt-file prompt_A1.txt \
    --ref refs/mg_dr_south_v4.png --post east.post.json --terms "plano gratuito; conferir uso comercial"
```

O prompt é o texto **exato** colado na conversa; correções enviadas viram uma linha no
`--review-notes` ou no `--prompt-file`. Cada tentativa é um arquivo e um registro (`_v2`, `_v3`).

### Desenho à mão

```bash
python -I tools/art_pipeline/record_generation.py east.png --generator "desenho à mão" --host manual \
    --request "mg_dr / east" --prompt "" --terms "autoria do usuário"
```

Prompt vazio é aceito, mas precisa ser passado de propósito (`--prompt ""`).

## 6. `record_generation.py`

Acrescenta um registro v2 para **um** arquivo: calcula o SHA256, lê largura e altura do cabeçalho
do PNG, calcula o SHA256 de cada `--ref` (que precisa existir; `--allow-missing-ref` grava
`"unavailable"`) e grava em `provenance.json` ao lado do arquivo (`--store` muda). Opções:

| Opção | Efeito |
|---|---|
| `--kind` | tipo do arquivo (padrão: pela pasta, senão `other`) |
| `--generator`, `--model`, `--host`, `--generator-version` | quem gerou |
| `--request`, `--prompt` ou `--prompt-file`, `--negative-prompt`, `--seed` | o pedido exato |
| `--param CHAVE=VALOR`, `--params-json` | parâmetros (`VALOR` lido como JSON quando possível) |
| `--ref` (repetível, na ordem enviada) | referências |
| `--post` (arquivo JSON ou JSON inline, repetível) | passos de pós-processamento |
| `--measure idle_height_px=[…]` | medições |
| `--selected` / `--not-selected` | escolha (padrão: sem decisão, `null`) |
| `--review-status`, `--review-date`, `--review-notes`, `--terms` | revisão e termos |
| `--root` | raiz do projeto, se o arquivo estiver em outra |
| `--replace` | substitui um registro diferente do mesmo arquivo e hash |
| `--from-comfy-log` | preenche pelo log do `qedit/faledit/hfedit` |
| `--dry-run` | mostra o resultado sem gravar |

Recusas: a pasta já tem um `provenance.json` v1 (use `--store provenance_v2.json`), o arquivo ficou
fora da raiz, falta o prompt, o registro já existe com conteúdo diferente (sem `--replace`).

## 7. Seleção (`selection.json`)

Um por lote ou classe, normalmente ao lado das imagens:

```json
{
  "schema": "ragrpg_art_selection_v1",
  "scope": "e08_codex_1123/characters/sp_ac",
  "updated": "2026-11-16",
  "selections": {
    "south": {"path": "south.png", "sha256": "…"},
    "east":  {"path": "east_v2.png", "sha256": "…"},
    "west":  {"path": "west.png", "sha256": "…"},
    "north": {"path": "north_v3.png", "sha256": "…"}
  }
}
```

O caminho é relativo à pasta do `selection.json`; o SHA256 impede que o empacotador pegue outro
arquivo sem avisar. Para criar a partir das marcas `selected: true` de um registro v1 ou v2:

```bash
python -I tools/art_pipeline/selection.py derive .../e08_codex_1123/characters/sp_ac/provenance.json \
    --out assets/art/e08_codex_1123/characters/sp_ac/selection.json
python -I tools/art_pipeline/selection.py derive .../e08_codex_1116/characters/druid/provenance.json \
    --latest-if-unrecorded --out .../selection.json     # 1116 não guardou `selected`
python -I tools/art_pipeline/selection.py check selection.json
```

O `slot` é o nome do arquivo sem a extensão e sem `_vN` (`north_v3.png` → `north`,
`weapons_h1_v2.png` → `weapons_h1`). Duas marcas `selected` no mesmo slot são conflito e param a
ferramenta; slots com versões e nenhuma marcada saem em `unselected_slots`. A escolha é decisão
humana: a ferramenta só transcreve a marca.

**Uso pelo empacotador** (somente leitura; `tools/` no `sys.path`):

```python
from art_pipeline.selection import load_selection
selection = load_selection("assets/art/e08_codex_1123/characters/sp_ac/selection.json")
for direction in ("south", "east", "west", "north"):
    source = selection.resolve(direction)      # Path absoluto; falha se o SHA256 não bater
```

`tools/prepare_e08_directional_art.py` **não foi alterado** nesta tarefa (dono: T7). A T7 troca o
caminho fixo por `selection.resolve(view)` na `source_recipe.json`.

## 8. Arquivo (`archive.py`)

Copia lotes da staging para o arquivo durável fora do Git, confere cada cópia por SHA256 e escreve o
índice versionado (caminho, SHA256, tamanho, `selected`, `archived_path`, `type`):

```bash
python -I tools/art_pipeline/archive.py copy \
    --source "C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/assets/art" \
    --archive "C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/art_archive/e08" \
    --batch e08_codex_1119 --batch e08_codex_1120 --batch e08_codex_1121 --batch e08_codex_1122 \
    --batch e08_codex_1123 --batch e08_nb_1124 \
    --index docs/art/archive/e08_staging_1119_1124.json --dry-run
python -I tools/art_pipeline/archive.py verify --archive ".../art_archive/e08" \
    --index docs/art/archive/e08_staging_1119_1124.json --source ".../assets/art"
```

(`--dry-run` mostra o que seria copiado sem escrever nada; tire-o para copiar.) Garantias, todas
com teste:
- a **origem nunca é aberta para escrita**, movida ou apagada; o teste compara hash e data antes e
  depois;
- **nunca sobrescreve**: bytes iguais são `already_archived`; bytes diferentes são
  `refused_overwrite` (código `1`) e o arquivo arquivado fica como estava;
- cada cópia é conferida por hash logo depois de gravada; cópia que falha é removida;
- o índice nunca troca o SHA256 de um caminho já listado (`index_conflicts`);
- `.import`, `.uid`, `.tmp` e `.part` são ignorados por padrão (arte-fonte não leva `.import`, como
  no `db7f9252`); o arquivo precisa ficar fora da pasta de origem.

Por padrão entram todos os arquivos do lote, inclusive os `provenance.json` (`type: metadata`);
`--include '*.png'` limita ao que interessar. O índice guarda só caminhos relativos, e os
`*_root_hint` são texto informativo.

## 9. Substituir por ID (sem mudar consumidor)

Do contrato C5: um ícone pintado em `assets/art/skills/painted/<skill_id>.png` substitui o SVG, e um
flipbook em `assets/art/e08_vfx/<id>/flipbook.json` substitui o efeito desenhado em código. O
pipeline entra assim: gerar a folha-fonte (`icon_source` ou `vfx_source`), validar, registrar a
proveniência, e o empacotador existente produz o arquivo final com o mesmo ID. Nenhum consumidor
muda. A fila das peças pintadas está em [generation_queue.md](generation_queue.md).

## 10. Receita completa para uma classe nova

1. Gerar as quatro folhas (uma por vista), qualquer gerador; cada tentativa vira um arquivo
   versionado (`east`, `east_v2`…).
2. Registrar cada arquivo com `record_generation.py` (ou o log do ComfyUI).
3. Se o fundo é chapado: `remove_background.py` por folha, e registrar a saída com `--post`.
4. `validate_sheet.py --set …` com as quatro vistas. Ler os `error`; os `warning` de escala vão para
   o passo 5.
5. Altura diferente? `normalize_scale.py --set …` e registrar as saídas com o passo `post` que ele
   imprime.
6. O usuário escolhe a versão de cada vista. Marcar `selected` (`--selected` ao registrar ou na
   revisão) e rodar `selection.py derive`.
7. Conferir o resultado com `selection.py check` e olhar as folhas no tamanho de jogo.
8. Quando o lote estiver decidido, `archive.py copy` e commitar o índice e a arte escolhida
   (decisão D3: versiona-se só a arte escolhida).

## 11. Limites conhecidos

- O validador não avalia estilo, rosto, mãos nem gestos: isso continua sendo revisão humana, por
  captura no tamanho de jogo.
- A altura do corpo parado mede a caixa do alfa; capuz alto, chapéu ou cabelo contam como corpo.
- Duas figuras que se encostam na mesma célula não são distinguidas (a célula conta como uma).
- A remoção do fundo é por distância de cor: uma chave parecida com o traje come o traje (use
  `--mode connected` ou outra cor). JPEG recomprimido produz ruído; use PNG original.
- `crop_overrides` só movem limites verticais, como no empacotador. Limites horizontais bloqueados
  (por exemplo, `br_ac` norte na 1121) pedem outra versão da folha.
