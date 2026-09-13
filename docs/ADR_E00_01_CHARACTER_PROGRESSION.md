# ADR E00.1 — Personagem, progressão e limites da run

Data: 13/09/2026. Autor/revisor técnico: Astra, nesta tarefa, sem delegação.
Estado: proposta para aceite de design; nenhuma regra abaixo foi implementada.
Liberação: usuário disse “Pode começar.” na tarefa E00. Entrega deste checkpoint:
E00.1. Base técnica escolhida por Astra: `79196d5`, que contém o roadmap vigente
e a verificação do piloto. Essa escolha não declara aceite de produto do piloto.

## Autoridade e alcance

[LONG_TERM_EPICS.md](LONG_TERM_EPICS.md) e
[HYBRIDS_56_EXPLORATION.md](HYBRIDS_56_EXPLORATION.md) registram a direção recebida.
[MVP.md](MVP.md) preserva o piloto; [ARCHITECTURE.md](ARCHITECTURE.md) descreve os
contratos executados hoje. Este ADR propõe a substituição futura somente dos
trechos de persistência, progressão e composição de build. Não muda fórmulas de
combate, arquivos de save, catálogo jogável ou controles atuais.

**Aprovado anteriormente pelo usuário:** personagens persistentes e alts; menu de
seleção/build; base level e job level permanentes; pontos de atributos separados
de pontos de skills; evoluções 2-1/2-2/2-3 alternativas e direcionais; augments
temporários coletados no chão e escolhidos fora do encontro; demo com Espadachim,
Mago, Arqueiro, seis puras e seis híbridas direcionais entre essas bases.

**Proposto neste ADR, ainda sem aceite de design:** todos os números, regras de
respec, propriedade da coleção, momento de concessão de XP, fechamento da run,
herança detalhada de skills e comportamento dos presets. A afinidade secundária
sem necessidade de outro alt vem da exploração e é recomendada aqui explicitamente.

Oito bases + 16 puras + 56 híbridas = 80 identidades no plano amplo. O demo tem
3 + 6 + 6 = 15. Os nomes exploratórios não aprovam os kits das próximas tarefas.

## Donos do estado e duração

| Dono proposto | Conteúdo | Morte, abandono ou fechamento do aplicativo |
|---|---|---|
| Perfil local (`ProfileState`) | IDs dos personagens, seleção preferida, coleção compartilhada de equipamentos, preferências e estatísticas acumuladas | Conserva somente transações confirmadas em disco |
| Personagem (`CharacterState`) | ID estável, nome, base de origem, evolução, XP base/job, alocações, skills aprendidas, equipamentos selecionados e presets | Conserva; não troca classe nem perde níveis |
| Run (`RunState`) | ID da run, personagem de origem, cópia da build, HP/SP, cooldowns, cast, efeitos, augments, cartas/encaixes, ofertas, fase/encontro e RNG | Descarta; nova run cria novas instâncias |
| Catálogo (`Resource`) | Definições de classe, evolução, skill e nível, item, augment e progressão | Imutável; nunca guarda alocações, HP ou cooldowns |

Um perfil é local e offline; “conta” não implica login ou backend. Proposta: até
8 personagens no demo, sem implementar exclusão neste bloco. Uma run ativa por
perfil; não alternar personagem enquanto houver run ativa. O ID do personagem
independe do nome e nunca é reutilizado. A base de origem é fixa após a criação.

Equipamentos: coleção de desbloqueios por ID, sem duplicatas, compartilhada entre
alts; cada personagem escolhe seus itens válidos independentemente. Um desbloqueio
pode ser selecionado por dois alts, pois não representa uma cópia física exclusiva.
Manter arma, armadura e acessório. Cartas pertencem à run, com um encaixe por item
equipado; encaixar não modifica o item de catálogo nem grava carta no personagem.
IDs de cartas e encaixes temporários somem no encerramento da run.

## XP, pontos e evolução: proposta numérica do demo

