# Ajuste do editor de atalhos e controles de rank — 15/10/2026

Pedido humano: ícone integral também no editor, tecla legível sobreposta, sem texto lateral; +/− menores e contidos no cartão na árvore e lista.
Base: 769c368e467f779f1522bd40e9374bfe9b0bf37a; branch codex/e06-inventory; checkout C:/Users/João Pedro/.codex/worktrees/e06-inventory/RagRPG.
Sol executa/valida: scripts/ui/{action_bar_slot,action_bar_editor,skill_window}.gd, tests/{e06_icon_bar_test,skill_window_test}.gd, tools/{compact_gui_native_probe.gd,prepare_skill_iteration_runner.py} e documentação deste ajuste. Luna acompanha testes e possui exclusivamente e06_editor_alignment_luna.json.
APIs estáveis: ActionBarLayout, ranks, DnD e ControlPreferences permanecem. Não alterar aprendizagem, recargas, saves ou regras.
Conclusão: teste de refresh sem acumular overlays, arraste preservado, limites reais dos botões em árvore/lista, inspeção renderizada e verify.ps1 proporcional. Depois aplicar ao playtest preservando alterações pessoais; sem merge master/push.
