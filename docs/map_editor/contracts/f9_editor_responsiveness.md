# F9-10 — responsividade do editor (P2)

1/11/2026, Sol/Astra (Claude Opus). Base a08d0185. Pacote P2 da
[matriz de fechamento](../f9_closure_matrix.md). Sem mudança de corpo, cap,
guard, quota, fonte ou escala; os resultados dos compiladores e das buscas de
conectividade são os mesmos.

## Medição antes (headless, Godot 4.7.2, fixture compartilhada)

Cadeia de compilação do editor, duas rodadas iguais (sem cache, frio e quente
davam o mesmo tempo):

| Entrada | peças | terreno por peça | mapa | encontros | patrulhas |
|---|---:|---:|---:|---:|---:|
| Representativa (2 peças de exemplo) | 2 | 65–71 ms | 234–257 ms | 3,1–3,5 s | 3,4–3,6 s |
| Bosque do Santuário (conteúdo AX real) | 2 | 0,3–1,0 s | 24,7–27,1 s | 164,8–168,5 s | 180,2–180,8 s |

- A compilação das patrulhas do Bosque (180 s) encostava no limite de 180 s do
  processo de trabalho do editor: no editor ela podia falhar por tempo.
- Dentro dos encontros do Bosque: preparo 45,6 s (inclui o mapa), slots 47,5 s,
  amostragem dos pincéis 67,8 s, planejador 13,5 s.
- Cada busca de conectividade em lote reconstruía do zero os predicados de
  navegação (ponto, trecho livre, fração de apoio): ~11,5 s por slot, sem reuso
  entre os lotes da mesma compilação.

## O que mudou

1. **Lote de conectividade com o memo compartilhado.** `WorldConnectivityBatch`
   passa ao grafo e à busca o memo de predicados que o mundo já mantém para
   `path` (checkpoint35). `_navigation_clear` e `_navigation_fraction` envolvem
   exatamente `_clear_path_segment` e `SupportPatch.fraction`, então os valores
   são os mesmos; só deixam de ser recalculados. A métrica `phase_usec` mostra o
   tempo por fase de cada lote (diagnóstico, fora de qualquer prova).
2. **Cache verificável de compilação** (`scripts/map_authoring/compiler/compile_cache.gd`).
   Pacotes de mapa e de encontros ficam em `.godot/map_authoring/cache`. A chave
   junta tipo, revisão do compilador, hash canônico da fonte e um hash do
   ambiente (todos os scripts, `content/`, `data/expedition/`, a arte e os
   catálogos do editor). Uma entrada só vale se o `validate_package` do próprio
   compilador aceitar o pacote (que recalcula o hash do pacote) e se ela nomear o
   mesmo hash de fonte. Entrada adulterada ou de outra chave é ignorada e
   recompilada. Limite de 24 arquivos e 96 MB, os mais antigos saem primeiro.
   - É opt-in (`RAGRPG_COMPILE_CACHE=1`): o plugin do editor liga para o editor e
     para os processos de trabalho que ele cria. Os runners de teste ligam `0`,
     então todo teste compila de verdade. Builds exportados nunca compilam.
   - Invalidação: qualquer mudança de fonte troca a chave daquele pacote; mudar
     código, dados ou arte troca a chave de todos. A granularidade é o pacote
     (mapa, encontros), não uma região dentro da peça.
3. **Intercâmbio fora da thread da interface.** A prévia da base, que compilava
   no quadro principal depois da validação, compila no mesmo job da validação. O
   botão "Aplicar proposta…" compila a proposta numa thread e só faz a checagem de
   fonte desatualizada e o commit na thread da interface. `apply_result()` segue
   síncrono para AX e testes, com a mesma checagem.
4. **Processos de trabalho sem sobras.** Os jobs de encontros/patrulhas deixavam
   entrada, saída e log em `.godot/map_authoring/jobs` para sempre (~1 MB cada);
   agora a pasta do job é removida depois de lido o resultado. Jobs que falham
   mantêm o log.

## Medição depois (mesma máquina e entradas)

Rodada 1 com o cache vazio (compilação real, com o memo); rodada 2 com tudo no
cache:

| Entrada | rodada | mapa | encontros | patrulhas |
|---|---|---:|---:|---:|
| Representativa | 1 (cache vazio) | 0,57 s | 3,38 s | 0,55 s |
| Representativa | 2 (acerto) | 0,22 s | 0,25 s | 0,57 s |
| Bosque | 1 (cache vazio) | 25,9 s | 96,5 s | 9,8 s |
| Bosque | 2 (acerto) | 4,3 s | 4,8 s | 9,8 s |

- Encontros do Bosque, compilação real: 165–168 s → 96,5 s. O mapa dentro do
  preparo já sai do cache, e os lotes de slots e de pincéis depois do primeiro
  caem de ~7,4–11,5 s para ~2,1–2,6 s.
- Patrulhas do Bosque: 180 s → 9,8 s quando os encontros não mudaram (o caso de
  editar só a rota), longe do limite de 180 s do processo de trabalho.
- Um acerto custa a validação completa do pacote (o mapa do Bosque reconstrói as
  bordas para conferir): 4,3 s em vez de 25,9 s.

## Provas

- `CompileCache` (10): opt-in; falta compila e grava; acerto devolve o mesmo pacote
  e o mesmo hash; entrada adulterada é recompilada; fonte, revisão e ambiente
  escolhem a chave; entrada de outra chave é recusada; encontros idem; acerto mais
  rápido que compilação; limite de arquivos.
- Regressão de navegação e população com o memo: Ports, Batch, NavigationLazy,
  NavigationDense, NavigationContext, PopulationReachability, PopulationPlanner,
  CandidateBatch, NavigationAstar, NavigationAsync, Geometry, SurfacePick,
  GameplayNative, AssetManifest; runners M3–M7.

## Limites

- A primeira compilação de um Bosque ainda é longa (os números "depois"). O cache
  só ajuda quando nada mudou naquele pacote.
- "Iniciar teste" ainda monta o mundo no quadro principal, atrás da tela de
  carregamento (8 s com pacote pronto; até ~30 s numa compilação nova).
- Cache regional dentro de uma peça (recompilar só as células tocadas) não foi
  feito: a granularidade é o pacote.
