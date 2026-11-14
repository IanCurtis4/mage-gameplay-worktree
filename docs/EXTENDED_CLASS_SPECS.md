# Fichas das classes estendidas — rascunho para discussão

14/11/2026. Pedido do usuário: definir cada classe estendida com profundidade (foco,
temática, descrição, escopo, habilidades e composição), de forma precisa o bastante
para dois usos:
- o briefing de arte;
- descrever com exatidão as híbridas que resultam de cada par.

Fonte de identidade: [CLASS_IDENTITY_REVIEW.md](CLASS_IDENTITY_REVIEW.md) (bases e
substantivos aceitos em 13/11; escopo das bases com invocação aceito em 14/11). Este
documento é uma proposta: não altera contrato, catálogo nem runtime.

## Restrições herdadas (já valem no jogo)

- Cada estendida nova parte de **7 skills exclusivas: 5 ativas e 2 passivas**,
  liberadas nos níveis de job 20, 23, 25, 28, 31, 34 e 37. A do nível 20 é a
  **entrada**: rank 1 gratuito, não equipada automaticamente. É o padrão de
  Elementalista e Espiritualista. Defendente, Berserker e Sentinela têm 9 skills, e a
  Caçadora tem 8: a biblioteca pode crescer depois, sem aumentar o loadout.
- **Loadout:** 5 ativas e 2 passivas, além do ataque básico, escolhidas entre a base
  e a estendida. A estendida precisa de motivo para manter skills da base no
  loadout, e vice-versa.
- **Um kit precisa funcionar sozinho contra boss sem adds.** Augments ampliam o kit;
  não consertam um loop incompleto.
- **As cinco perguntas do handoff de 13/09:** distância preferida, recurso
  administrado, como abre e fecha a sequência, que decisão muda contra o boss, e
  que fraqueza se mantém.

## Modelo de ficha

1. **Foco:** o papel em uma frase.
2. **Temática:** substantivo visual, tema e tom.
3. **Descrição:** quem é, em um parágrafo. Serve de texto para a arte.
4. **Escopo:** o que é desta classe, o que fica com a base e o que pertence a outras.
5. **Mecânica central e loop:** o recurso ou a regra própria, e a sequência de jogo.
6. **Habilidades:** as 7 skills por nível de job, com a função de cada uma. Números
   ficam para o contrato de implementação.
7. **Composição:**
   - do kit: o que equipar, mais duas builds de referência;
   - visual: silhueta, cor, material, forma, VFX, arma típica e o que muda durante
     o combate.
8. **Como origem e como afinidade:** o que esta classe empresta a uma híbrida. Pela
   regra de 13/09, a origem dá o objeto, o material e a postura; a afinidade dá o
   fenômeno.
9. **As cinco perguntas.**
10. **Arte necessária:** o que já existe e o que falta.

## Ordem proposta

1. **Bruxo: Demonólogo e Necromante** (abaixo). É a família mais discutida e a que
   já tem arte de criaturas.
2. Druida: Naturalista e Metamorfo (já há formas e aspectos).
3. Acólito: Sacerdote e Cultista.
4. Ladino: Assassino e Dervixe.
5. Monge: Elevado e Campeão.
6. Fichas das seis estendidas jogáveis, levantadas do código e dos checkpoints, no
   mesmo formato. Essas não serão redesenhadas, só registradas, para servir às
   híbridas. Feito em 14/11, com o quadro dos dezesseis substantivos no fim.

---

## Família Bruxo

### A base, de onde as duas partem

Escopo aceito em 14/11. Proposta de kit da base (nomes provisórios):

| Skill | Tipo | Função |
|---|---|---|
| Praga | ativa | DoT de dano mágico em um alvo. A aflição comum às duas evoluções. |
| Toque Debilitante | ativa | Enfraquece um alvo próximo: menos dano causado e menos velocidade de ataque. |
| Pacto Vital | ativa | Paga uma fração do próprio HP por SP e por um bônus curto de MATK. |
| Colheita de Essência | ativa, canalizada | Drena HP de um alvo aflito, para quem precisa sustentar a luta. |
| Chamar Diabrete | ativa | Um único diabrete permanente e fraco que ataca à distância. O Bruxo pode dar vida a ele ou tirar vida dele. |
| Restos Inquietos | passiva | Inimigo aflito que morre pode levantar como um Ossudo fraco e temporário, no máximo dois. |

**Regra de família (handoff de 13/09):** toda classe da família tem DoT e invocação.
No Demonólogo, a entidade vem primeiro e a aflição a alimenta. No Necromante, a
aflição prepara a morte e o servo nasce dela.

**Relação com a invocação (usuário, 13/11):** no Demonólogo, **simbiose**; no
Necromante, **parasitismo**.

---

### Demonólogo — vínculo

**1. Foco.** Luta através de **um** demônio permanente, escolhido entre três
arquétipos. Mestre e demônio dividem vida e poder.

**2. Temática.** Substantivo: **vínculo**. Tema: corrupção, poder e sofrimento alheio.
Tom: o pacto é justo e é cumprido, mas os dois lados gostam do que fazem.

**3. Descrição.** O Demonólogo fez um contrato e o honra. Fala com o demônio como com
um sócio: barganha, provoca e protege. O sofrimento dos inimigos é o salário do
demônio, e o mestre o paga em dia. Nunca é o mais forte do campo, mas o que ele
traz junto costuma ser.

**4. Escopo.**
- **É dele:**
  - os três arquétipos;
  - a troca de vida nos dois sentidos;
  - as maldições que o demônio ativo lê de forma diferente;
  - a forma maior do demônio no golpe final do kit.
- **Fica com a base:** Praga, Toque, Pacto Vital, Colheita e o Diabrete único. O
  Diabrete da base é substituído pelo arquétipo ativo quando este é chamado.
- **Não é dele:**
  - vários servos temporários e o consumo de servos (Necromante);
  - adoração de uma entidade que não responde (Cultista);
  - a fera de companhia (só existe no inimigo Mestre das Feras).

**5. Mecânica central: o vínculo.**
- **Um arquétipo ativo por vez, sem tempo de vida.** Trocar de arquétipo tem recarga
  longa: é a decisão tática da classe.
- **Vida em mão dupla:**
  - **Sifão** tira vida do demônio para curar o mestre;
  - **Oferenda** paga vida do mestre para pôr o demônio em **Fervor** (mais
    dano e habilidade inata ampliada).
- **Interdependência:** parte do dano que o mestre sofre vai para o demônio. Se o
  demônio cair, o vínculo se rompe: o mestre perde uma fração do HP atual e não
  pode chamar outro demônio por alguns segundos.
- **Tempo sem demônio curto ou compensado** (observação do usuário em 14/11): classes de
  demônio ficam fracas demais sem ele. A espera depois de uma queda precisa ser curta;
  se for longa (como no Exorcismo do Exorcista), precisa de compensação
  mecânica. A medida depende de playtest.
- **Maldição lida pelo demônio:** uma única maldição, a Marca do Credor, tem efeito
  diferente conforme o arquétipo ativo (decisão do usuário em 14/11). É o que faz
  as maldições "sinergizarem com os demônios", como pedido.

**Os três arquétipos:**

| Arquétipo | Corpo | Inata | Em alvo com a Marca do Credor |
|---|---|---|---|
| **Bruto** (tanque) | 1 Bruto demoníaco | Intercepta: provoca inimigos próximos periodicamente e recebe parte do dano do mestre | O alvo marcado só ataca o Bruto e causa menos dano |
| **Matilha** (corpo a corpo) | 2 Cães demoníacos (3 em rank alto) | Faro: os cães saltam no alvo aflito com menos HP | A mordida consome a aflição do alvo para dano imediato e cura o vínculo |
| **Coro** (à distância) | 3 Diabretes | Brasa: disparos rápidos à distância; um diabrete abatido volta após uma recarga | O disparo espalha a marca e a aflição para um alvo vizinho |

O Coro reaproveita o corpo do Diabrete da base (decisão do usuário em 14/11). O
conjurador demoníaco grande fica fora por ora.

**Loop:** chamar o arquétipo da situação → marcar e afligir → o demônio converte a
aflição pela sua inata → Oferenda nas janelas de pico, Sifão quando o mestre aperta
→ trocar de arquétipo quando a luta muda → forma maior no fim.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Contrato de Legião** | ativa, entrada | Chama o arquétipo escolhido (Bruto, Matilha ou Coro). Chamar outro substitui o atual, com recarga de troca. |
| 23 | **Laço de Sangue** | passiva | Parte do dano sofrido pelo mestre passa ao demônio. O demônio escala com o MATK e o HP máximo do mestre. |
| 25 | **Marca do Credor** | ativa | Maldição em um alvo. Efeito conforme o arquétipo ativo (tabela acima). |
| 28 | **Oferenda** | ativa | Paga HP do mestre e põe o demônio em Fervor. |
| 31 | **Sifão** | ativa | Tira HP do demônio e cura o mestre. Não mata o demônio: para em um piso. |
| 34 | **Fome do Pacto** | passiva | Inimigos aflitos que morrem perto do demônio o curam e prolongam o Fervor. |
| 37 | **Ascensão do Pacto** | ativa | Por alguns segundos, o demônio ativo assume a forma maior: o Bruto vira muralha (ampliado, imparável), a Matilha ganha um cão a mais e o Coro dispara em rajada. |

**7. Composição.**
- **Do kit:** Praga e Toque da base continuam no loadout, porque alimentam as inatas.
  Pacto Vital disputa espaço com a Oferenda. A Colheita é a cura de quem joga com
  a Matilha.
- **Build "Muralha":**
  - ativas: Bruto + Marca do Credor + Praga + Sifão + Ascensão;
  - passivas: Laço de Sangue + Fome do Pacto;
  - jogo: o demônio segura o boss e o mestre sustenta de trás.
- **Build "Caçada":**
  - ativas: Matilha + Marca do Credor + Praga + Toque + Oferenda;
  - passivas: Laço de Sangue + Restos Inquietos (base);
  - jogo: dano contínuo, com risco de HP.
- **Visual:**
  - silhueta de mestre magro e ereto, com o demônio sempre por perto;
  - cor: preto-tinta, carmim e amarelo-bile, com brasa nos pontos de contato e sem
    verde;
  - material: couro e ferro marcado a fogo; forma: elos, correntes, chifres;
  - arma típica: um tomo de contrato acorrentado (equipamento de foco; decisão do
    usuário em 14/11);
  - VFX: **um elo visível entre o mestre e o demônio**, que pulsa e muda de cor
    conforme a vida corre num sentido ou no outro; marcas de ferro sobre a vítima;
    fumaça de enxofre;
  - em combate: em Fervor, as rachaduras do demônio e as cicatrizes do mestre
    acendem juntas.

**8. Como origem e como afinidade.**
- **Como origem**, empresta a postura de quem luta *junto* com outro: o mestre fica
  atrás ou ao lado. Empresta também o objeto: corrente, marca de ferro, tomo.
- **Como afinidade**, empresta o fenômeno: **um parceiro com vontade própria, preso por
  um vínculo que troca vida**, e uma maldição que esse parceiro interpreta. A classe
  de origem decide que arquétipo faz sentido. Um Defendente com afinidade demoníaca
  pede o Bruto; um Ladino pede a Matilha.
- **Para evitar:** "skill X contratada". A afinidade tem que trazer o demônio, não um
  adjetivo.

**9. As cinco perguntas.**
- **Distância:** média; o mestre fica atrás do demônio.
- **Recurso:** HP, dos dois lados do vínculo.
- **Abrir e fechar:** abre com a marca e a aflição; fecha com Oferenda e Ascensão.
- **Contra o boss:** o Bruto segura o boss, ou a Matilha dá dano sustentado. A
  escolha do arquétipo e a hora de trocar decidem a luta.
- **Fraqueza:** sem o demônio, a classe fica pela metade, e a quebra do vínculo
  custa HP. O mestre sozinho é frágil.

**10. Arte.**
- **Já existe:** o Bruxo, o Diabrete, o Bruto e o Cão (rodadas de 16/11 e 17/11).
- **Falta:**
  - o traje do Demonólogo (quatro vistas);
  - o tomo de contrato (equipamento);
  - o elo do vínculo, que pode ser desenhado em código;
  - efeitos de Oferenda, Sifão, Marca do Credor e Ascensão.

---

### Necromante — podridão

**1. Foco.** Espalha doença e transforma os mortos em servos descartáveis, que
consome para se manter e para propagar a peste.

**2. Temática.** Substantivo: **podridão**. Tema: morte, decomposição,
apodrecimento, fungos e doenças. Tom: frio e paciente; a morte é colheita, não
tragédia.

**3. Descrição.** O Necromante não negocia com ninguém, porque o que ele usa já não
quer nada. Ele estuda a decomposição como um jardineiro estuda a estação: sabe
quanto tempo um corpo aguenta de pé e o que brota quando ele cai. Os servos são
ferramentas e acabam como adubo.

**4. Escopo.**
- **É dele:**
  - doença que se espalha;
  - restos que viram servos, até um limite, com tempo de vida;
  - consumo de servos (explosão, banquete);
  - solo contaminado.
- **Fica com a base:** Praga, Toque, Pacto Vital, Colheita, Diabrete e Restos
  Inquietos (o Ossudo básico).
- **Não é dele:**
  - um parceiro permanente com vínculo (Demonólogo);
  - fantasmas e ecos de quem morreu (Espiritualista);
  - plantas vivas e terreno que cura (Naturalista). Os fungos dele nascem do morto,
    não do vivo.

**5. Mecânica central: restos e peste.**
- **Peste:** DoT que **pula para os vizinhos quando o alvo morre**.
- **Restos:**
  - todo inimigo com Peste que morre deixa um resto no chão;
  - um resto dura alguns segundos e é o material dos servos e dos efeitos de consumo;
  - **visual (decisão do usuário em 14/11): carcaça e ossos no chão.** Os fungos
    entram só como detalhe. Pode ser um pouco gore: carne escura e ossos expostos,
    estilizados no traço do jogo, sem sangue jorrando. Essa permissão vale para os
    restos do Necromante e não muda a regra das outras classes.
- **Servos:**
  - limite de servos ativos, cada um com tempo de vida próprio e sem arquétipo fixo;
  - quando acaba o tempo ou morrem, se desfazem em fungo.
