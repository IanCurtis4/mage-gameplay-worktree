# F9-T01 — proposta isolada

Estado: código proposto; integração, compilação, testes e inspeção visual pendentes. Base HEAD `4642dbf878fab4004f98141c7e2437ee11e22bd5`. Este diretório não é projeto Godot. As cópias seguem os caminhos de destino; `organic_example.gd` é novo e seu `.uid` será gerado na integração. Não houve alterações no candidato nem execução Godot.

SHA-256 dos originais na preparação:
- `scripts/map_authoring/terrain/brush.gd`: `c9639a248d37cf9a61c5d213899a510c60977f26b1380bb4b013cd8e61368537`
- `scripts/map_authoring/terrain/terrain_panel.gd`: `e93edefc52425db42b48ad5617daeda039bd5bc2021e63b3e3c369177eacdc72`
- `scripts/map_authoring/library/editor_preferences.gd`: `b837895351bc98f440d3c3f2a27dfc14161aba8f464e8d200c8d14cd16c35e88`
- `scripts/map_authoring/library/library_model.gd`: `8d877dc4aeeeeb47be49237590e3ec4164bd384087892a8a9eef856819e16a92`

Modo `rounded_hill`: peso `(1-u²)³` fora do núcleo definido pela dureza; dureza zero no preset. Os modos anteriores e seu preset permanecem inalterados. O exemplo constrói uma proposta em fonte vazia, aplica dois traços de força 110 e pinta um único traço curvo de material; o painel faz um único `session.apply`. O comando AX e o botão compartilham essa operação; o comando AX de traço usa `apply_stroke` como a GUI. O caminho usa segmentos para aproximar a curva, sem polígonos manuais.

Após liberação do congelamento, Sol deve conferir hashes e transferir os cinco arquivos para os respectivos caminhos, gerar `.uid` e integrar sem substituir alterações concorrentes. Luna deve criar e executar invariantes: fontes, limites e presets antigos preservados; centro 220, raio 420, perfil radial e derivadas nas extremidades, simetria e silhueta geométrica real; dois traços separados versus stroke congelado e eventos colineares/repetidos; regiões protegidas, conectores e camada travada; serialização e recuperação do preset novo; rejeição de documento ocupado para cada categoria, sem mutação; uma operação undo/redo; equivalência GUI/AX para traço e exemplo; layout da toolbar; compilação real e prova posterior de suporte, clique, navegação e renderização coerentes. Verificar orçamento e inclinação sem modificar caps, perfis ou amostra para obter aprovação. Executar seleção pertinente de `tools/verify.ps1` e inspeção visual após integração.

Nenhuma conclusão sobre compilação, desempenho, visual ou aceite humano é feita aqui. A amostra não encerra F9-02/12.
