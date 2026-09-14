# Handoff para Codex — MVP, arquitetura, design e direção visual

**Data:** 2026-09-14  
**Objetivo:** retomar o projeto com o mínimo possível de redecisão e retrabalho, preservando a franquia de uso do Codex.  
**Repo:** `IanCurtis4/mage-gameplay-worktree`  
**Documentos de repo consultados:** `docs/LONG_TERM_EPICS.md`, `docs/ART_DIRECTION_NEXT.md`, `docs/MAGE_ANIMATION_PLAN.md`.

> Este pacote complementa, e não substitui silenciosamente, o `E0_Handoff_Classes_Hibridas_MVP.pdf`. Quando houver conflito, tratar este documento como o estado mais recente **somente nos assuntos que ele atualiza explicitamente**: uso de modelos, direção visual, identidade das classes do MVP e loops recentes de híbridas.

---

## 0. Convenção de status

- **LOCKED** — decisão aprovada; não reabrir por preferência do agente.
- **STRONG DIRECTION** — deve ser preservada no próximo passe, mas números/nomes pontuais podem mudar após playtest.
- **OPEN** — não inventar uma decisão definitiva sem aprovação do usuário.

A regra operacional é: **não transformar brainstorming em requisito fechado**, mas também **não redecidir o que já foi aprovado**.

---

# PARTE I — DECISÕES ARQUITETURAIS / DE IMPLEMENTAÇÃO

## 1. Escopo estrutural do MVP

### 1.1 Personagem, conta e run — **LOCKED**

Manter separação explícita entre:

- `ProfileState`: coleção de personagens e preferências de conta/perfil.
- `CharacterState`: identidade persistente, classe/origem/evolução, Base/Job XP, níveis, pontos e skills aprendidas/presets.
- `RunState`: HP/SP corrente, cooldowns, efeitos transitórios, augments, encontro e snapshot temporário da build.
- Catálogos/Resources são dados de definição e **não devem virar estado mutável da run**.

A morte/reinício da run não deve apagar progressão persistente. Augments e estados transitórios não devem vazar entre personagens/runs.

### 1.2 Progressão — **LOCKED na estrutura; OPEN nos números finais**

- Base Level e Job Level são separados e persistentes.
- Pontos de atributos e pontos de skills são recursos separados.
- Evoluções 2-1/2-2/2-3 são alternativas.
- A ordem/origem das bases importa para híbridas direcionais.
- Skills possuem níveis/ranks; requisitos e valores exatos continuam sujeitos a aprovação/playtest.
- Não gravar números de balanceamento em UI; a UI deve consumir o catálogo/fórmula central.

### 1.3 Escopo do primeiro demo — **LOCKED**

Bases do MVP:

1. Espadachim
2. Mago
3. Arqueiro

Classes estendidas/puras do MVP:

- Defendente / **Warder**
- Berserker / **Ravager**
- Elementalista / **Elementalist**
- Espiritualista / nome inglês ainda **OPEN**
- Sentinela / **Sentinel**
- Caçador / **Waylayer**

Híbridas direcionais do MVP:

- Cavaleiro Rúnico / **Runebound Knight**
- Devastador Astral / **Astral Ravager**
- Baluarte de Cerco / **Siege Bastion**
- Saqueador / **Snare-Reaver**
- Geômetra / **Geometer**
- Caçador de Espectros / **Hollow-Marker**

O alvo distante continua maior, mas **E10/E11 não devem competir por tokens com o vertical slice do MVP**.

---

## 2. Contrato de movimentação e combate

### 2.1 Movimento — **LOCKED em direção**

A sensação de jogo deve permanecer mais próxima de MMORPGs coreanos/RO antigos em sua gramática espacial:

- click-to-move como navegação principal;
- autoataque/perseguição assistida relevantes;
- skills modernas podem ter telegraph, setup/combo/payoff e execução mais expressiva;
- o jogo não deve virar um action game WASD apenas porque os kits têm ideias modernas.

### 2.2 Inimigos e ameaça — **STRONG DIRECTION**

