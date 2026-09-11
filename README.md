# RagRPG

MVP de RPG de ação 2D isométrico em Godot, para Windows offline.

## Estado atual

Fundação aprovada e implementada por Astra. Há uma tela de status executável,
cálculo de atributos, resolução pura de dano e definição de augments.
**Ainda não há combate, fases ou save implementados.**

- Escopo: [docs/MVP.md](docs/MVP.md)
- Contratos e fórmulas: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Próxima tarefa para aceite: [docs/HANDOFF_SOL.md](docs/HANDOFF_SOL.md)

## Executar

Versão fixada: **Godot 4.7.2 standard**, GDScript, renderer Compatibility.
Importe `project.godot` no editor e pressione F6 na cena principal ou F5.
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

Validação da fundação: importação headless, 11 verificações de regras e smoke
da cena principal aprovados em Godot 4.7.2. A tela não recebeu aprovação visual
do usuário; desempenho e jogabilidade serão avaliados no marco 1.

## Créditos

Godot Engine: https://godotengine.org/license/ (MIT).
Nenhum asset de Ragnarok, Tree of Savior ou terceiros foi incorporado.
