# Checkpoint consolidado — atributos por faixas

## Candidato e escopo

Contrato: [STAT_THRESHOLDS_PLAN.md](STAT_THRESHOLDS_PLAN.md). Autorização humana
verificada no chat Astra, turno `01a11965-e98e-7700-9c8a-ed1a8eb77b14`, 07/10/2026.
Branch `codex/stat-thresholds`, base `628f68e3a953d17771daedfb2874cbceebb289c3`.
Ícones íntegros em `codex/skill-icons`/`35901f6`; habitual em codex/playtest/628f68e
limpo na abertura. Nenhuma publicação/merge/save pessoal autorizado neste pacote.

Resposta humana vigente nesta conversa: **“Não enviar ainda”** para o pacote de
atributos. Não enviar ao Astra por efeito da autorização anterior dos ícones.
Revisão integrada, publicação e aceite de produto continuam separados.
Retomada pela skill `ragrpg-resume` confirmou este contrato específico; o cabeçalho
histórico do Defendente não selecionou outra classe nem ampliou o escopo.

## Camada numérica

Contrato e oracle independentes escritos **antes de alterar runtime**.
Ganho `13+floor(nível alcançado/5)`; custo permanente crescente `2+floor((b-1)/10)`;
ganhos contínuos com bônus raw; caps e skills preservados. Novo envelope7/stat_thresholds_v1.
Prova exata de migração: 90 limites, todos níveis/origens. Preserva todas alocações
antigas legais, sem confirmação de reset necessária porque não há reset.
200 comparações de build, 100 fixtures novas, tabelas de todos marcos efetivos.
Oracle verifica batch/unit e monotonicidade; nenhuma medição de DPS/TTK/FPS.

Comando: `python tools/simulate_stat_thresholds.py --check`.
Camada numérica preservada no commit `77d2c18`. Evidência de design não é aceite
de gameplay; as validações runtime abaixo não são revisão integrada Astra.
Auditoria Luna somente-leitura concluída: DP independente confirmou 90/90 limites
e ausência de dívida. Corrigidos dois rótulos de precisão (fixtures são de design;
valores até120 não forçam clamps). Folgas desiguais nas builds concentradas são
explicitadas no contrato, não tratadas como prova de eficiência de dispersão.
Clamps reais com fontes extremas foram acrescentados aos testes runtime.

## Implementação e fechamento

Implementação concluída na branch isolada; core/migração em `7308288`.
O commit sucessor consolida painel, regressões e este checkpoint. HEAD efetivo
e identidade da árvore são obtidos pelo CLI, não inferidos de um hash histórico.

- `ProgressionRules` cobra pelo permanente/origem; lotes somam cada passo,
  respec reembolsa preço canônico e valores extremos não contornam cap por overflow.
- `StatCalculator` mantém termos contínuos, soma bônus raw e aplica as mesmas
  fontes/clamps. Fórmulas locais INT-only/INT+DES da Sentinela foram preservadas.
- Catálogos1..6 conhecidos migram ao par7/stat_thresholds_v1, após validação da
  carteira antiga e atual; investimentos, skills, barras, presets, equipamentos,
  seleção, alts, extensões e cursor de recompensa permanecem íntegros.
- Store conserva backup anterior e pending incerto. Migração/recuperação com
  pending não confirmado fica somente leitura; não o sobrescreve como scratch.
  Recuperação sem pending permanece testada. Falhas nos quatro estágios não
  substituem o primário antigo; versões futuras e linhagem de backup continuam protegidas.
- Preview de compra é somente leitura, sem abrir/gravar/reparar perfil; copia a
  build para incluir passivas dependentes da alocação (Sede de Sangue).
- Painel mostra permanente/efetivo, custo +1, próximo marco, ganhos antes→depois
  e bloqueio individual. Frações de cast usam três decimais para não ocultar ganho.
  Os seis atributos e suas descrições são alcançáveis por rolagem; rodapé permanece fixo.

## Evidências e reprodução