Preferir:

- inimigos passivos, defensivos e agressivos coexistindo;
- percepção local e estado atual do mundo;
- troca de alvo por proximidade, perigo imediato, dano recente, bloqueio, controle, oportunidade, etc.;
- leash/retorno e leitura espacial.

Evitar como núcleo uma aggro table invisível ao estilo `threat += damage * coefficient`. Pode existir memória/score interno, mas o comportamento deve parecer **dinâmico e situacional**, não uma tabela de raid MMO clássica.

### 2.3 Regra de precedência de alcance — **LOCKED para o design dos kits**

Quando uma híbrida junta uma classe melee e outra ranged/caster, **o arquétipo melee tem precedência no alcance do payoff principal**. A parte ranged prepara, marca, posiciona, controla ou alimenta a entrada; ela não deve transformar a híbrida em um caster que carrega uma espada por estética.

---

## 3. Stats e matemática

### 3.1 Separação das fórmulas — **LOCKED como princípio**

Uma única fonte de verdade deve controlar dano, HIT/FLEE, crítico, ASPD, cast, pós-cast, cooldown, DEF/MDEF e efeitos por nível. HUD/tooltips não duplicam fórmula.

### 3.2 Ataque de precisão por DES — **STRONG DIRECTION, ainda não aprovar como fórmula final**

A arquitetura atual historicamente empurrou dano físico para FOR. Para Arqueiro e híbridas de precisão, considerar um caminho explícito de `precision_attack`/escala por DES, mantendo melee em FOR e magia em INT.

**Não fechar coeficientes sem o gate numérico do épico de stats.**

---

## 4. Arquitetura de arte/VFX para economizar uso do Codex

### 4.1 Codex não é o diretor de arte iterativo — **LOCKED operacionalmente**

Concept exploration e direção visual devem ser feitas fora do Codex sempre que possível. O Codex recebe referências aprovadas e implementa **engenharia de apresentação**.

### 4.2 Kernel de VFX — **STRONG DIRECTION**

Criar poucas primitivas concretas e parametrizáveis antes de fazer dezenas de efeitos únicos. Exemplo de conjunto útil:

- `TrailVFX`
- `AfterimageVFX`
- `BurstVFX`
- `GroundAreaVFX`
- `AuraVFX`
- `TetherVFX`
- `FloatingGlyphVFX`
- `ProjectileTrailVFX`
- decal/ground trace simples
- hit flash / hitstop / screenshake por contrato

Não fazer um framework universal abstrato. Fazer cenas/componentes concretos, testáveis e reutilizáveis.

Depois disso, Terra/Luna podem configurar efeitos já contratados sem inventar arquitetura.

### 4.3 Pipeline de sprites — **STRONG DIRECTION do guia atual**

Do `ART_DIRECTION_NEXT.md`:

- 64×64 como ponto inicial de comparação, personagem ocupando aproximadamente 40–52 px de altura;
- comparar 48×48, 64×64 e 80×80 antes de fixar;
- pivô nos pés;
- armas longas/VFX podem usar camada/célula maior;
- validar **uma animação completa** antes de multiplicar classes/inimigos;
- arte conceitual gerada é referência; sprites finais exigem limpeza, pivô estável e continuidade de frames.

### 4.4 Sistemas de input especiais — **STRONG DIRECTION**

`Runebound Knight` e `Geometer` têm gramáticas próprias. Não obrigar suas runas/vértices a ocuparem artificialmente todos os slots comuns de skill. Tratar seleção rúnica e colocação de vértices como **característica intrínseca do kit**, com UI/input dedicado e testável.

---

# PARTE II — ROTEAMENTO DE MODELOS E REINTEGRAÇÃO DOS CHATS/ÉPICOS

## 5. Situação operacional

O roadmap original reservou uma conversa por épico E00–E11. O usuário informa que havia 12 chats pré-criados; hoje restam 11 a tratar e, ao concluir E01, restarão 10.

