# Checkpoint consolidado — atributos por faixas

## Candidato e escopo

Contrato: [STAT_THRESHOLDS_PLAN.md](STAT_THRESHOLDS_PLAN.md). Autorização humana
verificada no chat Astra, turno `01a11965-e98e-7700-9c8a-ed1a8eb77b14`, 07/10/2026.
Branch `codex/stat-thresholds`, base `628f68e3a953d17771daedfb2874cbceebb289c3`.
Ícones íntegros em `codex/skill-icons`/`35901f6`; habitual em codex/playtest/628f68e
limpo na abertura. Nenhuma publicação/merge/save pessoal autorizado neste pacote.

## Camada numérica

Contrato e oracle independentes escritos **antes de alterar runtime**.
Ganho `13+floor(nível alcançado/5)`; custo permanente crescente `2+floor((b-1)/10)`;
ganhos contínuos com bônus raw; caps e skills preservados. Novo envelope7/stat_thresholds_v1.
Prova exata de migração: 90 limites, todos níveis/origens. Preserva todas alocações
antigas legais, sem confirmação de reset necessária porque não há reset.
200 comparações de build, 100 fixtures novas, tabelas de todos marcos efetivos.
Oracle verifica batch/unit e monotonicidade; nenhuma medição de DPS/TTK/FPS.

Comando: `python tools/simulate_stat_thresholds.py --check`.
Evidência atual é numérica do implementador; ainda não runtime nem revisão Astra.
Auditoria Luna somente-leitura concluída: DP independente confirmou 90/90 limites
e ausência de dívida. Corrigidos dois rótulos de precisão (fixtures são de design;
valores até120 não forçam clamps). Folgas desiguais nas builds concentradas são
explicitadas no contrato, não tratadas como prova de eficiência de dispersão.
Clamps reais com fontes extremas permanecem obrigação dos testes runtime.

## Implementação e fechamento

Pendente: autoridade runtime/custos; migração validando orçamento legado;
projeção de compra e painel; invariantes/integral/renderização.
Manter um checkpoint, commits por camada. Não publicar candidato parcial no habitual.
Próximo passo permitido: implementação granular deste contrato, corrigindo achados
internamente; escalar se preservar save ficar impossível ou exigir nova decisão.
Enviar a outro chat somente com autorização humana explícita de envio deste pacote.

## Tooling

CLI não existe nesta base. Origem explicitamente informada pela delegação:
`C:/Users/João Pedro/.codex/worktrees/menu-tabs/RagRPG/tools/workflow/workflow.py`,
checkout HEAD `0c008d4843d13f772aa2b69be22d24d2300b80a1`, SHA256
`e642dbe882cd7ea3cd687da51ed978bdecc93675fbb31d08d26626a0b40a1bae`.
Sempre `--project C:/Users/João Pedro/.codex/worktrees/d066/RagRPG`; não copiar
tooling/manifesto velho. Guia lido de menu-tabs/docs/WORKFLOW_TOOLING.md.
Engine autorizado Godot4.7.2standard em habitual/.tools/review-engine/Godot.exe.