| Parâmetro | Proposta |
|---|---|
| Base level | Início 1, teto 30; XP acumulada começa em 0 |
| Job level | Início 1, teto global 40; sem evolução, teto 20 |
| Atributos | Vetor inicial da base soma 30; +3 pontos por base level ganho; custo de +1 atributo = 1 ponto |
| Limite de atributo | Até 60 no valor inicial + alocado; bônus de equipamentos/efeitos ficam fora deste teto de investimento |
| Pontos de skills de base | +1 por job level de 2 a 20: total 19 |
| Pontos de skills de evolução | +1 por job level de 21 a 40: total 20; carteira separada da base |
| Elegibilidade de evolução | Base level pelo menos 10 e job level 20; selecionar no menu, sem run ativa |
| Custo de evolução/respec no demo | Gratuito; sem moeda, consumível ou requisito de outro alt |

FOR/AGI/VIT/INT/DES/SOR continuam `str/agi/vit/int/dex/luk`. Propor manter os
vetores existentes: Espadachim 8/5/8/2/5/2; Mago 2/5/5/9/7/2. Para Arqueiro,
propor 3/7/5/2/10/3. A base de origem conserva esse vetor ao evoluir; modificadores
de identidade devem passar pelo mesmo cálculo central, sem alterar a alocação.

Custos propostos para passar do nível atual ao próximo:

- Base: `100 + 25 × (L − 1)`, para `1 <= L < 30`.
- Job: `80 + 20 × (J − 1)`, para `1 <= J < 40`; a transição 20 → 21 exige evolução.
- XP total para alcançar L: `100 × (L − 1) + 25 × (L − 1) × (L − 2) / 2`.
- XP total para alcançar J: `80 × (J − 1) + 20 × (J − 1) × (J − 2) / 2`.

XP acumulada inteira, não negativa, é a fonte de verdade. Nível e total de pontos
concedidos derivam dessas curvas; saldos descontam investimentos válidos. Não
somar pontos novamente ao carregar, recalcular nível, evoluir ou aplicar respec.
Uma recompensa pode subir vários níveis. No teto, limitar XP ao limiar do teto,
sem banco de excedente: base 30 = 13.050 XP; job 40 = 17.940 XP. Sem evolução,
job 20 = 4.940 XP. XP base continua entrando mesmo com job bloqueado. A UI deve
explicar o bloqueio antes da próxima run; evolução não concede XP retroativa.

O ritmo de XP por inimigo/encontro ainda será calibrado em E07; estas curvas não
prometem duração até o teto. Uma run pode começar com uma identidade evoluída.
Não exigir completar toda a campanha antes de permitir evoluir.

## Evoluções direcionais e respec

Cada origem oferece duas puras (`2-1`, `2-2`) e as híbridas (`2-3`) liberadas no
catálogo. O personagem mantém uma única evolução ativa, ou nenhuma antes de
evoluir. `2-3` é categoria; não é um identificador suficiente para o save.
O catálogo relaciona ID estável, origem, destino/afinidade e receita curada.

No demo, `sp_mg`, `mg_sp`, `sp_ar`, `ar_sp`, `mg_ar`, `ar_mg` são IDs distintos.
`sp_mg` requer origem Espadachim; selecionar `mg_sp` para esse personagem falha.
Não requer possuir/evoluir um Mago alt. Não há fusão de personagens, consumo de
alt, combinação com a própria base nem acesso integral à árvore da segunda base.

Herança proposta: biblioteca aprendida da origem permanece disponível. A híbrida
acrescenta seu catálogo exclusivo, contendo adaptações selecionadas da afinidade;
essas adaptações têm IDs e custos próprios e usam a carteira de evolução. Nem
pura nem híbrida recebe automaticamente todas as passivas de seus temas.

Respec de atributos devolve apenas os pontos investidos; não altera vetor inicial,
níveis ou XP. Respec de skills devolve cada custo à carteira correspondente e
restaura os ranks gratuitos iniciais. Respec completo evita manter skills com
pré-requisitos removidos; não propor reembolso parcial em cascata neste demo.

Trocar evolução só é permitido no menu e dentro da mesma origem. Conserva XP,
job level e a árvore base; devolve todos os pontos gastos da evolução antiga e
remove seus ranks gratuitos. Instala os ranks gratuitos da nova identidade uma
única vez. Não acumula carteiras de ramos anteriores. Depois de evoluir, trocar
entre destinos é permitido, mas voltar ao estágio sem evolução fica fora do demo:
isso evita personagem sem destino com job acima de 20.

