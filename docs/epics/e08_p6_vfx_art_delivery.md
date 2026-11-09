# E08 P6-B1 — empacotamento dos flipbooks de VFX (Terra)

Estado: entregue e validado tecnicamente; sem consumidor (A2 integra depois). Nada commitado.

## O que foi produzido

- `tools/prepare_e08_vfx_art.py` (Python + Pillow + numpy, `python` simples): fatia, registra,
  reduz e empacota; determinístico (duas execuções geram bytes idênticos, verificado por
  `sha256sum`); nunca escreve nas folhas de staging (só gera `staging/provenance.json`).
- 9 atlas `assets/art/e08_vfx/<id>/flipbook.png` (640x640), `flipbook.json` e `flipbook.png.import`.
- `assets/art/e08_vfx/staging/provenance.json` (política P5: `prompt: null`, status
  `generated_project_art_prompt_unrecorded`; o usuário dispensou a proveniência do Codex).
- `scripts/presentation/vfx_flipbook_catalog.gd` (`VfxFlipbookCatalog`): `ids()`, `definition(id)`,
  `frame_region(id, frame)`, `texture(id)`, `frame_at(id, segundos)`, mais `validate(id, dict)`
  público para teste. Dados puros, cópias, falha fechada; sem nós nem referência a gameplay.
- `tests/e08_vfx_art_test.gd`. **Registrar em `tools/verify.ps1` (coordenador).**

## Escolhas

- **Fatiamento:** limites `round(i*W/4)` (cada célula ~313,5 px).
- **Registro:** uma única caixa alfa comum (alfa > 8) sobre os 16 quadros; todos cortados na mesma
  janela quadrada centrada nessa caixa, então o efeito não "pula" entre quadros. A escala é única por
  folha (o quadro de pico preenche ~150-156 px; os quadros iniciais são menores, como desenhados).
- **Célula 160x160:** LANCZOS (Pillow pré-multiplica RGBA ao reamostrar, sem halos escuros), área útil
  156x156 com margem transparente de 2 px por lado, para que filtro linear/mipmap não vaze para a
  célula vizinha. Proporção mantida; sobra vira transparência. 160 px = ~2x a célula do atlas
  existente do Espiritualista (96) com folga para escalar até ~1,5x sem borrar demais.
- **Alpha bleed:** RGB dos pixels totalmente transparentes recebe a cor opaca vizinha (dilatação 3x3,
  24 passos); alfa nunca é alterado. `rgba_sha256` zera o RGB onde alfa == 0 (convenção dos manifestos
  direcionais); `png_sha256` é do arquivo.
- **Âncora:** `anchor_uv = [0.5, 0.5]` em todos: o centro da caixa comum é o centro da célula e, nestes
  efeitos em vista 3/4, o centro visual é o ponto no chão. Exceção conceitual: `slash_arc` varre
  esquerda para direita, então seu pivô de rotação é o centro da célula, não o arco visível.
- **FPS sugerido:** 12 padrão; 16 `slash_arc` e `lightning_burst`; 10 `summon_portal` e
  `nature_thorns`. `loop: false`; `frame_at` retorna -1 ao terminar (16/fps s).
- **`world_diameter_hint`:** largura da caixa alfa do quadro de maior área (pico) em pixels da célula
  empacotada. Desenhando 1 px = 1 unidade de mundo, o efeito tem esse diâmetro; o consumidor escala por
  `diametro_desejado / world_diameter_hint`. É heurística de largura visível, não raio de gameplay.
- **`.import`:** Lossless, mipmaps ligados, `fix_alpha_border` ligado, filtro no padrão do projeto
  (gerado pelo estágio import do wrapper, depois `mipmaps/generate=true`; reimportado).

## Hashes e metadados

