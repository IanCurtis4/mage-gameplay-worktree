# Verificação incremental

Norma autorizada em 10/10/2026; fluxo e gates em [WORKFLOW.md](WORKFLOW.md).
`tools/verify.ps1` usa PowerShell 7 e Godot 4.7.2 standard. Execute a partir
do checkout que contém a mudança; saves de teste devem usar fixtures explícitas.

## Escolher a cobertura

- Mudança pequena: executar os testes diretamente afetados e a integração da
  fronteira alterada, quando necessária. Novas falhas justificam a regressão
  correspondente, não uma repetição automática de tudo.
- Regra nova: incluir invariantes. Runtime compartilhado, persistência,
  matemática ou integração ampla podem justificar ampliar a seleção ou executar
  a suíte completa; registrar o motivo.
- Edição documental: conferir coerência, links, precedência e diff. Fixture
  pontual: testar seus consumidores afetados. Não repetir a suíte inteira por
  essas edições se a evidência anterior continuar compatível.
- Fechamento: cumprir a cobertura contratada e a revisão independente. A norma
  não remove R1/R2, aceite humano ou testes necessários; permite compor evidências
  compatíveis e executar o delta necessário, sem repetir etapas por conveniência.

## Opções do runner

Sem filtros, a ordem e todos os comandos da suíte anterior são preservados.
Consulte a lista atual antes de escolher índices; adicionar testes pode movê-los.

| Opção | Comportamento |
|---|---|
| `-List` | Retorna o plano selecionado com `index`, `name` e `arguments`. Não inicia Godot, cria diretório ou modifica manifestos. Não precisa de `-GodotPath`. |
| `-Test <nomes/padrões>` | Lista PowerShell de IDs sem `.gd`, como `foundation_test`, ou padrões `e06_*`. União dos nomes/padrões, sem duplicatas e na ordem original. Cada padrão deve encontrar pelo menos uma etapa. |
| `-FromStep N` / `-ToStep N` | Intervalo inclusivo dos índices da lista completa. Limites omitidos significam primeira/última etapa. Com `-Test`, usa a interseção entre nomes e intervalo. |
| `-SkipEditorImport` | Remove `editor_import` da seleção, sem renumerar as outras etapas. Exige cache de importação compatível já validado. |
| `-GodotPath <arquivo>` | Obrigatório para executar; opcional ao listar. |
| `-VerificationDirectory <diretório>` | Logs e manifestos; padrão `.godot/verification`. Usar pasta nova por rodada para preservar evidência anterior. |
| `-CheckTimeoutSeconds N` | Limite por etapa, de 60 a 300 segundos; padrão 120, preservado. |

Os IDs especiais são `editor_import` e `smoke`. Uma seleção por nomes executa
**somente** os IDs selecionados; inclua `editor_import` quando precisar importar.
Um intervalo iniciado depois da etapa 1 também omite importação. O smoke não
implica importação nem os demais scripts.

Seleção vazia, padrão sem correspondência (mesmo junto de um nome válido),
intervalo invertido/fora da lista e interseção vazia falham antes de iniciar
Godot ou tocar evidências. A listagem não declara PASS. A execução parcial
informa quantas etapas selecionadas passaram, sem aprovar etapas omitidas.

```powershell
# Inspecionar tudo ou somente a seleção, sem engine nem execução.
./tools/verify.ps1 -List
./tools/verify.ps1 -Test 'e06_*' -List

# Seleção direta com cache de importação já compatível.
./tools/verify.ps1 -GodotPath $engine -Test 'foundation_test','smoke' `
    -SkipEditorImport -VerificationDirectory '.godot/verification/focused'

# Importar explicitamente e executar uma família de testes.
./tools/verify.ps1 -GodotPath $engine -Test 'editor_import','e06_*' `
    -VerificationDirectory '.godot/verification/e06_selected'

# Retomar a partir do primeiro índice ainda não validado; confira o plano antes.
./tools/verify.ps1 -FromStep $nextStep -List
./tools/verify.ps1 -GodotPath $engine -FromStep $nextStep `
    -VerificationDirectory '.godot/verification/resumed_tail'

# Executar tudo quando a análise de risco ou fechamento justificar.
./tools/verify.ps1 -GodotPath $engine `
    -VerificationDirectory '.godot/verification/full'
```

`$engine` é o caminho do executável aprovado; `$nextStep` vem da lista e dos logs
da rodada interrompida, não de uma contagem presumida. Para vários IDs, use uma
lista PowerShell como nos exemplos (por exemplo em `pwsh -Command` ou `.ps1`).

## Evidência e retomada

`plan.json` registra SHA de HEAD, estado sujo informado pelo Git, hashes do
runner/engine, timeout, filtros explícitos e todos os índices/comandos selecionados.
É plano, não prova de conclusão. `checks.jsonl` contém somente etapas concluídas
ou encerradas por timeout: `index` é o índice **original**, `execution_index`
a ordem desta rodada; inclui nome, argumentos, exit code, timeout/falha, caminhos
e hash do output. Os nomes dos logs também mantêm o índice original. Falha,
timeout ou `SCRIPT ERROR`/`Parse Error`/`ERROR` interrompem a execução como antes.

Retomar uma cauda não certifica o prefixo nem outras etapas omitidas. Para
reutilizar evidência, registrar no checkpoint SHA testado e SHA candidato,
diff relevante (inclusive alterações não commitadas), fixtures/recursos,
engine/importação e demais inputs compatíveis, além de caminhos/hashes dos logs.
Mudança documental pode conservar os inputs executáveis; mudança de fixture
invalida a evidência dos consumidores afetados. Rebase/conflito ou alteração de
runtime exige avaliar novamente essa compatibilidade e testar a fronteira atingida.

O runner não decide compatibilidade automaticamente: HEAD sozinho não identifica
uma árvore suja, e uma lista de arquivos modificados não guarda seus conteúdos.
Preservar o diff/inputs usados e explicar a cobertura composta. Não sobrescrever
o recibo antigo nem somar contagens sobrepostas como novas provas independentes.
