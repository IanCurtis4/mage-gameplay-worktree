# Editor F0 / M0 — preparação contratual v0.2

24/10/2026. **CONTRATO CANDIDATO; hospedagem validada em prova isolada.** A decisão
humana posterior retirou a espera de integração/encerramento E07. D1/D3 foram
aprovadas neste chat. O schema exato continua com M1; D2/D4 com seus consumidores
M2. Não inicia M1 automaticamente. Recibo e propriedade:
[M0](../delivery/m0.md). Fontes: [arquitetura](../architecture.md),
[execução](../execution.md), [validação](../validation.md) e
[WORKFLOW](../../WORKFLOW.md).

## Base observada e reconciliação

| Referência | SHA completo observado | Uso permitido nesta preparação |
|---|---|---|
| `codex/playtest` | `fba777b3822356a10e7f6e050971e54ab1a9819b` | Leitura de autoridades; não é base futura de prova |
| `codex/e07-f8` | `26004852d2455c6f1a57fb603eadcbcaa4f38cfa` | Leitura de deltas e checkpoint; não declara integração |
| `master` | `8df3a67a21f26ff69249eadfc29d3d78eee8842e` | Referência aceita histórica; sem merge autorizado |

O merge-base F8/playtest é o próprio SHA observado de playtest. F8 tem correções
posteriores de continuidade assíncrona, rampa, seleção, viagem e oferta de
augments. Seu checkpoint mais recente ainda registra aceite humano/merge
pendentes e projeto habitual não atualizado nesta rodada. SHA de branch sozinho
não comprova encerramento de E07, que deixou de ser gate por decisão humana.
A prova de hospedagem usa projeto mínimo independente sobre base explícita,
sem inicializar jogo ou exigir o aceite da amostra; outra prova de runtime
reconsulta os registros e valida apenas as autoridades consumidas.

O diff entre essas duas refs não altera os diretórios de geração, geometria,
modelo, população, definições de expedição ou `enemy_actor.gd` inventariados
abaixo. Isso é evidência estática dessas fronteiras, não certificação dinâmica.
Snapshot, serviço, posse e apresentação têm deltas; não reutilizar suposições
antigas de durabilidade síncrona. O catálogo imutável permanece protótipo opt-in
com resultado negativo de desempenho; não ativá-lo para o editor por inferência.

## Inventário verificável de autoridades

| Arquivo / API existente | Fronteira contratual do editor |
|---|---|
| `scripts/data/expedition/part_definition.gd`: `ExpeditionPartDefinition.to_data()` | Saída compilada com superfícies, conectores, sockets, sólidos e blockers; não preserva controles de autoria |
| `scripts/data/expedition/surface_definition.gd` | Célula convexa planar, vértices 3D e headroom; terreno curvo deve ser particionado em células válidas |
| `scripts/data/expedition/connector_definition.gd` | Superfície, posição, normal, largura, headroom, kind/tags/direction; a emenda visual não muda esses limites |
| `scripts/core/expedition/model/generation_input.gd`: `ExpeditionGenerationInput.to_data()` | Seed textual, revisões, hashes, partes/policies/species, grafo e população; não receber campos editoriais extras |
| `scripts/core/expedition/generation/input_validator.gd`: `ExpeditionInputValidator.validate(input)` | Schema fechado antes da busca; o adaptador compila para ele |
| `scripts/core/expedition/generation/assembler.gd`: `ExpeditionAssembler.build(input)` | Revisão observada `f0_convex_cells_v1`; não oferece posicionamento manual arbitrário/pins fixos |
| `scripts/core/expedition/spatial/world_geometry.gd`: `configure`, `support_at`, `position_query`, `path`, `sweep`, `query_attack`, `resolve_surface` | Autoridade única para suporte, navegação, corpo, ataque e seleção; exige revisão corrente |
| `scripts/core/expedition/population/population_planner.gd`: `ExpeditionPopulationPlanner.build(manifest, catalog, rules)` | População passa pelo catálogo/regras e corpo/rota reais; brush novo não substitui essa validação |
| `scripts/actors/enemy_actor.gd` | Engajamento/home/leash/retorno existentes; patrulha autorada continua M5 |
| `scripts/core/content_authoring.gd`: `ContentAuthoring.prepare`, `compile_bundle` | Conteúdo editorial existente; não é compilador de mapas |