- **Parasitismo:** o Necromante pode consumir servos (explosão de esporos, banquete de
  vida). Servo é recurso, não companheiro.
- **Contra o boss sem adds (decisão do usuário em 14/11):** o chefe com Peste
  **solta restos de si mesmo conforme perde vida**: pedaços de carcaça e ossos que
  se desprendem do corpo e caem ao redor dele. Isso garante material sem depender
  de horda.
  - **Regra (confirmada pelo usuário em 14/11): por porcentagem da vida máxima, não
    por dano fixo.** Um
    resto a cada 10% de vida máxima perdida enquanto o chefe tem Peste, ou seja,
    até 10 restos por luta.
  - **Por quê:** com dano fixo, um chefe de muito HP solta restos demais e um de pouco
    HP quase nenhum. O número também mudaria conforme o personagem fica mais forte.
    Com porcentagem, toda luta de chefe rende a mesma quantidade previsível, e a
    quantidade se ajusta num único número.
  - **Proteção:** perder vários limiares de uma vez (num golpe muito forte) solta
    um resto por limiar, mas no máximo dois por segundo; o excedente cai em
    sequência. Limiares perdidos sem Peste no chefe não contam e não voltam.
  - Chefes nunca viram servos: os restos são pedaços, não o chefe.
- **Limites obrigatórios** (roster de 13/09):
  - teto de servos e duração;
  - chefes nunca viram servos;
  - morte de servo e DoT não geram cadeias infinitas de restos.

**Loop:** Peste → mortes espalham a Peste e deixam restos → Erguer Mortos → os servos
seguram e ferem → consumir servos (esporos para espalhar, banquete para curar) → os
servos que caem contaminam o solo → mais Peste.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Peste Rastejante** | ativa, entrada | DoT que pula para os vizinhos na morte do alvo e deixa resto. Em chefe, faz cair um resto a cada 10% de vida máxima perdida. |
| 23 | **Mãos Mortas** | passiva | +1 no limite de servos. Os servos herdam parte do MATK do Necromante. |
| 25 | **Erguer Mortos** | ativa | Levanta todos os restos próximos como Ossudos, até o limite, com tempo de vida. |
| 28 | **Esporos** | ativa | Consome um servo: ele explode numa nuvem que aplica Peste em área. |
| 31 | **Banquete** | ativa | Drena vida de todos os servos para curar o Necromante; os servos perdem tempo de vida. |
| 34 | **Solo Pútrido** | passiva | Onde um servo morre fica uma mancha de fungos que deixa os inimigos lentos e renova a Peste. |
| 37 | **Colosso de Podridão** | ativa | Funde todos os servos e restos próximos num colosso temporário de ossos e fungos. Quanto mais material, mais forte e mais duradouro. |

**7. Composição.**
- **Do kit:** Praga sai do loadout cedo, porque a Peste a substitui. Toque continua
  como defesa. A Colheita compete com o Banquete. Restos Inquietos (base) e Mãos
  Mortas juntos aumentam o exército.
- **Build "Horda":**
  - ativas: Peste + Erguer Mortos + Esporos + Toque + Colosso;
  - passivas: Mãos Mortas + Solo Pútrido;
  - jogo: muitos servos, contágio em cadeia, ótimo contra grupos.
- **Build "Parasita":**
  - ativas: Peste + Erguer Mortos + Banquete + Colheita + Pacto Vital;
  - passivas: Mãos Mortas + Restos Inquietos;
  - jogo: poucos servos usados como reserva de vida, mais resistente contra o
    boss.
- **Visual:**
  - silhueta curvada, com capuz e manto pesado;
  - cor: verde-musgo apodrecido, ocre, marfim de osso e roxo-hematoma;
  - material: osso, pano mortuário, terra e fungos; forma: costelas, chapéus de
    cogumelo, manchas;
  - arma típica: um cajado de ossos (equipamento; decisão do usuário em 14/11);
  - VFX: carcaças e ossos no chão (os restos), pedaços que se desprendem do chefe,
    esporos, nuvens de doença, chão que apodrece;
  - em combate: quanto mais servos ativos, mais fungos brotam no traje.

**8. Como origem e como afinidade.**
- **Como origem**, empresta a postura de quem fica atrás de uma massa descartável e
  o material: osso, fungo, pano mortuário.
- **Como afinidade**, empresta o fenômeno: **o que morre vira recurso**. Doença que se
  espalha na morte, restos usados como munição, corpo ou servo, e consumo do que é
  descartável. A origem decide o que se faz com o resto. Um Caçador o usa como
  isca de armadilha; um Berserker o devora para se curar.
- **Para evitar:** "esqueleto que faz a skill X". A afinidade traz o ciclo
  morte → resto → uso, não um esqueleto decorativo.

**9. As cinco perguntas.**
- **Distância:** média a longa, atrás dos servos.
- **Recurso:** restos e servos (tempo de vida); HP no Banquete.
- **Abrir e fechar:** abre com a Peste; fecha com os Esporos ou o Colosso.
- **Contra o boss:** sem horda, depende dos restos que o chefe solta ao perder
  vida. A decisão é gastar os restos em servos que seguram o chefe ou guardar para o
  Colosso.
- **Fraqueza:** lento para começar; se os servos forem limpos em área, perde o
  material. Sem servos, o Necromante sozinho é frágil.

**10. Arte.**
- **Já existe:** o Bruxo e o Ossudo.
- **Falta:**
  - o traje do Necromante (quatro vistas);
  - o cajado de ossos (equipamento);
  - o colosso (corpo grande, ou o Ossudo ampliado com fungos);
  - o resto no chão (carcaça e ossos, algumas variações) e o efeito de pedaços se
    desprendendo do chefe;
  - efeitos de Peste, nuvem de esporos, solo pútrido e banquete.

---

### Diferença entre as duas, num quadro

| | Demonólogo | Necromante |
|---|---|---|
| Relação | simbiose | parasitismo |
| Invocação | 1 arquétipo, permanente | vários servos, temporários |
| A aflição | alimenta o demônio | prepara a morte que vira servo |
| O que circula | vida nos dois sentidos | vida só para o mestre |
| A morte da invocação | rompe o vínculo e custa HP | é recurso (esporos, solo) |
| Fim do kit | o demônio cresce (Ascensão) | os mortos se fundem (Colosso) |

### Decisões do usuário sobre o Bruxo (14/11)

Família Bruxo fechada para fins de arte e de descrição de híbridas.

1. Artilharia do Demonólogo: **Coro de diabretes**. Conjurador grande fica fora por ora.
2. **Uma única Marca do Credor**, lida de forma diferente por cada arquétipo.
3. Necromante contra chefe: **o chefe solta restos de si mesmo conforme perde vida**;
   os restos são carcaça e ossos, com um pouco de gore permitido. Regra confirmada:
   **porcentagem da vida máxima**, um resto a cada 10% perdido com Peste ativa, no
   máximo dois por segundo.
4. Armas: **tomo acorrentado** (Demonólogo) e **cajado de ossos** (Necromante).

---

## Família Druida

### A base, de onde as duas partem

Escopo aceito em 14/11: a Druida **não se transforma**. Ela invoca aspectos (a
silhueta do animal sobreposta ao corpo por um instante), com os mesmos três animais
do Metamorfo. O lado Naturalista são skills de terreno. Proposta de kit (nomes
provisórios):

| Skill | Tipo | Função |
|---|---|---|
| Raízes | ativa | Prende um alvo ou uma área pequena por pouco tempo. |
| Broto Restaurador | ativa | Um broto no chão cura quem estiver perto por alguns segundos. |
| Espeto de Pedra | ativa | Um espeto de pedra sobe sob um alvo, com dano alto em alvo único. É a amostra da base para a magia de pedra da Naturalista. |
| Pele de Urso | ativa (aspecto) | Proteção curta (DEF/MDEF), com a silhueta do urso sobre o corpo. |
| Garra Felina | ativa (aspecto) | Golpe em arco curto à frente com marcas de garra. |
| Salto da Ave | ativa (aspecto) | Deslocamento com asas e penas; o fim do salto é imune a lentidão. |
| Memória da Terra | passiva | Usar uma skill de terreno reduz a recarga do próximo aspecto, e vice-versa. |

A passiva ensina a tensão da base (**enraizar ↔ tornar-se**): alternar os dois
lados rende mais que repetir um só. O roster de 13/09 trazia "Forma de lobo curta";
ela sai, porque o lobo não é uma das formas do Metamorfo e porque a base não se
transforma. "Pedra Ascendente" virou **Espeto de Pedra**, porque a pedra passou a
ser um pilar próprio da Naturalista (decisão do usuário em 14/11).

---

### Naturalista — raiz

**1. Foco.** Molda o campo com **pedra** e o ocupa com **sementes** que crescem e
lutam por ela. Luta de dentro do território que construiu.

**2. Temática.** Substantivo: **raiz**. Tema: o que cresce do chão, se agarra e
sustenta; paciência e território. Tom: serena até alguém pisar no que é dela.

**3. Descrição.** A Naturalista não corre atrás de ninguém. Ela escolhe o chão,
levanta a pedra e planta, e o lugar passa a lutar por ela: raízes de espinho que
cortam quem passa, flores que cospem, sementes que estouram. Fala pouco e conhece
cada palmo do território. Quem entra ali entra na casa dela.

**4. Escopo.** Dois pilares, por decisão do usuário (14/11):
- **Sementes:** plantas vivas que crescem e atacam sozinhas.
- **Rocha:** magia de controle de terreno (paredes, fissuras, espetos). O usuário a
  descreveu como "o quarto elemento perdido do Elementalista". Não é semente nem
  cresce: é terreno moldado na hora.
- **É dela:**
  - as três sementes e o território;
  - a muralha e a fissura;
  - a interação entre os dois pilares (pedra que faz a semente render mais).
- **Fica com a base:** Raízes, Broto Restaurador, Espeto de Pedra e os três
  aspectos.
- **Não é dela:**
  - armadilhas acionadas pelo inimigo (Caçador); a semente é uma planta viva que
    cresce e ataca por conta própria, não um mecanismo à espera do gatilho;
  - figuras geométricas entre pontos (Geômetra);
  - fungos e o que nasce do morto (Necromante); ela faz crescer o vivo;
  - fogo, gelo e raio com reações entre si (Elementalista). A rocha é matéria
    que fica no campo, não energia.

**5. Mecânica central: sementes, pedra e território.**
- **Sementes:**
  - cada skill de semente planta uma num ponto escolhido;
  - a semente leva alguns segundos para **amadurecer**; madura, fica mais forte;
  - há um limite de sementes ativas; plantar além dele seca a mais antiga;
  - os inimigos podem atacar as sementes.
- **Os três tipos (definidos pelo usuário em 14/11):**

| Semente | O que faz | Madura |
|---|---|---|
| **Espinheiro** | Espalha uma rede de raízes espinhentas no chão. Quem atravessa leva dano e fica lento. | A rede fica maior. |
| **Flor-cuspideira** | Uma flor fixa que atira projéteis em linha reta, de alcance médio, que **atravessam os inimigos**, como os tiros perfurantes da Sentinela. | Atira mais rápido. |
| **Semente-Bomba** | Explode depois de um tempo, ou antes se o inimigo a atacar. Causa dano em área e deixa uma **nuvem de pólen** que causa DoT. | Explosão e nuvem maiores. Se o inimigo a estourar cedo, a explosão é mais fraca. |

- **Pedra:** magia de terreno sem crescimento.
  - **Espeto de Pedra** (base): sobe sob um alvo, com dano muito alto em alvo único.
  - **Muralha Mineral:** ergue uma parede que bloqueia passagem e projéteis.
  - **Fissura:** abre uma fenda no chão em linha, com dano alto em área.
- **Pedra e semente:**
  - sementes plantadas junto à pedra amadurecem mais rápido;
  - a muralha protege a Flor-cuspideira e encaminha os inimigos para o Espinheiro;
  - a Fissura que atravessa sementes as faz agir na hora.
- **Território:** dentro do raio das próprias sementes, a Naturalista ganha **Seiva**
  (DEF, MDEF e regeneração). Fora dele, é frágil.

**Loop:** escolher o chão → erguer a muralha para fechar a passagem → plantar
Espinheiro no corredor, Flor atrás da muralha e Bomba onde o grupo vai chegar →
segurar o território enquanto amadurece → Fissura pelo meio das sementes no pico →
Espeto no que sobrar → replantar.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Semeadura** | ativa, entrada | Planta um Espinheiro no ponto escolhido. |
| 23 | **Seiva** | passiva | Liga o território: DEF, MDEF e regeneração perto das próprias sementes. |
| 25 | **Flor-cuspideira** | ativa | Planta uma Flor-cuspideira, que atira na direção do inimigo mais próximo. |
| 28 | **Muralha Mineral** | ativa | Ergue uma parede de pedra que bloqueia passagem e projéteis. |
| 31 | **Solo Fértil** | passiva | Sementes perto de pedra amadurecem mais rápido, e o limite de sementes sobe. |
| 34 | **Semente-Bomba** | ativa | Planta uma Semente-Bomba. |
| 37 | **Fissura** | ativa | Abre uma fenda em linha, com dano alto em área. Cada semente atravessada age na hora, já madura: o Espinheiro se espalha ao longo da fenda, a Flor dispara uma rajada e a Bomba explode. |

**7. Composição.**
- **Do kit:**
  - Raízes (base) segura o inimigo em cima do Espinheiro ou ao lado da Bomba;
  - Espeto de Pedra (base) é o dano em alvo único e o par natural da Muralha;
  - Broto Restaurador ainda serve quando a Seiva não basta;
  - os aspectos saem do loadout cedo.
- **Build "Bastião":**
  - ativas: Semeadura + Muralha + Flor-cuspideira + Raízes + Fissura;
  - passivas: Seiva + Solo Fértil;
  - jogo: fecha corredores e deixa as plantas trabalharem; forte contra grupos que
    avançam.
- **Build "Pedreira":**
  - ativas: Semente-Bomba + Muralha + Espeto de Pedra + Semeadura + Fissura;
  - passivas: Solo Fértil + Memória da Terra;
  - jogo: mais pedra e explosões; o Espeto dá o dano contra o chefe.
