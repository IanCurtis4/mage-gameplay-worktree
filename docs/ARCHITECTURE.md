# Arquitetura vigente — índice de autoridades e contratos

## Delta do editor F10 — 4/11/2026

F10 está ativo; Q5 em revisão, sem fechamento técnico ou aceite humano final.
O [contrato de grade Q1](map_editor/contracts/f10_height_grid.md) substituiu o
limite de 4 MiB apenas nos formatos contratados: envelope de snapshot até 16 MiB,
checkpoint format 2 comprimido e pacote de patrulha até 8 MiB. Outros codecs
conservam seus próprios limites. Geometria/corpo/LoS continuam canônicos.

O [consumo](map_editor/consumption.md) compõe fases autoradas e fixa a revisão
visual por estágio; a instalação reconstrói a vista descartável a partir desse
pacote, sem pôr o pacote visual no grafo salvo ou ler fontes de autoria.
Q5 corrige a coleta automática no limite do diário usando a barreira, o
checkpoint e o writer já existentes. Não há segundo writer nem novo formato de
diário. Evidências e limites no [checkpoint F10](map_editor/delivery/f10.md).

Q5 pode consumir árvores positivas de preparação em `.navproof`, vinculadas à
revisão RPP e verificadas geometricamente em mundos novos. A autoridade
`PreparationProofCache` não carrega estado de run nem vereditos persistidos;
pedidos sem cobertura usam a busca anterior. Contrato e limites:
[provas completas](map_editor/contracts/f10_preparation_proofs.md).

## Composição técnica E07 —23/10/2026

[F8](epics/e07/delivery/f8.md) consolida F0–F7 sobre runtime 7775f44: geometria com
altura, posse por personagem/schema8, conservação/durabilidade, ciclo, ameaça e UI
com amostra ramificada. Captura aguarda somente descarte pendente; elegibilidade
valida fonte viva; digest resolve recursos remapeados no export. Format1, revisão
estrita e limites de 4MiB preservados; sem migração de grafo entre builds prometida.
APIs permanecem nos recibos dos produtores. Custos síncronos de 8–15s foram medidos;
a leitura de 17/10 abaixo é histórica onde descreve essas fronteiras como futuras.

Consolidado em 17/10/2026 sobre `5beea5cd0c70813fbb85207e18bd249dd89c8384`.
É leitura do runtime e dos contratos existentes, sem nova implementação.
O relato anterior por pacote está no [histórico](ARCHITECTURE.history_2026_10_17.md).

## Precedência e leitura

[WORKFLOW](WORKFLOW.md) rege execução, validação e integração. [MVP](MVP.md)
resume o produto existente; [PRODUCT_DIRECTION](PRODUCT_DIRECTION.md) rege o
planejamento futuro de mapas/economia. [Contrato E06 consolidado](epics/e06_contract.md)
substitui as regras revogadas de sua v1, com links aos contratos executáveis.
[E00](E00_CONTRACT.md) conserva os fundamentos nos pontos não substituídos.
Históricos e recibos registram o que foi feito naquela versão, não liberam escopo.

## Autoridades de runtime

| Domínio | Autoridades existentes / obrigação |
|---|---|
| Atributos e progressão | `StatCalculator`, `ProgressionRules`; marcos/custos em [STAT_THRESHOLDS_PLAN](STAT_THRESHOLDS_PLAN.md) |
| Biblioteca, ranks e atalhos | `ProfileCatalog`, `BuildSnapshot`; [barras/passivas](SENTINEL_ACTION_BARS_PLAN.md) e [dependências](epics/e06/e06_all_skill_dependencies_scope.md) |
| Dano e aplicação | `DamageRequest`, `CombatMath`, `HealthState`; fórmula única, defesa/mitigação canônicas e callbacks após claim |
| Efeitos de build | `BuildEffectCatalog`, `BuildEffectComposer`, `SkillEffectResolver`, `BuildPresentation`; preview e execução usam a mesma composição |
| Causalidade | `EffectProcLedger` e contexto por emissão; planos finitos, deduplicação e descendentes secundários sem cascata |
| Equipamento e poder | `EquipmentInstance`, `EquipmentRules`, `EquipmentEligibilityRules`, `EquipmentPowerRules`; exemplares e regras imutáveis de poder |
| Inventário e trocas | `ProfileFacade`, `RunBuildService`, inventário de cartas no perfil; mudanças atômicas, sem cura/recarga implícita |
| Persistência | `ProfileState`, `ProfileCodec`, `ProfileStore`; um writer, revisão/recibos, backup/pending preservados e reconciliação |
| Recompensas | `RunRewardService`, resolvers e tickets congelados; retry não rerrola nem reconcede |
| Mobs e loot | `MobDefinition`, `MobOccurrence`, `MobCatalog`, `MobTierRules`, `MobLootResolver`; espécie/ocorrência/origem separadas |
| Roteiro atual | `PlaytestGameplay`, `RunController` em `scripts/main.gd`; seis etapas/três áreas predefinidas |
| Navegação atual | `ArenaNavigation`; coordenadas 2D, segmentos revalidados, raio inflado e obstáculos temporários |
| Apresentação | UI observa DTOs; geometria de mira/impacto compartilhada, atlas/anexos não causam dano |

