# E00 — Elenco e identidade do primeiro MVP

Contrato candidato v1, 13/09/2026. Incorpora as dez páginas de
`E0_Handoff_Classes_Hibridas_MVP.pdf` recebido do usuário; a
[transcrição com hash](references/e00_hybrid_handoff_2026_09_13.md) preserva o
material completo. Pedidos de executar pilotos dentro do PDF são recomendações
de produção, não autorização para iniciar E04/E05/E08 neste trabalho documental.

## Elenco fechado do demo: 15 identidades

| Origem / ID | Pura 2-1 / ID | Pura 2-2 / ID | Híbridas 2-3 dessa origem |
|---|---|---|---|
| Espadachim / `swordsman` | Defendente / `defender` | Berserker / `berserker` | Cavaleiro Rúnico `sp_mg`; Baluarte de Cerco `sp_ar` |
| Mago / `mage` | Elementalista / `elementalist` | Espiritualista / `spiritualist` | Devastador Astral `mg_sp`; Geômetra `mg_ar` |
| Arqueiro / `archer` | Sentinela / `sentinel` | Caçador / `hunter` | Saqueador `ar_sp`; Caçador de Espectros `ar_mg` |

Geômetra substitui **Arqueiro Arcano** no nome de `mg_ar`; direção Mago → Arqueiro
e receita Elementalista + Sentinela permanecem. Não incluir Emboscador, Tecelão
Astral, Acólito, Bruxo, Druida, Ladino ou Monge neste demo. As 80 identidades são
alvo posterior, não requisito adicional do primeiro MVP. Naturalista continua
nome de trabalho fora deste recorte. Nenhum asset de “warrior” cria outra classe.

Bases devem antecipar suas puras. Permanecem os pedidos de Mago: Bola de Fogo,
Parede de Fogo, Lanças de Fogo/Gelo, Teleporte, Parede de Gelo sólida, Assombro,
Barreira Fantasma, introdução a raio e canalização, até 10 ativas na biblioteca.
Gelo sólido exige revisão de geometria/navegação em E04; não é física nova já aceita.
Arqueiro inclui arco/tiros, armadilhas e ocultação. Espadachim inclui defesa,
pressão melee e mobilidade. As seis puras devem distinguir posição/risco,
elementos/espíritos e tiro/preparação, conforme o roster registrado.

## Regras incorporadas e prioridade em caso de conflito

Uma híbrida precisa de uma interação produzida pela combinação, cinco respostas
(distância, recurso, abrir/fechar sequência, boss, fraqueza) e pelo menos um momento
de leitura, salvamento ou combo. Funciona sem augment. Reprovar “base A + duas
skills de B” e designs que só mudam nome/cor. As prioridades de stats do PDF são
referências de build; os pesos reais por skill precisam seguir E00.2.

Famílias: Elementalista mantém Fogo/Gelo/Raio; Caçador depende de traps/rotas;
Assassino mantém stealth, entrada, facing/backstab e execução/saída; Bruxo mantém
DoT + summon, com causalidade diferente para Demonólogo e Necromante. As duas
últimas famílias são diretrizes de E10/E11, sem ampliar o demo.

Quando houver metade melee, payoff dominante é melee. Origem continua definindo
vetor de atributos, herança e identidade persistente, mas pode mudar alcance/arma
do auto via uma intrínseca explícita. Isso resolve Devastador/Saqueador, que não
devem manter auto ranged obrigatório por herança. Baluarte conserva represália
longa como preparação/resposta; não vira arqueiro imóvel de DPS principal ranged.

Regra visual geral: origem orienta objeto/material e afinidade o fenômeno. O PDF
abre exceções fortes para Devastador (silhueta berserker possuída) e Geômetra
(linha + energia); preservar essas exceções conscientemente. Legibilidade depende
de silhueta, material e movimento além de cor. Não gerar arte nesta etapa.