- **Visual:**
  - silhueta firme e baixa, de manto pesado e enraizado;
  - cor: verde-folha, marrom-terra, cinza-pedra, com flores pontuais;
  - material: madeira viva, pedra, musgo; forma: raízes que se agarram, camadas de
    rocha;
  - arma típica: cajado de madeira viva com folhas (equipamento);
  - VFX: as três sementes (plantada e madura), a rede de espinhos no chão, os
    projéteis da flor, a explosão e a nuvem de pólen, a parede, a fenda e o espeto;
  - em combate: dentro do território, o traje ganha folhas e o contorno brilha em
    verde-seiva.

**8. Como origem e como afinidade.**
- **Como origem**, empresta a postura territorial (ficar, defender o lugar) e o
  material: madeira viva, pedra, musgo.
- **Como afinidade**, empresta dois fenômenos, e a híbrida escolhe um como
  principal:
  - **plantas vivas que ocupam o terreno e lutam sozinhas** (sementes);
  - **o terreno moldado na hora** (pedra).
  A origem decide o uso. Uma Sentinela planta Flores-cuspideiras na própria linha de
  tiro; um Defendente levanta a própria muralha.
- **Para evitar:** "skill X com folhas". A afinidade traz uma planta que age ou uma
  pedra que muda o caminho, não uma cor verde.

**9. As cinco perguntas.**
- **Distância:** média, dentro do próprio território.
- **Recurso:** sementes (tempo de amadurecimento e limite), as paredes e a posição.
- **Abrir e fechar:** abre com a muralha e as sementes; fecha com a Fissura.
- **Contra o chefe:** plantar onde o chefe vai estar, não onde ele está, e usar o
  Espeto como dano principal. A decisão é gastar a Fissura nas sementes ou guardá-la
  para uma fase.
- **Fraqueza:** precisa de tempo para preparar, e as sementes podem ser destruídas.
  Se for empurrada para fora do território, perde a Seiva.

**10. Arte.**
- **Já existe:** a Druida (quatro vistas) e os aspectos (urso, felino, ave).
- **Falta:**
  - o traje da Naturalista (quatro vistas);
  - o cajado de madeira viva (equipamento);
  - as três sementes no chão, plantada e madura (props pequenos);
  - a rede de espinhos, o projétil da flor, a explosão e a nuvem de pólen;
  - a parede, a fenda e o espeto de pedra;
  - a Seiva no corpo, que pode ser desenhada em código.

---

### Metamorfo — pelagem

**1. Foco.** Luta **trocando de corpo**: urso para aguentar, felino para entrar e sair,
ave para atravessar. A troca de forma é, ela mesma, um golpe.

**2. Temática.** Substantivo: **pelagem** (pele, garra, crina: a fronteira do corpo que
muda). Tema: instinto, corpo, transição. Tom: selvagem, mas não descontrolado. A
diferença para o Berserker: a fúria dele custa sangue; a Metamorfo não perde o
controle, só muda de corpo.

**3. Descrição.** A Metamorfo deixou de pensar no corpo como uma coisa fixa. Ela entra
no urso quando precisa ficar, no felino quando precisa caçar e na ave quando precisa
sair dali. A voz, a postura e o olhar mudam a cada forma, mas a pintura no corpo e o
colar de pedras continuam lá: é sempre a mesma pessoa.

**4. Escopo.**
- **É dela:**
  - as três formas completas;
  - o golpe de entrada de cada forma;
  - o Instinto que passa de uma forma para outra;
  - uma ação que muda conforme a forma.
- **Fica com a base:** os aspectos e as skills de terreno. Os aspectos ganham um
  efeito extra na forma correspondente (Garra Felina na forma felina, por exemplo).
  As skills de terreno só funcionam na forma humana.
- **Não é dela:**
  - fúria que custa HP e marca o alvo (Berserker);
  - sequência de golpes em ritmo (Campeão);
  - invocar um animal separado de si (nenhuma classe jogável tem isso).

**5. Mecânica central: formas e transição.**
- **Três formas, além da humana:**
  - **Urso:** muito HP e DEF; o ataque básico vira patada em arco curto. Lento.
  - **Felino:** rápido; o ataque básico é veloz e tem crítico maior pelas costas.
    Frágil.
  - **Ave:** a mais móvel. Faz um **voo raso** (decisão do usuário em 14/11): ignora
    efeitos de chão (lentidão, armadilhas) e passa por cima dos inimigos, mas respeita
    os limites do mapa e não sobrevoa paredes nem vãos. O ataque básico é um rasante
    curto.
- **Entrada de forma (decisão do usuário em 14/11):** as formas não ocupam os 5
  slots do loadout.
  - A skill de entrada libera uma **barra de formas própria** (humana, urso, felino,
    ave), com teclas dedicadas, como a barra de elementos da Geômetra (hoje em F1,
    F2 e F3).
  - As teclas não precisam ser as mesmas. O usuário pretende rever essas teclas no
    futuro, porque não acha natural usar as teclas F.
- **Golpe de entrada:** entrar numa forma dispara uma ação própria.
  - Urso: rugido que provoca os inimigos próximos.
  - Felino: bote no alvo.
  - Ave: salto alto que reposiciona e evita o primeiro golpe recebido.
- **Instinto:** lutar numa forma acumula Instinto, até três cargas. Trocar de forma
  gasta todo o Instinto e amplia o golpe de entrada da forma nova. Isso transforma a
  troca numa decisão de ritmo: ficar para acumular ou trocar no pico.
- **Custo da troca:** uma recarga curta, previsível e igual para todas as formas,
  como o roster de 13/09 pedia.
- **Equipamento (decisão do usuário em 14/11):** na forma animal, a arma e o traje
  **não aparecem, mas os atributos continuam valendo**, inclusive o ATQ da arma.
  Um cajado melhor continua dando mais dano às formas. A personagem escala com o
  equipamento normalmente, sem precisar desenhá-lo no animal.

**Loop:** entrar no felino para alcançar o alvo → acumular Instinto → trocar para o
urso no pico (rugido ampliado) e segurar o grupo → ave para sair quando apertar →
voltar ao felino com o Instinto da ave → no fim, Ciclo Selvagem.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Metamorfose** | ativa, entrada | Libera a barra de formas e a **Forma do Urso**. |
| 23 | **Pelagem Viva** | passiva | Cada forma dá um bônus próprio enquanto ativa e deixa um resíduo de 3 s ao sair (urso: DEF; felino: velocidade de ataque; ave: esquiva). |
| 25 | **Forma do Felino** | ativa de forma | Libera o felino na barra de formas. Os ranks melhoram o felino e o bote. |
| 28 | **Forma da Ave** | ativa de forma | Libera a ave na barra de formas. Os ranks melhoram a ave e o salto. |
| 31 | **Instinto** | passiva | Liga as cargas de Instinto e a ampliação do golpe de entrada. |
| 34 | **Dilacerar** | ativa | Uma ação, três leituras: no urso, esmaga em área; no felino, rasga e deixa sangramento; na ave, rasante em linha. Não pode ser usada na forma humana. |
| 37 | **Ciclo Selvagem** | ativa | Por alguns segundos, trocar de forma não tem recarga, e cada troca dispara o golpe de entrada com Instinto máximo. |

Como as formas ficam na barra própria, o loadout normal guarda Dilacerar, Ciclo
Selvagem e três skills da base. Os aspectos ampliados pela forma são os candidatos
naturais.

**7. Composição.**
- **Do kit:** Garra Felina, Pele de Urso e Salto da Ave ganham sentido novo nas
  formas. As skills de terreno exigem voltar à forma humana: escolher entre ser
  bicho e cuidar do campo é a tensão da base levada ao limite.
- **Build "Fera da Linha de Frente":**
  - ativas: Dilacerar + Ciclo Selvagem + Pele de Urso + Garra Felina + Raízes;
  - passivas: Pelagem Viva + Instinto;
  - jogo: urso e felino alternados, sustentação contra grupos.
- **Build "Predadora":**
  - ativas: Dilacerar + Ciclo Selvagem + Garra Felina + Salto da Ave + Broto;
  - passivas: Instinto + Memória da Terra;
  - jogo: felino e ave, entrar e sair; dano em alvo único contra o chefe.
- **Visual:**
  - forma humana: a Druida com uma máscara ou um manto de pele de animal e pintura
    corporal mais marcada;
  - cor: castanho, cinza-lobo, ocre; a pintura muda de cor por forma (ocre no
    urso, verde no felino, âmbar na ave);
  - material: pele, amuletos de osso, garras; forma: silhueta que muda;
  - arma típica: a mesma da Druida (cajado), visível só na forma humana;
  - VFX: a transição explode em pelos ou penas; marcas de garra; o Instinto aparece
    como a pintura acendendo, uma marca por carga;
  - em combate: a pintura acesa conta o Instinto na própria pele.

**8. Como origem e como afinidade.**
- **Como origem**, empresta o corpo que muda e a postura instintiva, e o material:
  pele, garra, amuleto de osso.
- **Como afinidade**, empresta o fenômeno: **mudar o estado do corpo, com a transição
  servindo de golpe**. A origem decide em que o corpo se transforma ou em que
  momento. Um Berserker vira fera quando a ferida chega ao máximo; um Espiritualista
  passa a uma forma ancestral que atravessa a matéria.
- **Para evitar:** "skill X com orelhas de bicho". A afinidade traz uma troca real de
  estado, com custo e golpe de transição, não um efeito cosmético.

**9. As cinco perguntas.**
- **Distância:** corpo a corpo (urso, felino) e curta e móvel (ave).
- **Recurso:** Instinto e a recarga de troca.
- **Abrir e fechar:** abre com o golpe de entrada; fecha com uma troca no pico de
  Instinto ou com o Ciclo Selvagem.
- **Contra o chefe:** urso para as fases de pressão, felino nas janelas de dano, ave
  para sair das áreas. A decisão é quando gastar o Instinto.
- **Fraqueza:** cada forma tem um ponto fraco claro (urso lento, felino frágil, ave
  com pouco dano), e a recarga de troca pune a troca errada. Não tem acesso às
  skills de terreno enquanto está em forma animal.

**10. Arte.**
- **Já existe:** a Druida, as três formas (quatro vistas cada) e os aspectos.
- **Falta:**
  - o traje da Metamorfo na forma humana (quatro vistas);
  - a explosão de transição (pelos e penas), uma por forma;
  - os três efeitos de Dilacerar;
  - as marcas de garra do aspecto felino, que faltaram na entrega de 17/11 e podem
    ser desenhadas em código.

---

### Diferença entre as duas, num quadro

| | Naturalista | Metamorfo |
|---|---|---|
| Tensão da base | enraizar | tornar-se |
| Onde está o poder | no chão (sementes e pedra), fora do corpo | no corpo, que muda |
| Tempo | espera o amadurecimento | acumula Instinto e troca no pico |
| Posição | fica no território | entra e sai |
| Momento de glória | Fissura atravessando as sementes | Ciclo Selvagem |
| Fraqueza | preparação e posição | ponto fraco de cada forma |

### Decisões do usuário sobre o Druida (14/11)

Família Druida fechada para fins de arte e de descrição de híbridas.

1. **Barra de formas própria** para o Metamorfo, como a barra de elementos da
   Geômetra. As teclas serão revistas no futuro.
2. **Ave em voo raso:** ignora efeitos de chão e passa por cima dos inimigos, sem
   sobrevoar os limites do mapa.
3. **Nenhuma arma visível nas formas**, mas os atributos da arma continuam valendo.
4. **Sementes:** Espinheiro (rede de raízes espinhentas, dano e lentidão),
   Flor-cuspideira (projéteis perfurantes em linha reta, alcance médio) e
   Semente-Bomba (explode por tempo ou ao ser atacada, área e nuvem de pólen com DoT).
   A **pedra** sai das sementes e vira um pilar separado da Naturalista, de controle
   de terreno: paredes, fissuras de dano alto em área e espetos de dano muito alto em
   alvo único.

---

## Família Acólito

**Contexto técnico que pesa nesta família:**
- **O jogo não tem aliados.** Toda cura e proteção precisa valer para o próprio
  personagem; em híbridas, também para as próprias invocações.
- **Não existe categoria de inimigo** "morto-vivo" ou "fantasma". O bônus do
  Exorcismo depende de uma marcação nova nos inimigos, a ser criada com o conteúdo.

### A base, de onde as duas partem

Tensão: **servir ↔ contemplar**. Proposta de kit (nomes provisórios, a partir do
roster de 13/09):

| Skill | Tipo | Função |
|---|---|---|
| Luz Punitiva | ativa | Projétil de luz em linha que fere o primeiro inimigo. |
| Prece | ativa | Cura o próprio Acólito ao longo de alguns segundos. |
| Escudo Votivo | ativa | Barreira curta que absorve uma quantidade de dano. |
| Selo Sombrio | ativa | Marca um alvo: DoT de sombra e menos precisão por alguns segundos. |
| Sussurro Perturbador | ativa | Cone curto: aplica um pouco de Loucura (a mecânica do Cultista) e afasta os inimigos comuns por um instante. |
| Devoção | passiva | Usar uma skill de luz e depois uma de sombra (ou o contrário) deixa a seguinte mais forte. |

Arma típica da base: um livro de orações (foco).

---

### Sacerdote — halo

**1. Foco.** Delimita um lugar sagrado e luta de dentro dele. Protege a si mesmo, e
o excesso dessa proteção vira luz que pune.

**2. Temática.** Substantivo: **halo** (luz que envolve e delimita: aros, círculos,
selos fechados). Tema: fé, proteção, julgamento. Tom: firme e sem raiva; pune por
dever, não por prazer.

**3. Descrição.** O Sacerdote acredita que existem lugares onde o mal não entra, e que
o trabalho dele é desenhar esses lugares no chão. Fica de pé no centro do círculo, de
mãos abertas, e deixa o que não pertence ao mundo se aproximar o suficiente para ser
julgado. A cura que recebe e a que não precisou usar viram a mesma coisa: luz.

**4. Escopo.**
- **É dele:**
  - o Santuário (um círculo no chão com regras próprias);
  - a Graça (cura excedente transformada em carga de luz);
  - o halo no próprio corpo (barreira);
  - o julgamento (dano vertical de luz) e o exorcismo.
