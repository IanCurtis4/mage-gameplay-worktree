# Editor F7 / M7 — contrato executável 1

25/10/2026. VALIDADA TECNICAMENTE — aceite humano pendente.
Código congelado `c2d6aea78ce45c974d96d688ce591e339dbbe383`.
[Recibo/evidência](../delivery/m7.md). Autorização humana: “F6 acabou, podemos começar F7.”
Base `685d585b4b211e9228258a149d676aa2642d8e81` resolvida abaixo; F0–F6 integrados por ancestralidade.
Checkout reutilizado: C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
Branch codex/map-editor-m7. Principal/save pessoal preservados; dois checkouts.
D6 incluída como WFC experimental opt-in, conforme recibo M6; demais decisões
permanecem as dos produtores. CLI de workflow/WORKFLOW_TOOLING ausentes na base.
Retomada por Git/contratos, sem copiar ferramenta externa.

## Resultado e fronteira

Bundle JSON fechado, dados incorporados e nomes virtuais relativos (sem extração
nem resolução de arquivos do remetente). Cinco fontes: peça, mapa, encontros,
patrulhas e pedido de geração. Compiladores existentes; geração só valida o
pedido/mapa, não ativa WFC por importação. Assets são dependências do catálogo
local, nunca scripts, cenas ou binários externos. Miniatura produzida localmente
pela prévia, não mídia executável importada. Brief humano e corpus textual.
Pedido local confiável guarda base, permissões de seções/IDs, caminhos protegidos
e orçamento. Proposta não pode ampliar essas permissões. Diff recursivo em clone,
compilação e preview antes de aplicar, confirmação explícita e ação única com undo.
Base divergente exige novo pedido explícito; sem merge silencioso. Reaplicação
idêntica é no-op. Gravação local atômica com conflito/pendência explícitos.
Limites:16MiB por arquivo JSON, profundidade32,2000000 tokens do leitor comum;
até2048 mudanças,32 seções e128 IDs/caminhos de permissão. IDs/paths não são código.
Hashes de integridade não são assinatura/autenticação do remetente.

## Manifesto nominal e transferência sequencial

Sol possui scripts/map_authoring/exchange/{exchange,exchange_panel,headless}.gd
com respectivos .gd.uid; tests/map_editor_exchange{,_ui}_test.gd + .uid;
tools/map_editor_exchange/run.ps1; docs/map_editor/contracts/m7_dispatch.md;
docs/map_editor/delivery/m7.md; docs/map_editor/exchange.md;
docs/map_editor/delivery/evidence/m7/author/ e .gitattributes local (logs brutos); atualização de estado/link no README.
Fontes versionadas skills/ragrpg-{mapdelivery,enemydelivery,art}/SKILL.md;
art passa a ter fonte versionada baseada na cópia instalada lida, sem sincronizar
instalações nesta tarefa. Nenhuma geração raster solicitada.
Transferência sequencial dos produtores encerrados: addons/ragrpg_map_editor/shell.gd,
scripts/map_authoring/composition/map_panel.gd, population/population_panel.gd,
patrol/patrol_panel.gd, generation/generation_panel.gd (+ .uid existentes),
somente ponto de abertura/binding da janela comum de intercâmbio.
Demais arquivos runtime/catálogos/verify.ps1/project.godot somente leitura.
Luna (gpt-6-luna, baixo) possui somente evidence/m7/luna.md e luna_run/ após
congelamento; mesma fixture sequencialmente, sem editar runtime/oráculos.

## Provas e exclusões

Roundtrip cinco fontes; GUI/CLI hash compilado idêntico; diff com IDs/antes/depois;
base divergente/stale, no-op idempotente, undo/redo, rejeição sem mutação;
permissões locais, regiões/camadas/slots/pins protegidos; tipos/versões, duplicatas,
asset ausente, paths absolutos/traversal/backslash, extensão executável e tamanho.
verify.ps1 -List e seleção por impacto, inspeção nativa; Luna confere término,
erros/timeouts/hashes, Sol contrato/invariantes. Uma fixture e engine compartilhada;
limpeza final. Sem F8, master/push, campanha nova, catálogo novo, save pessoal ou
publicação externa. Limitações M3-NAV-01/E07 dos produtores permanecem.
