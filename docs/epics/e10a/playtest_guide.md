# Roteiro de playtest — candidato E10a

Candidato `{SHA}` (branch `claude/e10a-candidato`): a base **Acólito** e as duas evoluções puras,
**Sacerdote** e **Cultista**, mais o HUD da família. Aprovação técnica não é aceite: este roteiro
serve para o seu aceite visual e de jogo. Os números dos kits são ajuste de playtest, não equilíbrio
certificado.

## Como abrir

- **Build Windows (recomendado para o aceite):** pasta
  `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e10a/{SHA}/`.
  - Abra pelos atalhos **"Jogar E10a - <classe> - <build>"**. Cada atalho usa um perfil isolado dentro
    da própria pasta, com um personagem no job 40 e a build já montada.
  - O perfil é separado do RagRPG habitual; o save pessoal não é lido nem alterado. Não copie saves
    entre builds.
  - Mantenha o EXE e o PCK juntos.
- **Projeto habitual (F5 no Godot):** só depois da aprovação técnica. Esse caminho usa o seu perfil
  pessoal; para testar a criação do zero, crie um personagem novo.

## Builds nomeadas (perfis prontos)

Cada perfil tem o personagem no nível base máximo e no job 40, com as duas árvores e os atalhos da
build. Os perfis não trazem atributos nem equipamento: distribua os pontos e equipe antes de lutar.
O personagem se chama "E10a <build>".

| Classe | Origem | Build | Atalho |
|---|---|---|---|
| Sacerdote | Acólito | Bastião da Fé | Jogar E10a - Sacerdote - Bastião da Fé |
| Sacerdote | Acólito | Inquisição | Jogar E10a - Sacerdote - Inquisição |
| Cultista | Acólito | Profeta | Jogar E10a - Cultista - Profeta |
| Cultista | Acólito | Vidente | Jogar E10a - Cultista - Vidente |

## Roteiro

1. **Criação do Acólito (personagem novo).** Na criação, o menu agora tem **quatro** botões:
   Espadachim, Mago, Arqueiro e **Criar Acólito**. O Acólito mostra a descrição "Fé e sombra…" e o
   tooltip com a mesma frase. Crie um Acólito e confira:
   - o corpo próprio do Acólito nas quatro direções;
   - o **Livro de Orações do Noviço** já equipado (item inicial);
   - o guia de onboarding do Acólito (Loucura, Delírio, Visão Eldritch e Devoção);
   - as oito skills da base: **Luz Punitiva**, **Prece**, **Escudo Votivo**, **Selo Sombrio**,
     **Sussurro Perturbador**, **Visão Eldritch**, e as passivas **Devoção** e **Fé Protetora**.
2. **Evolução para Sacerdote e para Cultista.** Com **Admin · F10**, suba um Acólito até o job 20 e abra
   **Classe e equipamento**: a escolha lista **Sacerdote** e **Cultista**. Crie dois Acólitos e evolua um
   para cada. A evolução pede a confirmação de sempre e depois fica fixa. Cada evolução mostra o
   onboarding próprio.
3. **Base: Loucura, sombra e luz.**
   - **Selo Sombrio** marca o alvo por 6 s (menos precisão, dano de sombra por segundo) e dá Loucura.
   - **Sussurro Perturbador** dá Loucura a todo o cone e afasta os comuns; o chefe leva a Loucura, mas
     nunca é empurrado.
   - **Devoção**: luz seguida de sombra (ou o contrário) em até 8 s reforça a skill seguinte.
   - **Visão Eldritch** amplia o alcance do ataque básico e dobra a Loucura do próximo Selo ou Sussurro.
4. **Sacerdote (Santuário, Graça e Égide).**
   - **Santuário** abre a zona consagrada no ponto; **Graça** cresce com a cura excedente.
   - **Égide** é barreira com pulso de luz; **Juízo** derruba uma coluna de luz; **Selo de Luz** imobiliza
     (no chefe, só deixa lento); **Hora Santa** amplia o círculo e libera a Graça.
   - **Exorcista** remove escudo ou buff do inimigo; sem o que remover, o alvo fica **Exposto** à luz.