| Família pura | Cor / material / forma / VFX |
|---|---|
| Defendente | Prata/ouro/marrom/cinza; aço/couro/pedra; placas e massa; impacto seco/onda curta |
| Berserker | Vermelho/marrom/preto; ferro/ferida; diagonais/rasgos; pulsação e trails agressivos |
| Sentinela | Verde/azul claro/branco/marrom claro; madeira/tecido; linhas/mira; trajetória fina |
| Caçador | Musgo/marrons; madeira bruta/corda/osso; nós/ganchos/mecanismos; poeira/acionamento |
| Elementalista | Azul/branco/vermelho/amarelo; cristal/energia; prismas/radiais; arco/cristal/expansão |
| Espiritualista | Pálido/preto/cinza/prata; névoa/tecido/ectoplasma; véus/crescentes; atraso/dissipação |

## Progressão e input compartilhados

Preservar 5 ativas e 2 passivas equipadas do ADR. As tabelas do PDF descrevem cinco
ativas e duas passivas por híbrida, dentro do orçamento. Ajuste técnico explícito:
primeira ativa exclusiva libera gratuitamente em **job 20 ao evoluir**, em lugar
do job 21 do PDF, para não existir um nível de identidade sem seu loop. Demais
desbloqueios: passiva 23, ativa 25, ativa 28, passiva 31, ativa 34, ativa 37. Ranks 1–5
de ativas e 1–3 de passivas custam 1 por incremento; rank 1 gratuito não reembolsa.
Para este candidato, ranks superiores exigem só o job de entrada da skill e o
rank anterior; não impor job 37 extra para concluir rank 5 de Triangulação em job 28.

Cada identidade deve oferecer duas distribuições válidas sob os 19 pontos base e
20 de evolução; E05 comprova com loadouts concretos. Não exigir comprar todas as
skills/ranks. O desbloqueio não equipa automaticamente nem compra rank 1 pago.

Runas e vértices usam gramática intrínseca, sem consumir três slots apenas para
selecionar Fogo/Gelo/Raio. Comandos abstratos `element_fire`, `element_ice`,
`element_lightning`, `grammar_clear`; padrão sugerido 1/2/3 e Backspace,
remapeáveis em E02. Selecionam tokens, não lançam skill/auto nem consomem SP.
Execução/colocação usa uma das cinco ativas equipada, com targeting e regras de
cast existentes. Interface mostra sequência, fórmula resultante e custo antes
de confirmar. Input sobre UI, pausa, foco perdido e cancelamento não lança ação;
cancelar a mira descarta somente edição pendente, conserva a fórmula já confirmada.

Máximo 3 tokens. Sistemas de comando não permitem lançar skills não aprendidas ou
fora da barra. A intrínseca expõe estado/gramática e eventual conversão declarada
do auto; poder, cooldown e gatilhos entram no mesmo orçamento de habilidades.

## Seis contratos de identidade

| ID / receita | Distância, recurso e sequência | Boss e fraqueza | Assinatura visual |
|---|---|---|---|
| `sp_mg` Defendente + Elementalista | Melee; Carga Rúnica; escrever → guardar → converter bloqueio → Contra-runa | Guarda telegráfica alimenta carga sem adds; punido por flanco, erro de fórmula e janela sem guarda | Placa com inscrições; metal aquecido, bordas de gelo, circuitos de raio |
| `mg_sp` Espiritualista + Berserker | Melee; Tensão Astral + memória curta de golpes; possuir → gravar → ruptura → sair | Registra ataques contra o próprio boss; excesso de tensão expõe a recuperação, sem exigir matar | Ferida dessaturada por vestígio; arma antes dos ecos, atraso 150 ms como alvo visual |
| `sp_ar` Defendente + Sentinela | Melee/linha; Pressão de Cerco; ancorar → interceptar → realocar → devolver | Ler investida/projétil preserva pressão ao mudar âncora; flanco/área força desmontagem | Placa apontando corredor, pavês e visor estreito |
| `ar_sp` Caçador + Berserker | Melee/rede; Ímpeto; trap → bleed provoca → reivindicar → usar a própria trap → turbilhão | Autoativação e travessia geram ímpeto sem kill; boss não é arrastado; rede mal montada expõe o jogador | Mecanismo brutal, corda/mandíbula/ferrugem; vermelho cresce com ímpeto |
| `mg_ar` Elementalista + Sentinela | Ranged; sequência 3, vértices e uma figura; desenhar → explorar → editar/colapsar | Geometria sobre terreno funciona sem adds; pressão próxima, deslocamento e edição custam oportunidades | Linha/energia, campo como diagrama, forma distinta para cada elemento |
| `ar_mg` Caçador + Espiritualista | Ranged; traps/rastros; marcar → criar trilha → tiro atravessa → projétil espectral → novos corredores | Disparo de Vestígio inicia rastro no boss sem cadáver; mudanças de rota exigem remontar campo | Mecanismo + vestígio; flecha perde matéria no pó, três traps com silhuetas distintas |