Fronteira F8 a reler se consumida na base escolhida: `AsyncExpeditionSession`, writer/pump,
sampler, `ExpeditionService`, codecs e apresentação. Um preview futuro usa a
autoridade entregue; não cria writer, ACK fictício ou perfil pessoal. Publicar
conteúdo não é confirmar progresso durável da expedição.

## Decisões humanas ainda necessárias

| ID | Proposta para decisão | Consequência concreta / prova necessária |
|---|---|---|
| D1 | Plugin interno Godot com tela própria; alternativa: aplicativo dedicado | Plugin requer Godot instalado e lifecycle `@tool`; dedicado requer distribuição e shell próprios. Provar carregar/descarregar/recarregar sem autoloads de gameplay e sem referências órfãs |
| D2 | Primeiro medir apresentação F8 corrigida; comparação híbrida somente se autorizada | Escolher renderização/material/oclusão após capturas equivalentes e custo. Uma hipótese 3D não autoriza conversão do jogo ou produção de assets |
| D3 | Grade de alturas por camada, com superfícies especiais de ponte/rampa; alternativa: malha livre | Grade facilita brushes e validação; malha livre amplia edição/topologia. A saída continua células convexas planares e conexões válidas |
| D4 | Clareira, platô, rampa, passagem sob ponte, duas peças e um encontro | Dimensões, resolução, hardware e budgets ficam pendentes de medição. Não herdar escala/quota da amostra F7 |

D1 aprovada: tela própria no Godot. D3 aprovada: grade de alturas por camada,
com pontes/rampas especiais. As alternativas da tabela ficam como justificativa
da decisão. D2 antecede bake visual M2; D4 antecede aceite M2, com medição do
terreno quando existir implementação. M0 conclui sua fronteira após prova de
hospedagem e encaminhamento dessas pendências; não inventa dados de brush/bake.
D5/D6 continuam com seus consumidores.

## Contrato de fonte candidato, independente da hospedagem

O schema exato será congelado em M1 após decisões e prova M0. Esta proposta
define campos e regras para discussão; não existe leitor/compilador implementado.
IDs são strings técnicas estáveis; nomes visíveis ficam em pt-BR. Coordenadas
usam unidades do mundo E07: x/z horizontais, y altura. Não converter para metros
ou pixels implicitamente. Revisões são inteiros positivos; seed signed64 é texto
decimal canônico, incluindo extremos negativos, sem conversão via float.

| Estrutura candidata | Campos / restrições |
|---|---|
| Raiz `MapSourceDocument` | `schema_version`, `document_id`, `revision`, `units`, `dependencies`, `layers`, `special_surfaces`, `placements`, `regions`, `connectors`, `sockets`, `composition` |
| `dependencies` | Lista de `definition_id`, `revision`, `sha256`, `kind`; IDs/revisões devem resolver catálogo autorizado; sem paths locais absolutos |
| `layers` se D3 aprovada | `layer_id`, `origin_xz`, `sample_spacing`, `columns`, `rows`, `heights`, `material_masks`, `locked`, `protected_regions`; alturas row-major por z, depois x; número exato `rows*columns` |
| `special_surfaces` | `surface_id`, `layer_id`, `vertices_xyz`, `headroom`; não inferir conexão por sobreposição visual; serialização final depende de D3 |
| `placements` | `placement_id`, referência de definição/revisão, transformação autorizada e âncora com superfície; mover conserva ID, duplicar cria ID |
| `regions` | `region_id`, `layer_id`, polígono x/z e finalidade declarada; futuro brush populacional não vira ator nesta versão |
| `connectors` / `sockets` | IDs editoriais, âncora e campos compiláveis reais; conexão/slot precisa resolver superfície após bake |
| `composition` | `null` para peça isolada; documento separado para instâncias e vínculos, contratado em M3 antes de pins/placement fixo |