Os nomes desta tabela existem no candidato inspecionado. Projetos futuros de
gerador, superfícies em alturas, vendedores e consumíveis ainda não são APIs.

## Invariantes que consumidores devem preservar

Resources são definições imutáveis. No runtime observado, perfil contém progresso
e posses compartilhadas; personagem contém preferências/identidade. **Decisão
humana18/10 substitui esse compartilhamento futuro: itens e gold por personagem,
unlocks por perfil.** Migração ainda não implementada; contratar destinação dos
exemplares/encaixes e referências de alts antes de alterar save. Um arquivo de
perfil pode armazenar bens individuais sem torná-los compartilhados.
Transferências entre personagens ficam fora do escopo; cada um conquista seus bens.
Run contém augments, escolhas, efeitos, relógios e instâncias efêmeras. Cópias
runtime não mudam propriedade. `RunCardInventory` não torna cartas temporárias.

Schema 7/catalog 14 e `stat_thresholds_v1` são os valores observados no candidato.
Decoders históricos validam antes de migrar; não apagar desconhecidos, refazer
orçamento antigo ou usar fixtures no save pessoal. Versão nova precisa de contrato,
não de alteração isolada de constante. Estado incerto bloqueia nova intenção.

Trocas conservam déficits HP/SP, recargas, recursos e snapshots já emitidos.
Validar candidato/posse/conflitos antes de gravar; só publicar após confirmação.
Prévia é pura. Cura explícita da campanha é outra operação, nunca consequência
de recalcular stats ou vestir um item.

Raiz/emissão/família/alvo são preservados através de projéteis, timers e callbacks.
E06-TX substituiu o teto global histórico de16 por planos finitos da emissão;
o valor legado permanece para compatibilidade. Não truncar efeitos úteis por
um cap arbitrário nem remover os limites mundiais/por kit. Claims precedem
callbacks de morte/reentrada; vida do ledger cobre os eventos tardios.

Controles, preparo, custo, alvo e linha de visão se revalidam no commit. Pausa
congela a simulação; UI e VFX não avançam timers de gameplay nem aplicam dano.
Ativas de item têm fonte separada de aprendizado, rank efetivo pelo contrato e
recarga compartilhada. Remover fonte não apaga atalho nem zera cooldown.

## Contratos detalhados a abrir por impacto

- [E06 consolidado](epics/e06_contract.md): propriedade, itemização, loot e composição.
- [Itemização TX/API](epics/e06/e06_tx_api.md), [poder/loot](epics/e06/e06_balance_scope.md)
  e [cartas permanentes/conjuntos](epics/e06/e06_playtest_fixes_contract.md).
- [Aggro, tiers e áreas de demonstração](epics/e06/e06_gameplay_extension_contract.md).
- [Aprendizado das dez identidades](epics/e06/e06_all_skill_dependencies_proposal.md),
  [admin](epics/e06/e06_admin_extension_contract.md) e [export release](epics/e06/e06_export_profile_hotfix.md).
- Mecânicas de classes: contratos/checkpoints E04/E05 citados no
  [histórico técnico](ARCHITECTURE.history_2026_10_17.md). Seus deltas continuam
  válidos quando não substituídos; não reimplantar seus limites antigos de UI/save.

## Fronteira futura de mapas e combate

[Gate de cenários low-poly](gates/low_poly_environments.md): integração de 3D
com apresentação atual ainda exige arquitetura; não presumir conversão integral.
Ameaça, alvo atual e participação em combate de grupo terão autoridades distintas
conceitualmente; definir geração/controle/troca de alvo e cura antes dos consumidores.
Contratos atuais de aggro não provam essa extensão implementada.
Modelo aprovado: listas individuais por inimigo, geração diferenciada, limiar
de troca de alvo, provocar/redução ativa e UI de ameaça. Valores aguardam contrato.
Expedição conserva montagem/progresso/mácula até conclusão, inclusive entre
visitas. Primeira limpeza inicia timer global de respawn da fase; ondas repõem
trash morto elegível em estágios limpos, sem duplicar vivos ou respawnar bosses.
Suspensão conserva estado completo, augments e relógios congelados, sem progresso
offline. Captura/restauração de atores, ações e recibos ainda exige contrato;
persistência futura não está implementada. Morte conserva expedição/build, retorna
ao último portal e reduz tempo restante da próxima onda, disparando reposição
elegível ao atingir zero; valor/retorno/HP/SP aguardam regra.
Augments não viram posses permanentes e restauração não reconcede recompensas.
Multiplayer precisará definir autoridade e congelamento com outros membros ativos.

A navegação 2D atual não prova suporte a ponte sobre outra rota nem a linha de
visão entre alturas. [PRODUCT_DIRECTION](PRODUCT_DIRECTION.md) exige contrato
de superfícies/conectores, geometria e estado de combate antes dos consumidores.
O gerador deverá compartilhar geometria com navegação, spawn, clique e portais,
sem inventar um segundo mundo desconectado do combate.

## Evidência

[TESTING](TESTING.md): seleção por impacto em `tools/verify.ps1`, invariantes para
regras, registros de inputs/engine/SHA e inspeção nativa quando visual. Edição
documental não requer repetir gameplay; deve declarar essa limitação. Importação
no editor não substitui prova do PCK release após alterações de conteúdo/exportação.
