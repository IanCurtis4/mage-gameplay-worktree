# Consumo dos mapas publicados (F9-11)

Ponto de consumo dos mapas do editor para os próximos épicos (campanha, fases,
missões). Um mapa publicado é um **pacote imutável de patrulha** (`.rpp`) com
terreno, composição, encontros e rotas já compilados e certificados. Quem consome
pede um `package_id` e recebe o pacote validado, o `ExpeditionManifest` ou a
preparação de gameplay; não lê fontes de mapa, sessões do editor, caches,
`.godot/map_authoring` nem o perfil do jogador.

Prova: `ReleaseApi` 11/11 (checkpoint48) e a etapa `Release` do candidato M8, que
abre o Bosque no executável exportado, numa instalação limpa (`release_bosque`
8/8), além do pacote representativo (`release` 6/6).

## Uso

```gdscript
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")

# Lista para menus e tabelas de campanha: [{package_id, name}].
var maps := MapRelease.packages()

# O contrato de dados: o manifesto do pacote fixado na lista.
var opened := MapRelease.manifest("sanctuary_woods")
if not opened.ok:
	push_error(opened.diagnostics[0].message)
	return
var manifest: ExpeditionManifest = opened.manifest

# No processo de jogo (nunca no editor): mesma preparação do teste de gameplay.
var prepared := MapRelease.prepare("sanctuary_woods")
# prepared.manifest, prepared.rules, prepared.map_package, prepared.entry,
# prepared.candidate_hash, prepared.package, prepared.release
```

| Função | Onde | Devolve | Custo no Bosque |
| --- | --- | --- | --- |
| `packages(listing = {})` | qualquer | `[{package_id, name}]` na ordem da lista | lê só a lista |
| `entry(id, listing = {})` | qualquer | `{ok, entry}` com os pinos | lê só a lista |
| `load_package(id, listing = {})` | qualquer | `{ok, entry, package}` | ~17 s (valida rotas e encontros) |
| `manifest(id, listing = {})` | qualquer | `{ok, entry, package, manifest}` | ~17 s |
| `prepare(id, listing = {})` | só jogo | o resultado de `gameplay_candidate.prepare` + `package` e `release` | ~100 s, no quadro principal |
| `freshness(id, listing = {})` | autoria/testes | `{ok, current, source_hash, pinned_source_hash}` | lê e hasheia a fonte |

`listing` vazio usa a lista commitada; um dicionário com o mesmo formato serve
para testes. Toda falha devolve `{ok:false, code, diagnostics:[{code, severity,
entity_id, field:"release", message}]}` com mensagem em português.

`prepare()` certifica, com as autoridades do jogo e o perfil de travessia da fase
de produção, que a entrada autorada, todas as superfícies, objetivos e portais
têm ida e volta para o corpo real, que as casas dos encontros são alcançáveis e
que as patrulhas cabem no leash. Ela roda no quadro principal (~80 s só na
certificação do Bosque); tirar esse custo do quadro é pendência F10 já
registrada. Quem precisar só dos dados usa `manifest()`.

## Lista de mapas publicados

`res://data/map_authoring/release_packages.json` (JSON estrito, até 64 KiB e 64
mapas):

```json
{
	"registry_version": 1,
	"packages": [
		{
			"package_id": "sanctuary_woods",
			"name": "Bosque do Santuário",
			"kind": "patrol",
			"path": "res://data/map_authoring/sanctuary_woods.rpp",
			"source_path": "res://data/map_authoring/sanctuary_woods.patrol.json",
			"compiler_revision": "map_patrol_v1",
			"source_hash": "58df5d63…29dc1",
			"package_hash": "f3cdb460…93a53"
		}
	]
}
```

Formato fechado: exatamente essas chaves; `package_id` em minúsculas, dígitos,
`_` ou `-`; `kind` `patrol`; `path` e `source_path` diretamente em
`res://data/map_authoring/` (sem subpasta nem `..`); `compiler_revision` igual à
do compilador do checkout; hashes sha256 em hexadecimal minúsculo; IDs e caminhos
únicos. Qualquer desvio é `release_registry_invalid`.

O pacote só é entregue se `package_hash`, `source_hash` e `compiler_revision`
lidos do arquivo forem os da lista (`release_package_mismatch`). Arquivo ausente,
cortado ou alterado é `release_package_invalid`.

## Formato do `.rpp`

`"RPP1"` + sha256 hexadecimal (64 caracteres) do payload + `var_to_bytes(pacote)`,
no máximo 4 MiB. A leitura (`PatrolStore.load_package`) confere o cabeçalho e o
hash, decodifica com `bytes_to_var` (nunca instancia objetos ou scripts) e
revalida o pacote com `PatrolCompiler.validate_package`: forma fechada, hash do
conteúdo, encontros do pacote de população e cada rota de patrulha contra a
geometria e o catálogo de mobs atuais.

Pacote de patrulha (`format_version` 1):

| Chave | Conteúdo |
| --- | --- |
| `compiler_revision` | `map_patrol_v1` |
| `source_hash` | hash semântico da fonte de patrulha (que embute encontros e mapa) |
| `population_package` | pacote de encontros: `map_package` (geometria compilada), `rules`, `profile`, `manifest` |
| `manifest` | dados do `ExpeditionManifest` com as patrulhas nos slots |
| `package_hash` | digest canônico das chaves acima |

