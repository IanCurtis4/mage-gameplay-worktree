# Editor F3 / M3 — contrato executável 1

24/10/2026. ENTREGUE / VALIDADA TECNICAMENTE / ACEITE HUMANO REGISTRADO.
Aceite condicionado a não tratar a travessia pelo centro como navegação final;
pendência e critério no recibo m3.md. Integração ainda não realizada.
Autorização humana neste chat: “F2 terminou, F3 pode começar.”
Base completa `15c0d196105b8801e54d784a6226edf27a06b7bd`, incluindo aceite/passagem F2;
branch `codex/map-editor-m3`, checkout `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m3`.
M0/M1/F2 integrados por ancestralidade. Sol implementa e valida; Luna supervisionará
execução congelada, conclusão, erros, timeouts e hashes, sem auditoria semântica.

## Resultado e fronteira

Documento de composição separado, estrito/versionado, com snapshots imutáveis de
fontes de peças identificados por hash; cada instância fixa posição e rotação em
quartos. O adaptador compila F2/map_terrain_v2, preserva adjacências internas e
constrói Manifest canônico diretamente. Não passa placements manuais pelo sorteio F0.
Receita inicial é árvore explícita de peças/conectores: resolve transformações
deterministicamente e registra o mapa realizado; sem candidatos aleatórios ou WFC.
Rotação técnica do adaptador aceita 0/90/180/270°, sem espelho/escala/correção de cota.

Vínculos exigem aberturas coincidentes, normais opostas, largura/folga e direção
compatíveis. Overlap e caminho inacessível falham sem pacote parcial. Cada trecho
de borda é fechado por envelope físico com apresentação de ruína simples gerada
do próprio envelope; não representa catálogo de arte/biomas entregue. Aberturas
sem vínculo falham. Biomas sem perfil autorizado falham. Divisão do span deixa
livre somente a largura vinculada, sem duplicar sólidos coincidentes.

Publicação local mínima guarda pacote por hash em arquivo binário de dados,
sem objetos executáveis; valida hash/dependências e limite 4MiB antes de escrever,
recusa sobrescrita divergente. Não usa ProfileStore nem modifica save pessoal.
Teste isolado move WorldActorMotion sobre WorldGeometry e pacote real. Perfil
de teste técnico radius2/height12, sem população, combate novo ou progressão.
Fonte obsoleta/cancelamento não libera teste/publicação. GUI/headless compartilham API.

Relevo orgânico e mistura AoM continuam evolução de terreno do produtor F2;
F3 só acrescenta apresentação física das emendas/perímetro. Faces >45° não são
publicáveis; nenhum terreno sólido é inferido de cor/textura. Sem F4+, bundle M7,
publicação externa, merge master, push ou alteração do checkout habitual.

## Manifesto exclusivo e transferência sequencial

Sol F3 possui os seguintes arquivos novos (cada .gd inclui seu .gd.uid):

- scripts/map_authoring/composition/map_document.gd
- scripts/map_authoring/composition/map_session.gd
- scripts/map_authoring/composition/map_compiler.gd
- scripts/map_authoring/composition/map_store.gd
- scripts/map_authoring/composition/map_panel.gd
- scripts/map_authoring/composition/headless.gd
- scripts/map_authoring/preview/map_canvas.gd
- tests/map_editor_composition_test.gd
- tests/map_editor_composition_ui_test.gd
- tools/map_editor_composition/run.ps1
- docs/map_editor/contracts/m3_dispatch.md
- docs/map_editor/delivery/m3.md
- docs/map_editor/README.md (entrada de estado/índice)
- docs/map_editor/delivery/evidence/m3/author/ (evidência autoral)
- docs/map_editor/delivery/evidence/m3/official/ (regressões oficiais Sol)

Transferência M2→F3 de addons/ragrpg_map_editor/shell.gd: somente abrir janela
de composição, preservando autoria de peça. M2 encerrou escrita por seu fechamento;
demais arquivos M2 são só leitura. Runtime E07/F8, project.godot e verify.ps1
permanecem só leitura. Luna terá exclusivamente evidence/m3/luna.md e luna_run/.

Normalização exclusivamente de finais de linha, sem delta de blob Git, dos dois
assets/art/map_authoring/{earth_tile,grass_tile}.png.import no checkout isolado:
o checkout Windows havia convertido LF→CRLF e o importador restaura LF. Os bytes
certificados são LF em fonte e fixture. Nenhum parâmetro/material foi alterado.

## Provas e conclusão

Determinismo/reabertura/undo-redo; duas peças e travessia contínua real;
rota por adjacências F2; perímetro visível/fechado e abertura livre; receita;
rejeição de hash/revisão/posição/largura/direção/cota/overlap e bioma não entregue;
publicação imutável/releitura/corrupção, cancelamento e fonte obsoleta; inspeção
nativa e medição do composto. Runner oficial -List antes de seleção por impacto.
Recibo registra candidato, evidência autoral/Luna, limites e roteiro humano.