- **Fica com a base:** Luz Punitiva, Prece, Escudo Votivo, Selo Sombrio e Sussurro.
- **Não é dele:**
  - guarda direcional e contra-ataque pela posição do corpo (Defendente). O
    Sacerdote protege uma *área*, sem direção;
  - terreno que se planta (Naturalista);
  - campo mental que empurra e suspende (Elevado).

**5. Mecânica central: Santuário e Graça.**
- **Santuário:**
  - um círculo de luz no chão, um por vez, com duração;
  - dentro dele, o Sacerdote recebe menos dano e a cura dele rende mais;
  - inimigos que entram são queimados aos poucos;
  - sair do círculo não o desfaz, mas o Sacerdote perde os bônus.
- **Graça:**
  - toda cura que passaria do HP máximo vira **Graça**, até cinco cargas;
  - a Graça é gasta no **Juízo**.
  É assim que um curandeiro sem aliados não desperdiça a própria função: quanto
  melhor ele se protege, mais pune.
- **Exorcismo:** a luz do Sacerdote remove buffs e escudos de inimigos e causa dano
  extra em criaturas marcadas como mortas-vivas ou fantasmas, quando elas existirem.
  O usuário confirmou a ideia em 14/11. Ela será expandida quando chegarem as
  híbridas que dependem do Sacerdote. A cura que fere mortos-vivos e fantasmas
  também foi citada e fica registrada para essa expansão.

**Loop:** Santuário onde vai lutar → segurar o dano com o halo e a Prece → a cura que
sobra vira Graça → Selo prende quem entra → Juízo com Graça cheia → renovar o
Santuário → no pico, Hora Santa.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Santuário** | ativa, entrada | Desenha o círculo de luz no ponto escolhido. Um por vez. |
| 23 | **Graça** | passiva | Liga as cargas de Graça (cura excedente). Entrar no Santuário com Graça cheia dá um pulso de cura. |
| 25 | **Égide** | ativa | Um halo no próprio corpo absorve dano. Quando quebra ou expira, solta um pulso de luz que empurra os inimigos próximos. |
| 28 | **Juízo** | ativa | Gasta toda a Graça: uma coluna de luz cai sobre o alvo. O dano escala com as cargas. Dentro do Santuário, atinge todos os inimigos no círculo. |
| 31 | **Exorcista** | passiva | A luz remove um buff ou escudo do inimigo atingido e causa dano extra em mortos-vivos e fantasmas. |
| 34 | **Selo de Luz** | ativa | Um aro se fecha sobre o alvo: prende e marca. Dano de luz contra o marcado gera Graça. |
| 37 | **Hora Santa** | ativa | O Santuário cresce e fica dourado por alguns segundos: a cura dobra, a Graça não tem limite e cada Juízo dentro dele não custa SP. |

**7. Composição.**
- **Do kit:**
  - Prece e Escudo Votivo (base) são a fonte de Graça; ficam no loadout;
  - Luz Punitiva dá dano à distância fora do Santuário;
  - Selo Sombrio e Sussurro saem cedo: o lado de sombra fica com o Cultista.
- **Build "Bastião da Fé":**
  - ativas: Santuário + Égide + Prece + Escudo Votivo + Hora Santa;
  - passivas: Graça + Devoção;
  - jogo: quase impossível de derrubar dentro do círculo; dano vem do pulso da
    Égide e da queimadura do Santuário.
- **Build "Inquisição":**
  - ativas: Santuário + Juízo + Selo de Luz + Prece + Hora Santa;
  - passivas: Graça + Exorcista;
  - jogo: transforma cura em Juízos frequentes; melhor contra o chefe.
- **Visual:**
  - silhueta ereta e simétrica, de túnica longa;
  - cor: marfim, dourado pálido, azul-céu;
  - material: linho, ouro fino, vidro de vitral; forma: círculos fechados, simetria,
    verticais;
  - arma típica: um cetro com um aro dourado no topo (equipamento);
  - VFX: o círculo do Santuário no chão, aros que se fecham, feixes verticais (Juízo),
    poeira dourada que assenta devagar; as cargas de Graça como pequenos aros
    girando sobre a cabeça;
  - em combate: na Hora Santa, o círculo e o traje ficam dourados.

**8. Como origem e como afinidade.**
- **Como origem**, empresta a postura de quem fica no centro de um lugar protegido e
  o material: linho, ouro, vitral.
- **Como afinidade**, empresta o fenômeno: **um círculo que muda as regras de quem está
  dentro** (protege o que é seu, pune o que não é), e **proteção que sobra e vira
  luz**. A origem decide o formato do círculo. Um Defendente o carrega no escudo; uma
  Sentinela o desenha ao longo da linha de tiro.
- **Para evitar:** "skill X dourada". A afinidade traz um lugar com regra própria ou a
  conversão de proteção em dano, não um brilho.

**9. As cinco perguntas.**
- **Distância:** curta a média, dentro do Santuário.
- **Recurso:** Graça (cura excedente) e o tempo do Santuário.
- **Abrir e fechar:** abre com o Santuário; fecha com o Juízo ou a Hora Santa.
- **Contra o chefe:** levar o chefe para o círculo, ou mudar o círculo de lugar
  quando o chefe muda de fase. A decisão é gastar a Graça cedo ou acumular para um
  Juízo cheio.
- **Fraqueza:** dano baixo fora do Santuário; chefes que forçam movimento constante
  tiram o Sacerdote do círculo.

**10. Arte.**
- **Já existe:** o Acólito (quatro vistas).
- **Falta:**
  - o traje do Sacerdote (quatro vistas);
  - o cetro com aro (equipamento);
  - o círculo do Santuário (desenho no chão), a coluna do Juízo, o aro do Selo, o halo
    da Égide e a Hora Santa.

---

### Cultista — olho

**1. Foco.** Enlouquece os inimigos. Os comuns passam a atacar uns aos outros, e os
chefes abrem janelas de desorientação.

**2. Temática.** Substantivo: **olho** (a percepção que se abre: fendas, pupilas,
geometrias que não fecham). Tema: êxtase, revelação, loucura. Tom: o Cultista está
feliz, e isso é o mais assustador.

**3. Descrição.** O Cultista olhou diretamente para o que adora, e aquilo olhou de
volta. Desde então, ele vê coisas que os outros não aguentam ver, e o trabalho dele é
mostrar. Sorri na hora errada, sussurra para o vazio e se aproxima dos inimigos como
quem traz uma boa notícia. Ele não negocia com a entidade, como o Demonólogo; ele a
adora, e ela não responde.

**4. Escopo.**
- **É dele:**
  - a Loucura (acúmulo nos inimigos);
  - o Delírio (inimigo comum que se volta contra os outros) e a Desorientação (a
    janela no chefe);
  - o Ídolo (um objeto que atrai o olhar);
  - geometrias impossíveis no chão;
  - o Êxtase, que fortalece e expõe o próprio Cultista.
- **Fica com a base:** Luz Punitiva, Prece, Escudo Votivo, Selo Sombrio e Sussurro.
- **Não é dele:**
  - um demônio com vontade e vínculo (Demonólogo);
  - fantasmas e ecos dos mortos (Espiritualista);
  - medo e provocação comuns (Espadachim, Defendente). A Loucura muda *quem* o
    inimigo ataca; o medo só o faz fugir.

**5. Mecânica central: Loucura, Delírio e Êxtase.**
- **Loucura:** um acúmulo em cada inimigo. Cada skill do Cultista acrescenta Loucura.
  No limite:
  - **inimigo comum → Delírio:** por alguns segundos, ataca o inimigo mais próximo
    em vez do jogador. Há um limite de inimigos em Delírio ao mesmo tempo;
  - **chefe → Desorientação:** por alguns segundos, erra mais e recebe mais dano. Depois
    fica imune à Loucura por um tempo, para não ficar preso no estado (regra do
    roster de 13/09).
  - **Loucura menor do chefe (decisão do usuário em 14/11):** durante a
    Desorientação, alguns ataques do chefe acertam, ao acaso, os próprios lacaios.
    Só os que estiverem ao lado dele, e só enquanto durar o efeito. O chefe não troca
    de alvo nem para de lutar: ele erra a mão.
- **Êxtase:**
  - cada inimigo que entra em Delírio ou Desorientação dá uma carga de Êxtase ao
    Cultista: mais MATK e skills mais baratas;
  - **o olho olha de volta:** com Êxtase alto, o Cultista também recebe mais dano.
    O ônus é parte da identidade (decisão do usuário em 14/11). O Êxtase é a
    apoteose e a cobrança da visão do éldrico, por bem ou por mal: "quando você
    olha para o abismo e o abismo olha de volta, você só não pode piscar";
  - o Êxtase cai com o tempo se ninguém enlouquecer.

**Loop:** Ídolo no meio do grupo → Olhar do Abismo para acumular Loucura → Delírio
Compartilhado espalha → os comuns se atacam entre si → Êxtase sobe → Geometria
Impossível segura quem sobrou → Revelação no pico, sabendo que o Êxtase alto também o
expõe.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Olhar do Abismo** | ativa, entrada | Canalização em cone: dano mágico contínuo e Loucura nos alvos. |
| 23 | **Êxtase** | passiva | Liga as cargas de Êxtase: mais MATK e menos custo, e mais dano recebido com Êxtase alto. |
| 25 | **Ídolo Impossível** | ativa | Coloca um ídolo com HP próprio. Os inimigos próximos o atacam e ganham Loucura enquanto olham para ele. |
| 28 | **Delírio Compartilhado** | ativa | Marca um alvo: a Loucura que ele recebe também vai para os inimigos próximos; se ele entrar em Delírio, contagia. |
| 31 | **Pupila Aberta** | passiva | Inimigos em Delírio ou Desorientação recebem mais dano do Cultista. |
| 34 | **Geometria Impossível** | ativa | Uma figura no chão que não fecha: os inimigos comuns dentro andam na direção errada por um instante; o chefe fica lento. |
| 37 | **Revelação** | ativa | Um grande olho se abre sobre o campo por alguns segundos: todos os inimigos à vista ganham Loucura rapidamente, os Delirantes causam mais dano uns aos outros, e o chefe entra em Desorientação forte, acertando com mais frequência os lacaios ao lado dele. |

**7. Composição.**
- **Do kit:**
  - Sussurro e Selo Sombrio (base) acrescentam Loucura e ficam no loadout;
  - Escudo Votivo e Prece compensam o dano extra do Êxtase alto;
  - Luz Punitiva sai cedo.
- **Build "Profeta":**
  - ativas: Olhar + Ídolo + Delírio Compartilhado + Sussurro + Revelação;
  - passivas: Êxtase + Pupila Aberta;
  - jogo: grupos grandes se destroem entre si; o Cultista quase não precisa matar.
- **Build "Vidente":**
  - ativas: Olhar + Geometria + Selo Sombrio + Escudo Votivo + Revelação;
  - passivas: Pupila Aberta + Devoção;
  - jogo: Desorientações frequentes no chefe e dano concentrado nas janelas.
- **Visual:**
  - silhueta assimétrica, de roupa em tiras, um pouco curvada para a frente;
  - cor: preto-azulado, magenta, turquesa doentio;
  - material: tecido em tiras, pele marcada, metal oxidado; forma: olhos, espirais
    que não fecham, assimetria;
  - arma típica: um relicário com um olho dentro (foco);
  - VFX: pupilas que se abrem no chão, distorção da imagem, figuras impossíveis,
    tentáculos de sombra por um instante; a Loucura como um olho pequeno sobre o
    inimigo, que se abre conforme acumula;
  - em combate: com Êxtase alto, olhos se abrem no traje do Cultista.

**8. Como origem e como afinidade.**
- **Como origem**, empresta a postura do êxtase (se aproximar sorrindo, sussurrar) e o
  material: tiras, pele marcada, metal oxidado.
- **Como afinidade**, empresta o fenômeno: **ver demais faz perder o controle**. O
  inimigo exposto acumula Loucura, se volta contra os outros, e o chefe abre uma
  janela. A origem decide o que mostra ou como expõe. Um Caçador arma uma armadilha que
  dispara quando o inimigo olha para ela; um Dervixe gira e espalha o delírio.
- **Para evitar:** "skill X com um olho desenhado". A afinidade traz a Loucura e a
  troca de alvo dos inimigos, não um símbolo.

**9. As cinco perguntas.**
- **Distância:** média; perto o bastante para o olhar alcançar.
- **Recurso:** Loucura nos inimigos e Êxtase em si mesmo.
- **Abrir e fechar:** abre com o Ídolo e o Olhar; fecha com a Revelação.
- **Contra o chefe:** sem grupo para se destruir, vive das janelas de Desorientação.
  Se o chefe tiver lacaios, a janela também os fere. A decisão é provocar a janela
  cedo ou acumular Êxtase para que ela venha mais forte.
- **Fraqueza:** contra um chefe sozinho, o Delírio não serve. Com Êxtase alto, o
  Cultista fica exposto. Frágil de perto.

**10. Arte.**
- **Já existe:** o Acólito (quatro vistas).
- **Falta:**
  - o traje do Cultista (quatro vistas);
  - o relicário com olho (equipamento);
  - o Ídolo Impossível (objeto com HP, uma vista basta se não girar);
  - os efeitos da Loucura sobre o inimigo, do cone do Olhar, da Geometria
    Impossível e do grande olho da Revelação.

---

### Diferença entre as duas, num quadro

| | Sacerdote | Cultista |
|---|---|---|
| Tensão da base | servir | contemplar |
| Onde age | num lugar (o círculo) | na mente dos inimigos |
| Recurso | Graça (cura excedente) | Loucura nos outros, Êxtase em si |
| Risco | sair do círculo | o Êxtase também o expõe |
| Contra grupos | segura e queima quem entra | os faz se destruírem |
| Contra o chefe | Juízos com Graça cheia | janelas de Desorientação |
| Momento de glória | Hora Santa | Revelação |

### Decisões do usuário sobre o Acólito (14/11)

Família Acólito fechada para fins de arte e de descrição de híbridas.

1. **Sacerdote solo:** a cura excedente vira Graça, e a Graça vira dano no Juízo.
2. **Loucura no chefe:** a janela de Desorientação com imunidade depois continua. Ela
   ganha uma **forma menor de Loucura**: o chefe fere, ao acaso, os lacaios que estiverem
   ao lado dele enquanto durar o efeito.
