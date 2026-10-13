# Autoria de conteúdo E06

Sol define a receita; Luna cria o nome e o flavor. A descrição de efeitos vem da receita validada e permanece separada da narrativa.

## O que cada pessoa edita

| Campo | Dono | Regra |
|---|---|---|
| ID, origem, qualidade, nível, posição/mãos/encaixes, compatibilidade | Sol | Identidade e elegibilidade estáveis; nunca derivados do nome |
| Stats, efeito/handler, curva, rank, cap, conflito e família | Sol | Reusar autoridades e adaptadores executáveis; sem código em texto |
| Base de mob, ficha fixa, ligações carta/espécie e conjunto/peças | Sol | Dados reais e referências coerentes |
| Função e limites da ficha | Sol | Explicar a decisão de combate e o que a narrativa pode sugerir |
| `name` | Luna | pt-BR, uma linha, até80 caracteres |
| `flavor` | Luna | pt-BR, uma linha, até220 caracteres; imagem narrativa sem prometer novo efeito |
| `description` | Gerado por Sol | Números/curvas/caps e requisitos de execução; não é campo do JSON editorial |

O pacote demonstrativo contém24 fichas:14 posições, foco/duas mãos alternativos, conjunto, duas espécies com respectivas cartas e três augments. Os números são exemplos de contrato, não balanceamento nem fórmula de poder. Não estão nos diretórios carregados pelo jogo.

## Arquivos

- [demo_preview.md](demo_preview.md): leitura dos24 nomes, efeitos e flavors lado a lado.
- [demo_briefs.json](demo_briefs.json): ficha racional e descrição factual de cada entrada. Só Sol altera.
- [demo_texts.json](demo_texts.json): população criativa realizada por Luna. Só `name` e `flavor` são editáveis; preservar envelope, digest e chaves.
- `tools/content/demo_bundle.gd`: gera os Resources de exemplo. É uma fixture explícita, não o catálogo de produção.
- `ContentAuthoring.prepare(entries)`: valida os Resources e gera fichas/template e assinatura mecânica.
- `ContentAuthoring.compile_bundle(entries, texts, require_complete)`: devolve cópias com nome/flavor e descrição factual gerada, usando os mesmos catálogos/validadores do jogo.

A assinatura inclui todos os campos mecânicos exportados, inclusive efeitos aninhados, tags, restrições e referências. Textos/ícone são excluídos; a ordem das entradas não altera a assinatura. Mudança real de números/IDs deixa o editorial antigo pendente de reconciliação por Sol. Nenhum nome exibido muda a identidade de um efeito exclusivo.

A compilação rejeita campo inesperado, ID desconhecido, assinatura antiga, versão errada, texto ausente/excessivo/controle de linha e receita inválida. Equipamento passa também pela validação de exemplares e qualidade; mob/carta precisa de ligação coerente; conjunto precisa de posições suficientes em uma identidade disponível. A validação estrutural não procura todas as combinações de uma build: builds concretas continuam sendo compostas/testadas pelas autoridades existentes.

## Preparação e prévia

Com Godot4.7.2 standard, na raiz desta worktree:

```powershell
& '<Godot autorizado>' --headless --path . --script res://tools/content/preview.gd -- --prepare
& '<Godot autorizado>' --headless --path . --script res://tools/content/preview.gd
```

Preparar regenera as fichas, preservando o arquivo de textos quando ele já existe. Caso a assinatura mude, Sol reconcilia o lote; a ferramenta não apaga trabalho criativo.

A prévia exige as24 entradas completas e grava Resources nativos/manifesto apenas em `.godot/content_authoring/preview_*`. Recarregar esses Resources conserva mecânicas e os três campos de prosa. Essa saída não publica catálogo nem configura loot. `ready` significa editorial completo e pacote estruturalmente válido; não é aceite de balanceamento ou autorização de produção.

## Como ampliar com controle

1. Sol escolhe um lote mecânico com função, compatibilidades e casos de aceitação claros.
2. Sol cria/carrega Resources e fecha seus handlers/caps/IDs/referências. Validadores são os existentes; handler novo volta a um pacote Sol.
3. Sol gera ficha e template. Luna recebe somente o lote e os campos de texto autorizados.
4. Luna preenche nomes/flavor, sem ajustar mecânica para combinar com uma história.
5. Luna acompanha testes; falha mecânica volta a Sol. Stats/regras capturadas devem coincidir antes/depois da população.
6. Sol valida exemplos/builds relevantes, revisa coerência e integra o lote autorizado. Habilitar produção é uma etapa explícita, posterior a esta base.

Para T3 final ainda faltam orçamento/poder/tuning, taxas, contagens e cobertura de conteúdo, taxonomias adicionais e20 builds/10 identidades. Esta base não resolve essas decisões por placeholders. UI14, arte/chapéus, campanha/boss AI, playtest e merge permanecem fora do pacote.