A confirmação valida personagem, catálogo, requisitos, saldos, skills e loadout
como uma transação única. Se algo falha, mantém a versão anterior inteira. Repetir
a confirmação não duplica pontos ou desbloqueios.

## Kit completo, aprendizado e slots

Propor biblioteca por base com 6–10 ativas e 2–3 passivas; evolução acrescenta
4–6 ativas e 2–3 passivas exclusivas. Híbrida usa o mesmo orçamento de uma pura.
O Mago pode ocupar o teto de 10 ativas para comportar os pedidos já registrados.
Não reduzir a lista de magias solicitada para caber na barra simultânea.

Propor auto sem custo/slot; 5 slots de ativas e 2 de passivas selecionáveis,
compartilhados entre origem e evolução. Uma característica intrínseca de identidade,
se necessária para o loop, deve ser explícita e revisada no orçamento do kit; não
usar essa exceção para esconder várias passivas gratuitas. Auto/intrínseca não têm
rank comprado. Skills aprendidas podem ficar fora da barra sem perder o investimento.

Ativas com ranks 1–5 e passivas com ranks 1–3; 1 ponto por rank comprado. Cada base
começa com duas ativas em rank 1 e uma passiva em rank 1, especificadas em catálogo,
gratuitas e não reembolsáveis. A evolução libera uma ativa exclusiva em rank 1,
gratuita; as demais começam em 0 (não aprendidas). Melhorias desses ranks iniciais
custam normalmente. Não há obrigação de preencher todos os slots no nível 1.

Catálogo declara requisitos de job, identidade e ranks de outras skills por rank
desbloqueável. A árvore deve ser acíclica e alcançável com os pontos disponíveis;
skills da base não podem exigir uma evolução específica. Skills de evolução podem
exigir fundamentos da origem; trocar identidade não deve invalidar a árvore base.

Dois presets por personagem guardam seleção de slots/equipamentos, sem criar
carteiras adicionais ou memorizar outra distribuição de ranks. Trocar preset não
é respec. Após respec/troca de evolução, remover referências ilegais de todos os
presets, informar slots vazios e pedir configuração antes de iniciar, caso nenhum
slot ativo seja válido. Não substituir por skills aleatórias nem apagar presets
inteiros. Auto permanece disponível.

“Completo” exige auto e loop funcional sem augments, duas builds que mudam a tomada
de decisão, pré-requisitos/ranks alcançáveis, tooltips coerentes, opções de augment,
arte/áudio previstos no respectivo gate e respostas a melee, ranged e boss. Cinco
skills com cores diferentes não bastam. E04/E05 detalharão os kits, sem autorização
de implementação dada por este ADR.

## Recompensa persistente e build durante a run

Propor XP base/job concedida por eliminação válida e loot de coleção na coleta.
Morte/abandono preservam concessões já confirmadas; não concedem prêmio de vitória
ou de encontro ainda não concluído. A recompensa identifica run, evento e personagem
de origem; alterar a seleção do menu não muda seu destinatário. XP base/job e seus
efeitos sobre o personagem entram juntos em uma transação idempotente.

Uma concessão só é apresentada como salva após commit em disco. Falha de gravação
pausa a progressão e apresenta repetição/saída informada; repetir usa o mesmo ID.
Fechamento forçado pode perder a concessão ainda não confirmada, nunca duplicar a
já confirmada. Estratégia atômica, backup, recibos e recuperação serão E00.3/E01.

XP e pontos podem aumentar no personagem durante a run, mas a build inicial é uma
cópia por valor. Novos níveis, ranks e respec afetam a próxima run; investimento e
troca de slots são feitos no menu. Assim, ganhar nível durante o encontro não cura,
altera dano ou reduz cooldown de uma ação em curso. Mostrar “pontos para investir
no menu” e separar nível persistente dos stats efetivos da run.

Manter troca de equipamento/cartas fora do encontro conforme o piloto: nova cópia
válida de loadout atualiza a build runtime. Seleção de equipamento também atualiza
a preferência persistente do personagem após save; cartas nunca persistem. Troca
não repõe recursos: preservar déficits de HP/SP, limitar aos novos máximos e não
zerar cooldowns. A permissão de trocar equipamento não permite respec durante a run.

