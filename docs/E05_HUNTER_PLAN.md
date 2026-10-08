# E05 — Caçadora: contrato de implementação

08/10/2026. ID `hunter`, origem `archer`, evolução histórica 2-2.
Base `3d452fa2e4455f4c8636f4fb319a2d0607d08582`, branch `codex/e05-hunter`.

## Autorização e limites

Aceite humano conferido no chat Astra `01a08e78-172d-7281-a8ca-19761da1c572`,
turno `01a11b69-b678-74d0-a9e5-c8efff3d17f0`: aprovou as sugestões e autorizou
começar a implementação, destacando a marca aplicada pelas armadilhas.
Fonte: `menu-tabs/docs/E05_HUNTER_IDENTITY_DRAFT.md`, SHA256
`491a288148d14b530759ea02fcdd6d9a253def3db31bb103c5f0cfdf692dbe3f`.
O cabeçalho autorizativo substitui a restrição do brainstorm histórico.

Direção aprovada: preparar terreno → abrir uma presa → explorar com arco →
reposicionar. Cobertura territorial com breve saída é apoio, não requisito.
Números abaixo são tuning inicial de Sol para protótipo, não balanceamento aceito.
Uma revisão integrada por classe; sem gate por skill. Não publicar playtest,
alterar save pessoal, integrar ícones globais, iniciar outro épico ou fazer merge.
Autorização da classe não equivale a aceite de gameplay dos atributos/ícones.

Normativos: AGENTS.md, WORKFLOW.md, E00/E03 e STAT_THRESHOLDS_PLAN.md.
XP, carteiras 19 base/20 evolução em job40, caps, gates, 24 slots e passivas
aprendidas automáticas permanecem. Não há concessão oculta de skill da base.
`content_ready=false` até kit, consumidores e evidência integral concluídos.

## Kit fechado

Seis ativas novas e duas passivas. Explosiva e Laço são skills da base reutilizadas.
Gate vale para todos os ranks daquela skill, não cresce novamente por rank.
SP interpola linearmente R1→R5; números secundários também, salvo indicação.
Armadilhas novas: POINT, range360, preparo variável0,25s, armar0,60s,
permanência armada12s; custo somente no commit validado.

| ID | Nome / categoria | Gate / cap / grátis | SP / CD | Efeito R1→R5 |
|---|---|---|---|---|
| hunter_freezing_trap | Armadilha Congelante / ativa | 20 / 5 / R1 | 16→22 / 7s | raio52; root mágico0,8→1,6s; dano mágico `(12+1,8INT)×(1+0,1×(R−1))` |
| hunter_tar_trap | Armadilha de Piche / ativa | 20 / 5 / 0 | 16→22 / 9s | gatilho52; campo100 por4→6s; slow30→40%, residual0,4s; sem tick de dano |
| hunter_thorn_trap | Armadilha de Espinhos / ativa | 23 / 5 / 0 | 18→26 / 9s | gatilho52; área85; dano físico `(16+1,6INT)×(1+0,1×(R−1))`; bleed físico20% do snapshot, 1/s por4s; slow20% por2s |
| hunter_mark | Marca do Caçador / ativa | 25 / 5 / 0 | 10→14 / 10s | SINGLE_TARGET range360, instantânea; uma prioridade por6→10s; +1→2s à janela capturada da trap; recompensa +15→25% |
| hunter_shooting_discipline | Disciplina de Tiro / passiva | 28 / 3 / 0 | — | impacto físico secundário adicional de5/10/15% do ATQ de precisão capturado no tiro de exploração |
| hunter_covering_shot | Tiro de Cobertura / ativa | 31 / 5 / 0 | 16→22 / 8s | direção, range520, velocidade880; tiro físico GEOMETRY, crítico normal, ATQ precisão×1,1→1,5; recuo80 validado por segmento; sem reset de auto |
| hunter_easy_prey | Presa Fácil / passiva | 34 / 3 / 0 | — | +8/12/16% na recompensa da abertura quando presa marcada ou controlada antes do tiro; abertura sozinha basta contra boss resistente |
| hunter_total_cover | Cobertura Total / ativa | 37 / 5 / 0 | 20→28 / 18s | POINT range300; raio125 por4→6s; saída1s; limite comum de camuflagem3s |