3. **Êxtase com ônus:** o Cultista recebe mais dano com Êxtase alto. É a apoteose e a
   cobrança da visão do éldrico.
4. **Armas:** livro de orações (Acólito), cetro com aro (Sacerdote) e relicário com
   olho (Cultista).
5. **Mortos-vivos e fantasmas:** a ideia fica. Será expandida junto com as híbridas
   que dependem do Sacerdote. A cura que fere essas criaturas fica registrada para
   essa expansão.

---

## Família Ladino

**Contexto técnico que pesa nesta família:**
- **A ocultação já existe** no jogo: é a do Caçador. Inimigos fora do alcance perdem a
  aquisição do alvo, e atacar revela por um instante. O Ladino reaproveita essa regra.
- **O golpe pelas costas não existia.** Por decisão do usuário (14/11), passa a existir
  uma **regra de costas**: o ângulo entre a frente do inimigo e a posição do atacante
  define frente, flancos e costas. Serve ao Assassino, ao Metamorfo (felino), ao
  Dervixe e às híbridas que vierem deles.
- **O Dervixe de 13/09** ([DERVISH_READINESS.md](DERVISH_READINESS.md)) foi substituído
  em 14/11 por um arquétipo novo; ver a ficha dele.
- **Regra do handoff de 13/09 para o Assassino:** a ocultação, a entrada, o golpe pelas
  costas e a decisão de executar ou sair precisam ser evidentes. Numa híbrida, a
  segunda classe muda *como* o golpe pelas costas é criado, não o substitui.

### A base, de onde as duas partem

Tensão: **sumir ↔ não parar**. Proposta de kit (nomes provisórios, a partir do roster
de 13/09):

| Skill | Tipo | Função |
|---|---|---|
| Punhalada | ativa | Golpe rápido em um alvo. Dano maior pelas costas. |
| Veneno | ativa | Os próximos golpes aplicam um veneno simples (DoT). |
| Passo Sombrio | ativa | Um passo curto e instantâneo para o lado ou para trás do alvo. |
| Ocultação | ativa | Fica oculto por alguns segundos ou até atacar. Usa a regra de ocultação do Caçador. |
| Corte Giratório | ativa | Um giro curto que corta tudo em volta. |
| Salto Acrobático | ativa | Salta por cima de um inimigo e cai atrás dele. Prepara o golpe pelas costas do Assassino e os saltos do Dervixe. |
| Oportunismo | passiva | Golpes pelas costas, ou em alvos lentos ou presos, têm mais chance de crítico. |

A base dá uma amostra dos dois lados: Ocultação e Passo para sumir; Giro e Salto
Acrobático para não parar. O Gancho do roster de 13/09 saiu junto com o Dervixe
antigo.

Arma típica da base: um par de adagas (tipo de equipamento novo, aprovado pelo
usuário em 14/11).

---

### Assassino — sombra

**1. Foco.** Escolhe uma vítima, some, entra pelas costas e decide entre terminar o
serviço ou sair para voltar depois.

**2. Temática.** Substantivo: **sombra** (recorte, ausência, silhueta). Tema: paciência,
precisão, ofício. Tom: frio e profissional; nada pessoal.

**3. Descrição.** O Assassino não luta: trabalha. Escolhe quem vai morrer antes de
entrar na sala, conta os passos da vítima e espera o momento em que ela vira de
costas. Quando o golpe vem, é um só. Se não bastar, ele não insiste: some, e a vítima
passa os próximos segundos olhando para todos os lados.

**4. Escopo.**
- **É dele:**
  - a vítima marcada e a Sentença acumulada nela;
  - a entrada pelas costas (Emboscada);
  - o golpe final que, quando mata, devolve a ocultação;
  - a saída em combate (fumaça);
  - a combinação de toxinas.
- **Fica com a base:** Punhalada, Veneno, Passo Sombrio, Ocultação, Corte Giratório e
  Salto Acrobático.
- **Não é dele:**
  - a execução por exposição ao risco e por feridas acumuladas (Berserker). O
    Assassino executa pela preparação e pelo ângulo, não pelo risco;
  - movimento contínuo e cleave (Dervixe);
  - a cobertura que esconde do Caçador (Moita). O Assassino se esconde em si mesmo, não
    num lugar.

**5. Mecânica central: vítima, Sentença e saída.**
- **Vítima:** um alvo marcado por vez. Fica visível através de obstáculos para o
  Assassino.
- **Sentença:** um acúmulo na vítima, até cinco.
  - Golpe pelas costas: +2.
  - Primeiro golpe saindo da ocultação: +2.
  - Coquetel de toxinas completo: +2.
  - Outros golpes diretos: +1.
- **Golpe final (Sentença):** gasta todo o acúmulo; o dano escala com ele.
  - **Com o acúmulo cheio, é morte certa** abaixo de um limiar de vida que diminui com
    a categoria do inimigo (decisão do usuário em 14/11). Isso mostra que matar um
    raro-elite é mais difícil que matar um comum. As categorias já existem no jogo:
    normal, raro, elite, raro-elite e chefe. Os limiares são de implementação.
  - No chefe, não há morte certa: é só dano muito alto.
  - A diferença para a Execução do Berserker: a dele não é morte certa; a do Assassino
    é, dentro do limiar.
  - **Se matar, o Assassino volta à ocultação na hora.** Se não matar, fica exposto: é
    a decisão central da classe.
- **Saída:** a fumaça dá uma ocultação curta mesmo no meio do combate, e os inimigos
  perdem o alvo. É o "sair para voltar depois".

**Loop:** Marca → Ocultação → Emboscada pelas costas (+2) → toxinas → decidir: Sentença
agora, se mata, ou fumaça e nova entrada para acumular mais → se matou, já está oculto
para a próxima vítima.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Marca da Vítima** | ativa, entrada | Marca um alvo, que passa a acumular Sentença e fica visível através de obstáculos. |
| 23 | **Sombra Paciente** | passiva | Quanto mais tempo oculto, mais forte o primeiro golpe ao sair: crítico garantido a partir de alguns segundos. |
| 25 | **Sentença** | ativa | Gasta a Sentença no golpe final. Se matar, devolve a ocultação. |
| 28 | **Emboscada** | ativa | Só usável oculto: aparece nas costas da vítima e golpeia. Conta como golpe pelas costas. |
| 31 | **Coquetel** | passiva | O Veneno da base passa a alternar três toxinas (paralisante, hemorrágica, nervosa). As três no mesmo alvo causam uma reação: atordoamento curto e +2 de Sentença. |
| 34 | **Véu de Fumaça** | ativa | Bomba de fumaça: ocultação curta mesmo em combate, e os inimigos próximos perdem o alvo. |
| 37 | **Noite sem Fim** | ativa | Por alguns segundos, cada abate devolve a ocultação e zera a recarga da Emboscada. É uma corrente de vítimas. |

**7. Composição.**
- **Do kit:**
  - Ocultação e Veneno (base) são essenciais;
  - Passo Sombrio e Salto Acrobático ajudam a ficar nas costas sem Emboscada;
  - Corte Giratório sai cedo: é do lado do Dervixe.
- **Build "Contrato":**
  - ativas: Marca + Sentença + Emboscada + Ocultação + Véu;
  - passivas: Sombra Paciente + Oportunismo;
  - jogo: uma vítima de cada vez, com saída sempre pronta; o melhor contra o chefe.
- **Build "Noite Longa":**
  - ativas: Marca + Sentença + Emboscada + Veneno + Noite sem Fim;
  - passivas: Coquetel + Sombra Paciente;
  - jogo: corrente de abates contra grupos de inimigos frágeis.
- **Visual:**
  - silhueta fina, de capuz, encolhida;
  - cor: preto, cinza-chumbo e um único vermelho escuro;
  - material: couro fosco e tecido que absorve a luz; forma: recortes, ângulos agudos;
  - arma típica: adagas curvas de lâmina escura (equipamento);
  - VFX: some num recorte de sombra; marca da vítima como um traço vertical sobre ela,
    que se enche com a Sentença; o único brilho é o da lâmina no golpe pelas costas;
  - em combate: oculto, só a silhueta escura e o vermelho aparecem.

**8. Como origem e como afinidade.**
- **Como origem**, empresta a postura de quem some e escolhe, e o material: couro
  fosco, recortes.
- **Como afinidade**, empresta o fenômeno: **sumir e reaparecer no ângulo certo**, com
  uma vítima marcada e a decisão de executar ou sair. A origem decide como o ângulo é
  criado: um Caçador cria pela armadilha; um Defendente, pelo aparo que vira a vítima.
- **Para evitar:** "skill X com dano crítico". A afinidade traz a ocultação, a marca e a
  decisão de saída, não só um número maior.

**9. As cinco perguntas.**
- **Distância:** corpo a corpo, entrando e saindo.
- **Recurso:** Sentença na vítima e a ocultação.
- **Abrir e fechar:** abre com a Marca e a Emboscada; fecha com a Sentença, ou com a
  fumaça para sair.
- **Contra o chefe:** sem abates, não há reset da ocultação. A classe vive de entrar
  pelas costas, acumular, sair com a fumaça e voltar. A decisão é gastar a Sentença
  cedo ou acumular até cinco.
- **Fraqueza:** frágil se for pego exposto; fraco contra grupos que o cercam; precisa
  de tempo de preparação.

**10. Arte.**
- **Já existe:** o Ladino (quatro vistas).
- **Falta:**
  - o traje do Assassino (quatro vistas);
  - as adagas curvas (equipamento) e as adagas da base. Os dois tipos de arma foram
    aprovados pelo usuário em 14/11;
  - o recorte de sombra (sumir e aparecer), a marca da vítima, a fumaça, a reação do
    Coquetel e o golpe final.

---

### Dervixe — vendaval

Reescrito em 14/11 a pedido do usuário. A versão anterior (Prontidão, gancho que
orbita e Fortuna sorteada, de [DERVISH_READINESS.md](DERVISH_READINESS.md)) ficou perto
demais de arquétipos de outros jogos e foi substituída. Direção do usuário:
- **movimento constante e troca de inimigo** conforme causa dano;
- **cleave e dano em área** em volta do personagem;
- **vento e malabarismo;**
- **transe de combate feito de tempo e devaneio**, não de raiva e concentração;
- uma mistura de **duelista, dançarino, trapaceiro e saltimbanco**: performance,
  lâminas afiadas, a brisa que vira vendaval.

**1. Foco.** Dança pelo campo trocando de vítima a cada passo. Cada inimigo novo que
corta aumenta o vento, até a brisa virar vendaval e cortar tudo em volta.

**2. Temática.** Substantivo: **vendaval** (substitui "órbita"; nome "Dervixe" mantido,
decisão do usuário em 14/11). Tema: performance,
vento, devaneio. Tom: leve, exibido e um pouco ausente, como quem dança de olhos
semicerrados. A diferença para o Berserker: o transe dele é raiva concentrada; o do
Dervixe é tempo esticado e sonho acordado.

**3. Descrição.** O Dervixe vem de feira, de praça e de estrada: aprendeu a lutar com
os mesmos passos que usava para pedir moedas. Nunca fica parado diante de um inimigo
só. Corta, gira, salta por cima, corta o próximo, e a cada volta o vento em volta dele
cresce. Depois de algum tempo dançando, ele parece não estar mais ali: os olhos vagam,
o sorriso fica distante, e as lâminas continuam encontrando o caminho sozinhas. Quando
o número acaba, ele agradece a uma plateia que só ele vê.

**4. Escopo.**
- **É dele:**
  - o Vento, que cresce a cada inimigo diferente atingido;
  - o Devaneio (transe longo);
  - as piruetas que atravessam o inimigo;
  - as facas de malabarismo que voltam até ele;
  - a finta: uma imagem de vento que provoca e vira um redemoinho que puxa;
  - o grande final.
- **Fica com a base:** Punhalada, Veneno, Passo Sombrio, Ocultação, Corte Giratório e
  Salto Acrobático.
- **Não é dele:**
  - ocultação e execução (Assassino);
  - contagem de golpes com final de sequência (Campeão). O Dervixe não conta golpes,
    conta *vítimas diferentes*;
  - fúria por risco (Berserker);
  - campo mental que suspende objetos (Elevado). O vento do Dervixe é físico e só existe
    enquanto ele se move.

**5. Mecânica central: Passos, Vento e Devaneio.**
- **Passo:**
  - todo acerto em um inimigo **diferente do anterior** conta um Passo;
  - acertar o mesmo inimigo **de outro lado** também conta, pela regra de costas
    criada nesta rodada (frente, flancos e costas). É o que faz a classe funcionar
    contra o chefe sozinho: dançar em volta dele;
  - acertar o mesmo inimigo, do mesmo lado, não conta.
  - Confirmado pelo usuário em 14/11. Golpear o mesmo alvo por lados diferentes
    combina com a ideia de duelista.
- **Vento:** três estágios, **Brisa → Rajada → Vendaval**, subindo a cada tantos Passos.
  - A cada estágio, os golpes do Dervixe giram com raio maior (cleave em volta), e ele
    anda mais rápido.
  - No Vendaval, o próprio deslocamento solta cortes de vento em quem estiver perto.
  - **O vento cai** um estágio se o Dervixe ficar parado por cerca de um segundo, ou se
    for derrubado ou atordoado. A punição é intencional (decisão do usuário em 14/11):
    a classe precisa de um incentivo forte a movimento e combate constantes, para a
    luta não virar repetição entediante.
- **Devaneio (o transe):**
  - ficar no Vendaval por alguns segundos sem quebrar a dança leva ao Devaneio;
  - no Devaneio, a cada poucos Passos, um corte de vento sai sozinho em direção ao
    inimigo mais próximo que ainda não foi atingido;
  - uma única parada não derruba o vento: o Dervixe "acorda" um instante e volta;
  - é tempo, não raiva: o Devaneio só vem para quem sustenta a dança.

