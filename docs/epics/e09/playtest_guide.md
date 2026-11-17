# Roteiro de playtest — candidato E09

Candidato `3843d324` (branch `claude/e09-candidato`), quatro híbridas: **Paladino**, **Taumaturgo**,
**Duelista** e **Lâmina Arcana**. Aprovação técnica não é aceite: este roteiro serve para o seu
aceite visual e de jogo. Os números dos kits são ajuste de playtest, não equilíbrio certificado.

## Como abrir

- **Build Windows (recomendado para o aceite):** pasta
  `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e09/e09_3843d324/`.
  - Abra pelos atalhos **"Jogar E09 - <classe> - <build>"**. Cada atalho usa um perfil isolado dentro
    da própria pasta, com um personagem no job 40 e a build já montada.
  - O nome do aplicativo é **RagRPG E09 Candidato**. O perfil é separado do RagRPG habitual; o save
    pessoal não é lido nem alterado. Não copie saves entre builds.
  - Mantenha o EXE e o PCK juntos.
- **Projeto habitual (F5 no Godot):** só depois da aprovação técnica e da supervisão da T11. Esse
  caminho usa o seu perfil pessoal; para testar a escolha de evolução do zero, crie um personagem
  novo.

## Builds nomeadas (perfis prontos)

Cada perfil tem o personagem no nível base máximo e no job 40, com as duas árvores e os atalhos da
build. Os perfis não trazem atributos nem equipamento: distribua os pontos e equipe antes de lutar.
O personagem se chama "E09 <build>". A exceção é "Corrente de Execuções", que sai sem o prefixo,
porque o save aceita no máximo 24 caracteres no nome.

| Classe | Origem | Build | Atalho |
|---|---|---|---|
| Paladino | Espadachim | Baluarte da Luz | Jogar E09 - Paladino - Baluarte da Luz |
| Paladino | Espadachim | Martelo Consagrado | Jogar E09 - Paladino - Martelo Consagrado |
| Taumaturgo | Mago | Altar Prismático | Jogar E09 - Taumaturgo - Altar Prismático |
| Taumaturgo | Mago | Coro da Aurora | Jogar E09 - Taumaturgo - Coro da Aurora |
| Duelista | Espadachim | Lâmina Paciente | Jogar E09 - Duelista - Lâmina Paciente |
| Duelista | Espadachim | Arena do Duelo | Jogar E09 - Duelista - Arena do Duelo |
| Lâmina Arcana | Mago | Corrente de Execuções | Jogar E09 - Lâmina Arcana - Corrente de Execuções |
| Lâmina Arcana | Mago | Espectro Prismático | Jogar E09 - Lâmina Arcana - Espectro Prismático |

## Roteiro

1. **Escolha de evolução (personagem novo).** Crie um Espadachim e um Mago. Com **Admin · F10**, suba
   até o job 20 e abra a aba **Classe e equipamento**.
   - O Espadachim deve oferecer as evoluções de antes e, no fim da lista, **Paladino** e
     **Duelista**. O Mago deve oferecer as dele e **Taumaturgo** e **Lâmina Arcana**.
   - Cada híbrida nova mostra a afinidade ("Híbrida · afinidade Acólito" ou "Ladino").
   - Ao evoluir, a skill de entrada vem no R1 grátis, e o guia **"Guia +/−"** aparece no canto
     superior direito. O guia é estático: não mostra Graça, Sentença nem o círculo atual.
2. **Traje nas quatro vistas.** Em cada atalho, caminhe nas quatro direções, ataque, conjure e morra
   uma vez. Confira o traje próprio da classe, sem voltar ao corpo da origem.
3. **Paladino (Graça, Santuário em cone).**
   - **Juramento** projeta o cone à frente do escudo: menos dano de frente, queima de luz nos
     inimigos dentro.
   - **Graça de Guarda** gera Graça com a cura excedente e, com a Parede de Escudos, com golpes de
     frente.
   - **Impacto Consagrado** gasta até 5 cargas e derruba uma coluna de luz.
   - **Égide do Juramento**: halo de 6 s; ao quebrar ou expirar, um pulso que fere e empurra.
   - **Fé Inabalável**: dentro do Juramento, controles duram menos e a cura rende mais.
   - **Selo do Condenado**: o selado só ataca o Paladino, e dano de luz nele gera Graça.
   - **Hora do Juramento**: o cone vira círculo dourado, a Graça fica sem limite e o Impacto não
     custa SP.
4. **Taumaturgo (círculo elemental).**
   - **Círculo Votivo**: o primeiro feitiço de fogo, gelo ou raio lançado de dentro define o
     elemento (fogo queima mais, gelo dá DEF e lentidão, raio acelera o SP).
   - **Prisma Votivo**: trocar de elemento dentro do círculo gera Graça.
   - **Refração Curativa** cura e solta uma onda do elemento atual; **Mudança de Altar** troca o
     elemento na hora com um pulso do antigo.
   - **Coro dos Elementos**: três elementos seguidos deixam o círculo tricolor.
   - **Juízo Prismático**: coluna de luz em três pulsos; **Aurora Convergente**: círculo enorme,
     Graça sem limite e feitiços pela metade do SP.
