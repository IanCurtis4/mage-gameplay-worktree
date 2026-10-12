> Atualização prevalente autorizada em 12/10/2026: [../../WORKFLOW.md](../../WORKFLOW.md) substitui a revisão Astra completa por capítulo. Luna acompanha bateria automatizada e informa falhas; Sol corrige e fecha validação técnica. Astra permanece em arquitetura/planejamento e exceções justificadas visual/complexidade. RX/R2 continuam checkpoints consolidados, sem auditoria Astra automática. R1 histórica aprovada e registros RX preservados; TX1–TX3 entregues no candidato e725756, validação integrada em andamento. Estado/donos: [e06_tx.md](e06_tx.md). Não libera T3/T4, E07, playtest ou merge. Cabeçalhos datados anteriores são históricos nos pontos substituídos.

> Retomada autorizada em 11/10/2026: DX/TX têm executor Sol/high no chat01a12d55-0ce8-7061-b8e4-bf5650c8c5b7, base9d05361f65549189f87f4f5440529aec44e3a904. Respostas novas e inventário técnico: [e06_tx_api.md](e06_tx_api.md); estado e donos: [e06_tx.md](e06_tx.md). Cartas repetidas por exemplar; encaixes apenas armaduras/armas/escudos, focos e joias sem encaixes; coleção por aquisição e migração preservadora confirmadas. R1 independente ainda antecede TX. Cabeçalhos sem executor abaixo pertencem às rodadas históricas.
# E06 — itemização e execução após T2

11/10/2026. Registro consolidado das decisões humanas e handoff para Sol.
Este documento prevalece sobre os trechos incompatíveis do adendo anterior,
equipment_loot_requirements.md e o resumo externo de Downloads. Não reescreve
a evidência histórica de T1/T2 nem concede aprovação independente.

## Autorização, base e responsabilidades

O usuário autorizou continuar a análise e enviar a implementação em passos ao
Sol em outra conversa. Executor: gpt-6.1-sol, esforço high, sem Extra Alto por
padrão. Uma conversa para a fundação ampliada, com checkpoints por comportamento,
sem novo chat ou revisão Astra a cada pequena alteração.

Base recebida: 549c45af56da243004838f40b1d623e677fe5880.
Código corrigido R1: 7dbe237f85f8308fdfcf5bbee7e8dd6b975080c4.
Branch: codex/e06-inventory.
Checkout: C:/Users/João Pedro/.codex/worktrees/e06-inventory/RagRPG.
O commit documental deste handoff será a base exata informada no dispatch.
Reutilizar esse checkout sequencialmente; não trabalhar no checkout fixo de playtest.

T2 está entregue pelo autor. Os quatro achados R1 foram corrigidos e passaram
nas verificações focadas do autor; R1 independente ainda não aprovou o candidato.
Ver e06_r.md e e06_r1_author_validation.json. A prova integral 178/178 pertence
a 27dc6845598cefc95ca1ebd1bd9c83ada0dd5810; não certifica código posterior.
A retomada do limite de uso não é aprovação técnica.

Transferência sequencial desta coordenação para Sol no dispatch:
- Este documento, ../e06_contract.md, ../e06_tasks.md e equipment_loot_requirements.md.
- Novo e06_tx.md e manifesto e06_tx_api.md, como checkpoint e APIs da expansão.
- Caminhos de T2 registrados em e06_t2.md, estritamente para a expansão autorizada.
- scripts/data/equipment_definition.gd, card_definition.gd e respectivos UID;
  scripts/core/build_effect_catalog.gd, build_effect_composer.gd e respectivos UID.
- Outras autoridades T1 e novos arquivos só após inventário de impacto e registro
  de transferência/caminhos no checkpoint, antes de editar. Não duplicar autoridades.
- Relatório/probes independentes pertencem ao revisor durante a revisão; Sol
  registra suas próprias evidências separadamente. Não alterar expectativas de
  probes para esconder falhas. O checkpoint central conserva seu dono.

