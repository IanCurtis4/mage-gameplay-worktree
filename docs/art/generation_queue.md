# Fila de geração de arte

Escrita em 16/11/2026 (E09, tarefa T2, contrato C5). Guia das ferramentas:
[pipeline.md](pipeline.md).

**Regra da fila (decisão D4 do E09).** Geração de imagem fica **fora do caminho crítico**: nenhuma
tarefa do E09 espera por ela. Ícones e efeitos das skills novas saem por código; a arte pintada que
chegar substitui pelo mesmo ID, sem mudar consumidor. A fila só diz o que falta, o formato, onde
cai e quem consome. Entrar na fila não inicia marco nem autoriza gasto.

Manutenção: a T2 escreve este documento; a T10 atualiza o estado ao integrar o épico. Cada entrega
nova de arte registra a proveniência (v2) e atualiza a linha daqui.

## Geradores hoje (16/11/2026)

| Via | Estado | Limite |
|---|---|---|
| Codex imagegen (as folhas 1114–1123) | indisponível: o usuário não pode pagar | volta só se houver orçamento |
| ComfyUI local (`D:\ComfyUI`, Qwen-Image-Edit-2511 Q4 + Lightning, GTX 1080 de 8 GB) | funciona, mas de **20 a 37 min por folha** e trava sem memória de vídeo | só edição de folha; geração do zero é pouco provada |
| Hugging Face (páginas grátis) | recusaram ou falharam nos testes | cota de GPU gratuita |
| fal.ai (`fal-ai/qwen-image-edit-2511`) | pago por megapixel (cerca de US$ 0,03/MP); **pede cartão internacional** | `faledit.py --dry` mostra o custo antes |
| Gemini / Nano Banana (grátis) | o teste de 1124 **não trocou a pessoa nem o cabelo** | fundo chapado; recorte por `remove_background.py` |
| Desenho à mão | sempre possível | trabalho do usuário |

Orçamento do usuário: cerca de **R$ 15**, só Pix ou débito nacional. Enquanto nenhuma via for
viável, a fila espera, e o jogo segue com o que já está pronto.

## Visão geral

| # | Item | Peças | Prioridade | Bloqueia algo? | Estado |
|---|---|---|---|---|---|
| Q1 | 1124: Tempestário e Magister | 7 folhas | média | não (as classes ficam como estão) | **pendente** desde 16/11 (gerador inviável) |
| Q2 | Conjuntos de classe das quatro híbridas (elmo e ícones) | 4 conjuntos | média | não (D6: fora do E09) | pendente |
| Q3 | Ícones pintados das 28 skills | 28 ícones | alta entre as pinturas | não (o SVG por código vale) | pendente |
| Q4 | Efeitos pintados reservados pelos kits | por kit | média | não (efeito em código vale) | pendente; IDs saem dos kits K1–K4 |
| Q5 | Trajes das híbridas restantes | 28 híbridas × 4 vistas | baixa | não (fora do E09) | pendente |
| Q6 | Variantes de criatura | ver abaixo | baixa | não | pendente |

A ordem da tabela é sugestão de valor por custo: Q3 e Q4 melhoram o que o jogador vê nas quatro
classes do épico; Q1 corrige duas classes que já têm arte; Q2 completa as quatro classes; Q5 e Q6
ampliam o elenco.

## Q1 — 1124: Tempestário (`mg_dr`) e Magister (`mg_mo`)

- **O que falta:** corrigir a **pessoa do Mago** nas duas classes. Tempestário: leste, oeste e
  norte, a partir da `south_v4` de 1123 (que fica). Magister: as quatro vistas, com o cabelo da
  pessoa e um gesto 4 novo.
- **Formato:** `character_view`, 4×4, RGBA ou fundo chapado (Tempestário magenta `#FF00FF`;
  Magister verde `#00FF00`).
- **Pedido e referências:** [e08_codex_art_1124_brief.md](../epics/e08_codex_art_1124_brief.md) e
  [e08_nanobanana_1124_brief.md](../epics/e08_nanobanana_1124_brief.md). As referências sobre fundo
  chapado já estão em `…/assets/art/e08_nb_1124/refs/` (staging, fora do Git).
