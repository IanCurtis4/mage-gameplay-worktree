# E09 T9 — Escolha de evolução, onboarding e perfis de revisão

Entrega da tarefa T9 (Terra · Sonnet 5.5 · médio). Fonte: `docs/epics/e09.md` (A7, A9, A11, A17) e
`docs/epics/e09_contract.md` (C1.10, C1.12).

## Base

- Branch: `claude/competent-pascal-9d4802`; checkout `.claude/worktrees/competent-pascal-9d4802`.
- Base: `4fbfd9db26a1b753b53ba48cc21fa3fff74178c9` (ponta da T1, com T1.1, T1.2 e A14), por
  `git merge --ff-only` sem conflito. Contém `771a314f`.
- Commit entregue: o da própria entrega (`git log -1` da branch); sem push e sem `master`.

## Arquivos

| Arquivo | Mudança |
|---|---|
| `scripts/ui/character_menu.gd` | A linha de cada opção de evolução 2-3 passa a nomear a afinidade ("Híbrida · afinidade Acólito"/"Ladino"/classe). Nada mais mudou: o menu já listava todas as evoluções da origem com `content_ready` e requisitos atendidos (A7), qualquer que seja o número de híbridas. |
| `scripts/ui/classes/kit_onboarding_base.gd` | Base comum dos guias (sem `class_name`, carregada por caminho): painel retrátil "Guia +/−" no canto superior direito, só o botão captura o mouse, visível só para o jogador cujo kit é a identidade do guia. |
| `scripts/ui/classes/{sp_ac,mg_ac,sp_la,mg_la}_onboarding.gd` | Os quatro guias (C1.12): título, linha de laço e ajuda com as sete skills, a interação da base e a fraqueza, em pt-BR, das fichas de `docs/HYBRIDS_56_V3.md`. |
| `tools/e09_review_profiles.gd` | Leitor e validador de `review_builds.json` (`ragrpg_review_builds_v1`) e gerador de perfis isolados (A11). |
| `tests/e05_evolution_catalog_test.gd` | Listas de destinos (A9), sem afrouxar nada (ver abaixo). |
| `tests/e09/kit_seam_test.gd` | Só as listas de destinos (A9) e os checks de esqueleto de produção (A17). |
| `tests/e09/ui_evolution_test.gd` | Novo: escolha de evolução, onboarding e perfis de revisão. |
| `docs/epics/e09/t9_delivery.md`, `t9_capture_*.png` | Este recibo e as capturas. |

## Decisões

1. **Escolha de evolução.** A lógica já era "uma opção por definição pronta da origem", então não
   há teto de duas híbridas. A T9 só acrescentou a afinidade ao rótulo, para o Paladino e o
   Duelista (mesma origem) não ficarem iguais para quem lê. Híbridas sem `ready_for_play` não
   aparecem (A7); o teste cobre zero, algumas e as quatro prontas.
2. **Onboarding.** Uma base comum e quatro arquivos finos, em vez de quatro cópias do painel da
   Geômetra. O registro só precisa de `<id>_onboarding.gd` e `new()` devolvendo um `Control` com
   `configure(player)`/`refresh()`, o que o `main.gd` já usa. O texto é estático (não consulta o
   estado do kit, que ainda é de outras tarefas); só mostra o guia quando `player.kit.evolution_id`
   é a identidade.
3. **A9, listas.** Regra única: as dez identidades atuais (as doze do E00) mais as híbridas do
   E09 cujo kit declara `ready_for_play` (`ClassKitRegistry.ready_for_play`). Os metadados de cada
   híbrida pronta são conferidos exatamente (nome pt-BR, origem, afinidade, tier `2-3`, habilidade
   de entrada e as sete skills); as não prontas precisam estar ausentes. O `SCRIPT ERROR` da
   linha 47 do e05 sumiu porque a tabela `expected` ganha a chave de cada kit pronto, sem
   `.get(...)` e sem relaxar a checagem. Além das duas listas citadas, o e05 tinha uma terceira
   contagem fixa (`exact["options"].size() == 4`, em `_check_query_states`); o K1 e o K2 não a
   viam porque o `SCRIPT ERROR` interrompia a função antes. Ela agora espera 4 mais as híbridas
   prontas do Espadachim.
