# Composição AX — incremento validado em29/10/2026

Código2248ee724c7cec6b13396eaa99f56e6cfa3e5203 (produção6e506dc0;
2248 corrige somente a comparação numérica do teste nativo). Conteúdo Terra
integrado em `1bdc7301cd46ee40180b5c943f3fcfa10410dc5a`. Branch codex/map-editor-f9, checkout .tools/map-editor-m5,
fixture F1 única, Godot4.7.2 standard SHA AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424.
Aprovação deste incremento não é fechamentoF9, aceite humano ou candidato de playtest.

## Entrega e papéis

Sol escreveu MapOperations e integrou GUI/AX/MapSession/Store. Propostas fechadas
para snapshots imutáveis, instâncias/posição/rotação, vínculos, modos/contexto/
exceções e remoção com limpeza de referências. GUI e AX usam os mesmos produtores;
sem aplicar fonte JSON arbitrária. IDs retornados, no-op/histórico e seleção
editorial preservados; posição fracionária não é arredondada ao selecionar.

Novo/abrir com edição exige confirmação e preservação de rascunho; falha de arquivo,
rascunho ou conflito mantém fonte/histórico/nome ainda em edição. Save usa hash
esperado e não sobrescreve novo destino AX já existente. Worker real compila e
cliente espera resultado atual; screen=map abre a janela existente e retorna
map_snapshot com fonte/hash/dirty/histórico/seleção. A peça mantém seus campos de
topo por compatibilidade; por ação o hash pertence à sessão usada, mesmo em lote
que alterna peça e mapa. Cabeçalhos/UIDs gerados pelo engine, sem recriação manual.

Luna escreveu dois rascunhos e foi interrompida pelo limite antes de execução.
Rascunhos preservados em luna_initial_*.txt. Propriedade foi transferida a Sol,
que completou fixtures/oráculos e executou as provas. Não houve supervisão Luna
independente nem revisão semântica independente desta fatia. Terra escreveu as
receitas e montou o mapa exclusivamente por AX após liberação do produtor.

## Provas finais

- CompositionAX31 PASS em6e: shell/janela reais, semântica GUI/AX, snapshot dedup,
  IDs, transformação fracionária, pureza, inválidos sem mutação, vínculos e rejeição
  de porta reutilizada pelo compilador; contexto/exceções/warnings/modo; remoção
  limpa bordas/transições/vínculos/override com undo; Store/confirm/rascunho/nome
  pendente/conflito. Seu único delta posterior é o teste nativo, conforme auditoria.
- CompositionAXNative13 PASS em2248: controles reais de posição/contexto, validação,
  worker e captura1600x1000, canvas1226x753,18malhas/26cores, sem janela auxiliar.
  Sol inspecionou a captura e a do cliente nativo. Não é aceite de UX integral.
- Cliente AX10/10 headless/nativo, reabertura2/2 em processo novo e negativo que
  interrompe lote PASS: fonte973383a93450959f7d14efca14633ece8d5b2bdf0e9a4fbfd232cb7707ddfc55,
  compilação d155766188ced8d979b4ff6438b3ec0a5e485de4cfc35cb328851af7fe60eb8f,
  arquivo c8392218259a60c960bec84edf3e45b5bd8f43ca601b6f21920d2010b46b595d iguais.
- Regressão M3: Composition63, CLI2 processos mesmo pacote, Document70 PASS.
  Native24 falhou por fixture histórica anterior ao App, **não conta como PASS**;
  diagnóstico/baseline e timeout publicados em composition_regression/legacy_native_audit.md.
- BordersNative32 PASS: quatro famílias, envelopes/canais, GUI/AX/CLI e guardas
  de hash. GameplayNative52 PASS: candidato/corpo real, App/Player/Enemy/HUD,
  movimento/ponte/rota inferior/oclusão/combate/suspensão/retomada/restart. São
  amostras existentes; não certificam jogo/FPS do Bosque novo. Imagens inspecionadas.
- tools/verify.ps1 editor_import PASS1/299 com perfil descartável; demais etapas
  oficiais não repetidas. Warning conhecido de project.godot aninhado ignorado.

