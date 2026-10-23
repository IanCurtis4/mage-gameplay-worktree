# E07-F8 — checkpoint técnico

23/10/2026. **ENTREGUE / VALIDADA tecnicamente**, com limitações de custo explícitas.
[Recibo consolidado](delivery/f8.md), [propriedade/avals humanos](f8_dispatch.md),
[roteiro de playtest](f8_playtest.md). Base 5ee16ebdce1888c84f15b29f286e956db7b55d42;
runtime final 7775f44dc47fef6ebceeae667f43e7af963d5e02, codex/e07-f8,
`C:/Users/João Pedro/.codex/worktrees/e07-f8/RagRPG`.

As três transferências nominais autorizadas corrigiram captura no abate,
elegibilidade/provocar e resolução de hashes no export. Sem expectativas relaxadas.
Luna: 85 IDs contratuais +2 probes únicos PASS por impacto, com hashes/conclusão/erros
conferidos. Sol: invariantes e inspeção nativa; release 17+62 PASS em processos
separados e fluxo completo. Não é auditoria semântica independente.

Máquina i7-8700/GTX1080,1920×1080/OpenGL3.3. Amostra4 estágios/5 slots/2 ativos.
Entrada11,5s, suspensão7,7s, retomada3,5s; coletas/viagens/conclusão11,8–14,5s.
Pausas síncronas são limitação material; não prova de 60FPS, escala ou balanceamento.
Conservação funcional aprovada; aceite de produto e roteiro humano pendentes.

Preparação de playtest autorizada pelo WORKFLOW após esta validação. Preservação
prévia:246 sidecars/export e2saves com hashes intactos; backup somente dos246 arquivos
locais, sem cópia de save; nenhum caminho se sobrepõe ao delta do candidato.
Estado inicial habitual 9e457f222b0bc7dbbc67078ec7712eecee1bb353.
CLI ausente; avanço/import/smoke e hashes efetivos serão registrados abaixo.
Master/push, migração pessoal, E08+ e arquivamento não autorizados.

## Aplicação no diretório habitual —23/10/2026

**F0–F8 INTEGRADAS em codex/playtest; aceite humano pendente.** Fast-forward de
9e457f222b0bc7dbbc67078ec7712eecee1bb353 para a aprovação técnica
`12c606441ed309788d49e4a88ee5006869b733d4`, em
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG`. Commit subsequente só registra
este resultado; fontes de runtime permanecem7775f44 e conteúdo aprovado12c6064.

Importação normal com Godot4.7.2 e smoke headless no próprio diretório habitual
PASS, sem markers de erro, usando APPDATA/LOCALAPPDATA isolados. Primeira tentativa
com recovery-mode registrou erro de GitPlugin desabilitado pelo próprio modo;
não é PASS. Segunda importação normal carregou o plugin local e passou sem alterar
configuração versionada. Logs e resultado em playtest_checks_01.json/playtest_checks.json.
Nenhuma expectativa ou fonte foi alterada para contornar a tentativa negativa.

246 arquivos locais permanecem byte-idênticos; nenhum precisou de restauração.
Dois saves pessoais preservados por hash, sem abrir/copiar/migrar/gravar seu conteúdo.
Master permanece8df3a67a21f26ff69249eadfc29d3d78eee8842e; nenhum push.
Git normalizou o diagnóstico de sidecars por final de linha, sem mudar seus bytes;
o inventário por hash, e não a contagem de status, fundamenta a preservação.

Build normal final e play_isolated.cmd também abriram em perfil descartável;
o lançador criou somente test_profile/Godot/app_userdata/RagRPG sob sua pasta.
O projeto habitual mantém os sidecars/export locais; a distribuição usa staging.
F7 está integrada e tecnicamente arquivável, sem arquivamento automático. F8
permanece aberta para feedback do candidato. Próximo passo: parar a partida antiga,
aceitar reload no Godot e executar F5, ou usar a distribuição isolada com o roteiro.
Edição final exclusivamente documental validou referências/diff; não repetiu a suíte.
