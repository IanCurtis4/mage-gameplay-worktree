# F2 / M2 — terreno e compilação, contrato v1

24/10/2026. Autorização: “F1 terminou, pode começar F2.” Sol implementa/valida;
Luna supervisiona execução automatizada delimitada. Base M1 integrada por
ancestralidade `c6484ffebebaef588410e8002babc2eaf48e30e8` (M0 fdceea0).
Branch `codex/map-editor-m2`; checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m2`.
D1/D3 aprovadas. D2 aprovada neste chat: “Manter apresentação isométrica atual
no F2”. D4 fica pendente de medição/aceite; não inventar tamanho final ou FPS.

## Propriedade exclusiva e fronteira

M1 está encerrado para escrita de UI segundo entrega humana; esta ativação
transfere nominalmente `addons/ragrpg_map_editor/shell.gd` a Sol M2.
Demais arquivos M1 são consumidos sem escrita. Novos arquivos exclusivos Sol:

- `scripts/map_authoring/terrain/brush.gd`
- `scripts/map_authoring/terrain/terrain_canvas.gd`
- `scripts/map_authoring/terrain/terrain_panel.gd`
- `scripts/map_authoring/compiler/terrain_compiler.gd`
- `scripts/map_authoring/compiler/headless.gd`
- `tests/map_editor_terrain_test.gd`
- `tests/map_editor_terrain_ui_test.gd`
- `tools/map_editor_terrain/run.ps1`
- `.gd.uid` correspondentes a cada script acima
- `docs/map_editor/contracts/m2_dispatch.md`
- `docs/map_editor/delivery/m2.md`
- `docs/map_editor/delivery/evidence/m2/.gitattributes` e evidência autoral

Luna possui somente `docs/map_editor/delivery/evidence/m2/luna.md` e subdiretório
`luna_run/`; nenhum escritor simultâneo. Índice do editor: este contrato é o
registro do dispatch; README recebe apenas link/status M2 por Sol.
Sem escrita em runtime E07/F8, actors, runner oficial, project.godot, catálogo,
perfil ou arquivos do projeto habitual. Sem M3+, solver, assets novos, export
release, publicação, master ou push. Plugin continua opt-in.

## Operações e saída

Schema fonte1 de M1 preservado. Operações puras retornam proposta inteira e
`ok/code/diagnostics`; sessão M1 aplica uma ação atômica por traço. Traço usa campo de distância sobre polilinha contínua, com intensidade única
por amostra: eventos repetidos/colineares não mudam a operação. Cancelar/soltar fora descarta; trava/regiões/conectores protegidos
são preservados. Elevar/baixar, nivelar, suavizar, material, rampa por dois pontos;
círculo/quadrado, raio/intensidade/dureza. Duas tintas simples internas grass/earth,
sem importar texturas nem anunciar catálogo M4. Fonte não perde máscaras.

Compilador usa células convexas planares do kernel E07. Grade coplanar vira quad;
quad deformado vira dois triângulos. Arestas coincidentes completas viram pares
de conectores e adjacências explícitas, nunca conexão por projeção. Superfície
especial horizontal retangular ganha slab AABB de espessura4; demais polígonos
convexos planares são suportes especiais, sem inferir sólido de rampa. Headroom
padrão100, perfil técnico radius2/height12, valores em unidades E07, não escala
final de produto. Rejeitar sobreposição, suporte inválido, conector inválido,
folga insuficiente, capacidade não implementada e limite de células. Limites
medidos são defensivos, não metas D4. Sem quantização oculta de controles.

Pacote versionado contém parte canônica, adjacências internas, fronteiras
estáveis por aresta/célula, materiais visuais nos mesmos vértices, source_hash,
compiler_revision/dependências e package_hash. Não é uma receita F0 publicada:
o assembler F0 só conecta instâncias pela árvore; M3 consumirá adjacências
explicitamente, sem fingir que part.to_data sozinho conecta suas células.
Preview técnico de uma peça produz manifesto com esse mesmo grafo e configura
WorldGeometry sem alterar sua matemática. GUI/CLI usam o mesmo compile.
Bordas sem abertura têm suporte encerrado e face visível; perfis de barreira de
bioma e emenda entre peças ficam M3. Não declarar borda decorativa muro de LoS.

Provas positivas/negativas: determinismo de traços e pacote/ordem/processos,
trava/proteção/cancelamento/rejeição sem mutação, undo/redo/reabertura,
platô/rampa, passagem inferior e slab bloqueando ataque/raio, geometria e visual
no mesmo vértice, conectores/folga/NaN/concavidade, cancelamento/retorno obsoleto,
UI nativa e medições com contagens. Listar runner oficial e selecionar import e
geometria por impacto; runner próprio exercita fonte real em fixture isolada.
Nenhum teste lê save pessoal. D4 é apresentada com evidências antes do aceite.

A peça deve formar componente conectado para o perfil técnico, com inclinação
máxima45°, coordenadas até8192 e erro fonte→Vector3 limitado a0,001 unidade
pela faixa suportada. Arestas/fronteiras são identificadas por célula e endpoints.
Teste de desconexão preserva código route_unreachable; overlap tem contraprova
separada. Bake completo em worker cancelável, sem cache nem bake incremental nesta
entrega; não afirmar estes últimos. Cores simples interpoladas nos vértices;
sem texturas/UV/blend de bioma. Máscaras são normalizadas para apresentação.

