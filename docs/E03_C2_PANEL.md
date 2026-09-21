# E03-C2 — Painel e árvore de progressão

Estado: **entregue em `f0d1aeb`, `7a79830`, `c1d1d40` e no fechamento C2-D**.

## Resultado

O menu de personagens apresenta, para o personagem em foco, XP e níveis base/job,
estado de evolução, as três carteiras, seis atributos e a árvore de skills. A
interface consome somente `ProfileFacade.progression_summary`,
`ProfileFacade.progression_skill_options` e `ProfileFacade.build_preview`.
Valores efetivos de atributo vêm de `StatBreakdown`; a UI não reproduz curvas,
custos, ranks ou requisitos.

Cada atributo oferece investimento unitário e respec; cada skill expõe rank,
carteira, requisitos e compra apenas quando a projeção autoritativa permite. Os
respecs passam pelas transações da fachada. Falha definida de gravação conserva o
mesmo `request_id` e revisão para o próximo clique da mesma ação.

Estados vazio, perfil indisponível/somente leitura e run ativa têm mensagens em
pt-BR. Durante run, o painel permanece consultável e ações de progressão ficam
desabilitadas. Tooltips não afirmam poder, custo ou efeito por rank: essas tabelas
continuam em E04.

## Evidências

`tests/e02_character_menu_test.gd` cobre painel de leitura, personagem correto,
estados, ações de atributo/skill, requisitos, respec e retry. O teste integrado
`tests/e03_progression_panel_integration_test.gd` cobre painel → atributo/rank →
reload → preview/snapshot de run.

Verificação final:

```powershell
./tools/verify.ps1 -GodotPath `
  'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe'
```

## Limites

- Não há tabela de poder, custo, cast ou efeito por rank; isso permanece E04.
- Não há seleção ou troca de evolução; permanece E05.
- E03-I não é iniciado por este painel; a integração global de stats/HUD/combate
  continua tendo seu gate próprio.
- Nenhum schema, transação de persistência, fórmula, playtest, push ou merge foi
  introduzido por E03-C2.
