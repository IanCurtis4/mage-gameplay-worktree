# Intercâmbio com skills — F7 / M7

Contrato1: [dispatch](contracts/m7_dispatch.md). Fonte executável:
`scripts/map_authoring/exchange/exchange.gd`; cinco schemas/compiladores dos
produtores, sem nova fórmula/runtime ou writer de perfil.

## Autoria e revisão

Em Peça, Composição, Encontros, Patrulhas ou Geração assistida, abra
**Intercâmbio com skills…**. Escolha as áreas permitidas no menu e, se necessário, restrinja IDs, caminhos
protegidos e máximo de diferenças. Escreva
o brief e exporte o pedido `.rpx` para caminho novo. O default permite só nome;
para geração, o default permite Seed. É permitido exportar somente fonte compilável.
Guardar o pedido original localmente é a referência confiável de autorização.
A skill recebe uma cópia e devolve outro `.rpx`; ela não devolve um pedido novo
para substituir o original confiável. Se reabrir o editor, use **Abrir pedido
confiável…** no original guardado por você, depois **Importar proposta…**.

O diff identifica caminho, entidade, operação e valores antes/depois. Clique numa
linha para inspecionar os valores; abas Antes/Proposta mostram a geometria dos
mesmos compiladores. Encontros/patrulhas mostram o mapa de suporte; o diff contém
todos os slots/rotas, mas essas abas não simulam combate/patrulha. Testes de atores
continuam na tela do produtor. A miniatura é a prévia local reconstruída, sem
importar mídia. **Aplicar proposta…** exige confirmação e faz uma ação no histórico
da tela de origem. Desfazer/refazer e salvar continuam nela. Fechar/cancelar/rejeitar
não altera a autoria; o original exportado continua disponível em disco.

Se a fonte mudar durante a validação ou antes do commit, o editor recusa stale.
Uma fonte diferente da base recebe `base_diverged`; não há merge automático.
Reconciliar significa revisar as mudanças humanas, exportar novo pedido e obter
nova proposta. Repetir proposta já aplicada é no-op sem nova ação de undo.
Não há publicação por importação. A geração importa o pedido e valida seu mapa,
sem executar/ativar WFC; gerar variantes continua sendo uma ação explícita F6.

## CLI compartilhada

Prefixo: `Godot --headless --path <checkout> --script
res://scripts/map_authoring/exchange/headless.gd --`. Operações:

- `export <kind> <fonte.json> <permissoes.json> <pedido.rpx>`
- `propose <pedido.rpx> <candidate.json> <proposta.rpx>`
- `review <pedido.rpx> <proposta.rpx> <fonte_atual.json>`

Kinds: `piece`, `map`, `population`, `patrol`, `generation`. Arquivo de permissões:
`{"sections":["name"],"ids":[],"protected_paths":[],"max_changes":256}`.
Fonte de peça ganha revisão base+1 na proposta alterada para coincidir com a
sessão M1. Outras fontes conservam sua regra de revisão existente.
Ao alterar encontros, o `plan_hash` precisa corresponder à receita canônica
`PopulationDocument.recipe_hash`; inclua a seção Plano realizado na permissão.
Não recalcular slots por inferência: preparar nova população é a operação explícita M4.

CLI emite `MAP_EXCHANGE_RESULT` com ok/code/hash e diff quando review; termina
com código1 em falha. Propose não aplica nem publica. Saídas devem usar caminho
novo; conflito ou `.pending` interrompido é explícito, sem sobrescrever original.

## Formato e segurança de dados

JSON UTF-8 estrito, exchange_version1/revision map_exchange_v1, ticket completo
com kind/schema-base/compilador/permissões/brief/corpus/base, ticket_hash,
source_hash, files e bundle_hash. Exatamente dois nomes virtuais:
`source.json` e `report.json`, cada um com sha256 e data incorporados. Nenhum nome
é aberto, extraído ou interpretado como Resource. Só os schemas fechados podem
ser compilados; scripts/cenas/binários e entradas extras são recusados. Dependências
materiais e hashes de catálogo/políticas são os resolvidos pelos compiladores locais;
report inclui suas identidades e hash compilado, revalidados ao importar.
Não incluir saves, secrets ou paths da máquina no brief/fonte.

`sha256` dos elementos é SHA256 da representação canônica de dados do projeto
(não dos bytes JSON indentados); bundle_hash exclui só a própria chave.
Não são assinatura, identidade de remetente ou canal de confiança. A segurança
de permissões depende de guardar o pedido local original. A proposta precisa
ter ticket idêntico; alterações de permissões são recusadas mesmo com hash recalculado.

Diff usa `/colecao/@id/campo` para entidades e valores completos para arrays
numéricos/ordenados. IDs opcionais restringem a entidade alterada; mudanças em
campos globais não têm entidade e são recusadas quando IDs estão restritos.
Caminhos protegidos usam esse mesmo formato. Camadas travadas ou com regiões
protegidas preservam a camada inteira conservadoramente; regiões referenciadas,
slots fixos e placements de pins são protegidos, inclusive remoção da trava.
Essa política não promete uma máscara espacial de permissões subcamada.

Limites do leitor comum:16MiB, profundidade32, string65536,2000000 tokens; brief8192,
corpus32 seeds signed64 textuais,32 seções,128 IDs/caminhos,2048 diferenças.
Cada compilador conserva seus budgets e limite de pacote. Export/report não
certifica desempenho nos tetos nem conteúdo de release limpo (F8). Importar não
muda catálogo, política, save pessoal ou versões imutáveis já publicadas.

As fontes versionadas de mapdelivery/enemydelivery/art apontam para este fluxo;
cópias instaladas permanecem preservadas. Supervisão, recibo e limites:
[entrega F7](delivery/m7.md).
