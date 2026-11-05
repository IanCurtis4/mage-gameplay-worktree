# F10 Q5 — minimapa completo e zoom de câmera

Autorização humana de 5/11/2026, após testar o executável: “tá jogável”, com
pedido de minimapa quadrado, mapa inteiro, bolinhas vermelhas nos inimigos,
seta dourada no jogador indicando direção e zoom in/out para mapas maiores.
Base `f01d4cd215ddb5c161930cf2399a33d2e29f88e9`, mesmo candidato F10.
Esse retorno não encerra as demais obrigações de Q5 nem autoriza master/push.

## Comportamento e fronteiras

- O painel mostra o mapa **atual inteiro**, na mesma orientação isométrica
  do jogo nas expedições (x/y na arena plana). A área é quadrada; a transformação usa
  escala uniforme e margem, sem cortar o mapa ou mudar com a câmera.
- Superfícies e obstáculos vêm dos dados de apresentação já existentes.
  Geometria estática é preparada somente ao instalar/reconfigurar o mapa;
  marcadores atualizam no máximo dez vezes por segundo. Sem nova navegação,
  captura do viewport do jogo, leitura de fontes autorais ou reconstrução
  de WorldGeometry pelo HUD.
- Todos os inimigos vivos do mapa atual aparecem em vermelho, inclusive
  fora da câmera. Mortos e atores removidos deixam de aparecer; aliados e
  personagens de outros mapas não viram inimigos no minimapa. O pedido
  autoriza a informação do mapa inteiro, sem regra adicional de descoberta.
- A seta dourada usa posição e direção reais do jogador nas mesmas
  coordenadas do mapa; conserva a última direção quando parado. Nenhuma
  marcação decide alvo, caminho, colisão, elegibilidade ou estado da campanha.
- A roda sobre o mundo e botões `−`/`+` aproximam/afastam a **câmera do jogo**,
  entre 50% e 160%, com retorno a 100%. A escala da interface e o enquadramento
  completo do minimapa continuam independentes. GUI/rolagem/overlays não
  deixam o evento da roda alcançar o mundo. Modais/estado passivo continuam
  respeitados. A preferência usa `controls.cfg`, sem mudar schema de perfil
  ou checkpoint de expedição.
- HUD em pt-BR, com legenda/tooltip e controles que não disparem movimento ou
  skills. Verificar escala/resolução, sobreposição de painéis e leitura real.

## Propriedade e APIs congeladas

- Terra: exclusivamente `scripts/ui/expedition/stage_minimap.gd`, seu UID,
  `tests/stage_minimap_test.gd` e seu UID. Componente puro de apresentação,
  sem dependência de RunController/WorldGeometry. `class_name StageMinimap`,
  `extends PanelContainer`. Métodos:
  `configure_map(bounds: Rect2, surfaces: Array[PackedVector2Array], obstacles: Array[PackedVector2Array])`,
  `update_markers(player_point: Vector2, player_heading: Vector2, enemies: PackedVector2Array)`,
  `set_camera_zoom(value: float)`, `set_zoom_enabled(value: bool)`;
  sinais `zoom_requested(step: int)` e `zoom_reset_requested`.
  O quadrado deve ter 216 unidades lógicas de lado, com título, legenda
  compacta e controles abaixo; fundo estático separado dos marcadores.
- Sol: integração no host, adaptador de dados do mapa, direção pública de
  apresentação quando necessária, preferência/câmera, testes de integração,
  runners, documentação, revisão e novo executável. Sem escrita nos arquivos
  Terra antes da devolução explícita.
- Luna: execução/supervisão após congelar os inputs e transferir engine e
  fixture. Nenhum teste/engine em paralelo com fontes em edição.

## Evidência exigida

Provar enquadramento integral e escala uniforme, alinhamento de posição e
direção, remoção de mortos, mudança de mapa/retomada, extremos/default do
zoom, independência de HUD/minimapa, persistência da preferência, consumo de
eventos pela UI e preservação de checkpoint. `tools/verify.ps1` dirigido,
sonda nativa com captura e export Windows atualizado, com o mesmo namespace
  de save de teste separado **RagRPG F10 Q5 Mapa**, preservando o build e perfil
  **RagRPG F10 Q5** anteriores. Inspeção do código confirmou que checkpoints
  vinculam hashes de todos os scripts à versão exata: migração entre builds
  continua fora do contrato. Não reinterpretar checkpoint antigo ou liberar
  seu personagem por exclusão de dados; o executável anterior segue disponível.
