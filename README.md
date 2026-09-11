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

## Jogar

O diretório habitual permanece em `codex/playtest`: basta executar F5, sem trocar
branches no Godot. A arena está aprovada tecnicamente; o merge em `master` depende
do seu aceite após jogar. Se o editor detectar alterações externas, aceite o reload.

Versão fixada: **Godot 4.7.2 standard**, GDScript, renderer Compatibility.
Importe `project.godot` no editor e pressione F6 na cena principal ou F5.
A arena começa imediatamente:

- clique no chão para navegar e cancelar uma perseguição;
- clique num inimigo para se aproximar e autoatacar;
- use `Q` para o corte em cone apontado pelo cursor e `W` para a investida;
- toque no cristal após limpar o encontro, então use `E` para escolher o augment;
- use `Espaço` para iniciar o segundo encontro e `R` para reiniciar após o fim.

O Espadachim tem a passiva fixa de +50% de defesa, aplicada pelo mesmo pipeline de
atributos. O corte custa 15 de mana; a investida custa 20. Mana e recargas impedem
spam e são mostradas no HUD.

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

Validação automatizada: importação headless, 11 verificações da fundação,
37 verificações do Marco 1, 24 verificações do fluxo, 12 verificações de layout
em 1280×720/1920×1080 e smoke da cena principal em Godot 4.7.2. Logs ficam isolados
em `.godot/verification/`. Capturas renderizadas confirmaram arena, HUD e menu de
augments em 1280×720; sensação e desempenho ainda exigem playtest do usuário e não
houve medição de FPS nesta entrega.

## Créditos

Godot Engine: https://godotengine.org/license/ (MIT).
Nenhum asset de Ragnarok, Tree of Savior ou terceiros foi incorporado.