- **Tentativas até aqui:** Nano Banana (não trocou a pessoa), ComfyUI Q4 (20–37 min, travou), Hugging
  Face (falhou). Os trabalhos do ComfyUI estão em `D:\ComfyUI\ragrpg\jobs\` e as saídas em
  `…\out\1124*`; registre-as com `record_generation.py --from-comfy-log` para que a proveniência
  exista mesmo das tentativas descartadas.
- **Destino:** `assets/art/e08_codex_1124/characters/{mg_dr,mg_mo}/` (nome mantido pelo briefing,
  mesmo sem o Codex).
- **Pronto quando:** `validate_sheet.py --set` sem erro e com escala dentro de ±10%; o usuário
  aprova no tamanho de jogo e marca `selected`; `selection.json` por classe.
- **Quem consome:** o empacotador dos atlas V2 das duas classes (tarefa futura, fora do E09).

## Q2 — conjuntos de classe das quatro híbridas

- **O que falta:** para Paladino, Taumaturgo, Duelista e Lâmina Arcana, o conjunto no padrão dos
  conjuntos atuais: **elmo** (cabeça de conjunto) e **ícones pintados** de torso e pés.
- **Formato:** como as folhas de 1114: uma folha por classe com 2 células lado a lado
  (`class_set_<classe>.png`, torso e pés) e o elmo como cabeça
  (`class_set_<classe>_head.png`). Ver o briefing
  [e08_codex_art_1114_brief.md](../epics/e08_codex_art_1114_brief.md).
- **Referências:** a vista sul aprovada da classe (1123) e o conjunto da classe de origem.
- **Destino e consumo:** decisão D6 do E09 (conjuntos fora do épico): o item só entra em
  marco próprio, que define o catálogo de itens e a elegibilidade. A arte pode ser gerada antes,
  porque nada do runtime depende dela.
- **Pronto quando:** as quatro peças × classe validadas (`icon_source` ou `equipment_row`),
  proveniência v2 e escolha do usuário.

## Q3 — ícones pintados das 28 skills

- **O que falta:** um ícone pintado por skill, nos 28 IDs fixos de
  [e09_contract.md](../epics/e09_contract.md#1-identidades-e-ids) (sete skills por classe, prefixos
  `paladin_`, `thaumaturge_`, `duelist_`, `arcane_blade_`).
- **Formato:** `icon_source`, PNG quadrado de lado ≥ 128, RGBA, no estilo dos ícones atuais
  (T3 entrega os 28 SVG de referência; a prancha de revisão serve de modelo de composição).
- **Destino:** `assets/art/skills/painted/<skill_id>.png`. **Substitui o SVG pelo mesmo ID**; nenhum
  consumidor muda.
- **Pronto quando:** `validate_sheet.py --kind icon_source` sem erro para cada ícone; proveniência
  v2; escolha do usuário; conferência no tamanho real da barra de atalhos. Lotes por classe
  (7 ícones) são um tamanho de pedido razoável para qualquer gerador.

## Q4 — efeitos pintados reservados pelos kits

- **O que falta:** os efeitos que cada kit **reservar** com um ID e deixar desenhado por código no
  E09. O briefing 1123 (seção C) já lista os candidatos das quatro classes:
  - Paladino: cone e coluna de luz;
  - Taumaturgo: os três estados do círculo;
  - Duelista: aparo e giro;
  - Lâmina Arcana: lâmina de cristal, refração e reflexos.
- **Formato:** `vfx_source`, grade 4×4 de quadros (do início ao pico), RGBA.
- **Destino:** `assets/art/e08_vfx/<id>/flipbook.json` (mais as folhas). **Substitui o efeito em
  código pelo mesmo ID**; o consumidor não muda.
- **Dependência de informação (não de código):** os IDs e o número de estados saem dos recibos
  `k1`–`k4`. Não gerar antes de o kit publicar o efeito reservado.
- **Pronto quando:** validação sem erro (quadro em branco só aparece como aviso), proveniência
  v2 e escolha do usuário. Efeitos de outras classes do lote 1123 (Silvano, Inabalável,
  Tempestário, Magister) ficam para quando essas classes ganharem kit.

## Q5 — trajes das híbridas restantes

- **O que falta:** as 28 híbridas sem traje depois de 1120–1123, em lotes:
  - origens Arqueiro e Acólito (10);
  - Druida e Ladino (12);
  - Monge (6).
  Conferir a contagem contra [HYBRIDS_56_V3.md](../HYBRIDS_56_V3.md) antes de pedir.
- **Formato:** `character_view` × 4 vistas, no formato de 1118–1123, mãos vazias, sem arma.
- **Referências:** o traje da estendida de origem e a base; modelo de prompt em
  [e08_codex_art_1123_brief.md](../epics/e08_codex_art_1123_brief.md).
- **Pronto quando:** validação do conjunto sem erro e com escala dentro de ±10% (ou normalizada),
  as quatro classes de cada origem lado a lado no tamanho de jogo, aprovação do usuário.
- **Custo:** o maior item da fila; só vale depois que houver um gerador confiável para folhas 4×4.

## Q6 — variantes de criatura e corpos novos

- **Variantes de criatura do Demonólogo** (seção C do briefing 1120): elementais do Invocador (Bruto
  de gelo, Cão de raio, Diabrete de fogo); formas do Encarnado (Bruto, Cão e Diabrete com uma peça
  do Bruxo); Bruto e Cão com as faixas do Campeão (Domador).
- **Corpos novos e camadas** (seção C do briefing 1123): Carniçal de Raiz, Colosso Suspenso e as
  camadas de placa do Cavaleiro de Ossos.
- **Formato:** `creature_view` × 4 vistas (como os de 1117).
- **Pronto quando:** como em Q5.

## Como pedir um item

1. Escolher o item e um gerador viável (tabela do topo).
2. Gerar com o guia de [pipeline.md](pipeline.md): uma tentativa por arquivo versionado, cada uma
   registrada com `record_generation.py` (inclusive as descartadas; custam pouco e explicam depois
   por que uma versão foi escolhida).
3. Validar, normalizar a escala se for o caso, escolher com o usuário e gerar o `selection.json`.
4. Arquivar o lote (`archive.py`) e versionar só a arte escolhida.
5. Atualizar a linha deste documento.