Ranks inválidos retornam tuning vazio, nunca clamp para conceder rank.
Nomes visíveis pt-BR; IDs/código inglês. Handler/metadata/definição concretos
devem coincidir antes de qualquer skill integrar a biblioteca aprendida.

## Ciclo intrínseco e snapshots

Cada ativação válida de Laço/Explosiva/armadilha nova abre a presa atingida,
mesmo com CC resistido. Detectar ocupação após armar; substituir/expirar/limpar
não é ativação. Um único slot por presa: uma nova ativação substitui snapshot
e prazo, sem somar poder ou durações. Duplicata da mesma trap/presa não renova.
Janela4s, máximo6s com Marca. Snapshot da recompensa é físico GEOMETRY,
sem crítico, secundário, raw `(8+1,4×INT efetiva)×(1+0,1×(rank da trap−1))`.
Laço/Explosiva usam seus ranks comprados. A fórmula não lê DES, ATQ nem MATK.
Capturar multiplicador de dano causado do jogador na colocação; DEF física,
escudo e modificadores recebidos da vítima são atuais na exploração, pelo
resolver/aplicador canônico. Marca/Presa Fácil multiplicam somente essa parcela;
Disciplina acrescenta sua parcela de precisão no mesmo pedido secundário.
Nenhuma fórmula local altera stats de outras classes.

Gatilhos de exploração: auto, Double Shot, Piercing Arrow, Arrow Rain, Slowing
Arrow e Tiro de Cobertura, próprios, diretos e com `actual_damage>0`.
Erro, zero, absorção total, fonte alheia, trap, DoT e secondary não consomem.
Consumo/ledger e bônus de movimento são reivindicados no callback `damage_applied`
antes de callbacks de morte. Tiro letal consome e concede mobilidade; não tenta
atingir cadáver com bônus. Capturar listas e revalidar instâncias a cada emissão.

Deduplicar por emissão/vítima, inclusive uma abertura reaplicada entre impactos
da mesma emissão. Ledger até256 emissões, TTL12s (maior que vida dos tiros);
ao saturar rejeitar novos claims, sem expulsar IDs vivos. Aberturas até32 vítimas,
ledger de ativações até256 trap/vítima por16s, saturação rejeita sem mutar.
Relógios avançam exclusivamente com delta não pausado; não usar relógio de parede.

Passo de Caça: fonte `move_speed increased +25%`, duração1,5s, ICD compartilhado3s.
Uma emissão concede no máximo um buff, independente de vítimas; refresh de buff
não soma duração. Explorações durante ICD ainda causam bônus, mas não renovam
movimento. Aplicar/remover fonte recalcula stats pela autoridade existente,
preservando HP/SP faltantes e cooldowns. Sem cura, recarga ou refil implícito.

## Armadilhas, reação e cobertura

Reutilizar PlayerTrap/Registry: três não ativadas por dono; quarta substitui a
mais antiga. Armadas reconhecem alvo estacionário. Novas e especialização Hunter
revalidam terreno/LoS na colocação e em cada vítima da área; preview usa mesmas
funções/range/geometria. Terreno inválido não cobra. Campo de Piche: um por dono,
nova ativação substitui anterior; DoT Espinhos renova por fonte, não empilha.
Limite de campos não se confunde com três mecanismos não disparados.

Concretização H3 do tuning inicial: Congelante escolhe uma presa (mais próxima,
desempate por ID), como Laço; Espinhos e Piche abrem os ocupantes iniciais de
suas áreas85/100. Entradas tardias/reentrada no Piche só recebem slow, nunca
nova abertura. Listas são limitadas a32 e revalidadas após callbacks; novos
inimigos podem integrar mecanismos/campo Hunter ainda ativos. Expiração normal
do campo conserva no máximo o residual0,4s; substituição, consumo e limpeza
retiram a fonte sincronicamente. Não há dano periódico no Piche.
Fonte de Piche identificada por dono: limpeza terminal também retira o residual
após o campo visual expirar, preservando slows de outras fontes.

