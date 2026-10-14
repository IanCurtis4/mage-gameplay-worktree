# E06 — contrato das correções após playtest

13/10/2026. Escopo autorizado pelos sete pontos do feedback e pelas respostas do usuário. Base: `8e2badfad1bc7bdd21f3c1556a6ed47c426bbf0b`, branch `codex/e06-inventory`. [Registro de execução e donos](e06_playtest_fixes_scope.md). E07, novas classes, consumíveis funcionais, push e merge em master não estão autorizados.

## Coleção e migração

Somente augments e escolhas são transitórios. Cada aquisição de carta cria um exemplar permanente. A coleção de cartas e os encaixes pertencem ao perfil; o encaixe fica no exemplar físico de equipamento ao desequipar ou terminar uma run. Personagens e presets que apontam para essa peça observam os mesmos encaixes. A composição considera apenas os hosts equipados. Retirada e transferência gratuitas fora de combate, sujeitas aos mesmos bloqueios de oferta, sessão, morte e gravação das trocas de equipamento.

Schema 5/catalog 12: `card_inventory` guarda instâncias, sockets, contador, revisão e recibos de aquisição. Migração explícita de schema 4/catalog 11 cria uma coleção vazia; as cadeias históricas continuam passando pelas migrações próprias. Não reconstruir cartas descartadas em saves antigos. Um envelope antigo não pode inserir o novo campo como extensão. Validar IDs canônicos, contador, cartas conhecidas, host existente, capacidade, exclusividade física e recibos coerentes.

Card ID sorteado fica congelado no ticket. XP, equipamento, carta e journal são confirmados na mesma transação durável. A chave run/ticket impede duplicação em retry. Falha não publica estado; resultado incerto congela a operação até reconciliação da mesma intenção. Prévia não escreve. A fachada fornece as mesmas transações ao menu fora da run. Não acrescentar fórmulas à UI.

## Equipamentos e conjuntos

Preservar os 85 Resources anteriores à correção, incluindo os 12 equipamentos históricos, e o poder dos exemplares adquiridos. Acrescentar 46 equipamentos e 13 conjuntos: três genéricos e um para cada identidade jogável. Recursos-base da publicação anterior continuam com seus digests; defaults neutros de política ficam fora da assinatura histórica. Recursos de catálogo e caches são imutáveis; consumidores recebem cópias.

Faixas aprovadas: bases 2–5, evoluções 6–10, Geômetra 11–15. Genéricos nas três faixas. Conjuntos base também aceitam suas derivações; avançados exigem identidade exata. Faixa limita ilvl de drop e da peça que conta para o conjunto, sem escalar pelo jogador. A regra rare+ dos conjuntos permanece. Contar IDs distintos de peças; duplicatas físicas da mesma receita não somam outra peça. Bônus e comparações usam o compositor canônico.

Política opcional central em equipamento, layout, catálogo, pool de loot e conjuntos. Armas compartilhadas têm famílias explícitas. Contas de madeira ocupam Braços, armadura com encaixe; foco prismático ocupa a secundária compatível e não recebe cartas. Duas mãos continuam bloqueando secundária. Mantêm-se taxas de loot, crescimento numérico e XP já aprovados.

## Interface, desempenho e arte

Janelas arrastáveis de equipamentos e mochila, com 14 posições ao redor do personagem e quatro abas: Consumíveis, Equipáveis, Misc e Cartas. Abas sem conteúdo declaram vazio. Fechar tem área mínima 44×44 e responde em toda a área; janelas interceptam seu clique e permitem o clique fora delas. Prévia/confirmar e reconciliação preservam a autoridade da fachada.

Medir custo de recarga de catálogo e reutilizar dados imutáveis, devolvendo cópias. Não atribuir lag ao debug sem evidência, nem inferir FPS de um microbenchmark. Cache de animações/offsets evita análise repetida de pixels por ator.

Três espécies novas usam atlases kawaii originais com idle, andar, atacar, dano e morte em frente/costas. Morte preserva espécie e aparência. Arma, escudo, foco e contas são anexos visuais, sem efeito nas regras. O jogador usa corpo sem arma embutida para permitir equipar, trocar e retirar anexos; fontes e atlases históricos são preservados. Normalizar grade 4×8, célula 64, pivô (32,58), transparência, espelhamento e contato com o chão. Conferir leitura no renderer em fundos claros/escuros.

## Validação e entrega

Astra forneceu planejamento curto das fronteiras; não há auditoria Astra de capítulo. Sol implementa e fecha invariantes/integração; Luna acompanha execução, erros, timeouts e hashes. Checks por impacto no runner versionado, com fixtures isoladas e inspeção gráfica nativa. Reaproveitamento de PASS exige compatibilidade documentada. Não esconder falhas com mudanças arbitrárias de oráculo: apenas expectativas explicitamente substituídas pelo novo contrato.

Após validação técnica, atualização fast-forward no diretório habitual de playtest, importação/abertura e hashes do save pessoal antes/depois. Aceite de produto continua com o usuário; não inferir aceite ou merge da aprovação técnica.
