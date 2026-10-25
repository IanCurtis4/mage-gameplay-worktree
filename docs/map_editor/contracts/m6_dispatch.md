# Editor F6 / M6 — contrato executável 1

25/10/2026. VALIDADA TECNICAMENTE; aceite humano pendente.
[Recibo e evidência](../delivery/m6.md). Código congelado/supervisionado
`227dfb4e3646c4312ea075bca4d1e4a6dfb64a93`; fechamento posterior apenas documental
e remoção comprovada de linhas vazias extras no EOF, conforme recibo.
Autorização humana: “F5 terminou. Podemos começar F6.”
D6 confirmada: “Confirmo sim.” Composição manual/assembler preservados; WFC
opcional, experimental e ativado explicitamente. Sem substituição de produção.
Base completa `fab5c7b2b26c311c274e7f30b4d8b41c8506e27a`, F0–F5 por ancestralidade.
Branch `codex/map-editor-m6`; checkout reutilizado
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
Principal permanece em codex/playtest. Não exige aceite de F5/master inferido.

## Resultado e limites

Documento separado de geração1 contém snapshot M3, seed signed64 textual,
domínios de peças/rotações/pesos por instância, pins de instância inteira,
seleção regenerável, quotas por peça e diversidade mínima. Posições e links
permanecem autorados. Fora da seleção e nos pins, peça/rotação/posição são exatas.
Domínio é grafo de slots fixos, não grade infinita nem síntese de terreno.
Máximo16 instâncias,16 opções/slot,32 peças,64 vínculos,200000 operações,
256 backtracks e64 validações globais; sem reinícios automáticos. Opções têm
peso inteiro1–100. Enumeração canônica; sorteio pelo stream layout/seed/slot/opção.
População/decoração não são rerroladas nem fazem parte do stream de layout.

Solver opcional: propagação de compatibilidade de aberturas, escolha por menor
entropia ponderada, backtracking limitado e validação global M3 em cada solução.
Quota/diversidade não relaxam. Contador global abrange propagação/decisão; limite,
contradição e cancelamento não devolvem proposta aplicável. Compilação/cancelamento
usa o produtor M3; alteração de entrada invalida retorno. Aplicar exige hash-base
atual e ocorre em uma ação desfazível. Antes/depois e diagnóstico localizado.
Fonte/IO versionados; GUI/headless chamam mesma autoridade. Pacote final continua M3.

Comparação usa exatamente o mesmo documento/corpus. Adaptador só leitura chama o
assembler E07 real em árvores representáveis; transforma definições, candidatos
e rotações em Resources transitórios. Restrições adicionais são verificadas após
o resultado; falha é registrada, sem trocar seed, relaxar pin ou fallback. Ciclos
não representáveis e limites da interface são resultado explícito. Não comparar
hashes de formatos diferentes como se fossem equivalentes nem prometer ganho geral.

## Manifesto nominal exclusivo

Sol possui novos arquivos (cada .gd inclui seu .gd.uid):

- scripts/map_authoring/generation/generation_document.gd
- scripts/map_authoring/generation/generation_solver.gd
- scripts/map_authoring/generation/assembler_adapter.gd
- scripts/map_authoring/generation/generation_store.gd
- scripts/map_authoring/generation/generation_panel.gd
- scripts/map_authoring/generation/headless.gd
- tests/map_editor_generation_test.gd
- tests/map_editor_generation_ui_test.gd
- tools/map_editor_generation/run.ps1
- docs/map_editor/contracts/m6_dispatch.md
- docs/map_editor/delivery/m6.md
- docs/map_editor/README.md (D6/estado/link)
- docs/map_editor/STORAGE.md (worktree reutilizado/fixture única)
- docs/map_editor/delivery/evidence/m6/author/ e comparison.json

Transferência sequencial F3→F6 de scripts/map_authoring/composition/map_panel.gd
(+.uid), somente abrir geração assistida e aplicar proposta como ação M3.
F3/F5 encerraram a entrega, conforme autorização humana. Demais produtores,
renderer, geometria, atores, catálogo, snapshot, project.godot e verify.ps1 são
somente leitura. Luna possui exclusivamente evidence/m6/luna.md e luna_run/;
modelo gpt-6-luna, esforço baixo, supervisão delimitada após congelamento.

## Provas

Seed zero/negativa/extremos signed64; repetição e reordenação; variantes reais;
pin/fora da seleção byte-equivalentes; quotas/diversidade; contradições locais
e falha global; zero candidatos, tipos/versões inválidos; orçamento global e
backtracking/cancelamento; ausência de saída parcial; stale/base divergente;
IO e histórico; GUI/headless e inspeção nativa; comparação assembler real/WFC.
verify.ps1 -List antes da seleção por impacto, Luna verifica conclusão real,
erros/timeouts/hashes; Sol valida invariantes e limitações. Uma fixture reutilizável,
engine compartilhada, limpeza de artefatos gerados ao fechar. Sem F7+, push,
master, save pessoal, catálogo novo ou aplicação em playtest por inferência.
