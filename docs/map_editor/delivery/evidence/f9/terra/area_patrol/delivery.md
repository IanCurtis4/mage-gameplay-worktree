# Entrega Terra — guarda do beco (alley_watch)

Status: **PASS no checker estático** (`check_requests.py`). Nada foi executado na engine; PASS de compilação/gameplay é com Sol.

## Arquivos
`population_update_preview.request.json`, `population_update_apply.request.json`, `patrol_author.request.json`, `patrol_compile_launch.request.json`, `build_requests.py` (gera os 4 a partir da fonte real, preservando valores atuais), `check_requests.py`, `check_output.txt`.

Ordem de execução: 1 (prévia) -> 2 (apply, com os hashes da prévia) -> 3 -> 4. O pedido 3 importa a fonte de população **já salva pelo pedido 2**; o 4 abre o `.patrol.json` salvo pelo 3.

## Escolhas
- Brush `alley_patrol`: 12 campos idênticos aos atuais; só `species` muda para `pilot_bulwark_species / normal / trial_stage_1 / weight 1`.
- Slot `alley_guard`: mesmos id, brush, apoio, posição [1640,0,960], site "" e fixed true; só espécie/categoria/origem trocadas.
- Rota `alley_watch` (ping_pong, revision 1, slot `alley_guard`), toda no apoio do home `overpass/c_e33596bc5a5c9222_0_0_4_10` (quad plano Y=0, x 1280-1792, z 0-1280):
  - `alley_north` [1640,0,840], espera 2,5 s
  - `alley_south` [1640,0,1100], espera 2,0 s
  - Eixo N-S em x=1640 passando pelo home (z=960): ronda legível de 260 de extensão (160 + 140 saindo do home).
- Por que x=1640: fica 64 a leste do slot mais a leste do `west_group` (x=1576) e longe dos sólidos do oeste (carvalho/rochas em x 1408-1440). Norte parado em z=840 (e não mais acima) para ficar 72 fora da faixa da emenda/corredor (z 512-768, x 1280-1792). O sul está limitado pelo carvalho `overpass_oak_tree_06` (1664,1184); parei em z=1100.

## Folgas calculadas (centro do ponto; mínimos sobre todos os trechos na última linha)
| Ponto | Borda do apoio (>=40) | Leash ao home (<=850) | Sólido mais próximo (>=64) | Slot west_group mais próximo (>=48) | Faixa emenda z512-768 (>=64) |
|---|---|---|---|---|---|
| alley_north (1640,840) | 152,0 (borda x=1792) | 120,0 | 238,7 oak_tree_04 | 157,6 (slot_297da4) | 72,0 |
| alley_south (1640,1100) | 152,0 | 140,0 | 87,4 oak_tree_06 (2º: 121,7 moss_boulder_03) | 132,5 (slot_297da4) | 332,0 |
| home (1640,960), referência | 152,0 | 0 | 221,8 moss_boulder_02 | 68,4 (slot_297da4) | 192,0 |
| **Trechos (home<->pontos, norte<->sul, amostrados)** | 152,0 | 140,0 | 87,4 | 64,0 | 72,0 |

Y: apoio plano, Y=0 em todos os pontos (coerente). Polígono contém os dois pontos (XZ). Os trechos ficam dentro do mesmo quad convexo, então não saem do apoio nem do leash.

## Riscos conhecidos
1. **Aggro 420 do bulwark**: o guarda agora tem engajamento, que o `demo_chaser` não tinha. O corredor sob a ponte (z~640) fica a 320 do home e a 200 do ponto norte: um jogador que cruze a emenda pode puxar o guarda (leash 850). É consequência da decisão aprovada, não de coordenadas; avaliar no gameplay.
2. `collision_radius` do bulwark é desconhecido; o compilador usa max(20, raio da espécie). Folga mínima de 87,4 a sólidos absorve até raios altos, mas o raio de cada prop sólido também é desconhecido (assumi a regra de 64 do centro).
3. Slots `west_group` gerados podem mudar de posição se a prévia regenerar a distribuição (o hash da receita muda com o brush). Usei as posições da fonte atual; se mudarem, o mínimo trecho-slot (64,0) precisa ser recalculado.
4. `population/document/save` no mesmo caminho do `open`: o contrato recusa *novo* destino AX já existente; aqui é o caminho da sessão aberta, mas Sol deve confirmar que o save de sobrescrita passa.
5. `patrol/gameplay/launch` não está descrito em ax_contract_encounters_patrols.md; copiei os parâmetros do enunciado (`class_id`, `headless`).
6. A faixa da emenda/corredor (z 512-768) é minha leitura do enunciado ("Z≈640, largura 256"), não geometria extraída.

## O que Sol deve conferir
- **Prévia (pedido 1)**: diff só com `alley_guard` alterado (espécie) e brush `alley_patrol` (species); nenhum slot gerado (`west_group` x3, `clearing_dispersed` x3) removido ou alterado; guardar `expected_source_hash` e `proposal_hash` para os placeholders.
- `alley_guard` continua fixed true, mesma posição/apoio; sem diagnóstico novo.
- **Apply/save (pedido 2)**: `plan_hash` e hash de bytes coerentes; reabrir e comparar.
- **Pedido 3**: import traz 7 slots; `route/upsert` aceita; `patrol/map/query` com os mesmos hashes de mapa.
- **Compile (pedido 4)**: esperado `ok`; códigos possíveis de falha: `patrol_unsupported` (se o catálogo carregado divergir), `patrol_waypoint_invalid`, `patrol_unreachable`, `patrol_leash`. Não relaxar limites; se falhar, devolver o código e o `point_id` que eu ajusto.