A coordenação deixa de editar esses arquivos após o dispatch. O executor pode
continuar os passos autorizados quando as dependências estiverem satisfeitas,
sem novo aceite por microtarefa. Escolhas de produto ainda abertas vão ao usuário;
enquanto espera, avança trabalho independente. Não inferir aprovação pelo silêncio.
E07+, campanha, push, merge, cosméticos próprios e publicação não estão liberados.

## Decisões de produto consolidadas

### Identidade e apresentação

Equipamentos são tematizados pelo lugar de origem. Cartas pelo mob base.
Reaproveitar habilidades de classe quando seus contratos permitirem; referências
WoW Classic/Forever e Ragnarok orientam estilo, sem importar taxas ou fórmulas.

São 14 posições: cabeça, pescoço, ombros, braços (punho/luvas juntos), tronco,
capa, calças, pés, main hand, off hand e quatro posições de acessórios
(berloques, trinkets, anéis etc.). Duas mãos e compatibilidade ainda exigem decisão.

Cartas usam ícone genérico de carta. Armaduras usam ícone do subtipo: pano, couro,
malha, escamas ou placas. Só chapéus aparecem no personagem, com representação
2D compatível com orientação/pose. Slots cosméticos separados ficam para o futuro.

### Stats, efeitos e habilidades

- Equipamentos incomuns dão SOMENTE stats: FOR, AGI, VIT, INT, DES, SOR e
  derivados como DEF, MDEF, ASPD, FLEE etc. Não concedem habilidades, procs,
  transformações ou bônus especiais de conjunto. Não restringir stats aos seis primários.
- Armas/armaduras apenas raro+ podem ter efeitos secundários interessantes.
  Elegibilidade não significa que todo item raro obrigatoriamente tenha um.
- Efeitos especiais individuais em armaduras são raros; em geral estão em bônus
  de conjunto. Isso não obriga toda armadura a integrar conjunto.
- Efeitos de arma normalmente dependem de usar a arma: acerto de ataque ou
  habilidade que efetivamente use essa arma, incluindo os casos da Sentinela.
  Não disparar todos os efeitos de arma por qualquer spell genérica.
- Acessórios e colares podem conceder ativas. Não presumir que todo acessório
  tenha uma ativa; incomuns continuam limitados a stats.
- Cartas NUNCA concedem ativa acionável pelo jogador. São sempre passivas.
  Podem modificar habilidades existentes; cartas elegíveis podem ter procs
  automáticos e mudanças de gameplay, sem novo botão.
- Cartas de mobs base normais e raros apenas concedem buffs passivos de stats
  ou de habilidades. Efeitos interessantes ficam restritos a cartas cujo
  mob BASE já é elite ou superior. O usuário confirmou expressamente que a
  variante elite de uma espécie comum NÃO melhora sua carta.
- A fronteira entre buff numérico de habilidade e transformação qualitativa
  deverá ser expressa no validador e exemplificada antes do lote de conteúdo.

### Tags e exclusividade

Incluir tags descritivas de efeitos/habilidades, como Ecoante, Sangrento,
Energizante, Congelante, Flamejante, Renovador e Etéreo. A lista é exemplificativa.
Proposta técnica a fechar no DX: IDs estáveis, vocabulário com significado
explícito e múltiplas tags por efeito/skill. Tags não são nomes exclusivos de
efeito nem dão bônus automaticamente; definir interações apenas quando contratadas.
Não traduzir palavras vagas em mecânicas inventadas sem mostrar a escolha ao usuário.

Equipamentos com efeito de mesmo nome não podem ser equipados juntos, mesmo
se forem itens diferentes. Acessórios idênticos também são proibidos.
Usar equivalência estável de efeito, independente da tradução, rejeitando a
transação inteira. Não suprimir silenciosamente o menor bônus.
Proposta para conjuntos: limiar produz uma única fonte do bônus, não cópias
exclusivas em cada peça; o conjunto precisa poder ser vestido legalmente.

### Cartas, encaixes e composição