Model/native/cliente/regressões congelaram inputs/HEAD por execução. Manifests31/13
contêm2040 inputs, incluindo6imports de props e2backups de terreno;4imports de
terreno conferidos separadamente. Consumidor do novo mapa tem2041: arquivo novo
adicionado. Inputs antigos não foram alterados; não chamar conjuntos diferentes
idênticos. As fontes sanctuary_woods*.json usam LF em checkout para manter recibos
de bytes portáteis, sem mudar os bytes atuais. Logs/evidências desta fatia usam -text.

## Falhas preservadas e correções

Model01: duas inferências de tipo inválidas; Sol declarou String explicitamente.
Model02: desktop virtual headless menor que janela; host passou a embutir as mesmas
janelas reais em seu viewport, em ambos modos. Native01:12/13 por array numérico
com y int0 versus float0.0; probe separado demonstrou array==false, scalar/vector==true.
Oráculo passou a comparar coordenadas vetoriais exatas e manteve verificação de
hash alterado/restaurado. Não mudou produção para essa correção.
Fixtures iniciais Luna também tinham snapshots temporais avaliados após redo,
confirmação de documento já limpo, e leitura do autosave novo em vez do anterior;
foram corrigidas antes da prova, com rascunhos preservados e checks mais concretos.

M3Native24 pressupõe canvas.motion/testing e2filhos, anteriores ao App/MapPackageView.
Canvas, teste e toggle_test são idênticos a bbd (baseline anterior à fatia).
A fixture precisa migrar/ser retirada no tooling final sem perder comportamento;
Native13 e Gameplay52 certificam os contratos atuais escolhidos. Após timeout,
.NET confirmou0processos desse engine e o atalho descartável two_rooms foi
arquivado com bytes/hash; não apagou sessão/janela/perfil nem save pessoal.

## Consumo por Terra e corpo real

Terra executou7/7 ações de montagem, compile→save; processo novo abriu/recompilou
2/2. Fonte original `data/map_authoring/sanctuary_woods.map.json`,45.355B,
SHA2566b8d52095b0d98ba4a436fd5b192ff732b98a8f5da02855646e7e21b9792bb4f,
fonte2407588712870e8bd1b4820e2f82638fe29fb1ce955ae5541b14320e9a2cbe20,
compilação68bd0caa6a9865067bc9a6b025aa34202ba63f4f003642f027b72d2ffded0ed6.
Dois snapshots intactos,47props, clearing@[0,0,0], overpass@[1280,0,0], emenda
woods_seam e contexto forest sem override. Fontes das peças intactas. Captura
composition.png inspecionada por Sol; bordas visuais ainda são legadas.

Consumidor10/10 PASS do arquivo real: bytes/hashes/snapshots/poses/emenda,
compilação igual ao recibo, candidato imutável, corpo20x32, preparo com ponto de
cada apoio acessível e marcador exato[160,0,640] com espaço para esse corpo.
Entrada de prévia é provisória até configuração de população. Não houve App,
caminhada/combate/restart ou medição de FPS **deste mapa**. Não repetir a prova de
paths extras do checkpoint24 como se ela tivesse sido executada aqui.

Uma amostra: compilação 27.846s (navegação
25.924s), preparo
24.354s (navegação 22.454s),
lote total 63.547s incluindo hashes/IO. São métodos canônicos
com custo relevante para preparar o jogo; não são FPS nem uma meta de encurtar suíte.

## Próximos passos obrigatórios

Corrigir propagação do bioma de autoria ao manifesto (atualmente stage.biome=ruin),
com invariantes/fallback/compatibilidade; aplicar bordas florestais em transação
AX revisável usando hashes corretos; fechar população/patrulha/objetivo existentes
por comandos parametrizados. Preparar gameplay real do Bosque e tratar latências
canônicas. Layout/rolagem, fixture legada, síntese/regeneração regional, reconciliação,
assets passivos/ambiente limpo/recuperação/release e restante da matriz continuam F9.
[Pendências concretas](open_findings.md). Sem master/push/F10/playtest/save pessoal.
Documentação final valida coerência/referências; não repete gameplay por editar texto.

Após a falha da fixture Native24 impedir o footer original, o lote headless M3
foi repetido separadamente em composition_headless_manifest para produzir seu
manifest completo: import/63/CLI2/70 PASS, fonte/fixture iguais. A repetição não
revalidou Native24 nem alterou expectativas; tratou a proveniência ausente.
