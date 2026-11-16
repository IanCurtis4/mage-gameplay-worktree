# E09 T4 — arquivo e versionamento da arte: recibo de entrega

Tarefa **T4** de [e09.md](../e09.md), contrato **C6** de [e09_contract.md](../e09_contract.md#7-c6--arte-do-épico-tarefas-t4-e-t7).
Papel: Luna (Claude Haiku 5.5, esforço médio). Data: 16/11/2026. Estado proposto: **ENTREGUE**;
validação técnica e integração ficam a cargo de Sol/T10.

## Base e entrega

| Item | Valor |
|---|---|
| SHA-base | `68b760118c0e3004afc43d2bb86a1e4a4eb78d71` (ponta entregue da T2, `claude/hungry-elbakyan-169f52`) |
| Ação de base | `git merge --ff-only 68b76011…` a partir de `acd589eb`, sem conflito |
| Branch | `claude/silly-liskov-2366c4` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\silly-liskov-2366c4` |
| Commit de conteúdo | ponta da branch informada na mensagem final (um recibo não contém o próprio SHA) |
| Push / `master` / `codex/playtest` / save pessoal | não tocados |

## O que foi versionado (C6)

Só as versões `selected` de C6, no mesmo caminho relativo a `assets/art/`, com a
`provenance.json` completa de cada pasta e um `selection.json` criado por
`selection.py derive` (caminhos relativos à pasta, SHA256 de cada escolha).

Antes de copiar: `provenance.py check --selected-only` deu **0 problemas** nas seis pastas
(19 PNG conferidos por SHA256 e tamanho). `selection.py derive` sobre a staging coincidiu com a tabela C6
nas seis pastas, e cada `selection.json` gravado passou em `selection.py check` (sem `problems`).

Tamanho total: **19 PNG = 23.580.735 bytes** (23,6 MB, a conta de C6); os 6 `provenance.json` somam
163.005 bytes e os 6 `selection.json` somam 3.223 bytes. Total de dados: 23.746.963 bytes.

| Arquivo | Bytes | SHA256 |
|---|---|---|
| `assets/art/e08_codex_1120/equipment/provenance.json` | 10639 | `888f01679413463390030e4d99e9fdfbdc7dc08ec5a59651d0fa4705b96eba0f` |
| `assets/art/e08_codex_1120/equipment/selection.json` | 402 | `3b96cad4de4740e48d8194d35d5bb2696471e537e6fac5ca4a0614c5475ca269` |
| `assets/art/e08_codex_1120/equipment/weapons_h1_v2.png` | 1470020 | `b36825e12f9d3729bb5943ccf4ec5c9182b26616ac75c3dd76ee52e00b83016d` |
| `assets/art/e08_codex_1120/equipment/weapons_h2.png` | 1260678 | `504d034fd9e0756f5f86cef21f32a773818db9efcc0325b0d1957776d0c9acfc` |
| `assets/art/e08_codex_1123/characters/mg_ac/east.png` | 1352374 | `96b169d7d06edd4488e14af349d37917a1ac471334416be0c8fb1a0ecde9673d` |
| `assets/art/e08_codex_1123/characters/mg_ac/north.png` | 1467860 | `3c013991d7496b6c3fae742b54ed288e8ce62785f4de63db99604335239052a7` |
| `assets/art/e08_codex_1123/characters/mg_ac/provenance.json` | 21676 | `2d4713426216a7e686ce24138f189b530363f2a30b16bc719322d556b8322b5b` |
| `assets/art/e08_codex_1123/characters/mg_ac/selection.json` | 638 | `ecb932ce26ba7752bf6311ba0346a77b5c5adee4e6459f6a9a947f6c0e5f6d1c` |
| `assets/art/e08_codex_1123/characters/mg_ac/south.png` | 1464877 | `fd17dfb2d2a28e06b4557f0f0f8086f05b120e3aea414dbca30aa8a2c936f189` |
| `assets/art/e08_codex_1123/characters/mg_ac/west_v2.png` | 1247431 | `4fb71cbf5c5064b643cc39eaa5af146e252e8d98f7f8b63246ff08fcbcc8eb5c` |
| `assets/art/e08_codex_1123/characters/mg_la/east_v3.png` | 1129996 | `12afe8905c8cbb46c7b516228aeb7684a8a923e322f8ad0eac6d8eec7a2cce79` |
| `assets/art/e08_codex_1123/characters/mg_la/north_v2.png` | 1197118 | `1df8df974c197190fc3202d9ea5da6470b0b6f28349cfc605552935c668956d1` |
| `assets/art/e08_codex_1123/characters/mg_la/provenance.json` | 57804 | `b2e78ed2e7ee07b7fbb04fe6bd06e139fdeb4244c8e4ea324afc4af27c34730e` |
| `assets/art/e08_codex_1123/characters/mg_la/selection.json` | 644 | `4389f7a50b21e8bad3bb069cf522f6e6d37c7de93a3e9f1350cc6e91fbbee78e` |
| `assets/art/e08_codex_1123/characters/mg_la/south.png` | 1159381 | `f8202be8fd999920d9fc45b17f6797dc699a816e901c94c9acd2487d77296e05` |
| `assets/art/e08_codex_1123/characters/mg_la/west_v4.png` | 1141118 | `236064fbe73038c3bfc1b9f08c3402051c18eaf29a37b548df467599d564a427` |
| `assets/art/e08_codex_1123/characters/sp_ac/east_v2.png` | 1302198 | `a8c287dfd58e8a0d0cb636c1fc4383106da555e94e286a9a0bdd33c7efa5c926` |
| `assets/art/e08_codex_1123/characters/sp_ac/north_v3.png` | 1351421 | `2a7a064a1f088961e0fb7be86735ff75924264c0ea5c9b4d982aa7a9b9352d66` |
| `assets/art/e08_codex_1123/characters/sp_ac/provenance.json` | 37664 | `4303494387dd57b90e40f59051960532e6c9b2ddad509c12a7981ac668454e0d` |
| `assets/art/e08_codex_1123/characters/sp_ac/selection.json` | 641 | `9476bc11f6528197cf7b5e8caa42e08485c71553f073c852e7a6a112c2f57f10` |
| `assets/art/e08_codex_1123/characters/sp_ac/south.png` | 1610477 | `3e0291f22c75e5323427965390dd3a83f8703c4020305788b3b67e19b57f4c8e` |
| `assets/art/e08_codex_1123/characters/sp_ac/west.png` | 1279999 | `8759411a13d4eeeea0a9561f219b3634cfea9f3cebb6b5079d0add58137ba2dc` |
| `assets/art/e08_codex_1123/characters/sp_la/east.png` | 1123773 | `96d6cb7a0a32c9bebff902011f9679d8024cf560f56fe67715aa2cfb40d1d4d7` |
| `assets/art/e08_codex_1123/characters/sp_la/north_v2.png` | 1208974 | `d405cbbba75d05bb38adf26e6a8c910a3123daaf4474670be560a2703472dff3` |
| `assets/art/e08_codex_1123/characters/sp_la/provenance.json` | 28380 | `851d2d9863c0b4e0f802384a8065f5258e46e4643cd4d38bb533e3428a5b9d96` |
| `assets/art/e08_codex_1123/characters/sp_la/selection.json` | 638 | `f2f93b63ac3b63ae53555681258b8b3e70ae3218d48a0d0a513714abfe743d81` |
| `assets/art/e08_codex_1123/characters/sp_la/south.png` | 1222582 | `f342ebb56f63bac1b7d25c7302d263354ec6c8e97786231d3ac1c11c921dd5fa` |
| `assets/art/e08_codex_1123/characters/sp_la/west.png` | 1121319 | `d79e539b000316945eca7d46499118e5be07aecfb8c9b0b55ef6dbf1dd91c2f1` |
| `assets/art/e08_codex_1123/equipment/provenance.json` | 6842 | `2e4fb632df8215c0c2882250cfd28a99d05692c3e499ee775e36a23fd3248a84` |
| `assets/art/e08_codex_1123/equipment/selection.json` | 260 | `b748b9537eef06de5d1cc6ceceea794717c3aa8f8c6b5f1f7b21905fcdec6715` |
| `assets/art/e08_codex_1123/equipment/weapons_e1_v3.png` | 469139 | `5ba63f415058032faf8be13c2e5c20cc2979ff93f2d77e7f5cf072ee27f32dfa` |

Total: **31 arquivos** versionados (19 PNG, 6 `provenance.json`, 6 `selection.json`). Mais o índice,
abaixo.

Escolhas conferidas contra C6 (`selection.json`): `sp_ac` south/east_v2/west/north_v3; `mg_ac`
south/east/west_v2/north; `sp_la` south/east/west/north_v2; `mg_la` south/east_v3/west_v4/north_v2;
`1120/equipment` weapons_h1_v2 e weapons_h2; `1123/equipment` weapons_e1_v3. Sem slot sem escolha
(`unselected_slots` vazio).

## Arquivo fora do Git e índice

- Arquivo: `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\art_archive\e08\` (fora do Git, pasta
  `.tools/` ignorada). Lotes `e08_codex_1119`, `1120`, `1121`, `1122`, `1123` e `e08_nb_1124`.
- Índice versionado: [docs/art/archive/e08_staging_1119_1124.json](../../art/archive/e08_staging_1119_1124.json),
  schema `ragrpg_art_archive_index_v1`, SHA256 `039a167536de72ec9861b35e04fd34e9a1994f09726a8813972b4e2a05ca884f`,
  69.929 bytes.
- Contagem do índice (`totals`): **236 entradas** = **207 PNG** + **29 `provenance.json`**; tamanho
  total arquivado **301.901.389 bytes**. Dos 207 PNG, **99 com `selected: true`**, 98 com `false` e 10 sem
  registro (`null`, lote `e08_nb_1124`).
- Ordem de execução: `archive.py copy --dry-run` (236 arquivos, 301.901.389 bytes, sem escrita), depois
  a cópia real (236 copiados, 0 recusados, 0 erros, 0 conflitos de índice), depois `archive.py verify`
  (236 conferidos, 0 problemas, pelo hash de cada cópia e da origem).

### Diferença em relação ao número previsto (339)

O plano esperava **339 PNG**. A contagem real dos lotes pedidos é **207 PNG**; a diferença é de
132. O número 339 é o total de **registros** `provenance` (v1) de **toda** a staging (56 arquivos),
e inclui os lotes `e08_codex_1114` a `1118` (com 26 + 2 + 30 + 37 + 47 registros), que não estavam
no pedido, além de pastas fora do E08 (`map_authoring`, `e08_world`, `e08_pilot`, etc.). Nos lotes
1119–1123 há **197 registros** (1 + 45 + 67 + 12 + 72), que batem com os 197 PNG desses lotes; os
10 PNG de `e08_nb_1124` não têm `provenance.json`. Portanto 197 + 10 = **207**. Não forcei a conta
a 339.

### Coluna `selected` do índice

A coluna transcreve a marca `selected` dos registros v1 e v2 (ou `null`), e não é uma escolha nova.
Por isso há 99 `true` no índice, e não só as 19 escolhas de C6: as marcas dos lotes 1120–1123 já
existiam nos `provenance.json`. A escolha que conta para o E09 é a da tabela C6 (`selection.json`).

## Prova: staging intacta

Manifesto da staging (`…\RagRPG\.tools\map-editor-m5\assets\art`) gerado **antes** do dry-run e
**depois** da cópia e da verificação: caminho, tamanho, data de modificação e SHA256 de **todos** os
1884 arquivos da pasta (inclui os lotes arquivados e os demais).

| Manifesto | Antes | Depois |
|---|---|---|
| Lista de SHA256 (1884 linhas) | `ca296d866bfcc8a1e72dc14f90e2654a32901b69347718b9e17a4c68a4c4e6ab` | `ca296d866bfcc8a1e72dc14f90e2654a32901b69347718b9e17a4c68a4c4e6ab` |
| Caminho, tamanho e data (1884 linhas) | `4a82330ff990f320b054ba66901c2c5589364d8133da31b45e8690d3a9065032` | `4a82330ff990f320b054ba66901c2c5589364d8133da31b45e8690d3a9065032` |

Os dois manifestos são idênticos byte a byte (`cmp`), sem nenhum arquivo novo, removido ou alterado. Os
manifestos e os relatórios do `archive.py` (dry-run, cópia, verificação) ficam fora do Git em
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\art_reports\e09_t4\`.

A origem nunca foi aberta para escrita: a leitura é só de `archive.py` (ver a seção 8 do pipeline).

## Verificações

- **Testes Python:** `python -I -m unittest discover -s tools/art_pipeline/tests` → `Ran 89 tests … OK`.
- **`.import` no Git:** nenhum `.import` ou `.uid` entra na lista de arquivos novos (`git ls-files`
  confere depois do commit). A arte-fonte entra sem `.import`, pela regra do `db7f9252`.
- **`.tools`, `.godot`, builds:** nada desses entra no Git.
- **Godot:** nenhum editor aberto, nenhuma importação; a importação fica para a T7.
- **Runtime:** nenhum código de runtime mudou, então a suíte gameplay `tools/verify.ps1` **não foi
  repetida**. Esta entrega é de arte, documentos e um índice.

## Limitações e defeitos registrados

1. **Rótulo do índice com caractere quebrado (corrigido).** A primeira cópia gravou `source_root_hint`
   com `Jo�o`, porque o caminho com `ã` passado pelo Git Bash chegou com outra codificação. Os arquivos
   foram gravados no caminho certo (o caminho real estava correto e a verificação conferiu tudo); só o
   rótulo estava errado. Corrigi refazendo a mesma cópia com rótulos sem acento (`--source-label` e
   `--archive-label`): a segunda execução reportou `already_archived` nos 236 e atualizou só o rótulo, e
   `verify` deu 0 problemas de novo. O defeito é de codificação do shell, não da ferramenta;
   `tools/art_pipeline/archive.py` não foi editado.
2. **Arquivo não é versionado pelo Git.** Os 207 PNG e os metadados ficam só em `.tools/art_archive/e08`
   e na staging. Se a pasta `.tools` for apagada, o índice aponta para cópias que não existem mais; a
   origem na staging continua sendo a única segunda cópia.
3. **`e08_nb_1124` sem proveniência.** As 10 imagens são referências (`refs/`) e não têm `provenance.json`;
   o índice lista seus SHA256 com `selected: null`.
4. **Lotes 1116–1118 não arquivados.** Não estavam no pedido e continuam só no repositório (versionados
   pelo E08 anterior) e na staging.
5. **Validação visual não feita.** A T4 confere hash e registro, não estilo, mãos ou gestos; isso fica na
   captura do jogo (T7/T8).
6. **Arquivos copiados sem preservar a data.** `cp` não manteve o horário de modificação na worktree; o
   arquivo arquivado foi copiado com `copystat` e a origem não mudou.
