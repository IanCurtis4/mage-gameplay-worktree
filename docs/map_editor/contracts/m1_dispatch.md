# F1 / M1 — dispatch autorizado, schema v1

24/10/2026. Autorização humana neste chat: “F0 terminou, pode começar F1.”
Executor Sol, esforço médio. Base/dependência M0 integrada por ancestralidade:
`fdceea038ca72f34f03542909609583f44181647`. Branch `codex/map-editor-m1`,
checkout `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m1`.
O checkout inicialmente criado pelo app foi substituído por este worktree interno
à área autorizada de escrita e arquivado sem implementação. Houve detach
temporário do projeto habitual no mesmo HEAD durante a preparação; a referência
`codex/playtest` foi imediatamente restaurada, sem alteração de seus arquivos.
D1/D3 aprovadas; D2/D4 não são consumidores deste pacote. Sem alteração E07,
renderer, terreno/bake, solver, composição executável, catálogo ou perfil.

## Manifesto nominal e transferência

Sol possui exclusivamente os arquivos novos abaixo e seus `.gd.uid`:

- `scripts/map_authoring/document/source_document.gd`
- `scripts/map_authoring/document/source_schema.gd`
- `scripts/map_authoring/document/document_session.gd`
- `scripts/map_authoring/io/strict_json.gd`
- `scripts/map_authoring/io/source_store.gd`
- `scripts/map_authoring/io/headless.gd`
- `addons/ragrpg_map_editor/plugin.cfg`
- `addons/ragrpg_map_editor/plugin.gd`
- `addons/ragrpg_map_editor/shell.gd`
- `tests/map_editor_document_test.gd`
- `tests/map_editor_document_ui_test.gd`
- `tools/map_editor_document/run.ps1`
- `docs/map_editor/contracts/m1_dispatch.md`
- `docs/map_editor/delivery/m1.md`

Luna possui apenas `docs/map_editor/delivery/evidence/m1/luna.md` e logs sob
`docs/map_editor/delivery/evidence/m1/`. Sol registra evidências autorais nessa
mesma pasta antes da supervisão, sem escritores simultâneos. Nenhum outro arquivo
compartilhado é transferido. `project.godot` permanece sem plugin ativado por padrão;
o usuário pode habilitá-lo nas configurações do Godot. Fixture isolada o habilita.
UI permanece com M1 até transferência explícita para M2. Runner próprio evita
tomar propriedade de `tools/verify.ps1`; listar/verificar `editor_import` por impacto.

## Schema congelado e fronteira

JSON UTF-8 estrito, raiz fechada: `schema_version=1`, `document_id` técnico,
`revision` inteiro positivo até 2147483647, `units="e07_world"`, `name` pt-BR,
`dependencies`, `layers`, `special_surfaces`, `placements`, `regions`, `connectors`,
`sockets`, `composition`. As coleções são conjuntos por ID, exceto amostras,
vértices e demais sequências internas. Camada: `layer_id`, `name`, `origin_xz`,
`sample_spacing`, `columns`, `rows`, `heights`, `material_masks`, `locked`,
`protected_regions`. Grade entre 2 e 257 amostras por eixo, espaçamento positivo;
alturas finitas row-major z/x. Máscaras: mapa de ID de material para pesos 0..1,
com mesmo tamanho das alturas. Região protegida referencia `region_id` existente.

Dependência: `definition_id`, `revision`, `sha256`, `kind`. Superfície especial:
`surface_id`, `layer_id`, `vertices_xyz`, `headroom`. Região: `region_id`,
`layer_id`, `polygon_xz`, `purpose`. Placement: `placement_id`, `definition_id`,
`revision`, `position_xyz`, `rotation_y`, `surface_id`. Conector/socket:
respectivo ID, `surface_id`, `position_xyz`, `kind`; conector acrescenta
`normal_xyz`, `width`, `headroom`, `tags`, `direction`. Superfície editorial de
grade é referenciada pelo `layer_id`; IDs de superfície e camada são disjuntos.
Composição é null ou referência fechada `document_id`, `revision`, `sha256`,
sem consumir montagem M3. Sem seed/solver neste schema; migração futura exige
cópia e relatório, versões desconhecidas são recusadas.

Limites defensivos de leitura, não promessa de escala: 16 MiB, profundidade 32,
string 65536 caracteres, 2000000 tokens e 4096 entidades por coleção. Limites
serão exercitados com fixtures; não herdam 4 MiB de snapshot. Parsing/tipos/chaves
desconhecidas/versão excedidos são falha de leitura; documento estruturalmente
legível com duplicatas/referências/amostras inválidas é rascunho diagnosticado,
salvável e não publicável. Rejeição de operação deixa documento/histórico intactos.

Hash semântico v1: recursão com marcador de tipo e tamanho, strings escapadas JSON,
chaves ordenadas, coleções editoriais por ID, números finitos normalizados como
float64 little-endian hexadecimal (-0 normalizado para 0). Inteiros de revisão
limitados a faixa exata. Sequências preservadas. Não inclui caminhos/tempos.
Hash dos bytes é separado do hash semântico; edição externa compara bytes.

## API e provas de conclusão

Documento tipado `MapSourceDocument` encapsula dados por cópia; schema é autoridade
de leitura/diagnóstico/hash. Sessão tem undo/redo privado por snapshots; revisões
de conteúdo restauradas no undo, contador de geração monotônico evita ABA.
Store: load/save com hash esperado dos bytes, mutex por diretório criado atomicamente,
temporário validado, backup íntegro, rename
local, autosave separado e recuperação explícita (inclui base hash). Arquivo novo
espera ausência; nenhuma sobrescrita silenciosa. UI e CLI consomem essas APIs.
Operações retornam `ok/code/diagnostics/input_hash/output_hash` quando aplicáveis.

Provas: roundtrip incluindo tipos, ordem/hash Unicode/números, IDs e referências,
tipos/chaves/duplicatas/limites, arquivo truncado, desconhecido, edição externa,
falha de escrita, interrupção recuperável e retry; ações atômicas, undo/redo,
branch do histórico e rejeição sem mutação; shell real e lifecycle sem tocar
histórico global, CLI em processo novo. Inspeção visual com captura nativa.
Sem certificação de brush/bake, gameplay, escala ou usabilidade humana final.

Seleção consolidada: runner próprio exige 70 checks de documento e 40 de UI
headless (41 no gráfico, contando captura), além de import e processos CLI.
Supervisor termina um processo somente após sinal explícito de staging/autosave;
dois processos novos recuperam ambos para destinos ausentes e comparam hashes.
Interrupção deliberada tem flag própria e não é confundida com timeout/exit PASS.
CLI `apply` recebe fonte proposta e hash-base de bytes, usa a sessão para a mesma
validação/ação atômica, sem aceitar troca de identidade do documento.
