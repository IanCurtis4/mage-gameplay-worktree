# 56 híbridas direcionais — exploração v2

Atualização E00: [E00_MVP_CLASS_CONTRACT.md](E00_MVP_CLASS_CONTRACT.md) incorpora
o handoff recebido e prevalece para as seis híbridas do primeiro MVP. `mg_ar`
passa a se chamar **Geômetra**; a matriz ampla permanece exploração para E11.

13/09/2026. Pedido do usuário: explorar inversão da classe de origem e das partes
herdadas. Documento de design; nenhuma destas classes foi implementada. Substitui
a simetria da proposta de 28 híbridas em CLASS_ROSTER_BRAINSTORM.md.

## Regra de identidade e progressão

O personagem tem classe base persistente, nível de personagem e nível de job.
Ao evoluir, escolhe 2-1, 2-2 ou uma 2-3 disponível para sua origem. A segunda base
é uma afinidade incorporada pela evolução, não exige subir um segundo personagem.
Requisitos numéricos, reversibilidade e respec ainda serão aprovados em E00/E03.

Há 8 × 7 = 56 pares ordenados. Somando oito bases e 16 evoluções puras, são
**80 identidades**. Cada base tem duas evoluções puras e sete híbridas possíveis.
Não há combinações com a própria classe, nem um terceiro eixo de fusões.

Cada par não ordenado abaixo possui duas receitas complementares. Nesta primeira
exploração, a direção da primeira coluna usa os ramos 2-1 das duas bases; a inversa
usa os ramos 2-2. Isso garante que ambos os lados apareçam e facilita comparar os
kits. É uma convenção inicial de catálogo, não uma regra matemática que impeça
receitas cruzadas melhores: trocar uma receita exige inverter também a sua par.
Não criar automaticamente quatro ou oito variantes por par.

A classe à esquerda da seta define origem, postura de combate e acesso à árvore.
Cada híbrida ganha um recurso/interação própria. Ela não recebe duas árvores
completas, duas passivas integrais ou soma irrestrita de multiplicadores.

## Matriz completa

SP Espadachim; MG Mago; AR Arqueiro; AC Acólito; BR Bruxo; DR Druida; LA Ladino;
MO Monge. IDs são estáveis, nomes são propostas. Duas skills assinatura por
identidade abaixo são sementes de design, ainda sem números ou kit completo.

