# Roteiro de playtest — candidato E12 (HUD de combate)

Candidato técnico `874776ec` (branch `claude/e12-candidato`): o candidato E09 `a0c81525` mais as
tarefas H1 a H4 do [E12](../e12.md). Este marco só desenha: **nenhum dano, custo, recarga, ameaça,
regra de cast ou campo de save mudou**. Aprovação técnica não é aceite; o roteiro serve ao seu
aceite visual. Pontos que só você decide estão em "Para conferir" no fim.

## Como abrir

- **Build Windows (recomendado para o aceite):** pasta
  `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e12/e12_874776ec/`.
  - Abra pelos atalhos **"Jogar E12 - <classe> - <build>"**. Cada atalho usa um perfil isolado
    dentro da própria pasta, com um personagem no job 40 e a build já montada (as mesmas oito
    builds do E09: nomes na tabela abaixo).
  - O aplicativo se chama **RagRPG E12 Candidato**; o save é separado do habitual e o pessoal não é
    lido nem alterado. Mantenha o EXE e o PCK juntos.
  - Os perfis não trazem atributos nem equipamento: distribua os pontos e equipe antes de lutar.
- **Projeto habitual (F5 no Godot):** ainda **não** foi avançado. Isso só acontece depois da
  supervisão Luna (H6), da aprovação técnica e do aceite do E09 em `master`.

| Classe | Build | Atalho |
|---|---|---|
| Paladino | Baluarte da Luz / Martelo Consagrado | Jogar E12 - Paladino - … |
| Taumaturgo | Altar Prismático / Coro da Aurora | Jogar E12 - Taumaturgo - … |
| Duelista | Lâmina Paciente / Arena do Duelo | Jogar E12 - Duelista - … |
| Lâmina Arcana | Corrente de Execuções / Espectro Prismático | Jogar E12 - Lâmina Arcana - … |

**Onde lutar.** Para o **mapa plano**, use "Iniciar run" (ou "Treinar contra boss e reforços", que
não grava XP). Para o **mundo da expedição** (a floresta em perspectiva), use o botão
"Expedições". Confira cada item nas duas vistas quando o roteiro disser "plano e mundo".

## O que mudou na tela

| Elemento | Onde aparece |
|---|---|
| **Painel de recurso** | Sob VIDA e SP, só para quem tem kit (as quatro híbridas). Pontos, prazos e recargas do kit. |
| **Zona no chão** | Cone ou círculo do Santuário, desenhado sob os atores enquanto está ativo, na cor do elemento atual. |
| **Marcas sobre a vítima** | Pontos de Sentença (0 a 5) e selos, sobre o inimigo marcado, no padrão dos losangos de Ferida do Berserker. |
| **Aviso no atalho** | Palavra curta no canto do atalho (por exemplo "SEM CARGA") e a recarga própria do kit no centro; o texto longo está no tooltip. |
| **Barra de cast do jogador** | Centralizada **acima** da barra de atalhos, com nome e tempo restante. Substitui "Conjurando X · Ns" e "CONJURANDO Ns". |
| **Barra de cast do inimigo** | Fina, sob a barra de vida, só durante o cast do mob. |

## Roteiro

Para cada híbrida, confira **plano e mundo** e anote o que ficou claro, o que ficou confuso e o que
ficou pequeno demais para ler.

1. **Paladino** (Baluarte da Luz ou Martelo Consagrado).
   - **Painel:** a **Graça** aparece em pontos de 0 a 5 e sobe quando você gera Graça (cura
     excedente, golpes de frente com a Parede de Escudos). Com a **Hora do Juramento**, os pontos
     viram "∞" com o prazo restante. Linhas de prazo para **Juramento**, **Égide** (6 s) e
     **Hora do Juramento** só enquanto ativos.
   - **Zona:** ao usar o Juramento, o **cone** aparece à frente do Paladino, em tom de luz; na
     Hora vira um **círculo** dourado e maior. Some quando o Juramento acaba.
   - **Selo do Condenado:** o inimigo selado mostra o selo (uma marca, não pontos). Ele some com o
     selo ou com a morte do alvo.
   - **Atalho:** o Juramento mostra "HORA ATIVA" durante a Hora do Juramento.
2. **Taumaturgo** (Altar Prismático ou Coro da Aurora).
   - **Painel:** **Graça** em pontos (e "∞" na **Aurora Convergente**, com prazo). Linhas de prazo
     para **Círculo Votivo** (na cor do elemento atual do círculo), **Coro Elemental** (tricolor)
     e **Aurora Convergente**.
   - **Zona:** o **Círculo Votivo** aparece no ponto onde foi posto, **na cor do elemento**:
     comece sem elemento, lance fogo, gelo ou raio de dentro e veja a cor mudar; com o Coro, o
     círculo fica tricolor. Na Aurora o círculo cresce.
   - **Atalho:** "SEM CÍRCULO" na **Mudança de Altar** quando não há círculo; "AURORA ATIVA" no
     Círculo Votivo durante a Aurora.
3. **Duelista** (Lâmina Paciente ou Arena do Duelo).
   - **Painel:** linhas de prazo do **Duelo** e do **Aparo automático** (8 s), e a **Guarda
     Paciente** quando pronta. Fora disso o painel fica vazio.
   - **Sentença:** o inimigo que o Duelista "lê" mostra **pontos de Sentença** (0 a 5) acima dele;
     confira que sobem com a **Leitura do Oponente** e zeram depois do **Riposte Fatal**.
   - **Atalho:** o Aparo mostra "DUELO ATIVO" durante o Duelo (o Duelo já apara sozinho).