5. **Duelista (aparo, costas e Sentença).**
   - **Aparo**: um golpe corpo a corpo de frente dentro da janela é aparado; o atacante gira, fica
     de costas e perde o Duelista de vista. No tempo certo, o SP volta.
   - **Leitura do Oponente** acumula Sentença; **Riposte Fatal** gasta tudo, e com Sentença cheia e
     o alvo ferido abaixo do limiar é morte certa (no chefe, só dano alto).
   - **Finta**, **Guarda Paciente** e **Recuo em Guarda**: a Finta e o Recuo não foram testados no
     mundo automatizado; observe-os com atenção.
   - **Duelo**: por alguns segundos, todo golpe de frente é aparado sozinho e devolve uma estocada.
   - Nenhum inimigo atual dá golpe em área; o aparo só vale para corpo a corpo.
6. **Lâmina Arcana (cristal, ocultação e execução).**
   - **Lâmina Encantada**: o ataque básico vira golpe corpo a corpo mágico que alterna fogo, gelo e
     raio. O golpe de cristal é desenhado tricolor, sem a cor do elemento.
   - **Marca Refratada** marca a vítima (visível através de obstáculos); **Refração** oculta, e o
     primeiro golpe ao sair dá Sentença. O HUD não mostra a recarga própria da Refração.
   - **Salto Prismático**: só oculta, teleporta às costas da vítima marcada. Um Salto para fora da
     coleira faz o chefe voltar ao posto.
   - **Sentença Prismática** e **Espectro de Prisma** (três reflexos executam três inimigos).
     **Fratura de Luz** devolve a carga da Refração e SP numa execução que mata.
7. **Itens novos (loot atual).** Os quatro caem no loot das faixas de poder atuais:
   - **Escudo do Halo** (escudo, DEF física +2, raro, nível 11);
   - **Rodela de Aço Batido** (escudo, DEF física +2, comum, nível 2);
   - **Florete de Guarda Larga** (uma mão, ATQ corpo a corpo +2, só Espadachim, incomum, nível 6);
   - **Cajado Prismático** (duas mãos, ATQ mágico +2, só Mago, raro, nível 6).
   Confira o ícone no inventário e a arma na mão nas quatro vistas.
8. **Save, suspensão e retomada.** Com o Juramento, o Círculo Votivo ou uma marca ativa, suspenda ao
   lobby e retome. O estado do jogador volta. As marcas em inimigos seguem o inimigo: no save exato
   voltam com ele; no compacto o inimigo volta à origem sem marcas. Zona ativa obriga o save exato.

## Pontos de aceite visual (pendentes de você)

Não são falhas técnicas. São as decisões de aparência e de jogo que os testes não tomam.

- **Corpos (T7).** Encaixe aproximado, com erro de até ±1 px.
  - Paladino virado para oeste, pose 57: a espada fica na mão baixa.
  - Lâmina Arcana virada para leste, pose 0: o cajado atravessa o rosto.
  - Não há variante sem elmo (`bare_head`).
  - Capturas em [t7_evidence](t7_evidence/).
- **Armas (T8).** Só o quadro 0 foi conferido em captura; as outras poses usam os mesmos pontos de
  mão.
- **Efeitos (K1–K4).** Os efeitos desenhados em código não foram capturados em tela. O Paladino usa
  a cor `arcane` no feedback de luz, porque ainda não há elemento `light`.
- **Som dos kits.** Faltam no catálogo de áudio as deixas `dot`, `heal` e `summon` arcanas
  (P6), e o E09 não tem tarefa de áudio. Por isso:
  - os pulsos do **Juramento** e do **Círculo Votivo** soam com o impacto genérico
    (`world.impact`);
  - a **Refração Curativa** não tem som próprio de cura;
  - o **Espectro de Prisma** não tem som de invocação e fica em silêncio.

  Diga se isso atrapalha a leitura do combate.
- **Escolha de evolução (T9).** A captura usou kits de fixture; o candidato mostra os nomes reais.
- **Ritmo e dificuldade.** Os chefes de teste dos kits foram simulados no mapa plano; a dificuldade
  humana e o ritmo do chefe ficam para você.

## O que relatar

Para cada classe: o que ficou claro ou confuso, o que pareceu forte ou fraco, falhas de arte (mão,
cabeça, arma, efeito) com a direção e a ação, e qualquer erro de save. Uma falha vai para a tarefa
dona (T7 corpos, T8 armas, K1–K4 kits, T9 escolha e guias) e volta para nova integração.