Explosiva mantém ID/carteira/ranks. Somente Hunter usa raw físico exclusivo
`(22+2,2INT)×(1+0,1×(R−1))`, GEOMETRY, sem crítico. Arqueiro/Sentinela permanecem
no comportamento original. Piche→Explosiva consome o campo e remove seu slow
por fonte antes do dano; bônus da explosão +25%×fração de prazo restante (0..1).
Uma reação por explosão, não por alvo. Vítimas são snapshot de ocupantes da
explosão, sem detonação de outras traps. Só ativação primária abre janela;
reação/bônus/bleed não reabrem. Congelante e Espinhos respeitam CC canônico.

Contato da reação H3: círculos de campo/explosão sobrepostos e LoS entre seus
centros. A lista da explosão é capturada antes do consumo; um callback opcional
Hunter reivindica o campo antes do loop de impactos e retorna o escalar limitado
0..25%. Só a cópia do pedido de explosão recebe esse escalar; a recompensa da
abertura e o pedido original continuam intactos. Não existe sinal de reação que
detone outro mecanismo. Arqueiro/Sentinela sem esse callback mantêm o raw base.

Cobertura Total é ação própria: raio maior e graça de saída, sem apagar Abrigo
comprado. Na identidade Hunter ambas compartilham budget3s/ICD de cobertura18s
(após recarga canônica), fonte única por dono e bloqueio de revelação comum.
Consumir budget somente enquanto efetivamente oculto; não renovar por reentrar,
substituir campo ou alternar skills. Ataque ofensivo validado revela por1,25s,
inclusive fora do campo; saída concede até1s dentro do mesmo budget. Esgotado,
novo uso só após CD comum. Fora da identidade Hunter, Abrigo mantém seu contrato.
Camuflagem não muda HP, aggro do boss, contagem de encontro ou projectiles/AoEs
já emitidos. IA observa última posição quando oculto, sem travar/teletransportar.

Concretização H4 do protótipo: Marca é amostrada na ativação válida da trap;
trocar, expirar ou aplicar uma Marca depois não altera abertura já capturada.
Seu bônus escala somente o raw INT, preservando multiplicador de colocação e
resolver atual. A prioridade some ao remover/morrer a presa. Tiro de Cobertura
exige todo o segmento de recuo80 caminhável e ausência de root; se bloqueado,
cancela o tiro e o recuo sem cobrança. Projétil nasce na origem anterior ao recuo,
captura precisão/crit da emissão e não reinicia auto/recovery. Preview compartilha
destino/segmento e área real, sem ultrapassar paredes pelo endpoint.

Abrigo Hunter conserva raio110/duração comprados, sem graça extra; Cobertura
Total usa125 e graça1s apenas numa saída efetiva de área ativa. Expirar/remover
campo encerra a graça, mas não devolve budget nem apaga revelação. Uma colocação
paga após CD comum renova budget3; registrar, substituir e reentrar não renovam.
O relógio integra frações de frame de revelação/graça. Budget paga o estado de
camuflagem do ator; observador dentro do mesmo círculo ainda detecta, como na
base. Durante graça essa exceção usa a área de origem. Offense válida também
registra revelação fora de qualquer área e uma nova colocação não a apaga.
Ambas as recargas usam18s pela autoridade canônica; não existe novo relógio
paralelo de cooldown. IA Hunter conserva alvo/HP e caminha até a última posição
visível, sem seguir posição oculta ou emitir ataque enquanto não readquirir.
Essas concretizações não alteram Abrigo/IA de Arqueiro ou Sentinela.

