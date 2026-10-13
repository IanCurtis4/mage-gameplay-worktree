# E06 — proposta concreta de integração preservadora

13/10/2026. Consulta arquitetural Astra/low somente leitura, sem testes/auditoria. Sol conferiu a constatação: EquipmentInstance serializa seis campos totais; a composição resolve receita pelo definition_id. Atualizar os12 IDs ativos com as receitas do piloto aumentaria retroativamente o poder de todos os exemplares históricos. Metadata igual não preserva poder. O bundle offline69 e seus digests continuam congelados; publicação terá manifesto próprio.

## Opção recomendada: novas definições, legado intacto

Manter os12 IDs antigos com suas definições ativas atuais, sem novos stats/efeitos. Publicar suas receitas elaboradas sob12 novos IDs. Nenhum exemplar, instance_id, personagem ou preset existente é remapeado. Referências compartilhadas entre alts permanecem. Novas aquisições podem apontar às novas definições quando o roteamento for autorizado, sem alterar taxas agora.

| ID histórico preservado | ID proposto para nova receita |
|---|---|
| starter_blade | arena_starter_blade |
| starter_staff | arena_starter_staff |
| starter_bow | arena_starter_bow |
| traveler_vest | arena_traveler_vest |
| traveler_charm | arena_traveler_charm |
| riposte_blade | arena_riposte_blade |
| ember_staff | arena_ember_staff |
| hunters_bow | arena_hunters_bow |
| warden_mail | arena_warden_mail |
| channeler_robe | arena_channeler_robe |
| trailcoat | arena_trailcoat |
| prismatic_charm | arena_prismatic_charm |

Esses IDs são proposta, não migração aplicada. Conjuntos/builds novos terão referências remapeadas (ex.: arena_warden_mail); receitas mantêm efeitos/curvas aprovados. Qualidade5comuns/7raros, ilvl1/demo_arena, sockets1armas/armaduras0acessórios dos12 equivalentes continuam conforme tabela humana. Demais peças novas do piloto guardam seus metadados próprios.

Variante mínima recomendada: cinco starters antigos continuam padrões, também para novos personagens; os cinco equivalentes novos não são starters e ficam disponíveis como nova aquisição. Não duplicar starter=true: ProfileCatalog rejeita dois padrões na mesma origem/posição. Saves antigos não recebem item novo pela migração.

Acessório antigo e equivalente novo têm identidades distintas e podem coexistir. Antigo é neutro, portanto não duplica os efeitos elaborados; duas cópias novas de mesma definição continuam bloqueadas, assim como peças novas com mesma identidade de efeito. Bloquear também par histórico/novo exigiria grupo explícito de exclusividade; não acrescentar essa regra silenciosamente.

## Alternativas

1. Novos IDs com starters elaborados para novos personagens: mantém preservação dos antigos, mas precisa separar escolha de starters atuais da histórica usada por ProfileCodec._add_inventory_starters; não mudar a lista indiscriminadamente durante migração. Exige contrato/teste adicional desse roteamento.
2. Mesmos IDs com versão de receita por exemplar: exige campo persistido, migração inclusive de saves que já têm instâncias, default inequívoco de receita histórica, catálogo indexado por ID+versão e resolução consistente de efeitos/conjuntos/grants/preview. Ainda conserva receitas antigas. Benefício: mesma identidade técnica; custo e superfície de falha maiores.

## Critério de execução após decisão

Mapear publicação explicitamente e gerar manifesto/digest novos, sem reescrever evidências69. Provar composição antiga sem bônus novos; nova equivalente ao piloto remapeado; migration/roundtrip de instâncias e referências compartilhadas; starter por contexto; acessórios/conflitos; sockets; referências de conjunto/build; aquisição apenas dos IDs esperados. Não publicar enquanto a variante de produto não estiver escolhida.

Fonte principal de implementação futura: BuildContentLoader, ProfileCatalog/Codec, EquipmentRules/BuildEffectComposer e manifesto de dados. Nenhuma edição desses consumidores nesta proposta. Sem taxas/progressão, save/schema novo pela variante mínima, campanha/E07, push/merge ou aplicação no checkout fixo.

Decisão humana requerida: escolher variante de identidades/starters e confirmar regra visível de antigo/novo no mesmo equipamento. Estado DECISÃO_PENDENTE; direções T3 seguem em paralelo independente.