5. **Cultista (Delírio, Êxtase e Ídolo).**
   - **Olhar do Abismo**: cone que dá Loucura. **Delírio Compartilhado**: contágio que pula uma vez por
     evento; no máximo três inimigos em Delírio ao mesmo tempo, e os delirantes nunca atacam o chefe.
   - **Êxtase** (0 a 5): quanto mais alto, mais dano recebido a partir de 3.
   - **Ídolo Impossível**: um por vez, com prazo; só comuns e elites o atacam.
   - **Geometria Impossível**: comuns andam na direção errada; o chefe só fica lento. Confira também
     **Revelação** e a passiva **Pupila Aberta** (o onboarding do Cultista explica as duas).
   - Um abate por Delírio conta como do Cultista (XP e loot normais).
6. **HUD.** Confira o que aparece sem painel novo:
   - **Loucura** sobre os inimigos, em cinco degraus, na cor de sombra (roxa), e o selo de Delírio no
     inimigo em Delírio;
   - **Sacerdote:** Graça, Égide e Hora Santa, a zona do Santuário e o selo de Luz;
   - **Cultista:** Êxtase de 0 a 5 e o Ídolo (tempo e zona circular).
   - O Acólito sem evolução mostra só a Loucura; o Sacerdote e o Cultista somam a Loucura da base ao que
     é do próprio kit, sem duplicar.
7. **Livro, cetro e relicário.** Os três itens caem no loot das faixas de poder atuais:
   - **Livro de Orações do Noviço** (comum, nível 2–5; inicial do Acólito);
   - **Cetro do Halo Dourado** (raro, nível 6–10; típico do Sacerdote);
   - **Relicário do Olho Atento** (raro, nível 6–10; típico do Cultista).
   Equipe cada um e confira a mão nas quatro direções, parado, andando e atacando. O livro deve ficar na
   altura da mão, sem subir ao rosto ou ao torso (grip corrigido na T8). As armaduras de tecido do Mago
   servem ao Acólito.
8. **Augments.** Seis, no mesmo padrão dos anteriores, com três níveis cada:
   - **Pressão Votiva** (dano mágico a cada acerto) e **Reserva Votiva** (SP máximo): Acólito, Sacerdote
     e Cultista;
   - **Muralha da Fé** (vida máxima) e **Juízo Implacável** (dano do Juízo): só Sacerdote;
   - **Delírio Compartilhado Profundo** e **Olhar Sem Fundo** (dano de cada skill): só Cultista.
   Equipe um deles e confira que o texto e o efeito batem; um augment do Cultista não deve aparecer para
   o Sacerdote, e vice-versa.
9. **Seleções de andar (A19–A22).** Em um mapa com dois andares (a ponte da fase da floresta), confirme
   que nenhuma skill da família atinge o inimigo do outro andar:
   - **Juízo** (Sacerdote e Paladino): a coluna fere só o andar de quem conjura;
   - **Olhar do Abismo**, **Sussurro**, **Geometria**, **Revelação**, **Ídolo** e o contágio do Delírio:
     só o inimigo do mesmo andar entra. O Santuário e o Selo de Luz já respeitavam o chão.
10. **Fé Protetora sobre a Égide.** Com o Acólito e a passiva **Fé Protetora** em rank alto, a barreira
    recebida fica mais forte (+10/15/20%): o **Escudo Votivo** e também a **Égide** do Sacerdote. Compare a
    barreira da Égide com a Fé no rank 0 e no 3: a diferença é única (a barreira não é reforçada duas
    vezes) e a barreira expira no prazo, ainda com o reforço.
11. **Campanha e chefes (D10).** Sem mapa nem chefe novo.
    - **Fase da floresta** com o **Guardião Antigo** (invoca um companheiro). Luta de ponta a ponta com o
      Cultista (Profeta) e com o Sacerdote. O chefe nunca troca de alvo e os delirantes não o atacam.
    - **Roteiro do E06** com o **Mestre das Feras**. Confira o abate por Delírio dando XP e loot.
12. **Mage, Paladino e Taumaturgo.** Uma volta rápida para confirmar que o HUD das híbridas do E12 e as
    cores de luz e sombra seguem como antes.

## O que não foi testado em jogo

- Mortos-vivos e fantasmas: o bônus do Exorcista contra eles fica dormente até a categoria existir.
- Nenhum som novo: as deixas de áudio que faltam ficam como lacunas registradas (`KIT_AUDIO_GAPS`).
- A medição de multidão com Delírio ativo está no recibo da T13; ela não alega FPS.