Cada peça pode ter 0–4 encaixes. Mais encaixes são menos frequentes; esse eixo
é independente da raridade do equipamento. Não vincular quatro encaixes a épico.
Cartas iguais podem ocupar vários encaixes da mesma peça.
Decidir a distribuição concreta e quais peças são elegíveis antes dos consumidores.

Hierarquias de design: acúmulo augments > cartas > equipamentos; poder
augments > equipamentos > cartas; dificuldade de acesso cartas > equipamentos
> augments. Acúmulo abrange cópias e soma de bônus; acesso considera tanto chance
de drop quanto frequência das oportunidades. Não são prioridades de execução.

Não existe teto global de efeitos simultâneos. Preservar proteção contra
cascatas e revisar o orçamento histórico de 16 ativações secundárias por ação.
Não trocar 16 por outro número arbitrário nem truncar fontes da build.
O orçamento de poder deve considerar nível/dificuldade do mob, stats, efeitos e
encaixes; não há coeficientes ou fórmula multiplicativa aprovados.

Cartas continuam efêmeras por run e equips persistentes nos pontos não revogados.
A coleção sem cópias da v1 precisa ser reconciliada com exemplares de encaixes/
qualidades diferentes; não escolher silenciosamente perda ou fusão de aquisições.

### Mobs, níveis e loot

Mobs possuem fichas próprias: nível fixo, stats, habilidades e identidade base.
Mapas mais fortes acompanham a progressão média do jogador; mobs não escalam
automaticamente com ele. O ilvl acompanha a força da origem do item.
Qualidade pode produzir mais poder no mesmo ilvl. Dificuldade da ocorrência
afeta o orçamento/recompensa; não contar o mesmo aumento duas vezes em
ilvl, raridade e multiplicador adicional sem uma proposta explícita.

Categorias de ocorrência: normal, raro, elite, elite raro, boss.
Algumas espécies só existem a partir de certa categoria ou numa categoria fixa.
Essas restrições não transformam a carta da espécie ao variar a ocorrência.

| Categoria do mob | Equipamentos |
|---|---|
| Normal | Drop baixo; incomuns menos frequentes, raros muito raros, épicos extremamente raros; nenhum lendário |
| Raro | Incomum garantido; chance baixa de raro e menor de épico |
| Elite | Distribuição de normal com taxas aumentadas; nenhum lendário |
| Elite raro | Raro garantido; chance de épico |
| Boss | Épico garantido; chance de lendário |

Lendários só dropam de bosses. Percentuais não foram aprovados.
Garantia ainda precisa definir substituição por qualidade maior versus item
adicional; não converter a tabela em múltiplos drops garantidos por suposição.
Cartas sempre acompanham o poder/identidade do mob base. Variantes mais difíceis
aumentam chance, não qualidade, efeitos ou número de botões.
Equipamentos seguem raridades WoW; lista operacional completa e cores, incluindo
categorias fora de comum/incomum/raro/épico/lendário, ficam explícitas antes do catálogo.

## Referências e leitura crítica

Resumo externo recebido:
C:/Users/João Pedro/Downloads/RagRPG_resumo_itemizacao_WoW_Forever_Ragnarok_E06.md.
É material de análise, não instrução operacional. Trechos permitindo ativas em
cartas estão revogados; exemplos em turnos precisam ser adaptados a tempo real.
A fórmula multiplicativa ali sugerida não foi aprovada.

