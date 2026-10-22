# E07-F7 — despacho operacional após integração F1–F6

22/10/2026. Chat existente `01a150a6-c7d0-7623-90fc-365643b86d3c`,
**Terra / Médio**. O usuário já autorizou no próprio chat: “F6 foi entregue,
podemos começar F7.” Este despacho resolve os pré-requisitos operacionais que
o executor solicitou; não cria novo chat nem autoriza F8/E08+.

## Base integrada e checkout

Base integrada de runtime: **`f6ba5a9735846ca87fc735178df7bbe932539b6f`**,
branch de composição `codex/e07-integration`. Contém toda a cadeia F1–F6, incluindo
F6 runtime `22f98bc3016a99b705dece08b8a03490bf763571` e fechamento
`eca6f1bb76ce3e3654173763aefa3d006f4db82f`.
[Recibo de integração e validação](f1_f6_integration.md) identifica a evidência
reutilizada e a execução de integração. Não depender de cherry-picks manuais.

Checkout preparado exclusivamente para F7:
`C:/Users/João Pedro/.codex/worktrees/e07-f7/RagRPG`, branch **`codex/e07-f7`**.
O HEAD inicial inclui somente os registros documentais posteriores à base acima;
resolver e registrar seu SHA completo na retomada. Os inputs de runtime são os
mesmos da composição validada. A coordenação registra esse HEAD no recibo de
liberação, sem inventar hash circular neste documento.

O app ainda associa o chat ao diretório habitual: usar workdir explícito no
checkout F7 em TODOS os comandos/edições/importações. Não trocar a branch ou
editar o checkout habitual, os produtores F1–F6 ou a branch de integração.
F7 foi autorizado antes; esta preparação não envia mensagem nem inicia seu turno.

## Decisões e APIs disponíveis

[Decisões consolidadas](e07_decisions.md) indexam aprovações já obtidas:
D01 assistida; D02 uma expedição/personagem, locks, congelamento local e quest
antecipada como suspensão; D03 ondas/mácula/EXP; D04 morte e tabela por classe;
D05 lógica e apresentação 2,5D; D06 ameaça completa; D07 amostra de quatro estágios,
nível1 sem custo/chave e bônus de teste100 gold/300 EXP Base/200 EXP Job, sem item.
Delta de troca ativa transacional aprovado em F5. Não perguntar essas decisões
de novo. Ampliação de produto, escala, taxas ou novas exceções pede decisão própria.

Consumir [F0](f0_api.md), [F1](f1_api.md), [F2](f2_api.md), [F3](f3_api.md),
[F4](f4_api.md), [F5](f5_api.md) e [F6](f6_api.md). São APIs reais integradas.
F6 foi incluída por aval explícito e entregue: ThreatView pode ser consumida.
A referência arquitetural é [contrato E07](../e07_contract.md), com os deltas
aprovados registrados nos despachos/recibos dos produtores.

## Resultado e limites

Entregar seleção da fase/retomada por personagem, prévia e confirmação assistida
da migração, apresentação dos portais e ameaças e primeira amostra modular
legível sobre APIs existentes. Duas montagens diferentes da mesma fase;
ramificação/retorno, destinos e objetivos alcançáveis, alturas/rampas/ponte,
retorno após morte e mensagens de recuperação claras em pt-BR.

Resources de receita/partes/população são imutáveis. Consumir o gerador real,
geometria e planner; não copiar a fixture F5 como campanha fixa ou implementar
outro gerador. Os oito slots de F5 são densidade artificial de prova, não uma
quota universal aprovada. Inicialmente manter escopo pequeno/valores aprovados;
submeter qualquer expansão de quantidade/área antes de promovê-la a produto.
UI apenas apresenta DTOs e encaminha intenções. Não recalcular ameaça, recompensa,
limpeza, posse, recarga, elegibilidade ou montar writer próprio.

Migração pessoal NÃO foi autorizada: implementar/testar somente com fixtures;
a interface real exige prévia completa, destinos explícitos e confirmação do
digest exibido. Não confirmar automaticamente sugestões nem converter ao abrir.
Expor erros/suspensão/reconciliação e locks pelo serviço, sem desbloquear à força.
Respeitar publicação pós-commit, cena passiva/install/activate, pausa e a mesma
instância de serviço em falha incerta. Evitar novos Nodes de UI no grafo capturado:
nenhum runtime kind/estado persistente novo está autorizado por este despacho.

