# E10a T2 — arquivo e versionamento da arte: recibo de entrega

Tarefa **T2** de [e10a.md](../e10a.md), contrato **C4.1** de [e10a_contract.md](../e10a_contract.md)
(§5.1). Papel: Luna (Claude Haiku 5.5, esforço médio). Data: 18/11/2026. Estado proposto:
**ENTREGUE**; validação técnica (Sol) e integração ficam para a sessão de arquitetura.

## Base e entrega

| Item | Valor |
|---|---|
| SHA-base | `6938db71dc6bd56cce2658bcfbe7af956849ab8c` (commit do índice E10a, confirmado com `git rev-parse HEAD` no checkout) |
| Branch | `claude/e10a-t2-c0791b` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\e10a-t2-c0791b` |
| Commit de conteúdo | ponta da branch informada na mensagem final (um recibo não contém o próprio SHA) |
| Push / `master` / `codex/playtest` / save pessoal | não tocados |
| Arte gerada ou editada | nenhuma |

## Estado de partida (constatação)

Os 13 PNG de C4.1 e as quatro `provenance.json` das pastas já estavam **versionados no Git** desde o
E08 (commit `2d191956`): `assets/art/e08_codex_1116/` e `assets/art/e08_codex_1118/` (93 arquivos rastreados somando os dois
lotes: 77 PNG e 16 `provenance.json`, com as pastas de todas as classes). A base `6938db71` já contém esses arquivos.

Por isso a "cópia" de §5.1 não mudou nenhum byte: cada um dos 13 arquivos e das quatro
`provenance.json` foi comparado com a staging por SHA256 e é **idêntico** (nenhum arquivo foi
sobrescrito). O que a T2 acrescentou ao Git foi o que faltava: as quatro `selection.json` e o índice
do arquivo.

## Conferência antes de tudo

- `provenance.py check` sobre a `provenance.json` do 1116 (acolyte): 6 registros, 0 problemas
  (os quatro escolhidos conferem SHA256 e tamanho contra a staging).
- `provenance.py check --selected-only --root <checkout>` sobre as pastas do 1118: priest 4/0,
  cultist 4/0, equipment 2/0.
- SHA256 da staging e do repositório iguais para os 13 PNG (lista abaixo). Os quatro
  `provenance.json` são idênticos byte a byte entre staging e repositório (`cmp`).

## Arquivos de C4.1 (13 PNG, todos com SHA256 conferido)

| Arquivo | Bytes | SHA256 |
|---|---|---|
| `assets/art/e08_codex_1116/characters/acolyte/south_v5.png` | 1440782 | `8bdf9dea7213e80b2d6e78b003f1f1bb2e80be4810b6c12005012010cd7771b6` |
| `assets/art/e08_codex_1116/characters/acolyte/east_v3.png` | 1107121 | `ee48158b8546e44fa822b510e49bbbb412483935fd3abb09a13262c2ebb8630b` |
| `assets/art/e08_codex_1116/characters/acolyte/west_v3.png` | 1189496 | `8d7e3f0724f1ec57bc3f1397818a7aed62d0a859bd5d94165893e6c5c067fdfb` |
| `assets/art/e08_codex_1116/characters/acolyte/north.png` | 1626968 | `6d06e243759ceee8fb11540c05b80b52e08a4882b03fc95a04ed30a58cdbf7a4` |
| `assets/art/e08_codex_1118/characters/priest/south.png` | 1440743 | `9f21a15a47f09a231b8c2efacfb9e01ee369fa093f534f8bb60e3c90ef7ef225` |
| `assets/art/e08_codex_1118/characters/priest/east.png` | 1319015 | `c556b5dcaff8dd5bc2aed76b958979ff730ff0848ac61ab6f74a132ae2c9bd9d` |
| `assets/art/e08_codex_1118/characters/priest/west_v2.png` | 1357187 | `9a26446154d7d36c0e9162579bdb49611845955bf478de14742d21a9362090a3` |
| `assets/art/e08_codex_1118/characters/priest/north.png` | 1328148 | `44488787a5b996f002d18c853d9d010c8911345fc56ca46be119aebf12466573` |
| `assets/art/e08_codex_1118/characters/cultist/south.png` | 1426804 | `2c894b80576dc613070f977426ef886134f6bb774d0936eb1317e18452a67948` |
| `assets/art/e08_codex_1118/characters/cultist/east.png` | 1369633 | `b8dd93b5bafcaa30833109b9515dcede28081b28b3d735ddff6bc4a02c55de30` |
| `assets/art/e08_codex_1118/characters/cultist/west.png` | 1395360 | `c160be76efd1ac17b3c78d9097fc458f25a6a3f9e9f29cbccdd0238dc11a0af8` |
| `assets/art/e08_codex_1118/characters/cultist/north.png` | 1506350 | `ac027bd3a9fd73ce92eaacfaa192ad20c9daec6154b0328aa85fa07b5e9c22f4` |
| `assets/art/e08_codex_1118/equipment/weapons_b1.png` | 1619977 | `a4a088a4601b5c245aea177a6aaa37da058514f727cf734d8c6aae33d445fdfa` |

Soma dos 13: **18.127.584 bytes** (~18 MB, a conta de §5.1).

## Proveniência e seleção

| Arquivo | Estado | Bytes | SHA256 |
|---|---|---|---|
| `assets/art/e08_codex_1116/characters/acolyte/provenance.json` | já versionado (igual à staging) | 15736 | `7bb8e4862c936663c03581fcee9847aa3c1954d94658dbb131912b9a42954eca` |
| `assets/art/e08_codex_1116/characters/acolyte/selection.json` | **novo** | 992 | `a7e37f89f4b620326132e9cbb7325bdf5f85767bf5719415009ae057a5a219e4` |
| `assets/art/e08_codex_1118/characters/priest/provenance.json` | já versionado (igual à staging) | 13569 | `1b3a63617ca024269f28910d3cb9f28dc1dce932ac9172ee18ed163a1814c462` |
| `assets/art/e08_codex_1118/characters/priest/selection.json` | **novo** | 665 | `4ec6a06ad1400b16c28c24f9c98fc206f719f470f18c97c19492cbbfee638d84` |
| `assets/art/e08_codex_1118/characters/cultist/provenance.json` | já versionado (igual à staging) | 15400 | `f00d4243cf6fb946c367921c783b4c6a3885737bc64d2ea3e3f98607cbeb8427` |
| `assets/art/e08_codex_1118/characters/cultist/selection.json` | **novo** | 663 | `687a98bf09c9d6666a9152ebc96641e6815c69e067ee4633ad7f5011b32038f9` |
| `assets/art/e08_codex_1118/equipment/provenance.json` | já versionado (igual à staging) | 6513 | `c35bd4ecb70eccedf4552f60d547e8b90a21827c1642735fd8cfe8dc3085cb6c` |
| `assets/art/e08_codex_1118/equipment/selection.json` | **novo** | 272 | `1857404044486a16970147f609092a90f7837ed8a73d98fa8095194e9c3bc1bd` |

- **Acolyte (1116, sem `selected`):** `selection.py derive --latest-if-unrecorded` escolheu a maior
  versão `_vN` de cada vista: `south_v5`, `east_v3`, `west_v3`, `north`. Coincide com a escolha de
  §5.1 e fica marcada como `inferred` no `selection.json`. O registro v1 original não foi reescrito.
- **Sacerdote e Cultista (1118):** `selection.json` pelas marcas `selected` do próprio registro; 4
  vistas cada, sem conflito e sem vista sem escolha.
- **Equipamento (1118):** o registro marca `weapons_b1` **e** `weapons_b2` como `selected` (estado do
  E08). Esta tarefa escolhe só `weapons_b1` (C4.1), e o `selection.json` lista só ela. Ver limitação 2.

Checagem: `selection.py check` nos quatro arquivos, 0 problemas.

## Arquivo fora do Git e índice

- Arquivo: `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\art_archive\e08\` (fora do Git;
  `.tools/` é ignorada). Lotes **`e08_codex_1116`** e **`e08_codex_1118`**, inteiros: 93 arquivos
  (77 PNG e 16 `provenance.json`), 103.705.712 bytes.
- Ferramenta: `tools/art_pipeline/archive.py copy`, depois `archive.py verify` com `--source`.
  Dry-run primeiro (93 copiados, 0 recusados, 0 erros). Cópia real: 93 copiados, 0 erros, 0 conflitos
  de índice. Verificação: **93 conferidos, 0 problemas**, pelo SHA256 da cópia e da origem.
- Índice versionado: [docs/art/archive/e08_staging_1116_1118.json](../../art/archive/e08_staging_1116_1118.json),
  schema `ragrpg_art_archive_index_v1`, 28.256 bytes, SHA256
  `28b0db0259a6bfb5a5ff380e56c62826a88b0d19f03a50d8925798876078f636`. Totais: 93 entradas, 77 PNG,
  42 com `selected: true`, 103.705.712 bytes.
- Rótulos gravados sem acento (`map-editor-m5/assets/art (staging)` e `.tools/art_archive/e08`), para
  não repetir o defeito de codificação da T4 do E09.
- Relatórios (dry-run, cópia, verificação) e manifestos ficam fora do Git em
  `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\art_reports\e10a_t2\`.

## Prova: staging intacta

Manifesto da staging `…\.tools\map-editor-m5\assets\art` (caminho, tamanho e data de modificação de
**todos** os 1884 arquivos), tirado antes do dry-run e depois da cópia e da verificação: os dois
manifestos são iguais (SHA256 do manifesto `24791B0C6469A95BABCFD38A11632B82C8E4A19D28BBA70B80817EA57CBA4FDA`
nos dois casos). Nenhum arquivo novo, removido ou alterado na staging. A origem foi lida, nunca escrita.

## Verificações

- **Testes Python:** `python -I -m unittest discover -s tools/art_pipeline/tests` → `Ran 89 tests … OK`.
- **`.import`:** nenhum `.import` (nem `.uid`) entra como arquivo novo; nenhum `.import` rastreado em
  `e08_codex_1116/` ou `e08_codex_1118/`. Arte-fonte entra sem `.import`, pela regra do `db7f9252`.
- **Git:** só entram os quatro `selection.json` e o índice; nenhum PNG novo entra no commit.
- **Godot:** não importado nem aberto; a T2 não tem runtime.
- **Runtime:** `tools/verify.ps1` **não foi rodado**: entrega só de arte, dados e documento.

## Limitações

1. **Nada foi copiado de fato.** Os 13 PNG e as quatro `provenance.json` já estavam no Git
   (E08, `2d191956`) e são idênticos à staging. A conferência de hash está registrada, mas o
   "versionamento" de §5.1 já estava feito antes desta tarefa.
2. **`weapons_b2.png` ainda está marcado `selected: true`** no `provenance.json` do equipamento 1118
   (estado do E08). O `selection.json` da T2 lista só `weapons_b1`, como manda C4.1. Não reescrevi o
   registro. `weapons_b2.png` continua versionado (do E08) e fica fora desta escolha. Sol/T9 deve
   usar só `weapons_b1`.
3. **Seleção do Acólito inferida.** O registro v1 não tem `selected`; a escolha é a maior versão `_vN`
   e coincide com §5.1, mas está marcada como `inferred` no `selection.json`.
4. **Caminho do `selection.json` de equipamento.** `selection.py derive` gravou o caminho relativo ao
   projeto; corrigi para `weapons_b1.png`, relativo à pasta, como nas demais pastas. `selection.py check`
   passou depois da correção.
5. **Coluna `selected` do índice é transcrição.** O índice copia a marca `selected` dos registros
   (`null` onde o registro não tem o campo, como no 1116), e não é uma escolha nova. A escolha que
   vale é a de `selection.json`.
6. **Arquivo fora do Git.** `.tools/art_archive/e08` não é versionado. Se `.tools` for apagada, o
   índice aponta para cópias que não existem mais; a staging continua sendo a segunda cópia.
7. **Sem validação visual.** A T2 confere hash e registro, não estilo, mãos ou gestos; isso fica para
   a T8 (captura nativa).

## Próximo passo

Sol confere o contrato e os invariantes (sem edição de expectativa). A T8 (corpos) e a T9 (itens)
partem das cópias versionadas acima, com merge da T2 depois que ela for integrada. A T2 não edita
nenhum arquivo de outra tarefa.
