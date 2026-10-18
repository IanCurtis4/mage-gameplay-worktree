# E06 — contrato vigente consolidado

17/10/2026. Substitui como entrada a v1 e seus cabeçalhos sobrepostos, preservados
no [histórico](e06_contract.history_2026_10_17.md). Os contratos de rodada abaixo
mantêm detalhes executáveis; decisões mais recentes substituem apenas seus deltas.
Norma operacional: [WORKFLOW](../WORKFLOW.md), sem gate Astra de fechamento.

## Decisões que substituem a v1

| Assunto | Regra vigente | Fonte |
|---|---|---|
| Cobertura | Dez identidades jogáveis, incluindo evoluções e Geômetra; cinco híbridas futuras continuam bloqueadas | [MVP](../MVP.md) |
| Coleção | Equipamentos por exemplar, com identidade persistente; não conjunto sem cópias | [TX/API](e06/e06_tx_api.md) |
| Slots |14 posições, mãos compatíveis; duas mãos bloqueiam secundária | [Itemização](e06/itemization_execution.md), [TX/API](e06/e06_tx_api.md) |
| Cartas | Exemplares permanentes, repetição permitida; encaixes na peça sobrevivem à run e ao desequipar | [Correções13/10](e06/e06_playtest_fixes_contract.md) |
| Encaixes |0–4, eixo independente da qualidade; apenas tipos elegíveis (armadura/arma/escudo), não foco/joia | [TX/API](e06/e06_tx_api.md) |
| Natureza da carta | Sempre passiva, nunca botão ativo. Base normal/rara: stats/buffs; transformação/proc interessante depende de espécie base elite+ | [Itemização](e06/itemization_execution.md) |
| Qualidade/efeito | Incomum somente stats; raro+ pode ter efeito autorizado. Ativas por item apenas nos casos suportados; tags não inventam efeito | [TX/API](e06/e06_tx_api.md) |
| Loot | Por mob, com ticket congelado; substitui recompensa de equipamento/carta da etapa. XP/augment por etapa continuam | [TX/API](e06/e06_tx_api.md) |
| Nível e força | Origem fixa, sem scaling pelo jogador; poder do exemplar preserva ruleset/revisão | [Poder/loot](e06/e06_balance_scope.md) |
| Causalidade | Planos finitos por emissão, sem cascata/dedup reaberto; cap16 legado não é teto global da build atual | [TX/API](e06/e06_tx_api.md) |
| Habilidades |24 atalhos, passivas automáticas, requisitos/custos/ranks canônicos e aprendizado separado de grants de item/admin | [Dependências](e06/e06_all_skill_dependencies_scope.md) |

## Invariantes de execução

Definições de catálogo são imutáveis; estados de perfil/personagem/run são
separados. `BuildEffectComposer`, `SkillEffectResolver`, `StatCalculator` e
`CombatMath` são as autoridades comuns de preview e combate. Não criar fórmula
ou handler paralelo no ator/UI nem mudar receitas existentes silenciosamente.

Augments são transitórios. Oferta estável com tokens/revisão, até3 opções
elegíveis distintas; confirmar revalida e consome uma pendência uma vez. Pool
vazio tem resolução explícita, sem softlock; fechar/reabrir não rerrola. Menu
normal fora de encontro, com pausa; admin tem exceção explícita própria.
Habilidade alvo deve ser utilizável pela biblioteca/rank, sem depender de estar
na barra. Ganho efetivo/conflitos/caps são conferidos pelo mesmo compositor.

Equipamento/cartas são permanentes. O runtime E06 compartilha pelo perfil;
decisão18/10 substitui a direção por **itens/gold por personagem, unlocks por
perfil**, conforme [direção de produto](../PRODUCT_DIRECTION.md). A migração
precisa de contrato e autorização próprios; não reinterpretar saves existentes.
Cópias físicas
têm IDs próprios. Uma carta não ocupa dois encaixes; cópias distintas da mesma
receita podem acumular conforme contrato. Desequipar conserva encaixes e apenas
hosts equipados contribuem. Troca/remoção/transferência valida a intenção inteira
fora de combate, sem mutação parcial, cura ou reset de cooldown.

Exclusividade usa chave estável, não nome traduzido. Acessórios idênticos são
incompatíveis; conjuntos contam peças legais distintas e publicam uma fonte por
limiar. Proc de arma exige arma efetivamente usada na emissão. Remover item
não apaga atalho nem reinicia recarga; grant não compra rank ou biblioteca inteira.

Loot congela item/carta/RNG/origem em ticket. XP, item, carta e journal são
confirmados duravelmente na mesma transação; retry não rerrola/duplica.
Resultado incerto exige reconciliação. Carta depende da espécie base; tier da
ocorrência altera chance, não sua receita. Lendário somente de boss, garantias
de qualidade substituem o mínimo em um item, não adicionam item por inferência.
Rates e curvas de produção vêm do contrato de poder/loot, nunca de fixtures.

Schema observado7/catalog14; não resetar save, reconstruir cartas já perdidas
ou recalcular retroativamente poder de exemplares legados. As migrações recentes
validam a versão histórica antes de converter e preservam compras/grants legítimos.

## Extensões já entregues e fontes

- [Cartas permanentes, conjuntos, aparência e janelas](e06/e06_playtest_fixes_contract.md).
- [Seis etapas, aggro/leash, tiers e companheiro finito](e06/e06_gameplay_extension_contract.md).
- [Dependências de93 habilidades](e06/e06_all_skill_dependencies_proposal.md).
- [Admin de perfil/run](e06/e06_admin_extension_contract.md): concessões separadas de produção;
  spawns de teste sem XP/loot/crédito, augments transitórios, skills somente legais.
- [Exportação release](e06/e06_export_profile_hotfix.md): .tres.remap e inicialização
  fora de assert; import no editor não basta para validar PCK.

O antigo lote12equipamentos/6cartas era piloto. Contagens atuais devem vir do
catálogo/recibo correspondente, não virar quota universal das skills de entrega.
Mapas gerados, vendedores, consumíveis e misc: [direção futura](../PRODUCT_DIRECTION.md).
Este contrato não inicia E07 nem implementa a nova propriedade individual.
Preservar evidência dos contratos anteriores sem restaurar compartilhamento
como requisito futuro de produto.
