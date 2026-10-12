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