**Loop:** Pirueta através do primeiro inimigo → corta o próximo → facas lançadas
voltam pelo caminho e acertam quem estiver nele → a Brisa vira Rajada → Finta quando o
grupo fecha → Vendaval e Devaneio → Ciranda para gastar o vento numa roda grande, ou
segurar o vento até o Grande Número.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Pirueta** | ativa, entrada | Avanço girando que atravessa o inimigo e para do outro lado, cortando em volta no fim. Duas cargas. Atravessar já conta como golpe de outro lado. |
| 23 | **Compasso** | passiva | Liga os Passos e os três estágios do Vento. |
| 25 | **Facas ao Vento** | ativa | Malabarismo: lança três facas que saem em leque e depois voltam até a posição **atual** do Dervixe. Quem estiver no caminho, na ida ou na volta, é cortado. Mover-se muda a rota da volta. **Pegar uma faca no ar dá um bônus**; não pegar não tira nada (ver abaixo). |
| 28 | **Finta do Saltimbanco** | ativa | Salta para o lado e deixa onde estava uma **imagem de vento** que provoca os inimigos em volta. A imagem aguenta um ou dois golpes. Quando quebra ou acaba, vira um **pequeno redemoinho** que puxa os inimigos levemente para dentro, sem dano. |
| 31 | **Devaneio** | passiva | Liga o transe: cortes de vento automáticos e uma parada perdoada. |
| 34 | **Ciranda** | ativa | Gasta um estágio de Vento numa roda grande em volta do Dervixe, que puxa um pouco os inimigos para dentro e corta todos. Maior quanto mais alto o estágio gasto. |
| 37 | **Grande Número** | ativa | Por alguns segundos, o Dervixe vira um redemoinho em movimento: cada acerto conta como Passo novo, e o Vento não cai. No fim, uma reverência solta uma explosão de vento que cresce com o número de inimigos diferentes atingidos durante o número. |

**Pegar no ar (decisão do usuário em 14/11).**
- **Como funciona:** cada faca volta até onde o Dervixe está. Se ele estiver na ponta
  da faca no instante em que ela chega, a faca é pegada; se tiver se afastado, ela
  passa e some.
- **Bônus por faca pegada:** um Passo extra e uma redução na recarga das Facas. Pegar
  as três seguidas dá uma Pirueta extra.
- **Sem punição** por não pegar: a skill continua em recarga normal. O incentivo é
  só positivo.
- **Por quê:** junta o malabarismo (pegar) com o movimento constante (estar no lugar
  certo quando a faca chega).

**Finta: imagem e redemoinho (decisão do usuário em 14/11).** As duas ideias do
usuário viram uma só sequência de truque:
1. A imagem de vento provoca e absorve um ou dois golpes.
2. Ao se desfazer, deixa o redemoinho que junta os inimigos sem feri-los. Isso prepara
   a Ciranda ou a Pirueta.
3. A imagem é feita de vento, poeira e fitas de seda. Não é a imagem pálida e
   translúcida do Espiritualista, que é dele.

Arma: um par de cimitarras curvas (decisão do usuário em 14/11). As facas de
malabarismo são projéteis do kit, não equipamento.

**7. Composição.**
- **Do kit:**
  - Corte Giratório e Salto Acrobático (base) somam Passos;
  - Passo Sombrio é uma esquiva extra;
  - Ocultação e Veneno saem cedo: são do lado do Assassino.
- **Build "Saltimbanco":**
  - ativas: Pirueta + Facas + Finta + Salto Acrobático + Grande Número;
  - passivas: Compasso + Devaneio;
  - jogo: dança em volta do chefe pelos lados, sem nunca parar; o melhor contra o
    chefe.
- **Build "Vendaval":**
  - ativas: Pirueta + Facas + Ciranda + Corte Giratório + Grande Número;
  - passivas: Compasso + Oportunismo;
  - jogo: atravessa grupos, sobe o vento rápido e gasta em Cirandas.
- **Visual:**
  - silhueta aberta, de braços e fitas estendidos, sempre em meio a um passo;
  - cor: areia, turquesa, branco-vento, dourado e vermelho vivo nos tecidos;
  - material: seda leve, fitas, guizos e pequenas facas no cinto; forma: espirais,
    fitas em curva, saias e faixas que abrem no giro;
  - arma típica: cimitarras curvas;
  - VFX: fitas de vento, folhas e poeira em espiral, rastro de vento no chão; o estágio
    do Vento é lido no tamanho do redemoinho em volta (fitas finas na Brisa, redemoinho
    completo no Vendaval). No Devaneio, o personagem ganha um rastro de silhuetas
    esmaecidas, como uma lembrança do passo anterior;
  - em combate: quanto mais alto o Vento, mais as fitas e as faixas abrem.

**8. Como origem e como afinidade.**
- **Como origem**, empresta a postura de quem nunca para diante de um único inimigo e o
  material: seda, fitas, guizos.
- **Como afinidade**, empresta o fenômeno: **o vento que cresce a cada vítima diferente**
  e o transe que vem da dança sustentada. A origem decide o que o vento leva. Um
  Caçador espalha armadilhas pelo caminho da dança; um Espiritualista deixa ecos no
  rastro.
- **Para evitar:** "skill X que gira". A afinidade traz a troca de alvo como recurso e o
  vento que cresce, não só uma animação de giro.

**9. As cinco perguntas.**
- **Distância:** corpo a corpo, sempre em movimento.
- **Recurso:** Passos e o estágio do Vento; o tempo no Vendaval até o Devaneio.
- **Abrir e fechar:** abre com a Pirueta; fecha com a Ciranda ou o Grande Número.
- **Contra o chefe:** os Passos vêm de golpear o chefe de lados diferentes; a Pirueta
  através dele troca o lado na hora. A decisão é gastar o vento na Ciranda (quando
  há lacaios) ou guardar o Vendaval para o Grande Número.
- **Fraqueza:** parar custa caro. Atordoamentos e áreas que forçam ficar no lugar
  derrubam o vento. Armadura leve.

**10. Arte.**
- **Já existe:** o Ladino (quatro vistas).
- **Falta:**
  - o traje do Dervixe (quatro vistas);
  - as cimitarras curvas (equipamento);
  - as facas de malabarismo (projétil) e o brilho de faca pegada;
  - a imagem de vento da Finta e o pequeno redemoinho;
  - os três estágios de vento em volta do corpo, a Ciranda e a reverência do Grande
    Número;
  - o rastro de silhuetas do Devaneio, que pode ser desenhado em código.

---

### Diferença entre as duas, num quadro

| | Assassino | Dervixe |
|---|---|---|
| Tensão da base | sumir | não parar |
| Alvo | uma vítima, escolhida antes | uma vítima diferente a cada passo |
| Recurso | Sentença na vítima | Vento em si, subindo por vítimas diferentes |
| Ritmo | entra, golpeia, some | dança sem parar até o transe |
| Contra grupos | corrente de abates (Noite sem Fim) | Ciranda e Vendaval |
| Contra o chefe | entrar pelas costas, acumular, sair | golpear por lados diferentes |
| Momento de glória | Sentença que mata e devolve a ocultação | Grande Número |

### Decisões do usuário sobre o Ladino (14/11)

1. **Regra de costas criada:** dano pelas costas, medido pelo ângulo entre a frente do
   inimigo e o atacante. Serve ao Assassino, ao Metamorfo e às híbridas que vierem
   deles. Os lados (frente, flancos, costas) também alimentam os Passos do Dervixe.
2. **Sentença:** está boa. A Execução do Berserker não é morte certa; a Sentença é,
   com um limiar de vida menor para cada categoria de inimigo (detalhe na ficha do
   Assassino).
3. **Dervixe reescrito** como duelista, dançarino, trapaceiro e saltimbanco, com vento,
   malabarismo e transe de devaneio. A Fortuna e a Prontidão de 13/09 saíram. Perguntas
   do kit novo abaixo.
4. **Armas novas:** adagas (Ladino e Assassino) e cimitarras (Dervixe).

### Decisões do usuário sobre o novo Dervixe (14/11)

Família Ladino fechada para fins de arte e de descrição de híbridas.

1. **Nome mantido**, substantivo agora **vendaval**.
2. **Passos confirmados:** inimigo diferente, ou o mesmo inimigo por outro lado.
3. **Punição por parar mantida:** a classe precisa de incentivo forte a movimento e
   combate constantes.
4. **Pegar as facas no ar dá bônus**, sem punição por não pegar.
5. **Finta:** a imagem de vento provoca e aguenta um ou dois golpes; ao se desfazer,
   vira um pequeno redemoinho que puxa os inimigos sem causar dano.

---

## Família Monge

### A base, de onde as duas partem

Tensão: **conter ↔ soltar**. Proposta de kit (nomes provisórios, a partir do roster de
13/09):

| Skill | Tipo | Função |
|---|---|---|
| Palma de Impacto | ativa | Golpe de palma que empurra o alvo para trás. |
| Passo Evasivo | ativa | Esquiva curta; o fim do passo evita o primeiro golpe recebido. |
| Aparar Projétil | ativa | Postura curta que desvia o próximo projétil recebido. |
| Sequência de Três Golpes | ativa | Três golpes rápidos; o terceiro é mais forte. |
| Pulso Mental | ativa | Uma onda curta em volta que empurra e atordoa os inimigos comuns por um instante. |
| Poço Gravitacional | ativa | Um ponto no chão que puxa os inimigos próximos por alguns segundos. |
| Respiração Contida | passiva | Sem receber dano por alguns segundos, recupera SP mais rápido, e o primeiro golpe depois da pausa é mais forte. |

A passiva ensina a tensão de um jeito próprio: conter (esperar, respirar) para soltar
(o primeiro golpe). O lado Elevado aparece em Pulso, Poço e Aparar; o lado Campeão, na
Sequência e na Palma.

Arma típica da base: faixas de mão reforçadas (equipamento novo de punho; o jogo ainda
não tem armas de punho).

---

### Elevado — campo

**1. Foco.** Controla o espaço em volta com a mente: suspende, empurra, desvia e
arremessa. Acumula calma para soltar tudo de uma vez numa descarga.

**2. Temática.** Substantivo: **campo** (o espaço ao redor como extensão do corpo:
esferas, ondas, objetos suspensos). Tema: mente, gravidade, serenidade. Tom: sereno e
distante; parece sempre um pouco acima do chão.

**3. Descrição.** O Elevado treinou até o corpo parecer um detalhe. Ele não estende o
braço para alcançar as coisas: elas vêm até ele. Pedras sobem quando ele respira, e
os inimigos ficam suspensos um instante antes de entenderem o que aconteceu. Quanto
mais tempo passa sem ser tocado, mais calmo fica, e mais perigosa fica essa calma.

**4. Escopo.**
- **É dele:**
  - o campo em volta (a área em que age);
  - telecinese (agarrar e arremessar);
  - suspender inimigos e derrubá-los;
  - o campo de força;
  - a Calma acumulada e a grande descarga.
- **Fica com a base:** Palma, Passo Evasivo, Aparar Projétil, Sequência, Pulso Mental
  e Poço Gravitacional.
- **Não é dele:**
  - fogo, gelo e raio (Elementalista); o Elevado move matéria, não a transforma;
  - círculo de luz com regras (Sacerdote); o campo dele é força, não fé;
  - o vento em movimento (Dervixe); o campo do Elevado fica parado com ele;
  - terreno de pedra moldado (Naturalista); ele ergue o que já existe e solta.

**5. Mecânica central: campo, suspensão e Calma.**
- **Campo:** uma área em volta do Elevado onde as skills dele agem com força total.
  Fora do campo, agem mais fracas ou não agem.
- **Suspensão:** inimigos comuns no campo podem ser erguidos por um instante. Ficam
  sem agir, e cair dá dano. O chefe nunca é erguido: é pressionado (lentidão e dano).
- **Calma:**
  - acumula enquanto o Elevado não recebe dano, até um limite;
  - cada carga aumenta o MATK e o raio do campo;
  - receber dano perde parte da Calma;
  - a grande descarga gasta toda a Calma.
  É a tensão da base levada ao limite: quanto mais o Elevado consegue conter, mais forte
  solta.

**Loop:** Campo de Força para não ser tocado → a Calma sobe → Levitação ergue o grupo →
Telecinese arremessa um inimigo contra os outros → Queda derruba tudo o que está
suspenso → contra o chefe, guardar a Calma para a Descarga Interior.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Telecinese** | ativa, entrada | Agarra um inimigo comum ou um projétil inimigo dentro do campo e o arremessa na direção escolhida. Quem for atingido pelo arremesso leva dano. No chefe, só pressiona (dano e lentidão). |
| 23 | **Serenidade** | passiva | Liga a Calma: acumula sem receber dano, aumenta MATK e raio do campo. |
| 25 | **Campo de Força** | ativa | Uma esfera em volta do Elevado bloqueia projéteis e empurra quem entra, por alguns segundos ou até absorver uma quantidade de dano. |
| 28 | **Levitação** | ativa | Ergue por um instante todos os inimigos comuns no campo. O Elevado também flutua e ignora efeitos de chão enquanto durar. |
| 31 | **Mente Vasta** | passiva | O campo fica maior, e projéteis inimigos que entram nele ficam mais lentos. |
| 34 | **Queda** | ativa | Derruba com força tudo o que está suspenso: dano em área que cresce com o tempo de suspensão. No chefe, uma pressão forte para baixo. |
| 37 | **Descarga Interior** | ativa | **Só pode ser usada com a Calma no máximo.** Gasta toda a Calma e todo o SP: uma conjuração curta, com uma janela visível em que o Elevado fica exposto, e depois um impacto concentrado de dano enorme num alvo. O dano cresce com o SP gasto. |

O roster de 13/09 chamava a grande descarga de "Asura". O nome muda para **Descarga
Interior**, porque "Asura" é o nome de uma skill conhecida de outro jogo (decisão do
usuário em 14/11). A ideia do usuário fica: condensar força mental com custo e janela
de resposta. Mecanicamente, ela continua exigindo **uma preparação forte** antes do dano
enorme: Calma no máximo (tempo sem ser tocado), SP alto para o dano crescer, e a
janela de exposição. Sem preparação, não pode ser usada.

**7. Composição.**
- **Do kit:**
  - Poço Gravitacional (base) junta o grupo para a Levitação;
  - Aparar Projétil compete com a Telecinese de projéteis;
  - Pulso Mental é a defesa de perto;
  - Sequência e Palma saem cedo: são do lado do Campeão.
