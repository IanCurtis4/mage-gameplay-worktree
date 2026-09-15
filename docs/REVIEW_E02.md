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
- E02.2: presets legais por personagem, as cinco ativas e duas passivas
  contratadas, opções filtradas pelo catálogo/coleção, resumo de build, stats
  derivados sem fórmula duplicada e gravação transacional via `ProfileFacade`.
- E02.3: início explícito da run para o personagem selecionado, entrega do
  `RunState` à arena, barra/atalhos derivados da ordem das ativas equipadas,
  passivas existentes aplicadas somente quando equipadas, retorno terminal ao
  menu com `end_run`, e prevenção de sessão órfã no reinício/troca de classe.
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
de recuperação de estado. `e02_run_integration_test.gd` cobre o controller real:
ordem da barra/teclas do preset, passiva equipada, retorno terminal do Mago,
troca de personagem e retry de um fechamento que falhou.

## Limitação deliberadamente aberta

O controller agora usa o snapshot para disponibilizar somente as ativas equipadas,
na ordem do preset, e para condicionar as passivas já existentes. Isso não cria
novas fórmulas: ranks ainda não escalam poder/custo, alocações de atributos ainda
não alteram o ator e equipamentos continuam sem modificadores de combate. Esses
três pontos pertencem aos contratos centrais de E03/E06.

O modo direto de diagnóstico da arena continua usando o kit completo legado, sem
perfil persistente, para preservar os testes técnicos anteriores. Runs iniciadas
pelo menu não podem trocar classe dentro da arena: reiniciar ou escolher classe
fecha a sessão com confirmação e retorna ao menu de personagens.

## Revisão solicitada à Astra

1. Inspecionar o fluxo menu → run → resultado → menu em 1280×720 e uma janela
   de menor altura, conferindo rolagem, foco e legibilidade.
2. Confirmar que o personagem e a classe persistentes selecionados são os que
   chegam à arena, sem troca silenciosa de classe.
3. Confirmar o limite de escopo acima: ordem/eligibilidade de build em E02;
   progressão, fórmulas de ranks/atributos e efeitos de equipamento em E03/E06.
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
