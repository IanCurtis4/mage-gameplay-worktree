# Checkpoint28 — geração real de população desbloqueada

Sol consolidou o candidato `9c8185c6cedbfd1ef48dfa88821268fb9afb0677` em29/10/2026,
branch `codex/map-editor-f9`, checkout `.tools/map-editor-m5`. Código de produção
idêntico a `956d38dd05954f0f6093d5f26e802b82b4caf798`; último delta é protocolo
de teste/runner. Não há aceite de produto, atualização de playtest ou merge/push.

PopulationCompiler v2 usa a autoridade `WorldGeometry.connectivity_batch` para
existência de ida/volta, sem substituir menor custo/path/leash/ataque. Pool guarda
grid16/células exatos, exclusões, corpo20×32, política, densidade, pins, quotas e
seleção determinística. Contextos reservados propagam erro operacional. Pacotes
v1 são recusados sem reescrever o arquivo; fontes podem ser recompiladas. Função
individual `_path` original preservada para os diferenciais históricos.

## Evidência consolidada

- Luna: PopulationReachability27/27; Context Candidate53, Population91, Patrol58,
  Exchange113; todos exits0, sem timeout/abort/erro de script. Verify selecionou
  editor_import e e07_f5_population_test:2/299, ambos PASS; F5 população40 checks.
- Sol: `population_audit_01.json` confrontou os recibos, engineSHA, HEAD congelado,
 2056 inputs completion e2050 context contra fonte/fixture; zero divergências.
  Os seis imports de props e bytes Git dos inputs alterados foram conferidos.
- Mesma fonte real AX de Terra SHA256
  `4d64d6ffbce706a2917b2a1ad436decfd362b96575a7a4b4bbd001ededdb7cb1`:
  `population_measure_01` exit0, sem erro/timeout,157,130s incluindo startup;
  sem mutação,7slots e quotas3/3/1. Fonte final ainda não criada/aplicada.
- Mapa33,156s; prova entrada→santuário e retorno15,472s; fixo14,139s;
  pools78/316/165 terminais em28,087/2,571/50,569s. Máximo observado
  7881estados e88.124.288 unidades de armazenamento contabilizadas, não RSS.
  Limites/corpo/quotas/pontos/mapa/engine e guards não foram ampliados/reduzidos.

O baseline AX guardou timeout300s/360s. Sonda original individual permaneceu
sem retorno aos120s, com mapa28,313s e início da busca38,372s; não é possível
dar um fator de aceleração preciso a partir de tempo censurado. O novo ensaio
é uma cópia instrumentada do compilador (scripts exatos preservados `.gd.txt`),
não prova ainda aplicação AX, compilação final ou percurso no jogo.

## Falhas preservadas e correções

Sonda01 usou parser inadequado e falhou piece_hash_mismatch antes do mapa;
sonda02 corrigiu leitura por Store/StrictJSON. Directed01 falhou inferência de
tipo no teste: explicitado bool, sem alterar oráculo. Directed02 encontrou duas
referências históricas a `_path`: restaurada função original, sem mudar testes.
Directed03 executou27/27 mas runner recusou protocolo/count não cadastrado;
Directed04 corrige somente recibo e tabela esperada, repete27/27 com PASS total.
Todos os logs anteriores continuam presentes; falhas não contam como PASS.

## Continuação autorizada

Terra retoma exclusivamente por AX o rascunho preservado: abrir, preparar prévia,
inspecionar proposta/diff, aplicar com hashes exatos e salvar população final;
compilar em processo separado se necessário, depois criar patrulha. Separar
receitas longas preserva guards existentes, sem aumentar limite por job. Nunca
escrever fonte de produto manualmente. Não reduzir área, quotas ou corpo para
passar. Cancel/deficit/budget continuam diagnósticos, sem aprovação parcial.

Sol mantém integração; Luna supervisionou execução, sem auditoria semântica
independente. Fixture liberada e nenhum engine ativo no fechamento deste lote.
F9 integral continua aberto: compilação/publicação real, App/percurso/combate,
performance in-game e fonte/patrulha reais, UX/AX final, geração regional,
reconciliação, assets/export/release, guias e demais itens da matriz.
Path individual ainda pode ser lento; esta prova de existência não resolve
isso nem certifica FPS. Guard editor-worker180s também permanece exigido no
uso real. Playtest/save pessoal/master/push/F10 continuam preservados.
