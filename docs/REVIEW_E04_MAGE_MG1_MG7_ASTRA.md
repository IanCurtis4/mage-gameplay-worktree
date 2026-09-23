# E04 Mago MG1–MG7 — revisão Astra

23/09/2026. **APROVADO tecnicamente para playtest após correção.**
Entrega original 453ddd0 sobre 6059c7d; candidato corrigido cb1eb84.
Escopo: sete habilidades e dependências compartilhadas de controles/projéteis/
navegação. MGI ainda não foi entregue; não encerrar Mago ou E04 por este gate.

## Revisão

Marca/consumo de Eletrizado, rolagem única de stun, limites de controle, fear,
enfraquecimento e snapshots revisados. Parede de Gelo valida colocação,
reconstrói navegação, invalida rotas e remove colisão sincronicamente.
Barreira Fantasma tem cargas limitadas, filtra projéteis inimigos e aplica
debuffs de passagem. Catálogo/menu/ranks/save/run têm cobertura por habilidade.
Sol auxiliou na leitura MG1–MG5 e Terra em MG6; Astra revisou MG7 e composição.

Encontrado e corrigido: ArrowProjectile calculava a fração de entrada usando
projeção limitada ao segmento. Quando o centro do alvo ficava além do endpoint,
o impacto podia ocorrer antes do contato físico e ignorar barreira/obstáculo.
cb1eb84 calcula interseção na linha antes de limitar ao segmento; três checks
novos cobrem contato parcial e rejeição de alvos fora do trajeto.

Observação não bloqueadora: a Parede de Raios não amostra travessias no frame
em que seu timer expira; a precisão nesse último intervalo depende do frame.
Visuais provisórios, balanceamento e desempenho de reconstrução da navegação
com várias paredes continuam sujeitos a playtest.

## Evidência

Entrega original: 53 suítes / 2.467 checks, importação e smoke aprovados.
MG6 corrigido: 77 checks aprovados. Candidato corrigido: 53 suítes / 2.470 checks
e smoke passaram tanto na worktree quanto no diretório habitual, saída 0.
Importação na worktree limpa também passou.
Importação headless no diretório habitual encontrou erro de carregamento da
DLL local do plugin Git do editor. Arquivos locais foram preservados; importação
é verificada na worktree limpa e execução no diretório habitual usa
-SkipEditorImport. Não confundir esse problema do plugin com erro de gameplay.

## Playtest

Preparado em codex/playtest; master permanece no candidato anteriormente aceito.
Testar dois presets, aprendendo/equipando manualmente:

- Raio/gelo: Relâmpago, Descarga, Parede de Raios, Parede de Gelo, Teleporte.
- Espírito/fogo: Impacto das Almas, Assombro, Barreira Fantasma, Bola de Fogo,
  Parede de Fogo.

Conferir combo Eletrizado (stun é probabilístico), fear, proteção contra flechas,
desvio pelas pontas do gelo, expiração/limpeza e preservação do preset no reload.
Não alterar saves para fornecer pontos; redistribuição existente é suficiente.
Aceite técnico do recorte não substitui MGI com duas builds integradas nem
aceite de produto do usuário antes de merge em master.
