---
name: ragrpg-equipmentdelivery
description: Preparar ou entregar equipamentos, conjuntos, cartas e encaixes autorizados do RagRPG, integrando composição, loot, inventário e persistência. Pode preparar contratos futuros de consumíveis, misc e vendedores quando solicitados; não os implementa por inferência.
---

# Entregar equipamentos e itens do RagRPG

Resolva a raiz Git do checkout informado/cwd, confirme `project.godot` e leia
AGENTS.md, docs/WORKFLOW.md, docs/MVP.md, docs/ARCHITECTURE.md,
docs/epics/e06_contract.md e contrato/checkpoint do pacote. Para consumíveis,
misc ou comércio, leia também docs/PRODUCT_DIRECTION.md. Caminhos são relativos
ao projeto, não à instalação. Skill e reserva não iniciam novo marco/chat.

## Definir qual camada muda

Separe autoria de receita, nova capacidade de efeito, exemplares/migração,
loot/poder, UI/arte e economia. Registre IDs, origem, qualidade, ilvl, slot/mãos,
encaixes, conjunto, capacidades e consumidores, exclusões e donos por arquivo.
Não converter proposta de conteúdo ou receita de fixture em produção sem contrato.

Reutilize `EquipmentDefinition`, `CardDefinition`, `EquipmentInstance`,
`EquipmentRules`, `EquipmentEligibilityRules`, `EquipmentPowerRules`,
`BuildEffectCatalog`/`BuildEffectComposer`, `RunBuildService` e `ProfileFacade`.
Para aquisição, confira `MobLootResolver` e `RunRewardService`. Verifique nomes/
assinaturas no checkout; UI consome prévia canônica, não fórmulas de preço/poder.

## Regras atuais a preservar

Decisão18/10 em docs/PRODUCT_DIRECTION.md: itens/gold pertencem ao personagem,
unlocks ao perfil. Compartilhamento do runtime E06 é legado a migrar, não regra
futura. Antes de código, fechar destinação de exemplares/cartas/referências de
alts sem duplicar, apagar ou atribuir silenciosamente; não migrar save pessoal.
Venda confirmada de peça com cartas remove também cartas encaixadas após aviso;
desencaixe anterior preserva cartas. Não devolver automaticamente na venda.

- Equipamentos são exemplares permanentes; receita, exemplar e seleção são
  identidades diferentes. Não fundir cópias ou reprecificar poder legado ao
  atualizar catálogo. Preservar revisão/ruleset de poder do exemplar.
- Cartas/encaixes também são permanentes. Cópias iguais são permitidas; uma
  instância não pode ocupar dois encaixes. Encaixes ficam na peça ao desequipar;
  somente hosts equipados compõem efeitos. `RunCardInventory` é nome legado,
  não autorização para apagar cartas no fim da run.
- 14 posições; duas mãos bloqueiam secundária. Encaixes 0–4 são eixo independente
  da qualidade e somente tipos elegíveis recebem cartas; foco/joia não recebem.
- Incomum somente stats. Cartas nunca concedem ativa acionável. Base de espécie
  normal/rara permite stats/buffs; efeitos qualitativos/procs interessantes
  dependem de espécie base elite+, não de variante elite de uma espécie comum.
- Ativas de item só nas capacidades suportadas; não aprendem rank permanente.
  Capturar arma realmente usada para proc de arma. Remover fonte não zera CD
  nem apaga atalho; não conceder biblioteca inteira por um item de outra classe.
- Exclusividade por chave semântica, acessórios idênticos incompatíveis;
  conjuntos contam peças legais distintas e emitem uma fonte por limiar.
  Tags e flavor não são efeitos implícitos. Não fixar raridade/taxa por referência
  a outro jogo; consulte políticas de produção aprovadas.

Troca valida posse/slots/conflitos/recursos/sessão e revisão em cópia antes de
salvar. Conserva déficits HP/SP, recargas, recursos de classe e emissões em voo.
Confirmação durável precede publicação; falha/pending conserva a mesma intenção
para reconciliação. Aquisição usa ticket/RNG congelado, sem reroll/duplicação.
Migração valida envelope histórico e preserva backup, desconhecidos e compras.
Use perfis temporários; não testar no save pessoal nem criar segundo writer.

## Fronteiras futuras

Vendedores de lobby/gold, consumíveis e trash/misc são direção futura. Antes de
código, fechar propriedade/persistência de gold/estoque, preços e transações.
Decisões18/10: sem peso/capacidade de bag, pilhas sem limite de gameplay,
equipamentos não empilháveis e itens de quest não vendáveis. Vendedores oferecem
básicos/raros limitados, nunca conjuntos/épicos/lendários; consultar direção atual.
Não presumir API pronta
porque há abas vazias. Venda/compra deve ser transação única de item+gold com
replay/revisão e falha sem saldo ou item parcial.

Regra aprovada de poção: após uso, reutilização exige CD longo terminado **e**
saída daquele combate; sair cedo não zera CD. HP/SP têm uso separado; variantes,
duração, relógio, reentrada/morte e autoridade do combate exigem contrato.
Para expansão/profissões, ler docs/gates/consumables_professions.md. Não permitir
reset por troca/menu/portal ou interpretar como spam a cada timer dentro da luta.
Misc pode servir a missão/venda, sem inventar sistema de quests neste lote.

## Validar e fechar

Inclua testes que exercitem a mudança: instâncias/cópias,0/4 encaixes, mãos,
exclusividade/conjuntos, cartas repetidas, poder legado/novo, grants/remover/CD,
troca extrema sem cura, loot/retry/incerto, migração/backup e preview=combate.
Selecione `tools/verify.ps1` por impacto conforme docs/TESTING.md, com lista de
IDs conferida. Mudanças de descoberta/export exigem prova PCK release; editor
sozinho não detecta .tres.remap ou inicialização indevida dentro de assert.
Inventário/tooltip/anexos precisam de inspeção nativa; arte usa pipeline existente.

Entregue contrato/IDs/recursos, SHA, evidências/limitações e roteiro no checkpoint.
Luna acompanha testes; Sol corrige/valida; Astra somente arquitetura/exceção.
Não obrigar suíte integral por receita ou documento. Documento apenas declara
gameplay não executado; publicação/merge/arquivamento seguem WORKFLOW e autorização.
