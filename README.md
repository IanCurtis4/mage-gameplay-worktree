# RagRPG

MVP de RPG de ação 2D isométrico em Godot, para Windows offline.

## Estado atual

Arena técnica jogável do Marco 1 sobre a fundação aprovada. Inclui Espadachim,
navegação por clique com segmentos seguros ao redor de obstáculos, perseguidor,
arqueiro com flechas esquiváveis/bloqueáveis, dois encontros,
três augments gerais, HUD, morte, conclusão e reinício. Ainda não há Mago, fases,
boss, equipamentos, cartas, distribuição de atributos ou save.

- Escopo: [docs/MVP.md](docs/MVP.md)
- Contratos e fórmulas: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Handoff do Marco 1: [docs/HANDOFF_SOL.md](docs/HANDOFF_SOL.md)
- Fluxo de revisão e playtest: [docs/WORKFLOW.md](docs/WORKFLOW.md)
- Aprovação técnica e roteiro de teste: [docs/REVIEW_M1.md](docs/REVIEW_M1.md)
- Correções do feedback de playtest: [docs/PLAYTEST_M1_FEEDBACK.md](docs/PLAYTEST_M1_FEEDBACK.md)
- Peso do movimento e perseguição de arqueiros: [docs/PLAYTEST_M1_MOMENTUM.md](docs/PLAYTEST_M1_MOMENTUM.md)
- UI de batalha e validação: [docs/REVIEW_BATTLE_UI.md](docs/REVIEW_BATTLE_UI.md)
- Próximo passo de arte: [docs/ART_DIRECTION_NEXT.md](docs/ART_DIRECTION_NEXT.md)

## Jogar

O diretório habitual permanece em `codex/playtest`: basta executar F5, sem trocar
branches no Godot. A arena está aprovada tecnicamente; o merge em `master` depende
do seu aceite após jogar. Se o editor detectar alterações externas, aceite o reload.

Versão fixada: **Godot 4.7.2 standard**, GDScript, renderer Compatibility.
Importe `project.godot` no editor e pressione F6 na cena principal ou F5.
A arena começa imediatamente:

- clique no chão para navegar diretamente quando houver linha livre e cancelar uma perseguição;
- clique perto de um inimigo para selecioná-lo, se aproximar e autoatacar; hover e seleção têm realces distintos;
- use `Q` para mirar o corte e `W` para mirar a investida; clique esquerdo lança;
- botão direito ou `Esc` cancela a mira; os cartões da barra também selecionam skills;
- sem mira ativa, `Esc` ou **Controles** abre configurações de cast e smart lock;
- toque no cristal após limpar o encontro, então use `E` para escolher o augment;
- use `Espaço` para iniciar o segundo encontro e `R` para reiniciar após o fim.

O Espadachim tem a passiva fixa de +50% de defesa, aplicada pelo mesmo pipeline de
atributos. O corte custa 15 de mana; a investida custa 20; a regeneração base é de
6 mana/s enquanto vivo e sem pausa. O HUD mostra custo e estado (`PRONTO`, `SEM MANA`
ou `RECARGA`) sem arredondar a mana disponível para cima. A seleção tem assistência
de 68 unidades e o corpo clicado diretamente sempre tem prioridade; o alcance corpo
a corpo tolera 50 unidades além das bordas dos atores, sem atravessar obstáculos.

O personagem ganha velocidade em cerca de 0,2 s, conserva um pouco de impulso ao
virar e freia em um trajeto curto. A perseguição alcança a posição atual do inimigo;
cada auto tem um arco visual e uma pausa de 0,14 s antes de retomar a aproximação se
o alvo escapar. Um clique no chão cancela a perseguição e essa pausa.

Padrão escolhido: selecionar e confirmar com clique. Nas configurações também há
lançamento ao soltar Q/W e smart cast imediato. A preferência fica salva localmente.
Mirar não gasta mana; o estado da mira mostra se falta mana ou recarga. O cone usa o
alcance do corte; a investida mostra corredor e círculo de chegada, incluindo paredes.
Smart lock estabiliza o alvo sob o cursor, sempre priorizando um corpo clicado
diretamente. Está aplicado aos autos e preparado para futuras skills single-target;
corte e investida continuam direcionais.

A cópia portátil local está em `.tools/godot/` (ignorada pelo Git).
O executável principal funciona também em headless; o wrapper `_console.exe`
falhou com erro 193 neste ambiente e não deve ser usado nos comandos abaixo.

```powershell
& '.tools/godot/Godot_v4.7.2-stable_win64.exe' --path . --editor
```

## Verificar

Use PowerShell 7 (o verificador usa `ProcessStartInfo.ArgumentList`).

```powershell
./tools/verify.ps1 -GodotPath '.tools/godot/Godot_v4.7.2-stable_win64.exe'
```

Em worktrees, passe o caminho absoluto do executável portátil no checkout
original. A engine e os caches não são copiados pelo Git.
Não há export templates nem executável distribuível do jogo nesta etapa.

Se uma instância aberta do editor mantiver a DLL do GitPlugin em uso, acrescente
`-EditorRecoveryMode` ao verificador. Isso usa recuperação somente na importação
do processo de teste; os testes de gameplay continuam em modo normal. Plugins do
editor não são validados nessa opção, e sua configuração local não é alterada.

Validação automatizada: importação headless, 12 verificações da fundação,
63 verificações do Marco 1, 33 de perseguição/inércia, 40 de UI/input, 32 do fluxo, 28 de layout
em 1280×720/1920×1080 e smoke da cena principal em Godot 4.7.2. Logs ficam isolados
em `.godot/verification/`. Os testes de movimento cobrem 30/60/144 Hz; isso prova
consistência lógica, não FPS de renderização. Capturas renderizadas confirmam os
estados do HUD e o realce de seleção; sensação e desempenho ainda exigem novo
playtest do usuário.

## Créditos

Godot Engine: https://godotengine.org/license/ (MIT).
Nenhum asset de Ragnarok, Tree of Savior ou terceiros foi incorporado.