Assinatura candidata adicional do Devastador: a Maldição do Eco registra até 3
emissões melee distintas durante 4 s; Ruptura repete a sequência em ordem como
ecos, e não só um multiplicador abstrato. Usar snapshot do dano bruto de cada
emissão, fração 0.3, sem copiar crit, cura, controle ou procs. Tensão multiplica
essa fração por `1 + tension/100` (máximo 0.6). Repete em cone relativo à direção
da ruptura, cada eco uma vez/alvo, mitigação atual. Gravações expiram/consomem;
não registram ecos. Nome Devastador Astral permanece candidato, sem renomeação
arbitrária. Mecânica/telemetria serão testadas em E05.

Momento candidato do Baluarte: interceptar ataque frontal na janela de guarda
perfeita (0.2 s desde início de guarda) permite que Avanço de Muralha reposicione
a âncora até 180 unidades nos próximos 2 s, conservando pressão uma vez. Não
renova guarda, não zera recargas e respeita geometria; acerto de leitura vira
salvamento/realocação, além de dano acumulado.

## Biblioteca exclusiva incorporada

Cada linha lista ativa 20 / passiva 23 / ativa 25 / ativa 28 / passiva 31 / ativa 34 /
ativa 37. Detalhes funcionais e augments originais permanecem na transcrição.

| Identidade | Habilidades na ordem de desbloqueio |
|---|---|
| Cavaleiro Rúnico | Guarda Prismática / Aço Condutor / Contra-runa / Inscrição de Campo / Sintaxe Bélica / Reescrita / Apoteose Rúnica |
| Devastador Astral | Possessão Furiosa / Vaso Fraturado / Corte de Ecos / Passo Possesso / Canal Aberto / Maldição do Eco / Ruptura da Alma |
| Baluarte de Cerco | Postura de Cerco / Disciplina de Cerco / Disparo de Represália / Pavês / Olho do Baluarte / Avanço de Muralha / Rompimento de Cerco |
| Saqueador | Laço de Arrasto / Cheiro de Sangue / Reivindicar Presa / Mandíbula Serrilhada / Abate Sangrento / Fio de Tropeço / Turbilhão de Saque |
| Geômetra | Traçado Elemental / Teorema de Incidência / Translação / Triangulação / Memória Vetorial / Colapso Geométrico / Reescrita |
| Caçador de Espectros | Armadilha Espectral / Olho do Além / Disparo de Vestígio / Armadilha de Banimento / Pó Persistente / Armadilha Assombrosa / Procissão Espectral |

Augments propostos entram como backlog E06: Palimpsesto/Aço Ressonante/Sintaxe
Invertida/Sobrecarga Prismática; Coro de Guerra/Possessão Profunda/Reverberação/Vaso
Transbordante; Pavês Geminado/Resposta Instintiva/Corredor de Morte/Último Reduto;
Dentes Duplos/Arrastão/Sangue Fresco/Sem Escapatória; Parede Residual/Vértice
Ambulante/Prisma Balístico/Prova por Contradição; Ectoplasma Denso/Banimento
Fraturado/Assombração Residual/Eco Mortuário. São variedade planejada, não 24
efeitos já aprovados numericamente ou pré-requisito para um kit funcionar.