Como não há orçamento para créditos adicionais, **tokens/resets são recurso de produção**. A estratégia agora é preservar os chats como âncoras de contexto, mas não desperdiçar modelos fortes em execução rotineira.

A documentação atual da OpenAI resume os modelos assim:

- Astra: problemas difíceis, desconhecidos, arquitetura/auditoria complexa.
- Sol: implementação forte com melhor equilíbrio de capacidade/eficiência.
- Terra: mudanças rotineiras, UI/dados/documentação delimitada.
- Luna: tarefas repetitivas/focadas, edição curta, extração/configuração.

Também é documentado que inputs/outputs maiores, raciocínio alto e tarefas multietapas aumentam o consumo.  
Referência: <https://help.openai.com/pt-br/articles/20001516-managing-usage-with-gpt-6-astra-in-work-and-codex>

## 6. Protocolo de reintegração dos chats pré-setados

### Regra 1 — não jogar chats fora

Cada chat continua sendo o **container histórico do épico**. Não recontar toda a história em cada mensagem. Anexar/referenciar este pacote e informar somente:

- épico atual;
- commit/base conhecido;
- delta desde o último gate;
- tarefa atual;
- arquivos permitidos;
- critério de aceite/testes.

### Regra 2 — se o seletor permitir troca de modelo, trocar antes do próximo trabalho substantivo

Não manter Astra/Sol apenas porque o chat nasceu assim. O valor está no contexto do chat, não em pagar o modelo mais caro em todas as mensagens.

### Regra 3 — se o chat realmente ficar preso a um modelo forte

Usar o chat forte apenas como **gate**:

1. receber o estado;
2. decidir/validar o contrato em uma resposta curta;
3. produzir uma instrução de implementação fechada;
4. executar a mudança em modelo mais barato disponível;
5. voltar ao chat forte somente se testes mostrarem um problema sistêmico real.

Não fazer “Astra revisa cada commit” por padrão.

### Regra 4 — testes substituem parte da revisão humana/modelo caro

`tools/verify.ps1`, testes unitários/integrados, renderer/playtest e critérios de aceite são o revisor comum. Astra é exceção, não cron job.

### Regra 5 — congelar E10/E11 até o demo convencer

Não usar chats/tokens para cinco bases restantes ou catálogo das 56 híbridas enquanto o vertical slice de 3 bases + 6 puras + 6 híbridas ainda não estiver apresentável.

## 7. Nova rota por épico

| Épico | Modelo de execução recomendado | Gate caro | Observação |
|---|---|---|---|
| **E00** Contratos | **arquivar** | nenhum novo por padrão | não reabrir decisões fechadas |
| **E01** Persistência | **terminar no fluxo atual**; preferir Sol | só se houver quebra de contrato/save insolúvel | concluir antes de remapear tudo |
| **E02** Menu/build | Terra; Luna em tarefas repetitivas | Sol só se a UI revelar problema de estado | UI não inventa backend |
| **E03** Stats/job/skills | Sol | Astra **uma vez** apenas se houver conflito matemático/arquitetural | Terra faz UI após contrato |
| **E04** 3 bases | Sol | sem Astra por padrão | concept art fora do Codex; Sol integra |
| **E05** puras + híbridas | Sol por par/subépico | Astra somente se uma mecânica exigir mudar arquitetura compartilhada | Terra preenche dados depois do contrato |
| **E06** augments/equip/cards | Sol no pipeline; Terra/Luna em catálogo | Astra não | proteger contra proc cascata com testes |
| **E07** campanha/IA/boss | Sol | Astra só se houver impasse sistêmico de IA | Terra pode preencher composições |
| **E08** arte/feedback | **dividir**: A fora do Codex; B Sol; C Terra/Luna | no máximo um gate visual/arquitetural | ver seção abaixo |
| **E09** integração/demo | Sol | **um único passe adversarial Astra** se houver franquia; senão Sol + testes | Astra deixa de ser coordenador permanente |
| **E10** outras bases | congelado | — | pós-demo |
| **E11** 56 híbridas | congelado | — | pós-demo |

