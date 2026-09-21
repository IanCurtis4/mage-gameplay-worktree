# Revisão E03-C2 A–D — 21/09/2026

## Correção aprovada

**Aceite técnico concedido a `647665b`.** Foco agora é preservado por ID de
personagem, separado da seleção da run. Probe independente: foco 1 permanece 1;
dois investimentos produzem Alt1=0, Alt2=2. Testes adicionais cobrem falha/retry,
compra de skill, ambos os respecs e reload com dois alts.

UI distingue teto inicial+investido 60 e teto efetivo 120, ambos obtidos das
autoridades existentes. Tooltip não expõe mais o ID do épico futuro.
Verificação independente completa em Godot 4.7.2 passou com importação, 975
checks e smoke. Nenhum bloqueador novo identificado no delta.

E03-I liberado com Sol para fechamento integrado, incluindo conferência visual,
contrato numérico E00, cobertura L2 e roteiro de playtest. Aceite de produto,
integração de código no projeto fixo e merge em master ainda não ocorreram.

## Parecer anterior (corrigido)

Candidato `fe3a93c`; base `48a01be`. Aceite pendente de correção de foco.

Pacotes inspecionados: API de consulta `714d641`, leitura A `f0d1aeb`, atributos
B `7a79830`, skills C `c1d1d40`, integração/reload D `fe3a93c`.
As quatro partes estão presentes e usam transações existentes. A consulta nova
é somente leitura; não altera schema nem fórmulas. Testes cobrem compra, respec,
retry e reload, mas os fluxos de mutação usam um único alt.

Verificação independente: Godot 4.7.2, `tools/verify.ps1` com importação e smoke,
973 checks aprovados. Não houve aprovação visual nem atualização de código no
playtest/master nesta revisão.

## Correções

1. **P1 — Atualização troca o personagem em edição.** `_show_result` chama
   `_refresh`, que restaura `_selected_index` pelo personagem selecionado para a
   run. Ao navegar para outro alt e investir, o primeiro clique altera o alt em
   foco, mas o segundo altera o personagem anterior. Isso também quebra o retry
   da mesma ação após falha em um alt diferente. Reproduzido com perfil isolado:
   foco 1 antes, foco 0 depois; dois cliques resultaram em um ponto em cada alt.
   Preservar foco por character_id, distinguindo navegação de seleção da run.
   Testar sucesso, falha/retry, skills/respec e reload com dois personagens.
2. **P2 — Limite de atributo ambíguo/incorreto para investimento.** A UI mostra
   `limite 120` usando máximo efetivo do StatBreakdown, mas investimento inicial
   + alocado para em 60. Distinguir teto de investimento e teto efetivo, usando
   autoridade existente e sem copiar fórmula. Os testes hoje cristalizam 120
   como único limite; ajustar também o caso de atributo no teto.

Polimento no mesmo delta: substituir texto interno “definidos em E04” por
explicação ao jogador sobre efeitos por rank ainda indisponíveis; não expor ID
de épico na interface. Não é motivo para refazer o layout ou ampliar escopo.

Probe em `.tools/e03_c2_focus_probe.gd`. Correções encaminhadas ao Terra na tarefa
existente. Depois: revisão focalizada, E03-I e preparação de playtest do épico.