4. **A17, esqueleto.** O comportamento de esqueleto passa a ser provado com um `SkeletonKit`
   de fixture (classe aninhada no teste, `ClassKit` vazio) instalado por
   `ClassKitRegistry.install_fixture` e desfeito por `clear_fixtures()`. O novo
   `_check_skeleton_and_readiness_states` prova os três estados: zero prontos (quatro
   esqueletos), alguns (Paladino e Lâmina Arcana com `FixtureKit`) e os quatro prontos, cada um
   com a mesma checagem de listas e metadados. As listas de produção seguem a regra do item 3.
   "forcing an empty skeleton ready is refused" e "a fixture override can list a skeleton as
   unavailable" agora usam o `mg_ac` como esqueleto de fixture. O check "has no onboarding script
   yet" (linha 65, fora da lista da tarefa) pressupunha a ausência dos guias, que esta tarefa cria;
   passou a exigir o guia (`Control`) das quatro identidades. Os checks de corpo de fixture da A14
   e `_install_fixtures()` não foram tocados.
5. **A11, perfis.** O leitor (`ReviewProfiles.read_builds`) devolve `pending` (sem arquivo ou sem
   `ready_for_play`, sem erro), `ready` ou `invalid` com `error_code` e detalhe. A legalidade vem
   do `ProfileCatalog`: o mapa traz o rank **final**, o custo é o final menos o `free_rank` (o R1 da
   entrada é grátis), `validate_purchased_ranks` confere ranks, máximos e pré-requisitos, e
   `skill_points_spent` confere os orçamentos (19 de base e 20 de evolução; ≤, com o gasto total
   devolvido). Atalhos precisam ser ativas aprendidas, sem repetição. Cada build vira um perfil
   (`<id>__<build>/`) por `ProfileStore.commit` e é relido do disco. O gerador recusa pasta
   relativa, a pasta de dados do usuário ou uma pasta que já tenha perfil.
6. **Nível do perfil: 40, não 37.** A tarefa pedia "job 37". A 7ª skill libera no job 37, mas os 20
   pontos de evolução que as builds gastam só existem no job 40 (`nível de job − 20`; no 37 são
   17). Com 37, as duas builds reais do K1 e do K2 seriam ilegais. Os perfis usam, portanto, o
   XP mínimo do job 40, o que mantém o requisito de nível das skills (≤ 37) e o orçamento de
   19 + 20. Se a intenção era mesmo o job 37, as builds dos kits precisam gastar 17 pontos.

## Testes

Todos com `tools/verify.ps1 -SkipEditorImport` depois de `--headless --editor --import --quit`
(a falha `GitPlugin` é conhecida). O `kit_seam_hooks_v3_test` precisa de `-F1Fixture`; a fixture
foi regenerada por `e07_f1_import_test` depois da última edição do e05.

| Teste | Resultado | sha256 da saída |
|---|---|---|
| `battle_ui_test` | PASS, 47 | `F8318896CA4F69C73DFEE75D000BE93183454816283638EE4C14279A62749D21` |
| `ui_layout_test` | PASS, 30 | `2221C3B8FF5B8BC13995CE03DF5ADDB87D48671AD7CA4B1B51601E3D859D9690` |
| `e02_character_menu_test` | PASS, 26 | `92E8322739E3F81D8741FB767086745D0012C5B6A7B991C3B90A90688B3FA116` |
| `e05_evolution_catalog_test` | PASS, 81 | `A5E1E7F91D133043144EEEA92BBDE1231588F06F860518990B33DE52C44C5381` |
| `e05_evolution_transaction_test` | PASS, 51 | `7E4549E180A962046BD69F9FDA7B19F31B1CA00B8E153B12DC9A751E50C819A0` |
| `e05_evolution_menu_integration_test` | PASS, 25 | `4971C5F9BD615E8CFB872B89BA8A5ECF2F0704506752BF6D788A5A8C3A7D341C` |
| `e05_geometer_onboarding_test` | 274 checks, 0 falhas | `705F60C1B14DFE0445C621E03560A6FEC1C2476A572144D249467ACCE37E1F91` |
| `e05_sentinel_onboarding_test` | 140 checks, 0 falhas | `CA12F5F00517AB29F1689C800F835677BBB66605F182B5EF9A418BA4FEC2DF08` |
| `kit_seam_hooks_v2_test` | 38 checks, 0 falhas | `5182F32B62DE14BE5938AF67C615BFBC0CBB6BDF062A64EDB08131758CF6FA5A` |
| `kit_seam_hooks_v3_test` (com `-F1Fixture`) | 63 checks, 0 falhas | `D1DFD323C350F8F63140F3D8D86FE01FB566BAEE11ED3A93B953FBF99F78F449` |
| `kit_seam_test` | 264 checks, 0 falhas | `BC3E69998A9B23B22EC75875235AD4C36F83C5EF9BEEADB453F074AC1A486DCB` |
| `ui_evolution_test` (novo) | 97 checks, 0 falhas | `DF7B1619F114033B0C05563E933F5A06170AC0D0EEF1A886AA5C45F28C7369EF` |
| `e07_f1_import_test` (fixture) | PASS | `03B9A002FD4328A260628675539D4F1E076F6027032D28249EC159776E8EE030` |