### 7.1 Novo E08

**E08A — Bíblia visual / concept exploration**  
Fora do Codex. Este pacote já é a primeira versão.

**E08B — Kernel de arte técnica**  
Sol: VFX reutilizável, shaders delimitados, eventos de animação, pivôs, camadas, importação e ferramenta de preview.

**E08C — Hero pass do vertical slice**  
Terra/Luna configuram cenas/assets já definidos; Sol entra onde há shader/renderer/gameplay. Polimento desigual e intencional: gastar mais em 5–7 momentos vendáveis do demo, não em todos os efeitos.

### 7.2 Novo E09

Sol integra. O usuário playtesta. Suite de testes fecha regressões. **Astra recebe snapshot congelado**, não uma sequência infinita de drafts.

Prompt de gate sugerido:

> Audite este candidato a demo procurando somente falhas sistêmicas, inconsistências de contratos, save corruptível, estados impossíveis, regressões de input e riscos arquiteturais. Não refatore por preferência e não reabra decisões de design aprovadas.

---

# PARTE III — DECISÕES DE DESIGN

## 8. Norte estético e de sensação do jogo — **LOCKED como direção**

Objetivo: evocar a sensação de um RPG online coreano do início/meados dos anos 2000 sem copiar diretamente um jogo existente.

A referência emocional central é a **discrepância entre fofura e estranheza/terror**: um mundo que comporta mascotes extremamente simples e adoráveis e, algumas salas depois, criaturas perturbadoras, religiosas, decadentes ou grotescas. O exemplo mental discutido foi a diferença de tom presente em Ragnarok Online entre criaturas como Poring e bosses/dungeons como Beelzebub, Gloom Under Night e `ra_dun` — **referência de contraste**, não licença para copiar design, sprite, silhueta, mapa ou ornamento.

Características desejadas:

- personagens/cartoon com boa leitura em sprite;
- rosto/mãos/arma expressivos;
- silhuetas relativamente compactas;
- roupa e acessórios com “badulaques” legíveis;
- fantasia medieval/tecnomágica/oculta misturada sem realismo excessivo;
- cores ricas e VFX mais saturados que a base física;
- inimigos podem ir muito mais longe no estranho que o player character;
- concept sheets são exploração, não guia de reprodução 1:1.

Gameplay pode usar referências sistêmicas modernas de WoW/LoL — combo, setup/payoff, criação/gasto, janelas de poder — enquanto **movimentação, leitura de campo e ecologia de mobs** ficam mais próximas da tradição RO.

---

## 9. Gramáticas das classes estendidas

### Defendente / Warder

**Paleta conceitual (aproximada, não locked em hex):**

- carvão/ferro `#3E4144`
- prata quente `#A8A39B`
- marfim `#E2D9C9`
- couro `#6B5140`
- ouro velho `#C49B54`

**Material:** aço, couro, pedra.  
**Forma:** placas, retângulos, linhas grossas, massa vertical.  
**VFX:** impactos curtos/pesados, sigilos defensivos, ondas contidas.  
**Substantivo visual:** **placa**.

### Berserker / Ravager

- carvão `#232225`
- sangue seco `#642B31`
- crimson ativado `#A63C45`
- couro escuro `#574238`
- osso `#D2C4B0`

**Material:** ferro escuro, couro, pelo, osso, tecido rasgado.  
**Forma:** diagonais, dentes, rasgos, assimetria.  
**VFX:** pulsação, trails agressivos, explosão curta, sangue estilizado.  
**Substantivo visual:** **ferida**.

### Sentinela / Sentinel

- sage `#74816F`
- azul pálido `#B9D1E2`
- creme `#ECE5D4`
- couro claro `#8B735C`
- metal frio `#596267`

**Material:** madeira clara, tecido, metal polido, instrumentos de campo.  
**Forma:** linhas longas, chevrons, círculos de mira, bandeiras.  
**VFX:** linhas precisas, indicadores direcionais, projéteis limpos.  
**Substantivo visual:** **linha**.

### Caçador / Waylayer