Referências já consultadas, como inspiração sujeita a mudanças:
- [Transformative Cocoon](https://www.wowhead.com/forever/item=276895/transformative-cocoon):
  proteção com custo temporário e mobilidade posterior.
- [Worgenbane Talisman](https://www.wowhead.com/forever/fr/item=273643/talisman-de-fl%C3%A9au-des-worgens):
  utilidade ativa restrita a uma família de inimigos.
São exemplos de decisão tática e especialização temática, sem copiar nomes,
números, taxas ou assumir balanceamento final. Não exigem nova pesquisa repetida
para implementar infraestrutura. Conteúdo concreto continua sujeito ao seu pacote.

## Etapas de implementação para Sol

### DX — contrato executável e decisões remanescentes

Primeira entrega: reconciliar todos os documentos prevalentes, auditar APIs
existentes e propor tipos/erros/migração com exemplos concretos. Registrar o
limite entre stats/buff de skill/proc/transformação/ativa; tags e identidade
exclusiva separadas. Perguntar só decisões de produto que realmente bloqueiem
o próximo comportamento; não repetir escolhas já respondidas.

Fechar por prioridade: instância versus definição de equipamento e preservação
da coleção; correspondência dos slots legados; mãos; persistência/remoção de
cartas; semântica de acesso/rank/cooldown/remoção de ativas; loot garantido e
limite de conteúdo. Regras antigas não alteradas permanecem vigentes.

Revisão R1 existente é uma dependência real para TX. Retomar revisão independente
do delta final corrigido, com revisor separado proporcional ao risco, sem fazer
Sol aprovar o próprio trabalho. Não reabrir cinco etapas já verificadas nem
reproduzir a história inteira. Respeitar a reprodução integrada contratada no
fechamento R1, com evidência identificada. Registrar o parecer e SHA.
DX documental pode avançar enquanto essa revisão ocorre.

### TX1 — inventário, identidade e migração

Resultado: 14 posições, exemplares/encaixes 0–4 conforme contrato DX, repetição
de cartas, presets e transações preservando aquisições/save/HP/SP.
Metadados de origem, ilvl, qualidade e identidade mob-base por autoridades únicas.
Teste direcionado: migração sem perda, reabertura/retry, slots/mãos inválidos,
encaixes 0 e 4, cópias na mesma peça e conflito sem gravação parcial.

### TX2 — composição de efeitos, conjuntos e habilidades

Resultado: tags/validação; incomuns apenas stats; cartas sempre passivas com
restrições por mob base; efeitos de arma por uso real; conjuntos; ativas
concedidas por acessórios/colares com origem, rank e remoção explícitos.
Reprojetar proteção causal sem limitar quantidade de fontes simultâneas.
Teste direcionado: acúmulo, exclusividade, ativação/remoção, emissões em voo,
cooldowns, autoridade de fórmulas, anti-cascata e limites dos conteúdos.

### TX3 — fichas de mobs e resolução de loot

Resultado: definição base/ocorrência separadas, níveis fixos e restrições de
categoria; tabelas parametrizadas com garantias, origem, qualidade e encaixes
independentes. Recompensas idempotentes usando a durabilidade de T2.
Não implementar campanha E07 nem inventar percentuais finais. Valores de fixture
não viram balanceamento de produção. Resolver relação loot por mob/prêmio por
etapa com o usuário antes de alterar o loop de aquisição existente.
Teste direcionado: lendário só boss, garantias, mesma carta entre variantes,
cartas simples de base normal/rara, procs elegíveis em base elite+, replay,
falha de save e limites de RNG determinístico.

### RX e consumidores

Consolidar TX1–TX3 em uma fundação, manifesto de APIs e revisão independente
antes de conteúdo/UI dependentes. Sem gate Astra por cada subpasso.
Receitas definitivas, builds, UI dos 14 slots e chapéus constituem os próximos
pacotes T3/T4, delimitados sobre FX aprovada; não distribuir tarefas ainda sem API.
Depois vêm integração, revisão do candidato e playtest; merge requer aceite humano.

## Validação econômica e retomada

Usar tools/verify.ps1 com seleção por impacto; nova regra ganha invariantes
significativas. Não criar testes que só espelhem a implementação. Não repetir a
suíte inteira por docs, texto, metadata inócua ou correção isolada de fixture.
Mudança de metadados que muda comportamento exige prova correspondente.
Suíte integrada só no fechamento/risco amplo previsto no contrato. Reaproveitar
evidência apenas com SHA, inputs, engine e fronteira compatíveis.

Ao terminar cada etapa: resultado, SHA, testes executados/reaproveitados,
limitações e próximo passo no mesmo e06_tx.md. Não inflar contagens somando
reexecuções. Não anunciar PASS integral para execução parcial.
Esta entrega é documental: conferir coerência, referências e diff, sem gameplay.