4. **Lâmina Arcana** (Corrente de Execuções ou Espectro Prismático).
   - **Painel:** a **Refração** como uma carga (cheia ou vazia) e, vazia, a **recarga própria**
     contando; linha de prazo da **Ocultação** quando oculto.
   - **Atalho da Refração:** vazia mostra **"SEM CARGA"** e o tempo de recarga no centro; oculto,
     mostra "OCULTO". Tente conjurar sem carga: a regra continua recusando, como antes.
   - **Sentença:** pontos de 0 a 5 sobre a vítima marcada (Marca Refratada).
   - **Espectro de Prisma:** o selo do Espectro aparece sobre cada inimigo que vai receber um
     reflexo. Veja a limitação do Espectro abaixo.
5. **Barra de cast do jogador (plano e mundo).**
   - Conjure uma skill com tempo de preparo. A barra aparece **acima da barra de atalhos**,
     centralizada, com o **nome** e o **tempo restante**, e **enche até o fim do preparo**.
   - No plano, a linha "mover / Direito / Esc cancela" continua abaixo; no mundo ela não aparece
     (não aparecia antes) e a barra fica um pouco mais alta, acima da linha de status.
   - O texto antigo "Conjurando X · Ns" e o "CONJURANDO Ns" do atalho **não devem mais existir**.
6. **Um mob com cast.**
   - Lute contra o chefe da floresta (ou use "Treinar contra boss e reforços") e espere a
     habilidade com preparo. A barra **fina** aparece sob a barra de vida do mob, só durante o
     cast.
   - **Nome na barra:** só em **elite**, **elite rara** e **chefe**. Um mob comum mostra a barra
     **sem nome**. Confira se o nome, com contorno escuro, é legível sobre o chão.
7. **Pausa no meio de um cast.** Comece um cast (o seu e, em outra tentativa, o do mob), pause e
   olhe a barra: ela **congela** e **retoma do mesmo ponto** ao despausar, sem pular.
8. **Cancelamento.**
   - **Jogador:** com um cast em andamento, cancele pelo **botão direito**, pelo **Esc** ou
     **movendo-se**. A barra **pisca** (cor de cancelamento) e some.
   - **Mob:** interrompa o cast do mob com um atordoamento ou medo. A barra deve piscar e sumir.
   - Um cast **concluído** do jogador simplesmente some (veja "Para conferir").
9. **Pause, suspensão e retomada.** Com uma zona ou marca ativa, suspenda ao lobby e retome. O
   painel, a zona e as marcas voltam como o estado do kit (o HUD só lê o estado salvo).

## Para conferir (limitações registradas nos recibos)

São decisões ou pontos de legibilidade que os testes não tomam. Diga se aceita ou pede ajuste.

- **"SEM CARGA" em fonte 9 (H4).** As palavras do atalho ("SEM CARGA", "OCULTO", "HORA ATIVA",
  "AURORA ATIVA", "SEM CÍRCULO", "DUELO ATIVO") usam fonte 9, no canto de um atalho de 60 px.
  Cabem, mas a **legibilidade em jogo** só você confirma. O texto completo está no tooltip.
- **Cast concluído do jogador sem flash de liberação (H4).** O mago emite `cast`, não
  `cast_release`; por isso, ao concluir o cast a barra só **some**, sem o flash de liberação. O
  flash de **cancelamento** sempre pisca. O flash de liberação existe e é testado para atores que
  emitem `cast_release`.
- **Espectro da Lâmina (H2 e H4).** Com **um** inimigo o único reflexo golpeia no tick do cast e o
  selo do Espectro **nunca aparece**. Com **três** inimigos os reflexos saem escalonados em 0,20 s
  e o selo fica **0,40 s** na tela: perceptível, mas curto. Nenhuma regra mudou.
- **Cone do Paladino segue o sprite (H4).** O cone usa a orientação **atual do sprite** do
  Paladino, não a do cast; se ele virar durante o Juramento, o cone vira junto.
- **Prazos vêm da ficha (H2).** Os totais das barras de prazo saem da ficha da skill pelo rank;
  se você subir o rank, o total acompanha.
- **Recusas que dependem de alvo (H2).** O DTO só lista recusas que **não** dependem de alvo; a
  recusa por falta de alvo continua sendo a de antes, sem aviso no atalho.
- **Marcadores sobre ator oculto por piso superior (H4).** No mundo, uma marca sobre um inimigo
  atrás de uma ponte pode aparecer **acima** da ponte.
- **Cast de mob no mundo (H4).** Sem captura própria na entrega (o desenho é o mesmo do plano).
  Confira em jogo.
- **Efeitos sem cor de elemento.** A cor do elemento nos efeitos por evento (`draw_vfx`) segue
  fora do escopo, e o Paladino ainda usa a cor `arcane` no feedback de luz.
- **Som.** As lacunas de áudio dos kits do E09 (pulsos do Juramento e do Círculo, cura da Refração
  e o Espectro sem som) continuam.

## O que relatar

Para cada híbrida e para as barras de cast: o que ficou claro ou confuso, o que ficou pequeno ou
apagado, e em que vista (plano ou mundo). Falhas de desenho ou de posição (barra sobre texto,
marca sobre ator errado, zona na cor errada) com o ator e a ação. Uma falha vai para a tarefa
dona pela sessão de arquitetura; este roteiro não corrige código.