- musgo escuro `#354034`
- oliva `#59614B`
- marrom escuro `#604737`
- tan `#B39A78`
- osso/linho `#D8D0BE`

**Material:** corda, madeira bruta, couro, osso, folhagem, ferro de trap.  
**Forma:** ganchos, nós, triângulos baixos, mecanismos.  
**VFX:** poeira, folhas, marcas no chão, mecanismos acionando.  
**Substantivo visual:** **mecanismo**.

### Elementalista / Elementalist

- navy `#24344D`
- azul `#3574B8`
- branco frio `#E8EEF4`
- vermelho `#C14B43`
- amarelo elétrico `#E5B94E`

**Material:** cristal, vidro, metal arcano, energia.  
**Forma:** prismas, triângulos, formas radiais.  
**VFX:** **saturado**, brilhante, fogo/gelo/raio claramente separados.  
**Substantivo visual:** **energia**.

Regra de gameplay: híbridas com Elementalista devem tentar preservar a **tricotomia Fogo / Gelo / Raio** e reinterpretar a outra classe três vezes, não apenas adicionar “dano elemental”.

### Espiritualista / nome inglês OPEN

- branco pálido `#E6E4DC`
- prata/cinza `#A7ADB1`
- azul-cinza `#66737F`
- carvão `#343337`
- preto `#16161A`

**Material:** tecido, névoa, ectoplasma, metal ritual.  
**Forma:** crescentes, véus, duplicações, afterimages.  
**VFX:** **dessaturado**, translúcido, atrasado, dissipando.  
**Substantivo visual:** **vestígio**.

**Importante:** o arquivo `spiritualist_visual_mood_exploration.png` acertou a paleta/estranheza espectral, mas deriva demais para vocabulário de tracker/ranger. Usá-lo como **mood/VFX reference**, não como silhueta final obrigatória do Espiritualista puro.

---

## 10. Álgebra visual das híbridas

Regra adotada:

> A classe de origem define **o objeto/material/silhueta**; a segunda identidade define **o fenômeno que acontece com esse objeto**.

Isso evita “sprite A recolorido com paleta B”.

| Híbrida | Álgebra visual | Paleta/efeito |
|---|---|---|
| **Runebound Knight** | placa + energia = **inscrição** | metal Defendente; Fogo/Gelo/Raio aparecem em canais/runes saturados |
| **Astral Ravager** | ferida + vestígio = **possessão** | vermelho/preto Berserker vai dessaturando conforme espíritos tomam o corpo |
| **Siege Bastion** | placa + linha = **fortificação direcional** | prata/branco + sage/azul pálido; pavês, corredores, counterfire |
| **Snare-Reaver** | mecanismo + ferida = **armadilha brutal** | musgo/couro/ferrugem; vermelho vivo só quando a rede entra em frenzy |
| **Geometer** | linha + energia = **geometria** | branco/azul/ouro com cores elementais em vértices/arestas |
| **Hollow-Marker** | mecanismo + vestígio = **rastro** | equipamento terrestre; pó/flechas/traps espirituais pálidos e translúcidos |

---

## 11. Loops das seis híbridas do MVP

### 11.1 Runebound Knight — **STRONG DIRECTION**

- Tank melee com gramática rúnica.
- Três elementos: Fogo, Gelo, Raio.
- Dois slots permitem repetição e um contém a escolha não repetida: **18 resultados/fórmulas** no modelo discutido.
- Defesa/leitura gera combustível/carga; a fórmula define a resposta.
- Fantasia: “Hwei/Invoker tank”, mas o verbo principal continua sendo **defender e responder**.
- Não gastar 18 slots de skill; runas são linguagem intrínseca.

### 11.2 Astral Ravager — **STRONG DIRECTION, core ainda merece um playtest de identidade**

- Melee Berserker + Espiritualista.
- Possessão/tensão astral; ecos/afterimages repetem golpes com atraso.
- Visual: corpo agressivo vermelho/preto invadido por braços/silhuetas pálidas.
- Deve ter um pico de execução em que a sequência melee é ecoada/repetida.
- Não virar caster de espíritos à distância.