Fonte inválida pode ser salva como rascunho, com diagnósticos. Versão desconhecida,
JSON malformado, chave duplicada ou limites de leitura excedidos não são fonte
carregável: leitura falha sem substituir documento corrente. Campos desconhecidos
não são descartados silenciosamente. Parser precisa detectar duplicatas antes
que um Dictionary as colapse. Rejeitar NaN/Inf, IDs duplicados, referências
quebradas, contagens divergentes e tipos errados. Limites numéricos de leitura
(bytes, profundidade, strings, entidades) exigem prova M0, sem reutilizar 4MiB
do snapshot como limite de fonte.

Identidade independe de ordem de array/memória/NodePath. Operações de exclusão
apontam dependentes; duplicação remapeia referências internas. Ordem de traços,
vértices e waypoints tem significado e não pode ser ordenada como conjunto.
Migração cria cópia versionada e relatório; mantém original recuperável.

### Exemplo estrutural candidato de peça vazia

```json
{
  "schema_version": 1,
  "document_id": "clearing_sample",
  "revision": 1,
  "units": "e07_world_units",
  "dependencies": [],
  "layers": [],
  "special_surfaces": [],
  "placements": [],
  "regions": [],
  "connectors": [],
  "sockets": [],
  "composition": null
}
```

Exemplo de rascunho vazio, não pacote publicável. Com D3 aprovada, fixture mínima
adiciona uma grade 2x2 de alturas zero; fixture adversa usa três alturas para
quatro amostras. Outras negativas: versão2 sem leitor, dois `layer_id` iguais,
conector apontando superfície ausente e JSON com duas chaves `revision`.
Nenhuma dessas fixtures foi executada; os oráculos são especificados antes do código.

## API candidata e erros

Todas as operações retornam `ok`, `code`, `diagnostics` e `input_hash`. Sucesso
acrescenta saída tipada e `output_hash`; falha não publica pacote parcial.
Diagnóstico: `code`, `severity`, `entity_id`, `field`, `location` opcional com
superfície/posição, `message` em pt-BR e `suggestion`. Falha de parse pode não ter
`input_hash` semântico; conservar digest dos bytes recebidos em campo separado.

| Operação proposta | Entrada / saída e fronteira |
|---|---|
| `validate_source(source, target_profile)` | Resultado sem mutação; distingue rascunho legível de publicável |
| `compile(source, dependencies, target_profile, cancellation)` | Pacote com `source_hash`, revisão do compilador e dependências; job vinculado a revisão/hash da fonte |
| `validate_package(package, target_profile)` | Valida integridade, capacidades, geometria canônica e compatibilidade; não instala em perfil |
| `preview_composition(composition, packages, seed_text, target_profile)` | Manifesto realizado e diagnósticos; M3 deverá contratar adaptador para placement fixo |
| `export_bundle(package, destination)` | Escrita em staging e publicação atômica local; exige dono/revisão esperados do destino |
| `import_proposal(bundle, base_hash, allowed_operations)` | Clone com diff/diagnósticos, sem aplicar à fonte; confirmação vira uma ação desfazível |

Namespaces propostos: `source_parse_error`, `source_duplicate_key`,
`source_version_unsupported`, `source_limit_exceeded`, `source_invalid_type`,
`source_duplicate_id`, `source_reference_missing`, `source_non_finite`,
`dependency_missing`, `dependency_hash_mismatch`, `capability_unsupported`,
`geometry_invalid`, `route_unreachable`, `snapshot_limit_exceeded`, `cancelled`,
`stale_source`, `base_diverged`, `unsafe_bundle_path`, `io_conflict`, `io_failure`.
Não renomear códigos do runtime: diagnóstico de adaptador guarda o código original
e contexto. Os nomes acima são proposta de editor, sem registro no runner.

Hash semântico deve excluir timestamps/caminhos da máquina e incluir todo campo
que afete compilação. Ordenar apenas coleções declaradas como conjuntos; preservar
sequências. Antes de congelar, escolher codec canônico e oráculos independentes
para float finito, -0, UTF-8, números equivalentes e catálogo reordenado. Não
prometer equivalência por `JSON.stringify` ou formatação textual incidental.
Cache usa fonte+compilador+dependências+perfil-alvo. Resultado de job obsoleto é
descartado; cancelamento não publica. I/O de fonte e perfil são autoridades distintas.

