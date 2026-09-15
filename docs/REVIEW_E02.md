# Revisão técnica e playtest — E02

## Identificação

- Épico: E02 — Menu de personagem e build inicial.
- Branch candidata: `codex/e02-character-menu`.
- Base aprovada: `7fdecdd` (E01 integrado em `master`).
- Estado: candidato técnico preparado; ainda requer revisão integrada da Astra e
  playtest do usuário antes de qualquer merge em `master`.

## Escopo entregue

- E02.1: menu inicial com lista de alts, criação de Espadachim/Mago, seleção
  persistente e estados vazio, erro e somente leitura.
- E02.2: presets legais por personagem, opções filtradas pelo catálogo/coleção,
  resumo de build, stats derivados sem fórmula duplicada e gravação transacional
  via `ProfileFacade`.
- E02.3: início explícito da run para o personagem selecionado, entrega do
  `RunState` à arena, retorno terminal ao menu com `end_run`, e prevenção de
  sessão órfã no reinício.
- Usabilidade: o editor usa rolagem vertical e o botão de iniciar a run permanece
  visível; textos de sucesso e erros acionáveis estão em pt-BR.

## Evidência automatizada

Executar no candidato:

```powershell
& .\tools\verify.ps1 -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\review-engine\Godot.exe' -SkipEditorImport
```

A suíte cobre criação/seleção, presets, estado somente leitura, layout do menu,
persistência, snapshot de run, fechamento de sessão, arena e HUD. O teste
`e02_character_menu_test.gd` cobre também a ação de iniciar visível e os textos
de recuperação de estado.

## Limitação deliberadamente aberta

O snapshot persistente já carrega `skill_ranks`, `active_slots`, `passive_slots`
e `equipped`, mas a arena piloto ainda usa o kit completo definido em
`ClassCatalog`. Assim, alterar um preset hoje é durável e chega ao `RunState`,
mas ainda não restringe a barra/teclas nem altera os efeitos de passivas ou
equipamentos durante o combate.

Isso não deve ser escondido como efeito concluído: E02 proíbe inventar gameplay,
enquanto a aplicação canônica de progressão, ranks e stats pertence a E03 e os
efeitos de equipamentos pertencem a E06. A Astra deve confirmar que o handoff
de build é suficiente para encerrar E02 ou registrar um pacote estreito adicional
com o contrato de cinco ativas e duas passivas do E00.

## Revisão solicitada à Astra

1. Inspecionar o fluxo menu → run → resultado → menu em 1280×720 e uma janela
   de menor altura, conferindo rolagem, foco e legibilidade.
2. Confirmar que o personagem e a classe persistentes selecionados são os que
   chegam à arena, sem troca silenciosa de classe.
3. Confirmar o limite de escopo acima: persistência/handoff de build em E02;
   enforcement de combate, progressão e efeitos de equipamento em E03/E06.
4. Se aprovado tecnicamente, rebasear a branch candidata, repetir as verificações
   e avançar `codex/playtest` por fast-forward, preservando alterações locais do
   usuário no projeto fixo.

## Roteiro de playtest do usuário

1. Abra o projeto fixo após a preparação do candidato e pressione F5.
2. Crie um Espadachim e um Mago, alterne a seleção e os presets disponíveis.
3. Confirme que o botão “Iniciar run com este personagem” permanece acessível
   com o editor rolado.
4. Inicie uma run de cada classe, termine por vitória ou morte e use “Voltar ao
   menu de personagens”.
5. Confirme que o menu preserva o personagem escolhido e que não há uma run
   pendente impedindo uma nova tentativa.

Este relatório não é aceite técnico nem aprovação de produto.