### 11.3 Siege Bastion — **STRONG DIRECTION**

- Melee Defendente + Sentinela.
- Declara/segura linhas e corredores.
- Pavês/posição/pressão bloqueada preparam represália.
- Momento de glória: ler barrage/charge, aguentar deliberadamente e devolver a pressão pela linha.
- Risco de design: não deixar o kit estático demais; exigir reconstrução/reposicionamento do cerco.

### 11.4 Snare-Reaver — **LOCKED no twist central**

- Melee Caçador + Berserker.
- Pode **ativar as próprias traps**.
- Trap ativada pode virar ponto de mobilidade: rush rápido até ela, `Unstoppable`, strike e knockback em inimigos atravessados.
- Bleed não é só DoT: presa sangrando pode receber **mais movespeed**, criando pânico/rota mais perigosa e alimentando a caça.
- Kills em inimigos com bleed reduzem/rearmam cooldown de traps.
- Estado neutro deve ler “Caçador”; estado ativado revela o “Berserker”.
- Loop: preparar → sangrar/provocar → disparar rede → deslocar-se pela própria rede → matar bleeder → rearmar → continuar.

### 11.5 Geometer — **LOCKED no núcleo combinatório; catálogo de efeitos ainda expansível**

- Híbrida mais complexa do jogo por intenção.
- Flechas/vértices em chão ou oponentes.
- **6 paredes direcionais** entre elementos distintos (`F→G != G→F`).
- **27 triângulos** (`3^3`).
- Total conceitual: **33 magias/construções**.
- Efeitos podem atuar sobre terreno, inimigos, projéteis e aliados.
- Deve parecer uma linguagem espacial/programável, não 33 botões.
- Progressão deve ensinar gramática antes de liberar toda a combinatória.
- Fraqueza legítima: perder espaço/tempo para construir geometria.

### 11.6 Hollow-Marker / Caçador de Espectros — **LOCKED no loop principal**

Infraestrutura de `Soul Dust`/pó de alma no chão.

**Traps:**

1. **Spectral Trap** — perene no ambiente, pequeno DoT, marca/gera trilha, rearma após ~5 s (número de playtest).
2. **Banishment Trap** — bane alvos na área: imóveis + intangíveis pela duração; controle que também impede o jogador de atacá-los normalmente.
3. **Haunting Trap** — fear em área + redução de armor/MRES; dano quebra o fear.

**Trilha:**

- inimigos marcados deixam pó de alma;
- morrer sob o estado pode explodir/propagar a condição de trilha;
- flecha atravessando a trilha torna-se espectral: perfura alvos, aplica DoT e pode fazer atingidos gerarem nova trilha por um tempo;
- o mapa vai ficando progressivamente favorável ao Caçador conforme mortes escrevem rotas no chão.

Momento de glória: um tiro impossível/atravessando múltiplos alvos que só existe porque o jogador construiu a história espacial da luta.

---

# PARTE IV — MANIFESTO DAS IMAGENS E REFERÊNCIAS

## 12. Regra de propriedade intelectual

Todas as imagens deste pacote são **explorações originais geradas para o projeto**. As referências a Ragnarok, WoW, LoL, Invoker/Hwei etc. são linguagem de comunicação sobre sensação/gameplay. Não incorporar sprites, logos, roupas, monstros, mapas ou VFX proprietários desses jogos.

O objetivo é reproduzir **qualidades abstratas**:

- legibilidade/chibi e “paper doll” de MMORPG coreano antigo;
- contraste cute ↔ grotesco;
- progressão visual por acessórios;
- VFX legíveis em tela pequena;
- sistemas de combo/setup modernos.

## 13. Concept arts das classes estendidas

### `art/extended/warder_defendente.png`

**Uso:** referência principal do Defendente/Warder.  
**Inspirações abstratas:** cavaleiro-protetor, pavês/tower shield, relicário/lanterna, amuletos de juramento, pequeno guardião de pedra.  
**Paleta:** prata/ouro velho/marrom/cinza/marfim.  
**Não copiar 1:1:** quantidade de ornamentos pode ser reduzida bastante no sprite.