Concretização H5: Disciplina captura ATQ de precisão efetivo e rank legal na
emissão do arco; Presa Fácil captura seu rank/escalar na mesma emissão. Cópias
e projéteis conservam ambos. Na exploração, Marca atual/root/stun/fear/slow de
movimento pré-existentes qualificam Presa Fácil; weaken não é controle. Essa
amostragem ocorre no callback de dano, antes do controle do próprio tiro.
Boss com abertura qualifica sem exigir CC aceito. Presa Fácil multiplica só o
raw INT já capturado (incluindo Marca da ativação); Disciplina é somada depois.
O pedido secundário único conserva o multiplicador capturado na colocação,
sem repetir mitigação ou crítico. Alterar stats/ranks durante voo não recalcula
os escalares emitidos; erro/zero/absorção/secondary não reivindicam abertura.

Persistência H5: catálogo8/schema2/stat_thresholds_v1; migração explícita do par
7/stat_thresholds_v1 sem mudar regras/carteiras, investimentos, XP ou grants.
Versões1..6 continuam validando seus orçamentos antigos. A versão7 já usa custos
por patamar e não recebe essa validação antiga. Aberturas/camuflagem/payloads de
passivas continuam exclusivos da run. Produção ainda `content_ready=false`.

## Consumidores e validação

Sol: HunterMath/OpeningState, PlayerActor, main, traps/fields, input dispatch,
preview, lifecycle, regras/testes e checkpoint. Luna pode receber catálogo/tuning
e testes de dados fechados, com propriedade exclusiva dos arquivos delegados.
Terra só UI/VFX sobre eventos estáveis e pipeline visual inspecionado.

| Fronteira | Consumidor / evidência exigida |
|---|---|
| Identidade | ProfileCatalog/ClassCatalog; Hunter indisponível até fechamento; outras evoluções preservadas |
| Progressão/save | BuildSnapshot, codec/store/fachada; evolução e reload, carteira, primeira mutação/respec, pending/futuro sem perda; sem novo estado de run no save |
| Matemática | HunterMath/StatCalculator/CombatMath; INT isolada, crit/DEF/modificadores, snapshot e preview coerentes |
| Input | CastIntent/PlayerActor/main/BattleIndicators; modos3, binds24, cancela/revalida/cobra uma vez, recuo não atravessa parede |
| Lifecycle | traps/opening/fields; pausa, letal, morte do dono, fim/reset, callbacks destrutivos, duplicatas, bossCC e stationary |
| Apresentação | atlas/VFX nativo; pisos claro/escuro, solo/grupo/boss; animações e feedback não causam dano |
| Integração | duas builds legais menu→save→run→retorno; regressões arqueiro/sentinela e all implementer HEAD limpo |

Builds de referência job40/base30, compradas pela fachada (não por grants):
Preparadora: INT35/DES30/VIT25 incrementos, ranks freeze5/tar4/thorn4/mark2/
discipline2/easy2/cover1/shot1 (20 pagos). Emboscadora: DES40/AGI35/SOR25,
freeze1 grátis/tar1/mark4/discipline3/shot5/easy3/cover4 (20 pagos).
Selecionar skills base gastando até19 pontos em fixtures legais; saldo de atributos
não precisa ser zero. Confirmar custo pelo sistema novo, não copiar orçamento.
Ambas funcionam sem aprender kit inteiro e sem passivas tardias obrigatórias.

Visual: madeira/corda/osso, terra/musgo, origem Arqueiro, sprite próprio no contrato
64×64/pivô32,58. Preparando/armada/acionada/campo distintos por forma e ritmo;
abertura entalhada sobre presa, impacto ao consumir, curto rastro nos pés.
Pipeline existente e assets fonte preservados; concept não é atlas automaticamente.
Ícones exclusivos após IDs fixos, integração global de HUD/tooltip fora deste escopo.

Fechamento: invariantes e provas nativas, ferramentas/verify.ps1 e CLI all,
30/60/144Hz com IA ativa para solo/defesa, um checkpoint e revisão Astra integrada.
Sem afirmar FPS/DPS/diversão por screenshots ou fixtures sem IA.
Tuning poderá mudar internamente com testes, mas divergência do ciclo aprovado
ou dependência de decisão ausente exige escalar antes de consumidores afetados.
