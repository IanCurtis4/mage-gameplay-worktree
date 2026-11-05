# F10 — minimapa e zoom para teste

Atualização posterior: [terreno e desempenho](f10_terrain_performance.md).
Este build permanece disponível para continuar seus personagens/checkpoints.

5/11/2026. Após jogar o executável anterior, o usuário pediu um minimapa
quadrado com inimigos vermelhos e seta dourada do jogador, além de zoom.
[Contrato e propriedade](../contracts/f10_minimap_zoom.md).
Runtime final **`c9a3673f201f38f33d2a7200b61de12d3ebce84e`**, sobre
`8ca89b1b5b7ff6f538898f6f62b3c6cf9e9c8e86`; base da tarefa `f01d4cd2`.
Q5 permanece aberto; o retorno “tá jogável” não encerra a matriz inteira.

## Jogar

Abra `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\playtest_f10\Jogar RagRPG F10 - Mapa.lnk`.
O executável está em `.tools\playtest_f10\minimap_c9a3673f\RagRPG-F10-Q5-Mapa.exe`
do checkout habitual. Mantenha o `.pck` correspondente junto dele.

Crie um personagem de teste e escolha **Expedições → Floresta do Santuário**.
O canto direito mostra o **mapa atual inteiro**, em um quadrado, com a mesma
orientação isométrica do jogo. Bolinhas vermelhas representam os inimigos
vivos, inclusive fora da câmera; a seta dourada indica você e sua direção.
O fundo é um esquema de superfícies e obstáculos, sem recapturar as texturas
da tela. Os outros estágios aparecem quando você viajar até eles.

Use a **roda sobre o cenário** ou os botões **− / +** para afastar/aproximar
a câmera, de **50% a 160%**. Clique no percentual para restaurar **100%**.
O minimapa continua inteiro e a escala da interface permanece independente.
Cliques no mapa não comandam movimento; roda sobre a GUI não chega ao mundo.
Modais e estado passivo continuam bloqueando comandos de câmera.

A preferência fica em `controls.cfg` e é relida ao reconstruir a câmera,
inclusive após suspensão e retomada. O minimapa fica abaixo dos controles
de classe/controles e se ajusta ao espaço antes da barra de ações. O texto
de ajuda lateral recolhe quando não cabe; os controles continuam no menu.

## Perfis e versões

Este teste usa **RagRPG F10 Q5 Mapa**, em
`%APPDATA%\Godot\app_userdata\RagRPG F10 Q5 Mapa`.
O [executável anterior](f10_windows_playtest.md) e seu perfil **RagRPG F10 Q5**
ficam preservados, além do save pessoal **RagRPG**. Crie um personagem novo
nesta versão. Checkpoints de expedição validam os hashes exatos dos scripts;
migração entre builds continua indisponível. Termine uma expedição antiga
no executável antigo; não houve limpeza ou reinterpretação desses dados.

## Evidência e limites

- `verify_04`: **14/303 IDs, 873 checks PASS**, nos inputs depois versionados
  em `8ca89b1b`, cobrindo entrada,
  barras/atalhos/persistência, inventário, compatibilidade, retomada com
  falhas, apresentação, fluxo e snapshots; minimapa 18 e dados/preferências 30.
- A captura posterior expôs o botão de classe sobre o título. O delta final
  muda somente o posicionamento/reserva do HUD em `main.gd`, além da prova e
  contagem do runner. Núcleo anterior reaproveitado por compatibilidade;
  **StageMinimap 18, F7 flow 23 e F3 snapshot 52** repetidos em `verify_05`.
- `interface_06`: **31/31 PASS** na janela nativa, incluindo classe visível,
  enquadramento, direção, clique bloqueado no mapa, roda/botões/reset,
  movimento após zoom, independência de HUD, limites, modais, preferência,
  escala de UI 120%, checkpoint e retomada. **2.247 inputs** da conclusão
  coincidem entre fonte e fixture; a seleção de release usa **2.241** sem
  os seis arquivos de importação adicionais.
- Executável release: exportação, boot normal e encerramento programado.
  Inspeção/menu e floresta montam o PCK exportado na engine standard nativa,
  com perfil isolado. Isso distingue o boot do `.exe` do percurso do PCK;
  não é uma partida humana completa no executável.
- PCK final da floresta: **13/13 PASS**, incluindo 62 inimigos vivos marcados,
  inimigos fora da câmera, direção do jogador, espaço abaixo do botão de
  classe, zoom a 70%, captura nativa e suspensão/retomada com o mapa reconstruído.
  A captura final foi inspecionada. Entrada 69,5 s, suspensão 8,6 s e retomada
  22,1 s nesta única execução; são tempos da sonda, sem novo benchmark.

O manifesto do build final vincula o código `c9a3673f` a 2.241 inputs e ao
PCK SHA-256 `231561ef4c35c655466e65619de181d34f8d8999bcb70dea76fadf16cfbba848`.
A engine e o template são Godot 4.7.2 standard; não há console wrapper.
O CLI de workflow e `docs/WORKFLOW_TOOLING.md` estão ausentes neste checkout;
a retomada foi diagnosticada por Git, contratos e recibos existentes.

O fundo estático é preparado por configuração de mapa; os marcadores
atualizam no máximo 10 vezes/s. Não há busca de rota pelo HUD, alteração de
atores, fórmula, RNG ou autoridade de campanha. `stage_minimap` e
`camera_zoom` entram na lista explícita de omissões de apresentação do
manifesto; não são estado de run. Os limites/formato de checkpoint continuam.

Erros intermediários estão preservados: alias `Projection` colidia com um
tipo nativo; uma fixture nomeava a peça `ramp` em vez da instância `slope`;
o acesso a metadata ausente emitia erro na instalação. Foram corrigidos sem
relaxar expectativas. A falha física de reset foi isolada: a sonda enviava
pressão da roda sem liberação, retendo captura no mapa. A sequência completa
passou, com `button_down`, `button_up`, um pedido e reset a 100%. Sobreposição
com barra/classe foi corrigida na apresentação, com verificações próprias.

[Vínculo, build, logs, sondas e capturas](evidence/f10/reviewer/minimap_zoom_2026_11_05/),
[supervisão Luna](evidence/f10/luna/minimap_zoom_2026_11_05/supervision.md).
Sol conferiu contrato/invariantes e integrou UI Terra e testes Luna. Essa
supervisão de execução/hashes não é auditoria semântica independente.
Sem suíte inteira, certificação de fluidez ou aceite humano das novas funções.
Latência e demais tarefas de Q5 continuam no [checkpoint](f10.md).
As edições documentais finais foram conferidas por links, diff e hashes;
não motivaram outra repetição da suíte de gameplay.
