# E08 P4 — triagem e prova atual da interface por Sol

6/11/2026. **Subentrega técnica concluída; P4 permanece INCOMPLETO.**
Pedido humano: conferir o checkpoint parcial e assumir a complexidade possível.
Base Terra 6389edcdb7d145e4721b9504ba2876173d4d6a68; branch codex/e08,
checkout C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
Terra está parado. [Posse/escopo Sol](e08_p4_sol_contract.md).
Não houve alteração a runtime, assets, testes antigos, regras ou save pessoal.
O release jogável continua ad09b99d; esta subentrega não é um novo PCK.

## O que Sol entregou

- Causa raiz das sondas históricas: cartas sem owner_character_id causavam
  invalid_owner; ActionBarEditor.library é handle vazio intencional; a sonda
  game comprava habilidades sem satisfazer dependências e procurava um antigo
  ancestral ScrollContainer. Erros de sonda não provam defeito do jogo.
- Nova tools/e08_p4_ui_probe.gd com tools/run_e08_p4_sol_probe.ps1: UI atual de
  dez identidades, perfil persistido/reaberto, cartas e equipamentos por dono,
  atribuição e movimentação pelos payloads/handlers atuais, clique direito real,
  configurações abertas por clique e fechadas por Escape. UI120%,1280×720.
  Slots do menu são alcançados pela rolagem atual; conteúdo total maior que a
  janela não é falha quando cada slot pode ser alcançado sem corte.
- O desbloqueio de todas as skills usa PlaytestProfileAdmin.grant existente,
  explicitamente como fixture administrativa. Não afirma compra simultânea de
  todos os ranks num perfil normal nem altera carteiras ou pré-requisitos.
  Geômetra usa ID de evolução mg_ar; geometer é seu tipo visual.
- Inventário rastreável dos16 recursos de inimigo e hashes dos atlas existentes;
  auditoria reproduzida de24/56 grips sem pixel opaco na candidata Espiritualista.
  Não mover âncora para tecido para maquiar mão ausente. Arte candidata preservada.
- [Contrato técnico direcional](e08_p4_directional_contract.md): V2 com64poses,
  quatro vistas próprias, compatibilidade V1, um descritor comum para corpo,
  anexos/dedos/cabeça/morte e nenhuma mudança de simulação. Ainda não implementado.

## Evidência e validação

[Manifesto](e08_evidence/p4_sol/hashes.json),
[ZIP portátil](e08_evidence/p4_sol/evidence.zip),
[conferência Luna](e08_evidence/p4_sol/supervision.md).
ZIP74membros/16.875.379B, SHA256
3bff2cc958b7f996fc3fcace41e3f09df8a6dc089d74a9bd81576ba9ac2b001c.
Inclui32PNG finais, scripts exatos testados, stdout/stderr, resultados,
manifestos e tentativas históricas; não inclui perfis ou saves de teste.

Nativo final: **764checks,10identidades,32capturas,0falhas**, exit0 sem
SCRIPT ERROR/ERROR/timeout. Renderer Compatibility, GTX1080, driver582.66.
Não é arrasto físico: chamada do protocolo de drag/drop; clique direito e
clique/Escape de configurações entram pelo viewport nativo. Inspeção visual Sol
amostral de menu, inventário e jogo; não carimbo artístico das32imagens.

Verify.ps1 -F1Fixture: **4/4etapas,6.433checks,0falhas**, exit0 sem timeout:
e08_characters710, equipment_hand_alignment4593, e06_icon_bar24,
e06_admin_profile1106. Este último emite WARNING de2ObjectDB não liberados na
saída; registrado sem atribuir a uma mudança de runtime que não ocorreu.
Não repetida a suíte completa313etapas nem as14etapas do piloto por rotina.

Bootstrap F1 PASS:2.332fontes. Mesma fixture reutilizada. Durante desenvolvimento,
a sonda nova recebeu três atualizações explícitas com hashes antes/depois,
preservadas em cada tentativa; manifesto original do bootstrap não é anunciado
como manifesto final. Verify e conferência Python/Luna confirmaram todas as
2.332fontes finais byte a byte, origem/fixture, e a única diferença project.godot
é VCSautoload. Engine standard4.7.2 e quatro backups conferidos.
CLI workflow/WORKFLOW_TOOLING continuam ausentes; diagnóstico Git/documental.

Tentativas falhadas preservadas:1 reteve botão liberado por reconstrução da UI e
exigiu indevidamente conteúdo total de scroll dentro da janela;2 esgotou pontos
numa fixture tentando aprender todos os pré-requisitos;3 usou IDgeometer em vez
de mg_ar. Foram corrigidas as sondas/fixtures, sem mudar runtime ou oráculos.
Apenas a tentativa final é PASS. Não houve timeout nesses processos novos.

Luna confirmou74/74membros, fontes/engine/tools/backups, conclusão/logs/hashes,
sem rerun nem auditoria semântica/artística independente. Sol consolidou as
causas no código, inspecionou imagens amostrais e delimitou o escopo restante.

## Pendências reais e entrega possível por Sol

**Sol pode assumir o produtor compartilhado para quatro direções e a integração
de equipamentos. A dificuldade é delimitável e não exige repassar a Terra uma
API ainda indefinida.** Antes de código, registrar SHA e arquivos exatos do
produtor conforme contrato direcional; manter Terra parado nessa fronteira.
Depois integrar primeiro UMA identidade com arte e rig completos e então
replicar às demais, preservando os consumidores inimigos dos atlas compartilhados.

Há lacuna concreta adicional: InventoryCharacterPreview._draw_actor chama só
CharacterAnimation.draw_on; não chama EquipmentHeadVisual. O capacete pilot_head
está equipado no perfil da captura, mas não aparece no retrato. Portanto povoar
slot/capturar UI não aprova capacete. O descritor compartilhado deverá permitir
cabeça e anexos consistentes entre ator e retrato; não duplicar uma heurística
independente só para a prova passar. Nenhuma correção aplicada ainda.

Terra continua responsável por identidades distintas (especialmente
Elementalista/Espiritualista), fontes com mãos adequadas e poses laterais,
calibração revisável e acabamento sobre produtor estabilizado. A candidata
atual não oferece essas quatro vistas nem calibração válida. Não promovida.

Também pendem duas mãos/escudo/cabeça em todas as poses, transições/morte,
zoom real50/100/160, oclusão em cenários e inspeção completa de todos os conjuntos
de ícones/equipamentos. Capturas atuais são de treino/menu, não campanha jogada.
Não houve medição de custo de renderer novo porque nenhum foi implementado.

P4 NÃO está entregue/integrado; P5 continua bloqueado. Chat Terra não arquivado.
Habitual codex/playtest, alterações locais, saves, quatro .bak e fontes históricas
preservados. Sem master/push/terceiro checkout ou exportação volumosa adicional.