## Gramáticas sem contagem ambígua

Tokens internos `fire`, `ice`, `lightning`; F/G/R na explicação pt-BR.

**Cavaleiro Rúnico:** resolver a ambiguidade “não-repetida” como `c != b` na
sequência ordenada `(a,b,c)`. a e b aceitam qualquer elemento, inclusive iguais;
c aceita os outros dois. Assim 9×2=18 fórmulas, incluindo 12 com repetição e 6
tricolores; não há FFF/GGG/RRR. Esta é decisão técnica proposta, não frase
literal do PDF. `c != a e c != b` produziria 12, incompatível com o alvo 18.

Semântica composicional: a é matéria da guarda (F retorno ofensivo, G sustentação,
R conversão rápida); b define forma da resposta (F cone curto, G linha curta,
R arco encadeado limitado); c define consequência (F queimadura, G slow,
R pulso de interrupção). Nome/tooltip compõe as três funções. Não trocar a ordem
como mero cosmético. `Sintaxe Bélica` distingue repetição/especialização de
tricolor/utilidade, sem multiplicar três bônus de dano. Todas 18 ficam no escopo
do kit final; valores por rank e telegráficos entram no gate E05.

**Geômetra:** parede usa dois elementos diferentes, ordenados, 3×2=6. O primeiro
define interação na entrada (F dano ao cruzar, G lentidão ao cruzar, R condução de
projétil); o segundo define saída (F detonação localizada, G barreira de projétil,
R desvio dirigido). Não é parede física para navegação do ator no demo.

Triângulos têm três slots semânticos ordenados, com repetição: fundação/terreno
(F brasas, G geada, R condutor) → regra interna (F pulsos, G slow, R condução) →
resolução (F explosão, G contenção, R descarga). 3³=27: 3 puros +18 com dois iguais
+6 tricolores. R1 libera 3 puros; R3 adiciona 18 (total 21); R5 adiciona 6 (total 27).
R2/R4 melhoram valores do catálogo, não adicionam receitas ocultas. Parede 6 +
triângulo 27 =33 resultados; sem quarto vértice/quadrados. Cada combinação deve
mostrar prévia coerente, mesmo quando duas funções compartilham um elemento.

Uma figura ativa por Geômetra e até 3 vértices confirmados. Nova figura substitui
a anterior, sem disparar seu Colapso. Vértices persistem 8 s, figura até 6 s (rank pode
melhorar, teto 12 s). No demo fixam coordenada do chão na colocação; selecionar um
ator usa seus pés naquele instante, não acompanha movimento. `Vértice Ambulante`
permanece proposta posterior, não exceção já autorizada. Aresta<=600 unidades,
distância entre vértices>=24, área de triângulo>=256 unidades²; rejeitar linha
degenerada/fora do mapa/atravessando obstáculo antes de custo. Translação/Reescrita
revalidam a figura inteira; falha conserva a anterior, sem consumo.

## Limites runtime e conflitos resolvidos

Carga Rúnica, Tensão Astral, Pressão de Cerco e Ímpeto usam escala 0–100, começam
em 0 e não persistem. Proposta de baseline por evento raiz: guarda válida +10
Carga/Pressão (perfect guard +20 em vez de +10); golpe melee direto +5 Tensão;
trap ativada +15 Ímpeto. Máximo 20 por raiz, sem ganho por eco/DoT. Fora de encontro
decaem 10/s. Gastos de payoff drenam o valor capturado uma vez; afinidades não
usam SP excedente/HP como geração infinita sem limite de evento. Bônus de recursos
e gastos por rank precisam do mesmo teto, mesmo com augment.