| ID e direção | Receita / nome / assinatura | ID e direção inversa | Receita / nome / assinatura |
|---|---|---|---|
| sp_mg · Espadachim → Mago | Defendente + Elementalista: **Cavaleiro Rúnico**. Guarda prismática armazena elemento; Contra-runa o devolve em arco. | mg_sp · Mago → Espadachim | Espiritualista + Berserker: **Devastador Astral**. Possessão furiosa intensifica canalização; Ruptura da alma converte tensão em cleave espectral. |
| sp_ar · Espadachim → Arqueiro | Defendente + Sentinela: **Baluarte de Cerco**. Postura de vigia protege a linha de tiro; Disparo de represália rompe quem avança. | ar_sp · Arqueiro → Espadachim | Caçador + Berserker: **Saqueador**. Laço de arrasto reúne vítimas; Rajada predatória ganha ímpeto ao atravessar a armadilha. |
| sp_ac · Espadachim → Acólito | Defendente + Sacerdote: **Paladino**. Juramento ancora proteção; Impacto consagrado converte bloqueio em luz. | ac_sp · Acólito → Espadachim | Cultista + Berserker: **Flagelante**. Êxtase profano acumula fervor por exposição; Liturgia dilacerante descarrega dano e perturbação. |
| sp_br · Espadachim → Bruxo | Defendente + Demonólogo: **Guardião do Pacto**. Escudo contratado divide pressão com demônio; Cobrança infernal usa dano mitigado. | br_sp · Bruxo → Espadachim | Necromante + Berserker: **Cavaleiro da Carnificina**. Armadura de ossos consome servos; Ceifa vermelha reanima vítimas elegíveis. |
| sp_dr · Espadachim → Druida | Defendente + Naturalista: **Guardião de Gaia**. Baluarte vivo enraíza a guarda; Onda mineral abre caminho sem abandonar proteção. | dr_sp · Druida → Espadachim | Metamorfo + Berserker: **Fera de Guerra**. Forma devastadora transforma fúria em ataques naturais; Pisoteio rasga o grupo. |
| sp_la · Espadachim → Ladino | Defendente + Assassino: **Duelista**. Finta de guarda expõe uma vítima; Riposta fatal usa a abertura criada pelo aparo. | la_sp · Ladino → Espadachim | Dervixe + Berserker: **Corsário**. Abordagem puxa para a luta; Turbilhão de saque transforma prontidão em cleave. |
| sp_mo · Espadachim → Monge | Defendente + Elevado: **Guardião Cinético**. Guarda vetorial absorve impulso; Repulsão dirigida devolve energia em cone. | mo_sp · Monge → Espadachim | Campeão + Berserker: **Quebra-Montanhas**. Punhos em fúria sustentam combo; Ruptura sísmica termina a sequência com impacto. |
| mg_ar · Mago → Arqueiro | Elementalista + Sentinela: **Geômetra**. Vértices elementais formam seis paredes direcionadas e 27 triângulos; ver contrato E00. | ar_mg · Arqueiro → Mago | Caçador + Espiritualista: **Caçador de Espectros**. Traps criam pó de alma; tiros que cruzam o rastro se tornam espectrais; ver contrato E00. |
| mg_ac · Mago → Acólito | Elementalista + Sacerdote: **Taumaturgo**. Prisma votivo refrata elemento em proteção; Aurora convergente une luz e área elemental. | ac_mg · Acólito → Mago | Cultista + Espiritualista: **Oráculo do Abismo**. Sussurro coletivo liga mentes; Liturgia do vazio canaliza dano sobre a rede. |
| mg_br · Mago → Bruxo | Elementalista + Demonólogo: **Invocador do Cataclismo**. Familiar catalisador carrega um elemento; Conjunção infernal detona a preparação. | br_mg · Bruxo → Mago | Necromante + Espiritualista: **Lich**. Filactério menor sustenta canalização; Procissão fúnebre converte servos em ondas espirituais. |
| mg_dr · Mago → Druida | Elementalista + Naturalista: **Tempestário**. Raízes condutoras distribuem raio; Monção altera terreno e interações de fogo/gelo. | dr_mg · Druida → Mago | Metamorfo + Espiritualista: **Metamorfo Espectral**. Forma ancestral atravessa brevemente a matéria; Uivo das almas aplica fraqueza. |
| mg_la · Mago → Ladino | Elementalista + Assassino: **Lâmina Prismática**. Marca refratada prepara dano de um elemento; Passo fulgurante abre uma execução precisa. | la_mg · Ladino → Mago | Dervixe + Espiritualista: **Dançarino de Miragens**. Órbita fantasma deixa ecos; Corte da lembrança faz os ecos repetirem uma fração limitada do golpe. |
| mg_mo · Mago → Monge | Elementalista + Elevado: **Tecelão Astral**. Esferas orbitais carregam elementos; Compressão astral curva trajetórias e concentra impacto. | mo_mg · Monge → Mago | Campeão + Espiritualista: **Punho dos Ecos**. Combo ressonante marca ritmo; Palma das almas repete o final da sequência com dano espiritual limitado. |
| ar_ac · Arqueiro → Acólito | Sentinela + Sacerdote: **Inquisidor**. Flecha de julgamento expõe o alvo; Linha de absolvição protege quem fica atrás do disparo. | ac_ar · Acólito → Arqueiro | Cultista + Caçador: **Vigia do Abismo**. Ídolo oculto cria zona de loucura; Armadilha do olhar dispara quando o inimigo adquire alvo. |
| ar_br · Arqueiro → Bruxo | Sentinela + Demonólogo: **Atirador do Pacto**. Munição contratada troca recurso por perfuração; Olho infernal projeta linha de tiro do familiar. | br_ar · Bruxo → Arqueiro | Necromante + Caçador: **Caçador de Sepulturas**. Cova preparada detém e contamina; Laço ossuário consome cadáver para erguer sentinela temporária. |
| ar_dr · Arqueiro → Druida | Sentinela + Naturalista: **Atirador Silvano**. Arco de seiva cria cobertura viva; Flecha-raiz fixa corredor de disparo. | dr_ar · Druida → Arqueiro | Metamorfo + Caçador: **Predador da Mata**. Rastro de caça prepara terreno; Bote camuflado explora a armadilha em forma animal. |
| ar_la · Arqueiro → Ladino | Sentinela + Assassino: **Emboscador**. Disparo velado recompensa abertura furtiva; Marca de execução favorece precisão na vítima escolhida. | la_ar · Ladino → Arqueiro | Dervixe + Caçador: **Acrobata de Guerrilha**. Gancho de emboscada usa âncoras próprias; Órbita de armadilhas espalha mecanismos ao redor da trajetória. |
| ar_mo · Arqueiro → Monge | Sentinela + Elevado: **Arqueiro Zen**. Flecha telecinética ajusta trajetória limitada; Respiração imóvel acumula foco para tiro atravessante. | mo_ar · Monge → Arqueiro | Campeão + Caçador: **Peregrino das Armadilhas**. Selo de pouso arma o local do salto; Golpe de retorno lança o inimigo para uma zona preparada. |
| ac_br · Acólito → Bruxo | Sacerdote + Demonólogo: **Exorcista dos Pactos**. Selo de contenção subjuga um servo; Expiação contratual converte serviço demoníaco em proteção. | br_ac · Bruxo → Acólito | Necromante + Cultista: **Profeta da Peste**. Evangelho pútrido espalha aflição; Ídolo cadavérico converte mortos em influência e loucura. |
| ac_dr · Acólito → Druida | Sacerdote + Naturalista: **Hierofante**. Jardim sagrado sustenta um santuário; Renovação de pedra combina cura e resistência. | dr_ac · Druida → Acólito | Metamorfo + Cultista: **Fera do Eclipse**. Forma impossível adapta membros; Rugido delirante rompe a aquisição de alvos comuns. |
| ac_la · Acólito → Ladino | Sacerdote + Assassino: **Executor Velado**. Sentença luminosa identifica o alvo; Véu penitente oferece entrada curta para golpe consagrado. | la_ac · Ladino → Acólito | Dervixe + Cultista: **Dervixe do Vazio**. Dança delirante redistribui atenção; Giro do ídolo espalha maldição pela órbita. |
| ac_mo · Acólito → Monge | Sacerdote + Elevado: **Asceta Celestial**. Mantra suspenso sustenta campo protetor; Palma de luz comprime energia à distância. | mo_ac · Monge → Acólito | Campeão + Cultista: **Punho do Abismo**. Combo sacrílego acumula tensão mental; Impacto impossível descarrega sombra e desorientação. |
| br_dr · Bruxo → Druida | Demonólogo + Naturalista: **Jardineiro Infernal**. Semente contratada enraíza um demônio; Enxerto de brasa transforma planta em foco ofensivo. | dr_br · Druida → Bruxo | Metamorfo + Necromante: **Quimera Mortuária**. Forma de ossos incorpora essência limitada; Enxame necrótico desprende parte da carcaça como servos temporários. |
| br_la · Bruxo → Ladino | Demonólogo + Assassino: **Lâmina do Contrato**. Marca de cobrança associa familiar e vítima; Passo da dívida atravessa a linha de um alvo marcado. | la_br · Ladino → Bruxo | Dervixe + Necromante: **Ceifador Dançante**. Foice orbital colhe essência; Dança dos ossos faz servos acompanharem a trajetória. |
| br_mo · Bruxo → Monge | Demonólogo + Elevado: **Domador de Espíritos**. Grilhão mental ordena o servo em uma direção; Transbordamento psíquico converte energia do pacto em campo. | mo_br · Monge → Bruxo | Campeão + Necromante: **Punho Ossuário**. Sequência fúnebre acumula fragmentos; Colosso de ossos reveste o final do combo. |
| dr_la · Druida → Ladino | Naturalista + Assassino: **Herborista Sombrio**. Toxina de raiz é preparada no terreno; Estaca oculta explora uma vítima envenenada. | la_dr · Ladino → Druida | Dervixe + Metamorfo: **Dançarino Feral**. Giro das formas alterna garras e alcance; Bote pendular encadeia gancho e transformação. |
| dr_mo · Druida → Monge | Naturalista + Elevado: **Geomante**. Pedra suspensa orbita e protege; Pressão telúrica converge terreno sob o alvo. | mo_dr · Monge → Druida | Campeão + Metamorfo: **Mestre das Feras**. Posturas animais alteram o combo; Sequência quimérica alterna membros naturais em golpes definidos. |
| la_mo · Ladino → Monge | Assassino + Elevado: **Lâmina Psíquica**. Fio mental cria abertura à distância; Passo telecinético reposiciona para um golpe preciso. | mo_la · Monge → Ladino | Campeão + Dervixe: **Dançarino Marcial**. Roda de palmas mantém combo radial; Gancho de retorno permite trocar a órbita sem perder ritmo. |

