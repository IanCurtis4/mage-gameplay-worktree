---
name: ragrpg-enemydelivery
description: Preparar ou entregar espécies, ocorrências e populações autorizadas de inimigos do RagRPG, com AI, progressão por origem/bioma, loot e leitura em combate. Não usar para apenas desenhar um monstro sem integração de gameplay.
---

# Entregar inimigos do RagRPG

Resolva a raiz Git do checkout informado/cwd e confirme `project.godot`.
Leia AGENTS.md, docs/WORKFLOW.md, docs/MVP.md, docs/ARCHITECTURE.md,
docs/PRODUCT_DIRECTION.md, docs/epics/e06_contract.md e contrato/checkpoint
autorizado. Caminhos são da raiz do projeto. Não iniciar E07, criar chats ou
produzir catálogo inteiro por efeito de invocar esta skill.

## Separar os eixos de conteúdo

Registre espécie base, fantasia/bioma, silhueta, ficha, habilidades e contrajogo;
separadamente ocorrência, origem/nível, tier, população e loot. Confira
`MobDefinition`, `MobOccurrence`, `MobCatalog`, `MobTierRules`, `MobSkillAdapters`,
`EnemyActor`, `MobLootResolver` e autoridades canônicas de dano/stats.
Receita de AI sobre primitiva pronta difere de sistema novo: não simular nova
habilidade só com metadata, nem duplicar fórmula no ator ou na ficha descritiva.

Normal/raro/elite/elite raro/chefe são categorias de ocorrência com restrições
da espécie. Mob não escala automaticamente com o nível do jogador. Origem da
campanha resolve nível e loot de modo coerente; mapa avançado contém inimigos
mais fortes ainda temáticos. Não contar dificuldade três vezes em ilvl/raridade/
multiplicador sem contrato. Carta aponta espécie base: variante elite de comum
não muda sua receita/capacidade, apenas chance conforme tabela aprovada.

## Comportamento e exposição

Defina aquisição/visão, aggro, perseguição, alcance, preparação, aviso, ataque,
controle, leash/retorno, morte, pausa e limpeza. Reuse adaptação existente de
Hunter/taunt/CC e exceções de boss; sem telepatia da AI através de ocultação ou
geometria. Retorno não cura nem repõe convocação consumida por inferência.

Summons precisam de limite, dono e regra explícita de morte/recompensa. No
contrato atual do Mestre, animal é finito, inferior, sem recursão/loot/XP/ticket
independente e não impede conclusão; não aplicar universalmente essa receita a
toda espécie futura. Spawn admin também não vira recompensa de produção.

Para população, mapas vizinhos do mesmo bioma compartilham espécies e deslocam
pesos/concentrações gradualmente; transição de bioma pode romper o gradiente.
Os exemplos 100 géis/50 lunáticos e 60 géis/80 lunáticos são proporções ilustrativas,
não quotas simultâneas ou nomes de catálogo aprovados. Distribuição espacial,
áreas seguras, encontro/portal, respawn e budget ativo precisam de contrato.
Audite múltiplas seeds, mantendo seed/revisão reproduzíveis; não exigir pesos
exatos em cada amostra aleatória. Coordene com ragrpg-mapdelivery quando mapas
mudarem, com API estável/donos e sem disputar `main.gd` ou navegação.

Elevação futura afeta rotas; linha de visão entre alturas ainda exige contrato.
Não certificar AI multialtura somente porque navegação 2D passa. Números de
população total não são número de atores simultaneamente simulados.

## Recompensa, apresentação e prova

Loot/XP pertencem a eventos reais identificados. Claim antes de callbacks,
ticket/RNG congelado, retry sem duplicar. Não conceder simultaneamente o mesmo
loot por mob e por etapa; augment continua no fluxo de etapa. Usar produção
aprovada, não taxa de fixture. Ficha, tooltip e ataque derivam das mesmas regras.

Arte deve mostrar espécie/tier, orientação, telegraph, impacto e morte sem
mudar hitbox para corresponder ao desenho. Reutilize contratos de atlas/pivô
e ragrpg-art quando pertinente; raster IA usa imagegen. A prova de combate
tem AI ativa e terreno real, sem inflar HP/refill para alegar viabilidade.

Testes por impacto via `tools/verify.ps1`/docs/TESTING.md: origem/nível/tiers,
habilidades suportadas, LoS/aggro/leash, ocultação/taunt/CC, summons, morte/limpeza,
loot/replay, seed/pesos e progressão temática. Testar extremos de RNG e categorias
restritas; clocks dependentes de delta precisam das taxas pertinentes. Renderer
confere leitura e contrajogo; medir população ativa/desempenho quando relevante,
sem apresentar checks como FPS/diversão.

Checkpoint reúne ficha/contrato, base/SHA, consumidores, evidências, limitações
e próximo passo. Luna supervisiona; Sol corrige/consolida; Astra só arquitetura
ou exceção justificada. Documento apenas confere coerência e não repete gameplay.
Playtest, merge e arquivamento continuam sujeitos ao WORKFLOW e escopo autorizado.


## Intercâmbio no editor de mapas F7

Use population/patrol para encontros e rotas sobre espécies existentes. O pacote não autoriza espécies, loot ou políticas novas.
Leia `docs/map_editor/exchange.md` no checkout autorizado para schema, CLI e limites.
Receba o pedido `.rpx` exportado pela pessoa, preserve-o byte a byte e trabalhe
numa cópia de `files[source.json].data`. Não edite ticket, base, permissões ou
relatório para ampliar o escopo. Declare o hash do pedido/base e os IDs que vai
alterar. As seções/IDs e caminhos protegidos são autorização local; camadas
travadas, regiões protegidas, slots fixos e pins permanecem conservados.

Produza candidate.json estrito e rode a CLI versionada `propose <pedido.rpx>
<candidate.json> <proposta.rpx>` com o Godot contratado. O produtor valida/compila;
falha conserva o original, sem scripts/cenas, paths absolutos/traversal ou
reparo silencioso. Confira `review <pedido.rpx> <proposta.rpx> <fonte_atual.json>`
e entregue proposta, diff, hashes e limitações. Base divergente exige novo pedido
exportado/reconciliação humana explícita. A pessoa importa a proposta no editor,
compara Antes/Proposta e confirma uma ação desfazível. Não sobrescreva a fonte
humana, não publique nem ative o WFC por inferência. A mesma autoridade atende
GUI/CLI. Essa adaptação da fonte versionada não sincroniza cópias instaladas.