### `art/extended/ravager_berserker.png`

**Uso:** referência principal do Berserker/Ravager.  
**Inspirações:** fúria física, caçador de troféus, pelo/osso/ferro, personagem fofo com sorriso predatório; companheiro pequeno contrasta com brutalidade.  
**Paleta:** preto, sangue seco, vermelho ativado, couro, osso.

### `art/extended/sentinel_sentinela.png`

**Uso:** referência principal da Sentinela.  
**Inspirações:** vigia de fronteira, scout, bandeiras, bússola/lente, arqueiro disciplinado, coruja de observação.  
**Paleta:** sage, azul claro, branco/creme, couro claro, metal polido.  
**Distinção:** deve ser mais leve/linear que o Siege Bastion.

### `art/extended/waylayer_cacador.png`

**Uso:** referência principal do Caçador/Waylayer.  
**Inspirações:** trapper, fieldcraft, redes/cordas/jaw traps, camuflagem, ferret/stoat companion, leitura do terreno.  
**Paleta:** musgo, oliva, marrom, tan, linho.  
**Distinção:** pouco vermelho; violência ativada pertence ao Snare-Reaver, não ao Caçador puro.

### `art/extended/elementalist_elementalista.png`

**Uso:** referência principal do Elementalista.  
**Inspirações:** estudioso-aventureiro de elementos, astrolábio/prisma, trio de mascotes elementais.  
**Paleta:** navy/branco com Fogo vermelho, Gelo azul, Raio amarelo.  
**Regra:** Elementalista deve ser a identidade **mais saturada cromaticamente** entre as mágicas do MVP.

### `art/extended/spiritualist_visual_mood_exploration.png`

**Uso:** moodboard para Espiritualista: paleta, afterimages, ectoplasma, relação cute/uncanny.  
**Caveat:** a geração contaminou a silhueta com ranger/ghost-hunter. Não tratá-la como model sheet final do Espiritualista puro.  
**Paleta:** branco pálido, prata, cinza-azulado, carvão, preto.

## 14. Concept arts das híbridas

### `art/hybrids/runebound_knight_cavaleiro_runico.png`

**Referências/inspirações:** lógica de Invoker/Hwei aplicada a tank; cavaleiro rúnico clássico apenas como arquétipo amplo; defesa como ato de “escrever” fórmula.  
**Visual:** armadura do Warder com canais elementais — não uma roupa RGB.

### `art/hybrids/astral_ravager_devastador_astral.png`

**Referências:** Berserker + medium/possessão; golpes com ecos atrasados; contraste de corpo brutal com mãos/rostos espectrais.  
**Visual:** quanto maior a possessão, mais o vermelho pode perder saturação para branco/cinza espectral.

### `art/hybrids/siege_bastion_baluarte_de_cerco.png`

**Referências:** pavise, fortificação móvel, sentinel/watch lane, counterfire.  
**Visual:** Warder continua sendo o corpo; Sentinel aparece como linha, mira, bandeira e corredor.

### `art/hybrids/snare_reaver_saqueador.png`

**Referências:** trapper + berserker; rede de traps como rota do próprio corpo; caça que acelera com bleed.  
**Visual:** estado neutro terroso/musgo/ferrugem; vermelho vivo surge em traps acionadas, rush e frenzy.

### `art/hybrids/geometer_geometra.png`

**Referências:** “super-Invoker” espacial; geometria/astrolábio/cartografia, arco como ferramenta de desenho; pensamento tático prolongado.  
**Visual:** alta limpeza, branco/azul/ouro; as cores elementais devem aparecer nos **vértices/arestas**, não cobrir o personagem inteiro.

### `art/hybrids/hollow_marker_cacador_de_espectros.png`

**Referências:** Caçador + Espiritualista; soul dust, ghost arrows, banishment, rastreamento por mortos.  
**Visual:** corpo/equipamento continuam terrenos; só o fenômeno espiritual fica pálido/translúcido.