Chaves do manifesto que os consumidores podem ler: `manifest_revision`,
`geometry_revision`, `input` (`parts`, `traversal`, `entry_stage_id`,
`phase_id`), `stages` (uma etapa `map_preview` com `surfaces`, `sockets` e
`entrance`), `traversal`, `population.slots` (espécie, categoria, origem, casa,
travessia e, quando houver, `patrol`), `objectives` (`objective_id`, `point`),
`portals` e `witnesses`. No Bosque: 1 etapa, 84 superfícies, entrada autorada
`authored_entry` em (160, 0, 640), 7 slots, 1 patrulha, objetivo
`shrine_completion` em (2336, 128, 192) sobre o viaduto, nenhum portal.

`manifest()` devolve uma cópia: alterar o manifesto não altera o pacote. Quem
adapta o manifesto para outra fase (como faz o teste de gameplay com a entrada e o
perfil de travessia) trabalha numa cópia e valida pelas autoridades canônicas.

## Revisões e compatibilidade

- O pacote é imutável. Uma nova versão do mapa é um novo `.rpp`, com outro
  `package_hash`, e novos pinos na lista; os bytes publicados nunca são editados.
- `PatrolStore.publish(pasta, pacote, hash_da_fonte_atual)` grava
  `<package_hash>.rpp`, recusa fonte velha (`stale_source`) e nunca sobrescreve
  um valor diferente no mesmo nome (`immutable_conflict`).
- Uma mudança de `REVISION` de qualquer compilador (`map_terrain_v5`,
  `map_composition_v5`, `map_population_v2`, `map_patrol_v1`) invalida os pacotes
  antigos: é preciso republicar. A validação também depende do catálogo de mobs e
  dos catálogos de mapa; mudar um deles pode recusar um pacote antigo, o que é
  diagnóstico, nunca reparo silencioso.
- A compilação é determinística: recompilar o Bosque da mesma fonte deu os mesmos
  bytes do pacote de 31/10 (sha256 `e695a49e…dfb619`, ~3 min sem cache).

## Publicar uma nova revisão

Pelo editor (checkpoint50): na tela de patrulhas, depois de validar e testar no
jogo a revisão atual, "Publicar no jogo…" no roteiro mostra o que muda e, depois da
confirmação, grava `data/map_authoring/<id>.<hash12>.rpp` (a revisão anterior
continua em disco), a fonte `<id>.patrol.json` e a entrada da lista
(`map_release.gd` `plan_publication`/`publish`). Detalhes em
`contracts/f9_guided_flow.md`.

À mão, o mesmo resultado:

1. Compile e publique pela CLI do produtor (Godot 4.7.2 contratado, use o
   executável de console para esperar o fim):
   `--headless --path <projeto> --script res://scripts/map_authoring/patrol/headless.gd -- <fonte.patrol.json> <pasta>`.
   O resultado `MAP_PATROL_RESULT` traz `input_hash` e `output_hash`.
2. Copie `<pasta>/<package_hash>.rpp` para `data/map_authoring/` (o editor usa
   `<package_id>.<hash12>.rpp`; o Bosque de 1/11 ficou em `sanctuary_woods.rpp`) e
   atualize `path`, `source_hash` e `package_hash` na lista.
3. Rode `tools/map_editor_completion/run.ps1 -Stage ReleaseApi` (confere lista,
   pinos, frescor da fonte, adulteração e preparação) e
   `tools/map_editor_candidate/run.ps1 -Stage Release` (export e execução limpa).

`freshness()` aponta quando a fonte commitada já não produz o `source_hash`
fixado; o teste `ReleaseApi` falha nesse caso.

## Export

O preset de release inclui `data/map_authoring/*.json` e `*.rpp` (pacotes e
lista) e o manifesto de assets; num build exportado, os hashes de texturas,
sprites e catálogos vêm de `asset_manifest.json`, não dos arquivos brutos. A
prova roda o executável copiado com o `.pck` para uma pasta nova fora do projeto,
com perfil novo (`APPDATA`/`LOCALAPPDATA`) e diretório de trabalho nessa pasta;
a pasta é apagada depois e os arquivos que o jogo criou ficam listados no
`release_manifest.json` da evidência.

As fontes JSON vão no pacote do jogo por causa do filtro, mas não fazem parte do
contrato: o jogo não as lê.

## Fora do contrato

Não são API de consumo e podem mudar sem aviso: recibos de variação regional e o
livro de revisões, bundles de intercâmbio (`.rpx`), candidatos e sessões de teste
em `.godot/map_authoring`, o cache de compilação, a fonte de cada tela, os
painéis e comandos AX do editor e o pacote representativo do M8
(`representative.rpp`, que é fixture de regressão e não está na lista).

## Diagnósticos

| Código | Quando |
| --- | --- |
| `release_registry_invalid` | lista ausente, maior que 64 KiB ou fora do formato |
| `release_unknown` | `package_id` que a lista não tem |
| `release_package_invalid` | `.rpp` ausente, cortado, adulterado ou recusado pela validação |
| `release_package_mismatch` | o arquivo é válido mas não é o fixado na lista |
| `release_source_missing` | `freshness()` sem a fonte no projeto |
| `runtime_required` | `prepare()` chamado dentro do editor |
| `entrance_unsafe`, `body_unreachable`, `interaction_unreachable` | a preparação de gameplay não certificou o mapa |
