# F9 — pacotes Terra6.1

27/10/2026. Autorização humana na retomada para delegar fatias pequenas/médias
de implementação generalista e arte. Não abre épico/F10. Norma: WORKFLOW.

## F9-T01 — pincel e exemplo de relevo arredondado

Base executável4642dbf878fab4004f98141c7e2437ee11e22bd5, mesma branch/checkout.
Modelo gpt-6.1-terra, médio; Sol integra/analisa e Luna testa. Dependências: Brush,
TerrainPanel, preferências e biblioteca existentes; física/renderer já compartilhados.
Estado: rascunho entregue por terra_organic_brush (gpt-6.1-terra/médio), conferido
quanto à localização e manutenção do HEAD. Código ainda aguarda análise/integração,
compilação, testes e prova visual; não declarado concluído em runtime.

Resultado: pessoa modela colina arredondada pelo pincel e cria exemplo orgânico
editável de uma peça; curva real em alturas, material de caminho gradual, sem
montar polígonos à mão. Um apply permite undo completo. Não encerra F9-02/12.

Propriedade nesta preparação: SOMENTE
.godot/f9_shadow_draft/terra_organic/ (ignorado, não é projeto/fixture extra).
Entregar cópias propostas dos arquivos abaixo, mantendo mapeamento/SHA-base:

- scripts/map_authoring/terrain/brush.gd
- scripts/map_authoring/terrain/terrain_panel.gd
- scripts/map_authoring/terrain/organic_example.gd e futuro .uid
- scripts/map_authoring/library/editor_preferences.gd
- scripts/map_authoring/library/library_model.gd
- delivery.md no rascunho, com aceitação/limites/instruções de integração.

Não editar scripts/tests/tools/HEAD/fixture reais, não rodar Godot, não commitar.
Transferência nominal de fontes e .uid ocorrerá após o congelamento. Não modificar
geometria, compiladores, schemas, saves, fórmulas de combate ou tetos técnicos.

Aceitação da implementação proposta: modo novo com perfil radial de derivada
suave, preservando modos/presets anteriores, stroke congelado, locks/proteções e
serialização de parâmetros; preset adicional; GUI e ação semântica na mesma API;
exemplo vazio → uma camada33x33/passo50/domínio1600, colina220/raio420 com duas
operações110 (sem aumentar limite128), caminho curvo pintado por Brush existente.
Preservar documento ocupado; exemplo editável e um único apply/undo. Toolbar sem
estouro e textos pt-BR. Pode ajustar detalhe de apresentação sem relaxar a prova
Gauss17/512 original ou prometer desempenho não medido.

Terra entrega código revisável e especificação de testes. Não declara integração,
compilação ou prova visual concluídas no rascunho. Luna criará/supervisionará os
testes de comportamento, fonte preservada, undo/preset e coerência real de suporte/
clique/navegação/renderização após integração; Sol verificará cobertura e resultado.
Se parar antes de cumprir algum item, declarar PARCIAL e exatamente o faltante.

Próximas fatias só serão despachadas com escopo/base/arquivos concretos; geração
regional segue f9_regional_synthesis.md, sem delegar a árvore inteira de uma vez.


### F9-T01 — autorização de integração após checkpoint91dfa48

O usuário autorizou mais esta integração, com validação proporcional e foco no
jogo/AX. Runtime4642dbf tecnicamente verificado; metadados91dfa48731e92640f80abac7b9548300ff7876ff;
fixture liberada. Transferência nominal no ownership: Terra escreve os cinco
arquivos da aplicação; Sol integra metadados/runner e .uid do módulo; Luna escreve
os dois novos testes/.uids e ajusta somente a expectativa legítima dos quatro
presets em map_editor_library_test.gd, preservando os anteriores.

A regra anterior de somente rascunho foi satisfeita e fica histórica. Agora Terra
pode aplicar a proposta conferindo os SHA-base, corrigir dentro desses cinco
arquivos e concluir o código da fatia, sem testar/editar outros caminhos ou
commitar enquanto Luna prepara testes. Manter os três presets antigos na mesma
ordem e acrescentar o novo. Luna pode escrever testes em paralelo sobre o contrato
estável; nenhuma execução/fixture até Sol congelar os inputs. Falha local volta
à mesma fatia Terra. Não repetir a bateria inteira de navegação do checkpoint19.

Prova dirigida mínima: modelo (fonte e caps, alturas/caminho, stroke/proteção,
preset/ocupado); UI real GUI/AX/undo/layout e gameplay da mesma peça com corpo20/32,
apoio/picking e caminhada em elevação. Registrar tempos de preparação separadamente
de frames/ações em gameplay (não inferir FPS do tempo do teste). Library50 e
LibraryNative53 por impacto; seleção tools/verify de geometria/ator. Ampliação só
se falha/delta demonstrar necessidade. Contagens dos novos testes serão registradas
no runner após autoria, sem fragilizar oráculos. Compilação/validação continuam
com orçamento/forma/corpo originais; não reduzir33x33/220/420 para obter PASS.