Não criar economia/lojas/consumíveis, quests completas, classes, multiplayer,
assets low-poly, política de autosave ou migração de checkpoint entre builds.
Limites atuais: snapshot/perfil4 MiB, revisões exatas, captura/escrita síncronas
com custo material; não prometer FPS, escala ou fluidez a partir dos checks.

## Transferência exclusiva de arquivos

Coordenação encerra sua escrita do runner após validar esta composição. F7 recebe
sequencialmente de F1–F6, somente para UI/apresentação e wiring autorizado:

- `scripts/ui/character_menu.gd`;
- `scripts/ui/run_inventory_panel.gd`;
- `scripts/ui/reward_feedback_panel.gd`;
- `scripts/ui/battle_controls.gd`;
- `scripts/main.gd` (entrada/saída, sinais e ligação de UI, sem reimplementar core);
- `scenes/character_menu.tscn`;
- `scenes/main.tscn`;
- `scripts/world/expedition_portal.gd` (apresentação, preservando regras F5);
- `scripts/world/expedition_geometry_view.gd` (apresentação, preservando geometria F1);
- `tools/verify.ps1` (registro/seleção de testes F7, sem relaxar falhas).

Respectivos .uid seguem os scripts. Nenhum outro escritor paralelo possui esses
arquivos. Não refatorar funções alheias ao resultado só porque o caminho está na lista.

Novos caminhos exclusivos:

- `data/expedition/phases/**`, `data/expedition/parts/**`,
  `data/expedition/populations/**` (conteúdo sobre contratos reais);
- `scenes/expedition/**`, `scripts/ui/expedition/**` e .uid próprios;
- `tests/e07_f7_*.gd`, .uid e `tests/fixtures/e07/f7/**`;
- `docs/epics/e07/f7_api.md`, `f7_checkpoint.md`, `delivery/f7.md`;
- seção F7 de `docs/epics/e07_tasks.md` e `docs/epics/e07.md`, somente estado da entrega.

Demais fontes/fixtures/testes de F0–F6 são leitura/execução. Perfil/codec/store,
serviços de expedição, geometria/ameaça, manifesto/adaptadores de snapshot,
catálogos/fórmulas e políticas existentes não são transferidos a Terra.
Se faltar primitiva, registrar reprodução e delta delimitado para Sol/coordenação;
não duplicar a regra em UI. Transferência nominal deve anteceder edição externa.

## Verificação e entrega

Godot4.7.2 standard:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe`.
Usar runner próprio, `-List`, novos testes F7 e regressão por impacto, inclusive
`e02_character_menu_test`, `menu_tabs_test`, `e06_inventory_profile_panel_test`,
`e06_inventory_window_input_test`, `e07_f2_migration_test`, `e07_f4_restart_test`,
`e07_f5_campaign_test`, `e07_f5_build_test`, `e07_f5_recovery_test`,
`e07_f6_runtime_test` e `verification_profile_isolation_test` quando consumidos.
Não modificar expectativas existentes sem adendo nominal/justificativa contratual.

Bootstrap conhecido: executar `e07_f1_import_test` pelo runner; ele importa cópia
nativa de fontes reais. Única diferença de configuração: autoload VCS desligado
na cópia. Depois `-F1Fixture -SkipEditorImport` para testes de gameplay; manter
manifestos/hashes. O import comum pode falhar por GitPlugin indisponível: registrar
esse limite, não relaxar erro ou copiar configuração para o checkout pessoal.

Renderer/UI requer inspeção nativa da amostra, seleção/retorno, migração completa,
modal de erro, portais/ameaça e duas seeds; preservar capturas/inputs/reprodução.
Luna supervisiona lote automatizado delimitado, executor corrige e consolida
comportamento sobre APIs estáveis. Questão de core vai a Sol, sem gate Astra
rotineiro. Nenhuma publicação ou confirmação no save pessoal para obter prova.

Entregar commits próprios, SHA real, APIs/recibo, testes/logs/hashes e capturas,
limitações e roteiro humano. Não atualizar playtest/master, fazer push ou iniciar
F8 por conta. Arquivar somente após entrega validada e integrada; correções
reutilizam este chat. CLI de workflow ausente: diagnóstico por Git/contratos,
sem instalar ou inventar uma CLI para contornar isso.