- **Build "Gravidade":**
  - ativas: Telecinese + Levitação + Queda + Poço Gravitacional + Campo de Força;
  - passivas: Serenidade + Mente Vasta;
  - jogo: controle total de grupos; o campo vira uma armadilha.
- **Build "Descarga":**
  - ativas: Telecinese + Campo de Força + Passo Evasivo + Aparar Projétil + Descarga
    Interior;
  - passivas: Serenidade + Respiração Contida;
  - jogo: nunca ser tocado, acumular Calma e soltar tudo no chefe.
- **Visual:**
  - silhueta leve e ereta, com os pés levemente fora do chão em parado;
  - cor: branco, azul-violeta, dourado leve;
  - material: tecido leve, contas e pedras suspensas; forma: esferas, círculos
    concêntricos;
  - arma típica: um rosário de contas que flutua em volta da mão (foco);
  - VFX: distorção do ar no limite do campo, ondas de pressão, pedras e destroços
    flutuando, esfera do Campo de Força. A Calma aparece como contas que se acendem
    e giram em volta do corpo, uma por carga;
  - em combate: com Calma alta, mais contas e pedras orbitam o corpo.

**8. Como origem e como afinidade.**
- **Como origem**, empresta a postura serena e flutuante e o material: tecido leve,
  contas suspensas.
- **Como afinidade**, empresta o fenômeno: **o espaço em volta como extensão do corpo**:
  suspender, empurrar, desviar e arremessar, além de conter calma para soltar de uma
  vez. A origem decide o que o campo move. Uma Sentinela curva a trajetória das
  próprias flechas; um Defendente devolve o impulso de quem bate nele.
- **Para evitar:** "skill X com distorção no ar". A afinidade traz controle real do
  espaço (suspender, arremessar, desviar), não um efeito de brilho.

**9. As cinco perguntas.**
- **Distância:** média; os inimigos precisam estar dentro do campo.
- **Recurso:** Calma (tempo sem ser tocado) e SP.
- **Abrir e fechar:** abre com o Campo de Força ou a Levitação; fecha com a Queda ou a
  Descarga Interior.
- **Contra o chefe:** o chefe não é erguido, então o jogo é de não ser tocado,
  acumular Calma e acertar a janela da Descarga. A decisão é quando aceitar ficar
  exposto.
- **Fraqueza:** perde a Calma ao ser atingido; a Descarga deixa o Elevado sem SP;
  inimigos que ficam fora do campo escapam do controle.

**10. Arte.**
- **Já existe:** o Monge (quatro vistas).
- **Falta:**
  - o traje do Elevado (quatro vistas);
  - o rosário flutuante (equipamento);
  - o limite do campo, a esfera do Campo de Força, as contas da Calma, a suspensão e
    a Queda;
  - a conjuração e o impacto da Descarga Interior.

---

### Campeão — ritmo

**1. Foco.** Luta em sequência: cada golpe acertado no tempo certo sobe a contagem, e
a contagem alimenta os golpes que terminam a sequência.

**2. Temática.** Substantivo: **ritmo** (sequência, impacto que se repete, contagem).
Tema: corpo, treino, competição. Tom: entusiasmado e competitivo; trata a luta como um
treino que ele quer vencer.

**3. Descrição.** O Campeão aprendeu a lutar contando. Um, dois, três: cada golpe tem
o seu tempo, e quem acerta o tempo acerta o golpe seguinte com mais força. Ele luta
sorrindo e conta em voz alta, até que o adversário perde o ritmo e ele não. O último
golpe da contagem é sempre o que todo mundo lembra.

**4. Escopo.**
- **É dele:**
  - a Contagem (até 9), que sobe com golpes no tempo certo;
  - o tempo certo entre golpes (o ritmo);
  - os golpes que gastam a contagem;
  - agarrar o golpe do inimigo e arremessá-lo.
- **Fica com a base:** Palma, Passo Evasivo, Aparar Projétil, Sequência, Pulso Mental
  e Poço Gravitacional.
- **Não é dele:**
  - vento que cresce trocando de vítima (Dervixe). O Campeão conta golpes no tempo,
    em geral no mesmo alvo;
  - fúria por risco e feridas (Berserker);
  - trocar de corpo (Metamorfo);
  - o contra-ataque de guarda do Defendente (Rebater). O Campeão não bloqueia: agarra
    o golpe e arremessa o atacante.

**5. Mecânica central: Contagem e ritmo.**
- **Ritmo:**
  - depois de cada golpe, há uma **janela de tempo certo** para o próximo;
  - um marcador no personagem mostra o tempo (um pulso que se fecha);
  - golpe dentro da janela: +1 de Contagem e mais dano;
  - golpe cedo demais ou tarde demais: a Contagem cai pela metade;
  - a janela é generosa nos primeiros números e mais apertada perto do 9;
  - a exigência de execução é intencional (decisão do usuário em 14/11): a
    dificuldade reflete o controle que o Campeão tem sobre o próprio corpo.
- **Contagem:**
  - vai de 0 a 9 e aparece como números sobre o personagem;
  - a cada 3, um bônus curto (velocidade de ataque e DEF);
  - sem golpe por alguns segundos, zera.
- **Golpes de fim:** Salto Esmagador e Cem Palmas gastam Contagem. O Último Compasso
  só tem força total no 9.

**Loop:** abrir com o Golpe Ritmado → golpes no tempo até 3, 6, 9 → Redirecionamento
quando o inimigo ataca (conta como golpe no tempo) → Salto Esmagador para trocar de
alvo gastando um pouco → no 9, Último Compasso.

**6. Habilidades.**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | **Golpe Ritmado** | ativa, entrada | Um golpe que sobe a Contagem em 2 se acertado no tempo e marca o próximo tempo certo. Abre e mantém a sequência. |
| 23 | **Fluxo** | passiva | Liga o ritmo e a Contagem: mais dano no tempo certo; fora do tempo, a Contagem cai pela metade. |
| 25 | **Salto Esmagador** | ativa | Salta para um ponto e cai com impacto em área. Gasta até 3 de Contagem para ampliar o impacto. |
| 28 | **Redirecionamento** | ativa | Postura muito curta: o próximo golpe corpo a corpo recebido é agarrado, e o atacante é arremessado para o lado escolhido. Dá +2 de Contagem. No chefe, só desvia o golpe e dá a Contagem. |
| 31 | **Disciplina do Corpo** | passiva | A cada 3 de Contagem, ganha velocidade de ataque e DEF até a sequência acabar. |
| 34 | **Cem Palmas** | ativa | Uma rajada de palmas no alvo à frente. O número de golpes é a Contagem atual, que é gasta inteira. |
| 37 | **Último Compasso** | ativa | No 9, um golpe final que repete num só impacto todos os golpes da sequência, com uma onda de choque em volta. Abaixo de 9, é mais fraco. |

**7. Composição.**
- **Do kit:**
  - Sequência e Palma (base) somam Contagem;
  - Passo Evasivo é a esquiva entre os tempos;
  - Pulso, Poço e Aparar saem cedo: são do lado do Elevado.
- **Build "Torneio":**
  - ativas: Golpe Ritmado + Redirecionamento + Cem Palmas + Passo Evasivo + Último
    Compasso;
  - passivas: Fluxo + Disciplina do Corpo;
  - jogo: um alvo de cada vez, sempre no tempo; o melhor contra o chefe.
- **Build "Arena":**
  - ativas: Golpe Ritmado + Salto Esmagador + Sequência + Palma + Último Compasso;
  - passivas: Fluxo + Respiração Contida;
  - jogo: salta de grupo em grupo, gastando a Contagem em impactos de área.
- **Visual:**
  - silhueta baixa e larga, punhos à frente;
  - cor: vermelho, laranja, preto, faixas brancas;
  - material: faixas, luvas de couro, pele; forma: punhos, diagonais rápidas;
  - arma típica: manoplas de couro e ferro (equipamento de punho);
  - VFX: impactos que se repetem na contagem, números de 1 a 9 sobre o personagem, o
    pulso do tempo certo, rastros de punho sobrepostos e uma onda de choque curta no
    Último Compasso;
  - em combate: a cada 3, as faixas brilham mais.

**8. Como origem e como afinidade.**
- **Como origem**, empresta a postura baixa e de punhos e o material: faixas, couro.
- **Como afinidade**, empresta o fenômeno: **ações no tempo certo sobem uma contagem
  que termina num golpe final**. A origem decide o que é contado. Um Arqueiro conta
  disparos no tempo; um Mago conta conjurações em sequência.
- **Para evitar:** "skill X com combo". A afinidade traz o tempo certo e a contagem,
  não só mais golpes.

**9. As cinco perguntas.**
- **Distância:** corpo a corpo.
- **Recurso:** Contagem (0 a 9) e o tempo certo.
- **Abrir e fechar:** abre com o Golpe Ritmado; fecha com as Cem Palmas ou o Último
  Compasso.
- **Contra o chefe:** subir até 9 no tempo, usando o Redirecionamento nos golpes do
  chefe. A decisão é gastar cedo nas Cem Palmas ou arriscar chegar ao 9.
- **Fraqueza:** errar o tempo custa metade da Contagem; ser empurrado para longe
  quebra a sequência; pouco alcance.

**10. Arte.**
- **Já existe:** o Monge (quatro vistas).
- **Falta:**
  - o traje do Campeão (quatro vistas);
  - as manoplas (equipamento) e as faixas reforçadas da base;
  - os números da Contagem e o pulso do tempo certo (podem ser desenhados em código),
    o impacto do Salto, o arremesso do Redirecionamento, a rajada das Cem Palmas e a
    onda do Último Compasso.

---

### Diferença entre as duas, num quadro

| | Elevado | Campeão |
|---|---|---|
| Tensão da base | conter | soltar |
| Onde está o poder | no espaço em volta | no próprio corpo, no tempo certo |
| Recurso | Calma (tempo sem ser tocado) | Contagem (golpes no tempo) |
| Distância | média, dentro do campo | corpo a corpo |
| Contra grupos | Levitação e Queda | Salto Esmagador |
| Contra o chefe | acumular e acertar a Descarga | chegar ao 9 no tempo |
| Momento de glória | Descarga Interior | Último Compasso |

### Decisões do usuário sobre o Monge (14/11)

Família Monge fechada para fins de arte e de descrição de híbridas.

1. **Ritmo do Campeão** como está: a dificuldade reflete o controle do corpo e
   combina com o tema.
2. **"Asura" vira "Descarga Interior"**, mantendo a mecânica: uma preparação forte
   (Calma no máximo, SP alto) antes do dano enorme.
3. **Chefe contra o Elevado:** nunca é erguido nem arremessado, só pressionado; a
   Telecinese pega os projéteis dele.
4. **Armas:** faixas reforçadas (Monge), rosário flutuante como foco (Elevado) e
   manoplas (Campeão).

---

## As seis estendidas jogáveis (registro)

Estas classes já estão no jogo, com kit, arte e aceite de produto. As fichas abaixo
**registram o que existe**, no mesmo formato, para servir às híbridas. Não são
redesenho. Fontes:
- [E05_S2_SP_KIT_CONTRACT.md](E05_S2_SP_KIT_CONTRACT.md) (Defendente e Berserker);
- [E05_ELEMENTALIST_CHECKPOINT.md](E05_ELEMENTALIST_CHECKPOINT.md);
- [E05_SPIRITUALIST_CHECKPOINT.md](E05_SPIRITUALIST_CHECKPOINT.md);
- [E05_SENTINEL_PLAN.md](E05_SENTINEL_PLAN.md);
- [E05_HUNTER_PLAN.md](E05_HUNTER_PLAN.md);
- os níveis de job de [e06_all_skill_dependencies_proposal.md](epics/e06/e06_all_skill_dependencies_proposal.md);
- os substantivos e a linguagem visual do handoff de 13/09
  ([e00_hybrid_handoff_2026_09_13.md](references/e00_hybrid_handoff_2026_09_13.md)).

Números exatos (pesos, custos, recargas) ficam nesses documentos e no catálogo. Aqui
vai só a função.

**Correção de premissa:** o padrão de 7 skills (5 ativas e 2 passivas) vale para a
Elementalista e a Espiritualista. Defendente, Berserker e Sentinela têm 9, e a
Caçadora tem 8; a biblioteca foi ampliada de propósito, sem aumentar o loadout de 5
ativas e 2 passivas. As fichas novas deste documento seguem o padrão de 7, que
continua sendo o ponto de partida.

---

### Defendente — placa

**Foco.** Lê a frente, segura um corredor e responde ao que bateu nele.

**Temática.** Substantivo: **placa**. Prata, dourado, marrom e cinza; aço, couro e
pedra; formas de placa, retângulo e massa; VFX de impacto seco, ondas curtas e
partículas pesadas.

**Mecânica central: token de guarda e corredor.**
- **Token de guarda:** um impacto frontal mitigado de verdade (ou um projétil
  interceptado) concede um token por alguns segundos. O Contraforte e a Onda o
  consomem para dano extra.
- **Marco de Guarda:** uma zona onde o Defendente ganha DEF, e os inimigos dentro ficam
  lentos.
- **Fraqueza:** flanco, ataques em área e ser obrigado a sair do Marco. Não tem
  mitigação em todas as direções nem cura em combate.

**Habilidades (9).**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | Contraforte | ativa, entrada | Golpe e guarda frontal curta; gasta o token para dano extra. |
| 23 | Vigília | passiva | Golpe corpo a corpo reduz o dano causado pelo alvo por um instante. |
| 25 | Marco de Guarda | ativa | Zona no chão: DEF para o Defendente e lentidão para os inimigos. |
| 25 | Guarda de Retirada | ativa | Passo para trás mantendo a guarda frontal. |
| 28 | Trava de Linha | ativa | Faixa à frente: dano e root. |
| 31 | Resguardo | passiva | Evento frontal de guarda devolve SP. |
| 31 | Rebater | ativa | Contra-ataque em cone à frente que exige e gasta o token de guarda. |
| 34 | Avanço de Muralha | ativa | Avanço curto com mitigação frontal, empurrando o primeiro alvo. |
| 37 | Onda de Represália | ativa | Pulso em volta do Marco (ou do Defendente); o token amplia e empurra. |