Godot4.7.2standard, Compatibility. Perfis de testes exclusivamente sob `.godot/verification`.
Luna executou auditoria limitada e atualização justificada de fixtures; Sol revisou
o delta e as regressões. E00 histórico permaneceu byte a byte inalterado.
Não se atribui a isso aprovação independente integrada de Astra.

- `python tools/simulate_stat_thresholds.py --check`: PASS, 90 limites exatos,
  200 comparações/100 fixtures, batch/unit e marcos.
- `tests/stat_threshold_rules_test.gd`: PASS, **28.090 checks**; custos, atomicidade,
  respec, extremos, marcos/frações/fontes/clamps, monotonicidade e limites de skills.
- `tests/stat_threshold_migration_test.gd`: PASS, **520 checks** na execução dirigida
  final; origens/níveis, envelopes, old overspend, primeira compra, respec/reload,
  backups/pending/futuro/falhas, sessão ativa e contadores.
- Matriz E03: PASS, **296 checks**, todos10 casos preservados. Mudanças derivadas
  calculadas explicitamente; histórico E00 não virou oracle do runtime novo.
- Preview/painel: prova no renderer real com **32 checks, zero falhas**, 720p e1080p,
  custos individuais, compra/reload/run, passiva dependente de VIT e buff cruzando
  marcos HP/SP/HIT sem reposição de déficit comportado pelos máximos ou reset de CD.
  Capturas: `.godot/verification/stat_attributes_{1280x720,1920x1080}{,_bottom}.png`.
- `tools/verify.ps1`: PASS, import,156 testes e smoke. Log da árvore pré-commit:
  `.godot/verification/stat_verify_all.log`. Os checks finais adicionais de sessão
  ativa/exibição/rolagem estão nos testes dirigidos e na seleção integral do CLI.

Fechamento vinculado ao candidato: executar `validate --suite all --role implementer`
em HEAD limpo depois do commit. Saída: `.godot/verification/stat_cli_all.log`; o CLI
emite o caminho exato `.godot/workflow/<execução>/report.json`. Só um relatório
PASS com `current_inputs=true` representa evidência integral deste HEAD; usar
`status --contract docs/STAT_THRESHOLDS_PLAN.md` ao retomar. Este texto não cria
aprovação nem substitui o resultado do relatório. Relatórios antigos dos ícones
e logs da primeira triagem não aprovam atributos.

## Limites e próximo passo autorizado

Pacote permanece aqui, aguardando autorização humana de envio. Não repetir o
handoff antigo dos ícones, publicar no habitual, integrar master ou abrir marco novo.
Habitual confirmado limpo em `codex/playtest`/`628f68e` ao consolidar.

Sem DPS/TTK/FPS medidos, balanceamento em gameplay ou aceite visual humano.
Concentradas podem deixar orçamento ao atingir cap; tabelas não equiparam gasto.
Recursos continuam com o contrato existente: déficits preservados onde comportados
pelos máximos; não foi introduzido ledger novo de dívida de HP/SP. Nenhum teste
acima qualifica déficits maiores que o máximo reduzido. Sem sistema de peso/drop/
perfect dodge ou bônus novos em fórmulas locais de skill. Saves pessoais intocados.

## Tooling

CLI não existe nesta base. Origem explicitamente informada pela delegação:
`C:/Users/João Pedro/.codex/worktrees/menu-tabs/RagRPG/tools/workflow/workflow.py`,
checkout HEAD `0c008d4843d13f772aa2b69be22d24d2300b80a1`, SHA256
`e642dbe882cd7ea3cd687da51ed978bdecc93675fbb31d08d26626a0b40a1bae`.
Sempre `--project C:/Users/João Pedro/.codex/worktrees/d066/RagRPG`; não copiar
tooling/manifesto velho. Guia lido de menu-tabs/docs/WORKFLOW_TOOLING.md.
Engine autorizado Godot4.7.2standard em habitual/.tools/review-engine/Godot.exe.