Início de run concede HP/SP máximos, efeitos/cooldowns vazios e zero augments/cartas.
Transição de fase mantém a recuperação prevista no piloto; é uma cura explícita
do fluxo, não efeito de recalcular atributos. Não haverá retomada de run ao reabrir.

## Migração: direção e limites deste passo

Na base `79196d5`, a busca no código identifica somente `controls.cfg` como save
implementado. `profile.json` v1 aparece como contrato futuro em ARCHITECTURE.md;
não há personagem persistido a converter. `RunState.reset()` hoje reinicializa
skills em rank 1; isso é estado do piloto, não histórico de aprendizado recuperável.

Propor primeiro formato real de perfil com versão explícita, preservando as
preferências existentes. Não fabricar personagens, XP ou itens a partir de uma
run antiga ou de defaults do piloto. Primeiro acesso sem perfil abre criação de
personagem. Save legado inesperado, desconhecido ou de versão futura não deve
ser sobrescrito por defaults; preservar para recuperação e informar ao usuário.

E00.3 definirá versão concreta, campos, migração suportada, validação de IDs,
política de corrupção e fixtures. E01 não deve persistir formato definitivo até
esse contrato e as decisões de design serem aceitos. O respec aqui proposto não
substitui política de migração quando um catálogo ou limite mudar.

## Casos de referência para revisão

Estes são resultados esperados do desenho; não são testes de sistema implementado.

| Caso | Resultado esperado |
|---|---|
| 350 XP base em personagem novo | Nível 3 (limiar 225), 125/150 rumo ao 4; 6 pontos de atributos concedidos |
| Mais 25 XP no caso anterior | Nível 4 (limiar 375); total de 9 pontos concedidos |
| 4.940 XP job, base level 9 | Job 20 e 19 pontos da base; evolução bloqueada pelo base level |
| Mesmo job, base level 10, escolher `sp_mg` como Espadachim | Evolui, conserva job 20, carteira de evolução 0, ativa inicial gratuita em rank 1 |
| Ganhar 460 XP job após evoluir no caso anterior | Job 21 (limiar 5.400), 1 ponto de evolução; carteira base continua 19 |
| Trocar evolução com job 25 e 5 pontos exclusivos gastos | Devolve 5 à carteira de evolução; remove skills antigas, não concede outros 5 |
| Respec de Espadachim base 30 com 87 pontos investidos | Restitui 87; vetor volta a 8/5/8/2/5/2; XP permanece 13.050 |
| Aprender ativa inicial de rank 1 até rank 5 | Gasta 4; respec devolve 4 e mantém rank 1 |
| Aplicar duas vezes a mesma recompensa confirmada | Segunda aplicação não muda XP, coleção ou pontos |
| Morrer com dois augments e uma carta após ganhar XP salva | XP permanece no personagem; nova run tem zero augments e cartas |
| Equipar/retirar item que dá +20 HP com déficit de 30 | Déficit continua 30 onde comportado pelos máximos; nenhuma cura pela troca |
| Dois alts selecionam o mesmo item desbloqueado | Ambos válidos conforme restrições; loadouts e progressões independentes |

## Revisão técnica e decisões pendentes

Autorrevisão Astra: propriedade sem Resource mutável; carteiras conservadas ao
trocar ramo; direções distintas; ganho multinível sem concessão duplicada; slots
limitados sem reduzir biblioteca do Mago; ausência de save legado real distinguida
de contrato planejado. Não houve revisão independente por outra tarefa/agente.

Para aceite de design, revisar especialmente: progressão 30/40 e evolução 10/20;
respec gratuito com origem fixa; 5 ativas/2 passivas; equipamentos compartilhados
e cartas temporárias; progresso salvo por evento com investimentos apenas no menu.
Alternativas consideradas: evolução irreversível reforça alts, mas encarece testar
as 15 identidades; árvore integral de duas bases elimina orçamento comparável;
aplicar ranks durante a run exigiria contratos adicionais de atualização de ação.

E00.2 ainda precisa definir fórmulas, limites e donos de todos os valores do painel,
inclusive resistências e controle de boss. E00.3 precisa fechar save/migração e
fixtures executáveis. Este checkpoint não conclui E00 nem libera E01–E11.