**Como origem e como afinidade.**
- **Como origem**, empresta o corpo como bloco que aponta para uma direção e o
  material: placa, aço, pedra. Exemplo do MVP: Cavaleiro Rúnico (placa + energia =
  inscrição).
- **Como afinidade**, empresta o fenômeno: **o golpe recebido de frente vira recurso
  para responder**, e um lugar que se defende. Exemplo do MVP: o Bastião
  recebe a fortificação e a represália.

**As cinco perguntas.** Distância: corpo a corpo. Recurso: token de guarda. Abre com
o Contraforte e o Marco; fecha com a Onda ou o Rebater. Contra o chefe, o impacto
frontal dá token sem adds. Fraqueza: flanco e área.

---

### Berserker — ferida

**Foco.** Marca o alvo, insiste nele e executa, pagando com exposição e HP.

**Temática.** Substantivo: **ferida**. Vermelho, marrom e preto; ferro escuro,
couro, feridas; diagonais e rasgos; VFX de pulsação, spray, tremor e rastros
agressivos. Arma de duas mãos de lâmina larga, sem escudo.

**Mecânica central: a ferida.**
- **Ferida:** a Ruptura abre uma ferida no alvo, e cada golpe corpo a corpo seguinte
  acrescenta uma carga, até três. Reativar a Ruptura ou usar a Execução converte as
  cargas em dano.
- **Custo:** a Execução custa uma fração do HP. A Obstinação recompensa lutar com
  pouca vida.
- **Fraqueza:** a exposição da Fúria e do custo de HP; trocar de alvo ou errar perde a
  marca. Sem cura gratuita.

**Habilidades (9).**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | Ruptura | ativa, entrada | Abre a ferida; a segunda ativação detona as cargas. |
| 23 | Obstinação | passiva | Com HP até a metade, mais dano corpo a corpo direto. |
| 25 | Salto Cruento | ativa | Avanço ofensivo com golpe no alvo. |
| 28 | Execução | ativa | Custa HP; consome as cargas e ganha bônus em alvo com pouca vida. Não é morte certa. |
| 31 | Caça Persistente | passiva | Golpe em alvo ferido recupera SP. |
| 31 | Talho de Perseguição | ativa | Golpe corpo a corpo direto, com bônus se o alvo já estiver ferido; não abre ferida. |
| 34 | Fenda Sangrenta | ativa | Faixa à frente: dano e sangramento. |
| 37 | Arrancar Fôlego | ativa | Golpe que cura parte do dano se o alvo ferido sobreviver. |
| 37 | Hemorragia Profunda | passiva | Alonga o sangramento da Fenda. |

**Como origem e como afinidade.**
- **Como origem**, empresta a postura inclinada e agressiva e o material: ferro escuro,
  couro, a ferida. Exemplo do MVP: o Saqueador (mecanismo + ferida = armadilha
  brutal).
- **Como afinidade**, empresta o fenômeno: **insistir no mesmo alvo acumula uma marca
  que se converte em dano, pagando com risco**. Exemplo do MVP: o Possesso
  (ferida + vestígio = possessão).

**As cinco perguntas.** Distância: corpo a corpo. Recurso: cargas de ferida e HP.
Abre com a Ruptura; fecha com a detonação ou a Execução. Contra o chefe, o mesmo loop.
Fraqueza: exposição e troca de alvo.

---

### Elementalista — energia

**Foco.** Alterna fogo, gelo e raio no mesmo alvo para ser recompensada pela
sequência.

**Temática.** Substantivo: **energia**. Azul, branco, vermelho e amarelo; cristal,
vidro, energia; prismas e formas radiais; VFX de alto brilho, expansão, cristais e
arco elétrico.

**Mecânica central: alternância de elementos.**
- **Regras dos elementos:** o fogo só causa dano; o gelo deixa lento; o raio marca
  (Eletrizado) e, no golpe seguinte, consome a marca com chance de atordoar.
- **Recompensa pela alternância:** acertar elementos diferentes no mesmo alvo devolve
  SP (Foco Prismático), e três elementos distintos ampliam o terceiro golpe
  (Ressonância Prismática). Não há barra de recurso nova.
- **Fraqueza:** exposição durante a conjuração e custo de SP alto se não alternar.

**Habilidades (7).**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | Explosão de Chamas | ativa, entrada | Detonação de fogo num ponto. |
| 23 | Foco Prismático | passiva | Dois elementos diferentes no mesmo alvo devolvem SP. |
| 25 | Anel Glacial | ativa | Anel de gelo em volta: dano e lentidão. |
| 28 | Arco Voltaico | ativa | Raio que salta para mais dois alvos. |
| 31 | Ressonância Prismática | passiva | Três elementos distintos ampliam o terceiro golpe. |
| 34 | Trilha de Brasas | ativa | Três erupções de fogo em linha. |
| 37 | Nova Tríplice | ativa | Três pulsos em volta: fogo, gelo e raio. |

**Como origem e como afinidade.**
- **Como origem**, empresta a postura do conjurador e o material: cristal, vidro, energia.
- **Como afinidade**, empresta o fenômeno: **fogo, gelo e raio com regras próprias, e
  a ordem e a alternância importam**. Regra de família do handoff: os três elementos
  precisam estar presentes, reinterpretados no substantivo da outra classe. Exemplos
  do MVP: Cavaleiro Rúnico (runas) e Geômetra (vértices).

**As cinco perguntas.** Distância: média a longa. Recurso: SP e a sequência de
elementos. Abre com qualquer elemento; fecha com o terceiro da sequência ou a Nova.
Contra o chefe, alternar no mesmo alvo. Fraqueza: conjuração exposta.

---

### Espiritualista — vestígio

**Foco.** Fixa uma maldição que ecoa e se propaga, drena e manifesta espectros
curtos, sem cadáveres nem invocações permanentes.

**Temática.** Substantivo: **vestígio**. Branco pálido, preto, cinza e prata;
tecido, névoa, ectoplasma; crescentes, véus, duplicações; VFX de imagens
remanescentes, translucidez, atraso e dissipação.

**Mecânica central: o eco.**
- **Maldição do Eco:** marca o alvo; o próximo golpe direto consome a marca e produz um
  eco atrasado.
- **Propagação:** desde 02/10, a maldição marca também os vizinhos, e o eco se propaga
  entre marcados, com limites contra cascata.
- **Drenagem:** canalizada, cura um pouco e exige ficar parado.
- **Fraqueza:** a canalização exige imobilidade e linha estável; a marca precisa do
  segundo golpe.

**Habilidades (7).**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | Maldição do Eco | ativa, entrada | Marca o alvo (e vizinhos); o próximo golpe produz o eco. |
| 23 | Recolhimento | passiva | O eco devolve SP. |
| 25 | Drenagem Espiritual | ativa | Canalização de quatro ticks que cura uma fração do dano. |
| 28 | Véu Espectral | ativa | Zona que reduz o dano causado pelos inimigos dentro. |
| 31 | Foco do Além | passiva | Drenagem completa amplia a próxima Maldição ou o próximo Rito. |
| 34 | Procissão de Espectros | ativa | Três aparições em sequência num alvo. |
| 37 | Rito de Dissipação | ativa | Área num ponto; dano extra nos amaldiçoados e enfraquecimento. |

**Como origem e como afinidade.**
- **Como origem**, empresta a postura de quem canaliza e o material: tecido, névoa,
  ectoplasma.
- **Como afinidade**, empresta o fenômeno: **o que passou deixa um vestígio que
  repete, com atraso, o que aconteceu**. Exemplos do MVP: Possesso (ecos
  que repetem o golpe) e Rastreador (rastro de pó de alma).

**As cinco perguntas.** Distância: média. Recurso: SP, a marca e a canalização. Abre
com a Maldição; fecha com o Rito. Contra o chefe, a marca e o canal funcionam sem
adds. Fraqueza: imobilidade na canalização.

---

### Sentinela — linha

**Foco.** Encontra janelas de estabilidade, acumula Foco e escolhe um disparo de
precisão, de linha ou de área.

**Temática.** Substantivo: **linha**. Verde, azul-claro, marrom-claro e branco;
madeira clara, tecido, metal; linhas longas e mira; VFX de trajetórias limpas, linhas
finas e brilho direcional.

**Mecânica central: Foco.**
- **Foco:** um recurso de 0 a 100, separado do SP, que se acumula parado em combate.
  Andar interrompe a geração, mas não apaga o Foco.
- **Fontes em movimento:** Observar e Leitura de Aberturas dão Foco mesmo andando.
- **Gasto:** os tiros fortes gastam Foco.
- **Duas builds:** crítica (DES/AGI/SOR) e conjuradora (INT/DES/SOR).
- **Fraqueza:** precisa parar para gerar Foco.

**Habilidades (9).**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | Tiro na Cabeça | ativa, entrada | Tiro forte em alvo único; gasta Foco. |
| 20 | Observar | ativa | Marca um alvo; os próximos acertos dão Foco. |
| 23 | Postura de Precisão | passiva | Parado, ganha DES e SOR. |
| 25 | Tiro Perfurante | ativa | Atravessa os inimigos em linha; gasta Foco. |
| 28 | Tiro de Rede | ativa | Rede em área que prende. |
| 31 | Tiro Explosivo | ativa | O próximo ataque explode em área; gasta Foco. |
| 31 | Leitura de Aberturas | passiva | Crítico ou alvo controlado devolve Foco. |
| 34 | Tiro de Concussão | ativa | Atordoa e enfraquece. |
| 37 | Foco Absoluto | ativa | Por alguns segundos, mais alcance e geração de Foco mais rápida. |

**Como origem e como afinidade.**
- **Como origem**, empresta a postura imóvel de mira e o material: madeira clara,
  tecido, metal.
- **Como afinidade**, empresta o fenômeno: **linhas longas de tiro e paciência que
  rende**: ficar parado e mirar acumula e é recompensado. Exemplos do MVP: Baluarte de
  Cerco (a linha de vigia) e Geômetra (linha + energia = geometria).

**As cinco perguntas.** Distância: longa. Recurso: Foco. Abre com Observar e parando;
fecha com o Tiro na Cabeça, o Perfurante ou o Explosivo. Contra o chefe, gerar Foco
nas janelas paradas. Fraqueza: o movimento forçado.

---

### Caçadora — mecanismo

**Foco.** Prepara o terreno com armadilhas, e cada armadilha ativada abre a presa para
o tiro seguinte.

**Temática.** Substantivo: **mecanismo**. Marrom-escuro, verde-musgo e marrom-claro;
madeira bruta, corda e osso; ganchos, nós e mecanismos; VFX de poeira, folhas, marcas no
chão e acionamento mecânico.

**Mecânica central: abertura.**
- **Abertura:** toda armadilha ativada (inclusive o Laço e a Explosiva da base) abre a
  presa por alguns segundos.
- **Exploração:** o próximo tiro direto na presa aberta causa dano extra e dá um curto
  bônus de velocidade (Passo de Caça).
- **Marca:** amplia a janela e a recompensa.
- **Cobertura:** a moita esconde.
- **Regra do handoff:** se tirar as armadilhas e a classe ficar quase igual, o design
  falhou.

**Habilidades (8).**

| Job | Skill | Tipo | Função |
|---|---|---|---|
| 20 | Armadilha Congelante | ativa, entrada | Prende quem pisa e causa dano mágico. |
| 20 | Armadilha de Piche | ativa | Campo que deixa lento. |
| 23 | Armadilha de Espinhos | ativa | Dano em área, sangramento e lentidão. |
| 25 | Marca do Caçador | ativa | Prioridade: janela maior e mais recompensa na presa marcada. |
| 28 | Disciplina de Tiro | passiva | Tiro que explora a abertura ganha dano extra de precisão. |
| 31 | Tiro de Cobertura | ativa | Tiro forte e recuo da Caçadora. |
| 34 | Presa Fácil | passiva | Mais recompensa se a presa estiver marcada ou controlada. |
| 37 | Cobertura Total | ativa | Área grande que esconde por alguns segundos. |

**Como origem e como afinidade.**
- **Como origem**, empresta a postura de quem prepara e espera e o material: madeira
  bruta, corda, osso.
- **Como afinidade**, empresta o fenômeno: **o terreno preparado decide a luta**:
  mecanismos que disparam com a presa e abrem a janela. Exemplos do MVP: Saqueador (a
  rede que vira rota) e Rastreador (armadilhas que criam rastro).

**As cinco perguntas.** Distância: média a longa. Recurso: armadilhas armadas e a
janela de abertura. Abre com a armadilha; fecha com o tiro de exploração. Contra o
chefe, a abertura funciona mesmo com controle resistido. Fraqueza: tempo de preparação
e chefes que não passam pelas armadilhas.

---

## Quadro dos dezesseis substantivos

| Base | Estendida | Substantivo | Fenômeno que empresta como afinidade |
|---|---|---|---|
| Espadachim | Defendente | placa | golpe recebido de frente vira resposta |
| Espadachim | Berserker | ferida | insistir no alvo acumula marca que vira dano, com risco |
| Mago | Elementalista | energia | fogo, gelo e raio, com ordem e alternância |
| Mago | Espiritualista | vestígio | o que passou repete com atraso |
| Arqueiro | Sentinela | linha | linha longa e paciência que rende |
| Arqueiro | Caçadora | mecanismo | terreno preparado que abre a presa |
| Acólito | Sacerdote | halo | círculo com regra própria; proteção que sobra vira luz |
| Acólito | Cultista | olho | ver demais faz perder o controle |
| Bruxo | Demonólogo | vínculo | parceiro com vontade, vida trocada pelo vínculo |
| Bruxo | Necromante | podridão | o que morre vira recurso |
| Druida | Naturalista | raiz | plantas que ocupam o terreno; pedra que muda o caminho |
| Druida | Metamorfo | pelagem | mudar o estado do corpo, com a transição como golpe |
| Ladino | Assassino | sombra | sumir e reaparecer no ângulo certo, e decidir entre executar e sair |
| Ladino | Dervixe | vendaval | o vento que cresce a cada vítima diferente |
| Monge | Elevado | campo | o espaço em volta como extensão do corpo |
| Monge | Campeão | ritmo | ações no tempo certo sobem uma contagem até o golpe final |

Com este quadro, cada híbrida pode ser descrita como **o objeto e a postura da
origem + o fenômeno da afinidade**, que é o método do handoff de 13/09.