## 15. Preview in-game

### `art/previews/extended_classes_ingame_avatar_preview.png`

Mostra uma simplificação de cinco classes em proporção mais próxima de avatar de jogo: Warder, Ravager, Sentinel, Waylayer e Elementalist.

**Uso correto:** referência de silhueta, proporção e grau de simplificação.  
**Uso incorreto:** recortar o PNG como sprite final.

Ele deve ser comparado ao pipeline atual de Espadachim/Mago/inimigos no repo antes de definir escala, número de cores e frames.

## 16. Arquivo de exploração

`art/exploration_archive/` contém painéis anteriores. Servem para ideias de objeto, material e composição; não são fonte de verdade quando conflitam com as sheets individuais mais novas.

---

# PARTE V — COMO O CODEX DEVE RETOMAR

## 17. Mensagem de bootstrap recomendada para cada épico

Copiar/adaptar:

```text
Leia CODEX_HANDOFF_README.md e o documento do épico no repo.
Não implemente ainda.

1. Diga qual é o estado atual deste épico e qual commit/base você está assumindo.
2. Liste somente as decisões LOCKED que afetam a tarefa atual.
3. Liste decisões OPEN que realmente bloqueiam implementação; não invente resposta para elas.
4. Proponha a menor fatia implementável com arquivos permitidos, testes e critério de aceite.
5. Não reabra arquitetura, identidade de classe ou direção visual por preferência.
6. Não faça trabalho de outro épico.
7. Se a tarefa for rotineira e puder ser feita em Terra/Luna, diga isso antes de consumir trabalho de modelo mais caro.
```

Depois da aprovação, enviar uma tarefa fechada, por exemplo:

```text
Implemente somente a fatia aprovada.
Não altere gameplay fora dos contratos listados.
Rode os testes/verify acordados e reporte: arquivos mudados, testes, limitações e próximo delta.
Não faça refactor cosmético fora do escopo.
```

## 18. O que NÃO deve acontecer na retomada

- reescrever E00 porque um modelo prefere outra arquitetura;
- fazer Astra revisar toda mudança de UI/VFX;
- pedir ao Codex “deixe bonito” em loop aberto;
- gerar todos os sprites do roster antes do piloto de animação;
- implementar E10/E11 antes do demo;
- converter concept art diretamente em especificação de equipamento/skill;
- copiar ativos/estética proprietária de Ragnarok ou outros jogos;
- transformar click-to-move em WASD por conveniência;
- simplificar Geometer/Runebound Knight removendo sua gramática só para facilitar implementação;
- tratar números exemplificativos do E0 como balanceamento final.

---

# PARTE VI — PRÓXIMO NORTE PRÁTICO

Depois de E01, a sequência de maior retorno por token é:

1. **E02/E03** fechar UI mínima + progressão/matemática com contratos testáveis.
2. **E04** tornar Espadachim/Mago/Arqueiro completos e gostosos sem depender de augments.
3. Em paralelo fora do Codex, continuar a Bíblia Visual e reduzir concept sheets a silhouettes/paletas utilizáveis.
4. **E05** implementar híbridas por pares, começando por uma de cada tipo de complexidade, não as seis simultaneamente.
5. **E08B** criar kernel de VFX/animação reutilizável assim que os eventos de gameplay estejam estáveis.
6. **E07** provar ecologia de mobs/click-to-move/boss.
7. **E08C** gastar polimento nos momentos de glória do vertical slice.
8. **E09** integrar e congelar candidato; auditoria final cara somente no fim.

A prioridade do MVP é demonstrar simultaneamente:

- **identidade visual própria**;
- sensação nostálgica de MMORPG coreano antigo;
- sistemas de classe mais ousados/modernos;
- movimento/ecologia espacial coerentes com essa nostalgia;
- um vertical slice suficientemente bonito para comunicar potencial a apoiadores/investidores.

Não é necessário provar produção final de 80 classes para provar isso.