Busca por `SCRIPT ERROR` e `still in use` nos logs de saída e de motor de todas as rodadas: 0
ocorrências. (Uma rodada anterior do `ui_evolution_test` acusou `still in use` por um
`PlayerActor` não liberado no próprio teste; corrigido.)

### Verificação extra: dois kits reais prontos (cópia descartável, nada commitado)

Nesta mesma árvore, `git merge --no-commit --no-ff 6e37da52 a0a65700` (K1 e K2 prontos, com a T5
que eles trazem), nova importação, depois `git merge --abort`. Nada dessa composição entrou no
commit.

| Teste | Resultado | sha256 da saída |
|---|---|---|
| `e05_evolution_catalog_test` | PASS, 87 checks | `3B667A91EC05729D749FC9C7500BD8F27BE5C1FFA31F6A44C875FFCD88D74AD0` |
| `kit_seam_test` | 266 checks, 0 falhas | `F92F22E5054D4096045664AA88CEA4F85B763ED08439D2FDB349FCF98F3E3E94` |
| `ui_evolution_test` | 97 checks, 0 falhas | `DF7B1619F114033B0C05563E933F5A06170AC0D0EEF1A886AA5C45F28C7369EF` |

A primeira tentativa dessa verificação acusou a contagem fixa do item 3 acima (1 de 87), que
foi corrigida antes do resultado da tabela. Ainda com o merge, `tools/e09_review_profiles.gd`
rodou contra o catálogo real e os arquivos reais: 4 perfis gerados (`sp_ac__paladin_bulwark`,
`sp_ac__paladin_hammer`, `mg_ac__thaumaturge_prism_altar`, `mg_ac__thaumaturge_dawn_choir`),
`sp_la` e `mg_la` pendentes ("sem review_builds.json"), nenhum inválido.

## Capturas nativas

Janela do Godot 4.7.2 a 1280×720 (renderizador padrão, não headless), kits de fixture:

- [t9_capture_evolution_choice.png](t9_capture_evolution_choice.png): aba "Classe e equipamento" de
  um Espadachim base 10/job 20 com Paladino e Duelista de fixture prontos, ao lado do Defendente e
  do Berserker. Os dois rótulos "Kit de teste" são o nome do `FixtureKit`; os kits reais trazem
  Paladino e Duelista. A afinidade aparece em cada linha.
- [t9_capture_onboarding_sp_ac.png](t9_capture_onboarding_sp_ac.png): o guia do Paladino
  expandido, sobre fundo liso.

## Limitações

1. **Capturas com fixture.** Os kits reais não são prontos nesta base; a captura mostra o nome de
   teste. A composição final com os nomes reais fica para a T10.
2. **Perfis de fixture no job 40**, não 37 (decisão 6).
3. **Perfis de revisão sem equipamento nem atributos.** Só ranks de skills e barra de atalhos;
   atributos livres, sem equipamento e sem preset customizado. Quem revisa distribui os atributos.
4. **Onboarding estático.** Não mostra Graça, Sentença nem círculo atual; precisam do estado dos
   kits, que pertence a K1–K4 e T5/T6. A base aceita sobrescrever `status_text()` quando houver API.
5. **`review_builds.json` exige no mínimo duas builds** (C4.2) e só valida legalidade de catálogo;
   não valida se a build é boa.
6. **Perfis do K3 e do K4** ficam pendentes até haver arquivo e `ready_for_play`; o teste prova o
   estado pendente com fixtures, não com os arquivos reais, que ainda não existem.
7. **Escopo da supervisão:** execução, conclusão, erros, hashes e invariantes. Não é auditoria
   semântica independente.
8. Arquivos `.import` e `.gd.uid` gerados pelo editor fora das pastas da tarefa foram desfeitos
   antes do commit.