| id | fps | quadros vazios | diâmetro | pico | source_sha256 | png_sha256 | rgba_sha256 |
|---|---|---|---|---|---|---|---|
| arcane_warp | 12 | - | 156.0 | 8 | `5ee7f2b1d389e7dbf076840c5c50d0837f0abe03a6e836818a142b4539455fe5` | `58020712adb7852b00b16240173dc480956235d5563b408d78d143bc88d2bb2c` | `2ae511de5a873b74bde062ed7faa959ce8223d7c6ecd340661080bbafe64e6ff` |
| blood_rift | 12 | - | 156.0 | 7 | `0590789364b8132873f42231556880cf637ffd52db0e024f9a89caa8ad438ef0` | `12c1cfc2278921b5429121faa23b893501bb7842f13bbb6b094dfcb59ebd8909` | `33a41f172c93f6e33a8b7af05b47243d1a933d0317ecf97f540cad61a1f54eaa` |
| fire_burst | 12 | [15] | 150.1 | 5 | `ce4a961234d9aafedb5d6a2afedd9debc2113ddb83a3b69cf1b6f7a9c8cd8d45` | `4c048d21f3e9bcd5435c5786b676233b8593980ad859b8dcefd509499d9fca78` | `10041c0d8036c654c4c09c3691bc0ef7ab88ade0385da3ec13cd2f63b6c55c62` |
| ground_shockwave | 12 | - | 153.1 | 7 | `d8ee56f584aa82163177a985e85f00c83690a9dc4925fa8ee6295d67b1fde307` | `66bc59e701ca3f2f4a17bb409058d2539b628f9e4022bf7feedb3a86a2c52ca6` | `dff8b1fa39aaf32822198eb5ca85274d4c19997864434602b096e685af1b0e13` |
| ice_shatter | 12 | [15] | 136.7 | 8 | `28623e9025043470acc29d652d589e6f2e99f96e9114e07b24073305ea94f226` | `fa84b796f5a4e095d9b71751b23a98c72e4c5200750d2df307e76e0f69c9bddd` | `4ee28f3c45aa14068d8a7ad7f1229c01bd37d4a3b5cd0f956601049674af5763` |
| lightning_burst | 16 | - | 156.0 | 6 | `955dde854caedad2734a1b336fdf91fd09c05b36c856ef77e17efc34ed093d37` | `a4edb8a8574e508e69e4af1434b36ee8bac33d6b2f7ff37601474a9554ebb84b` | `ada71d88b649d0ee5e50b1eb1bf713750b22e273a1c840f68a0b58b7fad1c482` |
| nature_thorns | 10 | - | 155.5 | 8 | `419bc40da47c158f26fe06967a95f06830eff02e84280cd2bc75e1794e33e12f` | `b8ca64bccd83aa76b869699c0cc0769a3182a58b849c033b38556487e9141c54` | `cb943794fdd24fbfba300b5fedd602a8ee33ea141cdfcf76ade8dc90a8d37f79` |
| slash_arc | 16 | [15] | 147.5 | 6 | `ca37be2786eb6dfbf1d53f818c67e0accb95e6b55c87ea6679de2a42056c58ea` | `e4fc38665bc0afd0eaf47157f28872b6b57521fe8d702194b4ccd6b3c95c93bb` | `02018d89b95bd1005179c6062102ea9b6791e4b5677418596a7c30a72e24b1b1` |
| summon_portal | 10 | - | 156.0 | 7 | `e5a49e73df170351f7c2e61d2d7bbabeb80bf323f649b381556484e4dead0b16` | `22e29a29494c3b8f974da572801b80f873718533fb6c2a2d5f8b40bd6a5972de` | `425c2425446b2c58d3057db2cfab90572f314239f699c74e78cda82cdc2983d2` |

## Testes

`tests/e08_vfx_art_test.gd`: **596 checagens, 0 falhas** (`B1_terra_vfx_art_probe_b1_probe_2`).
Primeira rodada (`b1_probe_1`, 13 falhas) preservada: eram erros do próprio teste (comparação de
arrays int vs float vindos do JSON), corrigidos no teste, não nas expectativas de arte.
Cobre: 9 ids, atlas 640x640, hashes recalculados, textura importada, quadros vazios/não vazios,
conteúdo sem tocar a borda de 1 px da célula, alpha bleed presente, `frame_at` (início, negativo, passo,
fim, INF), `frame_region`, cópias independentes, id inexistente e 14 mutações de manifesto rejeitadas,
proveniência (sha256 contra as folhas de staging e campos da política). Evidências:
`b1_sync_1..3`, `b1_import_1..2`, `b1_probe_1..2` em `.godot/verification/p6/`.
Não executei `verify.ps1` nem a suíte de gameplay.

## Achados visuais

Folha de contato (verde 70,90,60 e cinza 120,120,120, atlas em escala 1x, 3x3 atlas) em
`.godot/verification/p6/B1_contact/`. Sem halos escuros ou coloridos, sem recortes e sem salto de
posição entre quadros nos 9 efeitos; âncoras no centro coerentes (efeitos assentados na elipse do chão).
Observações: quadros finais de `ground_shockwave`, `fire_burst` (fumaça) e `blood_rift` ficam bem
tênues sobre o cinza; `slash_arc` termina quase invisível; `lightning_burst` e `slash_arc` são
brancos/violetas claros e perdem contraste sobre fundos claros.

## Limitações

- Sem proveniência de prompt (dispensada). Arte ainda WIP: sem revisão de produto.
- Escala única por folha: efeitos pequenos nos primeiros quadros usam pouca área da célula.
- Nada consome o catálogo ainda; fps e diâmetros são sugestões para A2.
- `slash_arc` só orientado para a direita (o jogo rotaciona).