## Piloto no ilvl 1 (T3-B)

`tools/content/pilot_bundle.gd` fixa as63 receitas do piloto, mantendo os12 IDs/metadata de equipamento e cinco augments históricos. Valores de receita são tuning manual explícito, sem multiplicador por ilvl/qualidade. Recursos de exemplo da T3-A continuam separados; o piloto não substitui o catálogo ativo.

`tools/content/pilot.gd -- --prepare` gera pilot_briefs.json e cria pilot_texts.json somente se ausente. Nunca sobrescreve população existente. Se a mecânica mudar, o digest muda; o autor deve transferir nova ficha e reconciliar o envelope/textos conscientemente. O comando sem argumentos compila o documento completo, gera pilot_builds.json e63 Resources nativos em `.godot/content_authoring/pilot_*`, com manifesto e production_published=false. O diretório não é consumido pelo loader do jogo.

[Prévia legível do piloto](pilot_preview.md) reúne descrição factual gerada e flavor Luna. [Comparações](pilot_builds.json) guardam20 seleções legais, metadados de aprendizado/equipamento/encaixe e capturas/stats calculados pelos serviços existentes. composition_valid não significa tactical_validated: o relatório declara explicitamente que a validação tática de T3 continua pendente. Não usar contagem de linhas ou mudanças numéricas como prova de novas decisões de combate.

Os novos efeitos de proc direcionado incluem as habilidades alvo na descrição factual. Curvas completas, caps e ranks permanecem na ficha; nome/flavor jamais definem execução. Específicos de Foco, ecos, armadilhas e geometria não são gerados a partir de tags. Qualquer transformação futura exige contrato/handler executável antes da população.

## Duas políticas espaciais aprovadas

`tools/content/spatial_bundle.gd` acrescenta somente spiritualist_echo_fixed_origin e geometer_ground_anchor ao bundle anterior, sem editar suas63 entradas. Os handlers de política são fechados e restritos a augment/uma aquisição/evolução correta; não reutilizar a nova capacidade em cartas/equipamentos/conjuntos por suposição.

`tools/content/spatial.gd -- --prepare` gera spatial_briefs.json e, somente se ausente, cria spatial_texts.json copiando os63 name/flavor anteriores. Luna só preenche os2 novos. O comando sem argumentos valida/completa, gera spatial_builds.json e65 Resources em `.godot/content_authoring/spatial_*`, sem publicar no loader ativo. `pilot_*` continua preservado; as comparações A de Espiritualista/Geômetra passam a incluir o modo espacial no novo relatório.

[Prévia legível](spatial_preview.md) explica os resultados observáveis. O compositor/capturas guardam kit_policies por valor; ondas e reservas seguem suas capturas depois da retirada do augment. Não tratar políticas como modificador numérico, proc de arma ou autorização de outros4 efeitos da proposta. Os valores de dano/cadência/progressão/rates continuam com suas autoridades anteriores.

## Quatro transformações restantes

`tools/content/transform_bundle.gd` conserva as 65 receitas espaciais e acrescenta quatro políticas de kit aprovadas. `tools/content/transform.gd -- --prepare` gera fichas e cria o envelope editorial somente se ausente, copiando as 65 células antigas; execução sem argumentos valida editorial, gera `transform_builds.json` e 69 Resources em `.godot/content_authoring/transform_*`. Os bundles anteriores e o loader ativo não são reescritos.

Luna edita somente os quatro nomes/flavors. Pré-requisitos dos adapters fechados ficam em BuildEffectCatalog, sem propriedades exportadas novas. Inscrição requer Drenagem+Maldição; mecanismo requer Marca+uma armadilha afetada; Colapso requer sua ativa+Triangulação. O compositor ativa somente a política útil de rank legal. [Prévia legível](transform_preview.md) e [checkpoint](../../docs/epics/e06/e06_transform_remaining.md) registram os comportamentos e limites.

## Vinte direções de combate

`tools/content/directions_bundle.gd` usa as mesmas 69 receitas e cria vinte blueprints com compras/slots de preparação legais. `tests/e06_directions_test.gd` gera `directions_execution.json` somente após confirmar todos os casos reais. `tools/content/directions.gd` verifica digest e igualdade dos blueprints observados antes de gerar `directions_builds.json` e Resources nativos separados. Não passa a integrar o loader ativo.

[Prévia das decisões](directions_preview.md). `direction_decisions_validated` indica prova dirigida dos caminhos; `tactical_validation_pending`, equilíbrio, desempenho e playtest humano continuam separados. Os resultados antigos de `pilot_*`, `spatial_*` e `transform_*` permanecem preservados.