## Recorte do primeiro demo

Três bases, seis puras e estas seis híbridas: Cavaleiro Rúnico, Devastador Astral,
Baluarte de Cerco, Saqueador, Geômetra, Caçador de Espectros.
O catálogo é direcional desde o começo, evitando migração de IDs quando outras
bases chegarem. Os nomes Emboscador e Tecelão Astral continuam no plano, mas
dependem de Ladino/Monge; não fazem parte do primeiro demo de três bases.

## Como avaliar se a inversão vale a produção

Cada par precisa responder: qual é a distância preferida, qual recurso administra,
como abre/fecha uma sequência, que decisão muda contra chefe e que fraqueza mantém?
Se as respostas coincidirem e só mudar cor/nome, reprovar tecnicamente o design
antes de gastar sprites, VFX e código. Um kit deve sobreviver ao teste sem augments;
augments criam variações, não consertam uma identidade incompleta.

Evitar duas classes competindo pelo mesmo verbo: Tecelão Astral conduz feitiços;
Guardião Cinético absorve/devolve impulso; Geomante desloca terreno. Lich organiza
canalização/servos; Profeta da Peste propaga influência; Quimera Mortuária transforma
o próprio corpo. Risco de redundância maior nestes grupos: revisar antes de E11.

56 híbridas dobram kits, ícones, progressão, interações e QA em relação a 28. Não
estimamos tokens ou prazos sem medir os seis pilotos. Produzir em lotes pequenos,
com aceite do usuário por subépico; não liberar 50 kits num único playtest.