## Prova delimitada preparada, ainda não executável

Sem exigir integração E07, resolver SHA completo e checkout isolado, registrar branch
`codex/map-editor-m0`, engine4.7.2/hash, proprietário nominal de cada probe,
cena/`.uid` e relatório. Não editar `project.godot`, runner, runtime, catálogos
ou UI compartilhada sem concessão nominal. Arquivos de probe ficam sob
`tools/map_editor_probe/` somente após esse dispatch. Esta preparação não cria
plugin de produção ou consumidor M1; a prova pode criar projeto mínimo isolado.

1. Hospedagem: ciclo habilitar/abrir/fechar/desabilitar/reabrir/reload, foco,
   uma ação undo/redo, cleanup e dependências transitivas. Detectar acesso
   involuntário ao perfil ou inicialização de gameplay. Repetir em processo novo.
2. Geometria: peça plana, rampa e ponte com passagem inferior; comparar saída
   compilada com `WorldGeometry` real, suporte contínuo, raio/headroom e LoS.
   Negativas: rampa sem conexão, célula não planar, conector estreito e saída
   inacessível. Um renderer novo só entra mediante autorização D2 específica.
3. Determinismo: mesma fonte/dependências em processos separados e coleções de
   IDs reordenadas; seeds zero, negativo e extremos signed64 textuais. Alterar
   um controle deve invalidar hash/cache; cancelamento/retorno tardio não publica.
4. Medição: cenários pequeno, representativo e estresse, aumentando uma dimensão
   por vez. Registrar hardware/viewport, área, resolução, células, triângulos,
   props, conectores, população total/ativa e bytes fonte/pacote/snapshot.
5. Tempos frio/quente: load, preview/brush, bake completo/incremental, cancelamento,
   geração/path, frame e save/capture separados. Registrar n e todas as amostras;
   p50/p95/máximo apenas com amostragem justificada, sem prometer60FPS.
6. D1/D3 aprovadas; consolidar D2/D4 com usuário após resultados dos respectivos
   produtores, budgets e limites observados, sem bloquear o shell M1 por herança.
   Luna supervisiona seleção por impacto, conclusão/erros/timeouts/hashes somente
   quando existir candidato executável; Sol mantém implementação e validação.

É esperado encontrar capacidades ainda ausentes de M1/M2. Nesse caso o probe
mede somente a fronteira existente ou stub explicitamente isolado; não declara
brush, compilador incremental ou editor completo testados. Lista de testes
reais será obtida por `tools/verify.ps1 -List` na base futura, antes da seleção.
M0 não toma a propriedade das correções de F8 nem inicia M1–M8.

## Resultado e encaminhamento vigentes

Prova delimitada de hospedagem executada no Godot4.7.2 standard: lifecycle,
foco, Resource `@tool`, histórico/undo/redo, reabertura em processos novos e
ausência do plugin no runtime. Ver [recibo](../delivery/m0.md). Não inclui hot
reload de código, editor funcional, brush/bake, escala ou gameplay E07.
D1/D3 aprovadas; schema/limites de leitura são congelados em M1 com fixtures,
D2/D4 nos prazos M2. M1 deve isolar histórico do documento sem limpar ações
globais alheias do Godot. Não copiar o driver de prova para produção.

Direção humana adicional de [composição e emendas](map_composition_and_seams.md)
integra o contrato: edição de peças e mapas completos, vínculos explícitos,
barreiras por bioma e escolha manual/algorítmica. Sua implementação pertence
a M2/M3/M6 conforme o documento, mantendo referência e IDs estáveis desde M1.

APIs Godot consultadas como apoio, além da prova local:
[EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html),
[EditorInterface](https://docs.godotengine.org/en/stable/classes/class_editorinterface.html) e
[EditorUndoRedoManager](https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html).
Documentação stable não certifica outra versão; evidência executável é4.7.2 local.