| Sistema | Limite e regra candidata |
|---|---|
| Guarda | Reduz 50% do dano frontal na janela da skill; perfect guard reduz 100% e gera carga apenas se havia dano mitigado positivo. Janela perfeita 0.2 s, pode premiar uma raiz só; não dispara procs de dano recebido |
| Pavês | 1 por jogador (augment pode elevar a 2); vida útil 8 s; HP=25% do max_hp capturado; só intercepta projétil; reposicionamento não restaura HP/duração |
| Traps | Até 3 por dono, incluindo tipos diferentes; colocar além do teto substitui a mais antiga sem detonar/recompensar |
| Saqueador autoativando | Mandíbula custa 5% max_hp capturado, nunca pode reduzir HP abaixo 1; exige HP estritamente maior que custo; custo não dispara efeitos de dano recebido nem gera Tensão |
| Bleed provocador | Alvo normal marcado recebe +15% movimento durante bleed, sem stacks; boss imune ao aumento; bleed físico usa DEF, ticks secundários |
| Reivindicar | Unstoppable por no máximo 0.6 s durante dash; trap/raiz só reivindicável uma vez; não dá invulnerabilidade nem atravessa parede |
| Rearme por kill | Uma trap no máximo por raiz de eliminação; recarga interna 2 s por dono, rearme nunca abaixo 1 s; redução de cooldown máximo 1 s por raiz, nunca abaixo restante 1 s |
| Rastro espectral | Até 12 segmentos/dono; largura 24 unidades, máximo 120 unidades por segmento, duração 8 s/teto 12 com ranks; substituir mais antigo sem proc; marcar movimento no máximo a cada 0.5 s |
| Armadilha Espectral | Perene durante a run até substituição; rearme base 5 s, mínimo 1 s; marca dura 4 s e produz trilha contra boss; sem inimigo na área não gera eventos |
| Flecha no pó | Transforma uma vez; remove alcance máximo físico restante, mas mantém TTL global 3 s desde emissão e fronteira do encontro; sem alcance mínimo, sem perseguir; bloqueada por geometria |
| Perfuração espectral | Até 4 alvos distintos por emissão, um impacto por alvo; DoT não cria tiros; chance de marca 25% por impacto, RNG explícito; marca dura 4 s |
| Morte marcada | Cria um segmento de rastro uma vez; não causa dano ou marca vizinhos automaticamente; boss não depende desse gatilho |
| DoTs | Mesmo dono/skill/alvo: renovar maior duração restante, sem somar DPS/stacks; sources diferentes podem coexistir até 4 DoTs totais/alvo, substituir o mais antigo sem tick extra |
| Debuff Assombroso | -20% DEF/DEFM por 3 s, não acumula com si mesmo; fear quebra por dano, banimento/CC de boss seguem E00.2 |

“Sem distância mínima” estava ambíguo no PDF: a escolha acima é remover a
distância máxima específica do tiro físico após transformação, conservando TTL e
limite da arena. Não criar projétil de duração/distância infinitas. Procs de marca
e rastro são eventos de terreno orçados, não autorização de dano secundário recursivo.
Tiros espectrais não voltam a transformar/ganhar chances ao cruzar vários rastros.

## Gates de conteúdo, sem esconder trabalho pendente

E00 fecha elenco, matemática, propriedade, gramáticas e limites de sistema. E05
ainda deve preencher custos/tempos/poder por rank, duas builds legais por identidade
e provar em 20–30 s de gameplay que decisão/momento de glória são reconhecíveis.
Isso é aceite do kit implementado, não teste possível para um épico documental.
Geômetra exige todas 6 paredes/27 triângulos no kit final; amostra inicial serve
só ao piloto. Cavaleiro precisa das 18 fórmulas finais e UI legível.

Ordem sugerida do PDF é registrada: fundação DES/intrínsecas; piloto Rúnico;
Saqueador; Espectros; Baluarte/Devastador; Geômetra começando por paredes. A execução
continua nos pares/subépicos de E05, definidos pelo coordenador quando liberados;
reordenar pilotos não autoriza seis implementações simultâneas ou novas tarefas.
E08 valida material/silhueta/VFX e performance real. Nenhum desses gates foi
marcado como aprovado por haver uma descrição ou fixture numérica.
