# E10a T10 — criação, evolução, onboarding e perfis (C7)

Papel: Terra (Claude Sonnet 5.5, médio). Contrato: [e10a_contract.md](../e10a_contract.md) §8; decisões A7, A11 e A15 (E09).

## Base e checkout

| Item | Valor |
|---|---|
| SHA-base | `b0583e16fc3e48e93be92ae7f3b60625d289cae2` (`git log -1` após `git merge --ff-only claude/e10a-candidato`, sobre `7795f56d`) |
| Contém | T5 `50fb61bd`, T6 `ce629e74`, T7 `de11f99d` (`merge-base --is-ancestor` ok nos três) |
| Branch / checkout | `claude/admiring-proskuriakova-de00f1`, `.claude/worktrees/admiring-proskuriakova-de00f1` |
| Commit entregue | o que contém este recibo (ponta da branch) |
| Engine | `Godot_v4.7.2-stable_win64.exe` via `-GodotPath`; `verify.ps1` rodado com `pwsh` (o `powershell` 5 não tem `Path.GetRelativePath`) |

Sem push, sem `master`, sem `codex/playtest`, sem save pessoal, sem worktree extra.

## Entregue

- `scripts/ui/character_menu.gd`: a criação lista as bases por `CREATION_CLASS_IDS`, só as disponíveis no `ProfileCatalog` (o Acólito entra por `base_class_is_available`, C1.3), cada uma com botão `Create_<id>`, descrição pt-BR e tooltip; `_class_name(&"acolyte")` = "Acólito". A escolha de evolução não mudou: já lista Sacerdote (2-1) e Cultista (2-2) por serem puras prontas.
- `scripts/ui/classes/kit_onboarding_base.gd`: a visibilidade usa `_active_identity()` (A7.5): `kit` se não for nulo, senão `origin_kit`. Sem isso o guia da base quebraria com `kit == null`.
- `scripts/ui/classes/{acolyte,priest,cultist}_onboarding.gd`: guias pt-BR de Loucura, Delírio, Visão Eldritch e Devoção (base); Santuário, Graça, Égide, Juízo, Exorcista, Selo de Luz e Hora Santa (Sacerdote); Olhar do Abismo, Êxtase, Ídolo, Delírio Compartilhado, Pupila Aberta, Geometria e Revelação (Cultista). Texto estático, sem consultar o estado do kit.
- `tools/e10a_review_profiles.gd`: reaproveita o leitor/validador do E09 (`ragrpg_review_builds_v1`); família = `acolyte` (sempre pendente, sem erro) + puras do Acólito; um perfil isolado por build no job 40, nome "E10a <build>" (máx. 24); recusa pasta relativa ou dentro de `user://`; nunca sobrescreve.
- `tests/e10a/ui_family_test.gd`: 86 checks.

## Testes (`-SkipEditorImport -F1Fixture`, depois de `editor_import` duas vezes e de `e07_f1_import_test`)

A fixture F1 guarda o hash dos testes: toda edição de teste exige rodar `e07_f1_import_test` de novo.

| Teste | Resultado | sha256 da saída (16 primeiros) |
|---|---|---|
| `ui_family_test` (novo) | 86 checks, 0 falhas | `cfd87d1482e2332…` |
| `ui_evolution_test` (E09: onboarding e perfis) | 97 checks, 0 falhas | `271bbf8375253e7…` |
| `e02_character_menu_test` | PASS, 26 | `0d8d0f1fff6079a…` |
| `e05_evolution_menu_integration_test` | PASS, 25 | `74a7ec99a684021…` |
| `e06_ui_menu_test` | 120 checks, 0 falhas | `f91307c07018679…` |
| `menu_tabs_test` | PASS, 40 | `f0c255f0c07305a…` |
| `profile_facade_test` | PASS, 52 | `658ac48e90c6785…` |
| `e05_evolution_catalog_test` | PASS, 99 | `f49ffd1e882bb6a…` |
| `kit_seam_test` | 276 checks, 0 falhas | `07028bfb1108d35…` |
| `base_seam_test` | 172 checks, 0 falhas | `a8a6f7a68629371…` |

Busca por `SCRIPT ERROR`, `still in use` e `ERROR:` nas saídas: 0 em todas.

## Ajuste da A15

`tests/e02_character_menu_test.gd`, linha 23, só esse check: `create_buttons.size() == 3` passou a `== 4` e acrescentou `create_buttons[3].text == "Criar Acólito"`. Nenhuma expectativa foi afrouxada; a linha 65 (botões desativados em perfil somente leitura) segue válida.

## Capturas nativas (janela Godot 1280×720, módulos de produção; script em [t10_capture.gd.txt](t10_capture.gd.txt))

- [t10_capture_creation.png](t10_capture_creation.png): criação com as quatro bases e a descrição pt-BR do Acólito.
- [t10_capture_evolution_choice.png](t10_capture_evolution_choice.png): Acólito base 10/job 20 com "Escolher Sacerdote" (2-1) e "Escolher Cultista" (2-2).
- [t10_capture_onboarding_cultist.png](t10_capture_onboarding_cultist.png): guia do Cultista expandido (o painel é mais alto que a janela; o texto continua abaixo da Revelação).

## Achado para a T7 / arquitetura

`scripts/classes/cultist/review_builds.json` usa rank `0` em `evolution_ranks` (`cultist_impossible_geometry` no Profeta, `cultist_ecstasy` no Vidente). O esquema do E09 exige rank ≥ 1 (`rank_not_positive_integer`); o leitor do E09 recusa o arquivo como inválido. O arquivo é da T7 e não foi editado. A ferramenta da T10 descarta as entradas com rank 0 numa cópia saneada em `.godot/verification/e10a_review_sanitized` e lê esse arquivo no lugar; arquivos sem rank 0 (Sacerdote) são lidos no lugar. Com isso os quatro perfis saem legais (19 + 20 pontos, testado). Recomendação: a T7 (ou a T13) remove os zeros do JSON; a tolerância fica inofensiva.

## Limitações

1. Onboarding estático: não mostra Loucura, Êxtase, Graça nem Ídolo ao vivo (HUD é a T12).
2. A tolerância ao rank 0 mascara o defeito do arquivo da T7 na ferramenta; o leitor do E09 segue estrito.
3. Perfis de revisão sem equipamento nem atributos; só ranks e atalhos, como no E09.
4. As descrições das outras três classes na criação são novas (pt-BR, curtas) e podem ser reescritas pelo produto.
5. Arquivos `.import` reescritos pelo editor não foram commitados.
6. Escopo da supervisão: execução, conclusão, erros e hashes; não é auditoria semântica independente.

## Próximo passo

T13 incorpora esta branch ao candidato; T12 (HUD) pode ler o estado dos kits para o onboarding.
