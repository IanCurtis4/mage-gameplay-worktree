# E09 T2 — pipeline de arte neutro: recibo de entrega

Tarefa **T2** de [e09.md](../e09.md), contrato **C5** de [e09_contract.md](../e09_contract.md#6-c5--pipeline-de-arte-neutro-tarefa-t2).
Papel: Terra (Claude Sonnet 5.5). Data: 16/11/2026. Estado proposto: **ENTREGUE**; falta
validação (WORKFLOW) e a integração por T10.

## Base e entrega

| Item | Valor |
|---|---|
| SHA-base | `771a314f78c7a0cb5fda2f1f48d93bc6dc776b68` (documentos do E09) |
| Origem da worktree | `master` = `acd589eb`; trazido com `git merge --ff-only 771a314f…` (sem conflito) |
| Branch | `claude/hungry-elbakyan-169f52` (nome criado pela ferramenta; o plano previa `claude/e09-t2`) |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\hungry-elbakyan-169f52` |
| Commit de conteúdo | ver `git log` da branch: o commit "feat(e09-t2)…". O SHA da ponta vai na mensagem final da sessão (um recibo não contém o próprio SHA) |
| Push / `master` | não feitos |

## O que foi entregue (C5)

Tudo em `tools/art_pipeline/` (2.319 linhas de código, 1.230 de teste). Guia em
[docs/art/pipeline.md](../../art/pipeline.md); fila em
[docs/art/generation_queue.md](../../art/generation_queue.md).

| Item do contrato | Arquivo | Notas |
|---|---|---|
| Validador da folha-fonte `ragrpg_source_sheet_v1`, saída JSON, motivo de cada falha | `validate_sheet.py`, `sheet_layout.py` | cinco `kind`; conjunto de vistas com razão de altura contra a referência; `--strict`, `--strict-scale` |
| Validação de lote em staging | `validate_batch.py` | escolhe a versão `selected`, 1116 por "maior `_vN`" (marcado), lote posterior substitui o anterior, aplica `crop_overrides` v1 |
| Removedor de fundo chapado, parâmetros registrados | `remove_background.py` | tolerância 48, modo global/connected, limpeza de franja, véu opcional; devolve o passo `post` |
| Normalizador de escala sem suavização | `normalize_scale.py` | `nearest` por padrão; `lanczos` só explícito e marcado `smoothing: true` |
| Esquema `ragrpg_art_provenance_v2` e leitor v1→v2 | `provenance.py` | lê 1114–1123 (1116 sem `selected`; 1114/1115 com caminho relativo ao lote); nunca reescreve v1 |
| `selection.json` e leitor para o empacotador | `selection.py` | slot = nome sem `_vN`; caminho relativo + SHA256; `resolve()` confere o hash |
| Ferramenta de arquivo | `archive.py` | cópia exclusiva (`xb`), hash conferido, índice versionado, nunca apaga a origem nem sobrescreve bytes diferentes |
| CLI `record_generation.py` | `record_generation.py` | também entende os logs de `D:\ComfyUI\ragrpg\{qedit,faledit,hfedit}.py` |
| Testes Python | `tools/art_pipeline/tests/` | 89 testes |

Extras pedidos no briefing: `docs/art/pipeline.md` (11 seções, receita por gerador) e
`docs/art/generation_queue.md` (seis itens, estado dos geradores).

## Testes

```bash
python -I -m unittest discover -s tools/art_pipeline/tests
```

Resultado: `Ran 89 tests in ~14 s … OK`. Cobertura por módulo: validador 20, removedor 10,
normalizador 9, proveniência 12, seleção 10, arquivo 11, `record_generation` 10, lote 7.
Destaques que o contrato pedia:
- validador: célula vazia, borda, faixa ausente (com corte sugerido que, aplicado, faz a folha
  passar), fundo chapado removido na memória sem gravar, equipamento encostado, 30% de escala;
- normalizador: o conjunto de cores da saída é subconjunto do da entrada (sem suavização);
- proveniência: v1 sem `selected`, sem `references`, com `crop_overrides`, caminho relativo ao
  lote; o original v1 não muda byte a byte; registros reais 1116–1118 do repositório conferem;
- arquivo: hash e data da origem iguais antes e depois; bytes diferentes no arquivo são recusados
  e preservados; cópia que falha não deixa arquivo parcial.

Dependências: as dos `tools/prepare_e08_*.py` (Pillow 12.2.0 e numpy 2.4.6); **nenhum pacote
novo**. Limitação do `python -I`: ele ignora a pasta de pacotes do usuário, onde o Pillow está
nesta máquina; `art_pipeline/imaging.py` acrescenta só essa pasta quando o import falha, e os testes
rodam com `-I` como pedido. Proveniência, seleção e arquivo não precisam de Pillow.

## Prova: validador sobre o material real (somente leitura)

Relatórios grandes ficam **fora do Git**, em
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\art_reports\e09_t2\` (pasta ignorada
pelo Git; os relatórios são determinísticos, sem data):

| Arquivo | Conteúdo | SHA256 |
|---|---|---|
| `staging_1120_1123_report.json` | 22 híbridas (88 vistas) e 4 folhas de equipamento | `3e7f1babe72e51f7afffb60534689b302e814e79818be2057f96d3827ac689d4` |
| `staging_summary.json` | resumo do anterior | `1c41e6ccb4af6d73dcc3d1a29b7fd8d3bbd6ea3bfb062d7a26a6949c71cac1cf` |
| `repo_1116_1118_report.json` | 22 conjuntos (88 vistas) e 5 folhas, versionados | `945cd232a756e99d7a13b359f8c7f010f8f4e00af79fbd2adfeac650bab6c2d3` |
| `repo_summary.json` | resumo do anterior | `296fbc9a2eb7e72d410da5aef1d6435f7900a60ef8cad1b160b670fc6b1c5dfe` |

Comandos (a staging é `…\RagRPG\.tools\map-editor-m5\assets\art`):

```bash
python -I tools/art_pipeline/validate_batch.py --art-root <staging>/assets/art \
  --batch e08_codex_1120 --batch e08_codex_1121 --batch e08_codex_1122 --batch e08_codex_1123 \
  --equipment-count weapons_h1=8 --equipment-count weapons_h2=8 --equipment-count weapons_n1=3 \
  --equipment-count weapons_e1=2 --equipment-count necro_props=7 --out staging_1120_1123_report.json
python -I tools/art_pipeline/validate_batch.py --art-root assets/art \
  --batch e08_codex_1116 --batch e08_codex_1117 --batch e08_codex_1118 --out repo_1116_1118_report.json
```

Tempo: cerca de 5 s para as 88 vistas da staging.

### Escala entre vistas: as diferenças conhecidas da 1120 foram apontadas

Altura do corpo parado em relação à vista sul, tolerância ±10%:

| Classe | Vista | Razão | Desvio | Briefing 1120 dizia |
|---|---|---|---|---|
| `br_la` Sicário | leste | **0,708** | −29,2% | 0,71 |
| `br_la` Sicário | oeste | **0,776** | −22,4% | 0,78 |
| `br_dr` Encarnado | oeste | **0,802** | −19,8% | 0,81 |
| `br_mo` Domador | leste | **1,180** | +18,0% | 1,19 |

Essas quatro são as únicas vistas das 22 classes fora da tolerância; as demais ficaram entre 0,92
(`br_la` norte) e 1,06 (o briefing citava 0,97–1,05 para as outras da 1120). A medição bate com o
`idle_height_px` que o Codex gravou nos registros (60 vistas comparadas): a diferença é de 1 a 3 px
(até cerca de 1%), sempre para mais, provavelmente por outro limiar de alfa.

As **quatro híbridas do E09** (`sp_ac`, `mg_ac`, `sp_la`, `mg_la`, 1123) passam sem erro: razões
entre 0,973 e 1,028, faixas entre células de 46 a 69 px, só o aviso de véu. A seleção derivada de
cada `provenance.json` por `selection.py derive` **coincide com a tabela C6** de
[e09_contract.md](../e09_contract.md#7-c6--arte-do-épico-tarefas-t4-e-t7):

| Classe | south | east | west | north |
|---|---|---|---|---|
| `sp_ac` | `south` | `east_v2` | `west` | `north_v3` |
| `mg_ac` | `south` | `east` | `west_v2` | `north` |
| `sp_la` | `south` | `east` | `west` | `north_v2` |
| `mg_la` | `south` | `east_v3` | `west_v4` | `north_v2` |

### Resumo da staging 1120–1123

22 híbridas, 88 vistas: **18 avisam, 4 reprovam, 0 passam limpas** (todas têm o véu de alfa). Contagem de
achados: `alpha_veil` 92, `scale_mismatch` 4, `no_gutter_band` 4, `touches_cell_edge` 4.

Reprovações reais, todas na **linha 4 (dano e morte)**, onde duas poses se encostam ou cruzam o limite
da grade, e nenhuma delas era conhecida ou registrada como `crop_overrides`:

| Classe | Vista | Problema | Corte sugerido (`x_px`) |
|---|---|---|---|
| `ar_br` Mercenário | south | pose 16 encosta no limite 3 da linha 4 | 855 |
| `br_dr` Encarnado | south | poses 15 e 16 cruzam o limite 3 | 806 |
| `br_la` Sicário | south | poses 15 e 16 cruzam o limite 3 | 803 |
| `br_ac` Arauto da Peste | north (`north_v4`) | pose da linha 4, coluna 1, encosta no limite horizontal 3 | sem corte possível (o empacotador só move limites verticais) |

Nenhuma dessas quatro é uma das híbridas do E09. As três primeiras se resolvem com um
`crop_overrides` na receita; a `br_ac` norte pede outra versão da folha.

Equipamento: as quatro folhas passam com as contagens esperadas (H1 8, H2 8, N1 3, E1 2, objetos
separados; só o véu). Os objetos de H1 vão de 54–201 a 1928–2132 em x, como o briefing 1120 descreve.
`weapons_e1_v3` (a do E09) tem 2 objetos, de 573–720 e 1301–1705.

### Repositório 1116–1118

22 conjuntos (5 de 1116, 7 criaturas de 1117, 10 de 1118) e 5 folhas: **22 conjuntos avisam, nenhum
reprova**; 14 razões de escala fora de ±10%. As maiores:
Druida oeste 1,326 e leste 1,324, Cão-demônio oeste 0,748, Ladino norte 1,244, Cão-demônio leste
0,801, Acólita oeste 0,836. A 1116 não grava `selected`, então a vista contada é a maior `_vN`
(marcada `inferred_latest_version`): vale como indicação, não como escolha. As folhas de
efeito (`aspect_*`, 1117) têm o quadro 16 em branco (aviso `empty_cell`); as de equipamento B1 e B2
da 1118 trazem 7 e 6 objetos (sem contagem pedida, aviso `expected_count_unknown`).

### Remoção de fundo contra a verdade conhecida

As referências `e08_nb_1124/refs/mg_ac_south_on_{magenta,green}.png` são a folha aprovada
`mg_ac/south.png` composta sobre o fundo chapado, então a folha original é o gabarito. O
removedor com os parâmetros padrão reproduz a silhueta (alfa ≥ 128, o mesmo corte do empacotador)
com **IoU 0,9971 (magenta) e 0,9983 (verde)** e levou ~0,5 s. Sem a limpeza de franja
(`--edge-steps 0`) o IoU cai para 0,977 contra o mesmo gabarito, então o passo vale a pena.
Observação: a folha do Codex quase não tem pixels com alfa 255 (197 em 1,57 milhão); o alfa é
semitransparente quase em toda a figura, o que a remoção a partir de fundo chapado não reproduz
(a saída é binária).

## Verificações de segurança do que não era para mudar

- **Staging e `D:\ComfyUI\ragrpg`:** só leitura. `find -newermt` em ambas, no fim, não achou arquivo
  modificado no dia. As chamadas de `record_generation.py` sobre os logs reais do ComfyUI usaram
  `--dry-run`; o arquivo `provenance.json` não apareceu nas pastas de saída.
- **v1:** carregados os 83 `provenance.json` (56 em staging, 339 registros; 27 no repositório, 142); todos os
  arquivos listados existem com SHA256 e tamanho certos. Nenhum foi escrito.
- **Fora do dono:** nenhuma edição em `tools/prepare_e08_*.py`, nos scripts do usuário, nem em
  outros documentos. Só entraram `tools/art_pipeline/**`, `docs/art/pipeline.md`,
  `docs/art/generation_queue.md` e este recibo.
- **Runtime:** nada de Godot mudou, então a suíte `tools/verify.ps1` **não foi repetida**; é uma
  entrega de ferramentas Python e documentação. A validação foi pelos testes Python e pela prova
  acima.

## Decisões e interpretações a conferir

1. **Escala é aviso, não erro.** O contrato diz que as diferenças "precisam ser apontadas". O
   normalizador (ou o `target_height` do empacotador) as corrige, então reprovar a folha seria
   exagero; `--strict-scale` reprova. Tolerância padrão ±10%.
2. **`empty_cell` em `vfx_source` é aviso.** Uma animação de efeito pode terminar em quadro vazio
   (as três de 1117 terminam). Para personagem e criatura, continua erro.
3. **Gutter por linha e por coluna.** O limite vertical é medido dentro de cada linha da grade, e o
   horizontal dentro de cada coluna, não pela folha inteira, que é como o empacotador corta. Por isso
   o relatório pode dizer "linha 4, limite 3".
4. **`provenance.json` v2 convive com o v1 no mesmo nome de arquivo.** `record_generation.py`
   recusa acrescentar a um v1 e sugere `provenance_v2.json`. A T4 e a T7 precisam saber ler os dois
   (`load_provenance` faz isso).
5. **`selected` ausente.** `null` no v2. A decisão de escolher a versão mais recente da 1116 é só
   do `--latest-if-unrecorded` e do `validate_batch.py`; ela fica marcada como inferida, nunca gravada
   como escolha humana.

## Limitações e próximos passos

- **Fora do escopo desta tarefa:** o empacotador `tools/prepare_e08_directional_art.py` ainda lê
  caminhos fixos; ele passa a usar `load_selection()` na T7 (dona do arquivo). Não escrevi nenhum
  `selection.json` no repositório: a T4 versiona a arte e cria os arquivos de seleção no mesmo
  commit.
- O validador **não julga estilo, mãos, gestos nem rosto**; isso segue sendo captura no tamanho de
  jogo e revisão humana. A altura do corpo mede a caixa do alfa (capuz alto e cabelo contam).
- Pixel art redimensionada com `nearest` por fator não inteiro fica com pixels de tamanhos
  desiguais; é o custo de igualar a altura sem suavizar. A alternativa é regenerar a vista.
- O fallback de `imaging.py` depende de `site.getusersitepackages()`; em outra máquina com
  Pillow em outro lugar, `python -I` falha com mensagem clara (`Pillow and numpy are required`).
- `archive.py` copia e confere, mas **não foi rodado sobre a staging** (é a T4, que escreve no
  arquivo fora do Git). O teste cobre as garantias com pastas temporárias; para a T4 recomendo começar
  com `--dry-run`.
- Gerar arte nova continua bloqueado pelo gerador (ver a fila). Nada depende disso no E09.

**Para T4 e T7:** a base é a ponta desta branch (o SHA vai na mensagem final). T4 pode usar
`selection.py derive` e `provenance.py check --selected-only` nas quatro classes de C6, `archive.py
copy --dry-run` primeiro, e `load_provenance` para os v1.