## Saída do checker
```
```
PASS  population_update_preview.request.json: JSON válido, ax_version 1
PASS  population_update_preview.request.json: ações com screen/id/parameters
PASS  population_update_preview.request.json: caminhos Windows absolutos com barra invertida
PASS  population_update_apply.request.json: JSON válido, ax_version 1
PASS  population_update_apply.request.json: ações com screen/id/parameters
PASS  population_update_apply.request.json: caminhos Windows absolutos com barra invertida
PASS  patrol_author.request.json: JSON válido, ax_version 1
PASS  patrol_author.request.json: ações com screen/id/parameters
PASS  patrol_author.request.json: caminhos Windows absolutos com barra invertida
PASS  patrol_compile_launch.request.json: JSON válido, ax_version 1
PASS  patrol_compile_launch.request.json: ações com screen/id/parameters
PASS  patrol_compile_launch.request.json: caminhos Windows absolutos com barra invertida
PASS  preview: sequência open, brush, slot, preview
PASS  preview: open na fonte real com confirm_discard
PASS  brush alley_patrol: 13 campos exatos e tipos corretos
PASS  slot alley_guard: 9 campos exatos e tipos corretos
PASS  SPEC do brush: 4 campos exatos e tipos corretos
PASS  brush: 12 campos não-species idênticos aos atuais
PASS  brush: species = bulwark/normal/trial_stage_1/1
PASS  slot: id/brush/surface/posição/site/fixed idênticos aos atuais (fixed true)
PASS  slot: espécie bulwark/normal/trial_stage_1
PASS  slot: surface_id existe em map_query
PASS  apply: 4 primeiras ações idênticas ao preview
PASS  apply: termina com plan/apply e document/save
PASS  apply: placeholders literais e confirm_apply true
PASS  apply: save no mesmo caminho da fonte
PASS  patrol_author: screen patrol
PASS  patrol_author: sequência new, import, query, route/upsert, save
PASS  patrol_author: document/new
PASS  patrol_author: import da fonte de população
PASS  patrol_author: map/query {}
PASS  patrol_author: save em sanctuary_woods.patrol.json
PASS  ROUTE alley_watch: 5 campos exatos e tipos corretos
PASS  ROUTE: id, revision 1, ping_pong, slot alley_guard
PASS  ROUTE: 2 waypoints (2 a 4)
PASS  ROUTE: point_id únicos
PASS  WAYPOINT alley_north: 4 campos exatos e tipos corretos
PASS  alley_north: espera 2.5 s (1,5-3)
PASS  WAYPOINT alley_south: 4 campos exatos e tipos corretos
PASS  alley_south: espera 2.0 s (1,5-3)
PASS  compile_launch: sequência open, compile, launch
PASS  compile_launch: parâmetros
PASS  entradas: 31 props sólidos, 3 slots west_group

--- Tabela de folgas (centro do ponto; mínimo sobre o trecho em parênteses) ---
PASS  alley_north: surface_id existe em map_query
PASS  alley_north: mesmo apoio do home
PASS  alley_north: dentro do polígono (XZ)
PASS  alley_north: Y=0 coerente com o apoio (Y apoio=0.0)
PASS  alley_north: borda do apoio 152.0 >= 40
PASS  alley_north: leash 120.0 <= 850
PASS  alley_north: prop sólido mais próximo 238.7 (overpass_oak_tree_04) >= 64
PASS  alley_north: slot west_group mais próximo 157.6 (slot_297da45e) >= 48
PASS  alley_north: faixa da emenda/corredor (z 512-768) 72.0 >= 64
      tabela alley_north: pos=(1640, 840) borda=152.0 leash=120.0 prop_min=238.7[overpass_oak_tree_04] slot_min=157.6[slot_297da45e] faixa=72.0
PASS  alley_south: surface_id existe em map_query
PASS  alley_south: mesmo apoio do home
PASS  alley_south: dentro do polígono (XZ)
PASS  alley_south: Y=0 coerente com o apoio (Y apoio=0.0)
PASS  alley_south: borda do apoio 152.0 >= 40
PASS  alley_south: leash 140.0 <= 850
PASS  alley_south: prop sólido mais próximo 87.4 (overpass_oak_tree_06) >= 64
PASS  alley_south: slot west_group mais próximo 132.5 (slot_297da45e) >= 48
PASS  alley_south: faixa da emenda/corredor (z 512-768) 332.0 >= 64
      tabela alley_south: pos=(1640, 1100) borda=152.0 leash=140.0 prop_min=87.4[overpass_oak_tree_06] slot_min=132.5[slot_297da45e] faixa=332.0
PASS  trechos (home<->pontos e entre pontos): todas as amostras dentro do mesmo apoio convexo, logo transitáveis sem sair do leash
PASS  trechos: menor distância a prop sólido 87.4 (overpass_oak_tree_06) >= 64
PASS  trechos: menor distância a slot west_group 64.0 (slot_297da45e) >= 48
PASS  trechos: menor distância à borda 152.0 >= 40
PASS  trechos: maior distância ao home 140.0 <= 850
PASS  trechos: menor distância à faixa da emenda 72.0 >= 64
PASS  extensão entre waypoints 260 (250-400)

RESULTADO: PASS
```
