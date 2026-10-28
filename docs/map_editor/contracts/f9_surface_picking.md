# F9 — clique em emendas de apoios contínuos

Correção autorizada F9-04/07/11; base9ed8926bc61fd7d5663d0461caaa3845734a4f7e.
Sol mantém WorldGeometry e runner; Luna cria SurfacePick test/.uid; manifesto
nominal atualizado antes da edição. Sem alteração de schema, física, navegação,
altura, largura, direção, EPS, corpo ou cap. Outros pendentesF9 continuam.

## Reprodução confirmada

Resume13 falhou no cliqueXZ780/780 depois de restaurar posição760/780. Rastreio
somente leitura do pacote real e raio isométrico: duas faces
hill/c_0d7e10294249c1f0_15_15_1_1_t1 e ..._t2 atingidas no mesmo
(780.0009765625,212.727462768555,780.0009765625), t9787.27247292257.
Ambas reconhecem o ponto na mesma abertura, kindwalk, forward/backwardtrue;
conector centro(775,210.9088745,775), largura70.7106781. Normal de cada plano
difere; não exigir coplanaridade para uma emenda de rampa/colina.
Código atual recusa todo empate, inclusive este apoio contínuo. Probe ignorado
não editou candidato/perfil e não criou outro projeto/checkout.

## Regra concreta

Coletar hits primeiro e usar menor t global, independente da ordem. Empates na
tolerância de projeção existente só se tornam uma escolha quando TODOS formam
um componente local de aberturas físicas de caminhada bidirecionais ativas.
Reusar SupportPatch.index/on_opening e transitions/endpoints; o ponto de cada
hit deve estar na abertura correspondente. Posições entre faces vizinhas devem
coincidir dentro de point_tolerance dos próprios hits (sem originfar nessa
comparação); vínculo3D/normal/span já filtrado pelo índice comum. Não somar
Eps nem expandir aberturas. Vínculo remoto, desativado, oneway, nãowalk, pisos
independentes ou sobreposições sem equivalência local continuam ambíguos.

No componente válido, dono é surface_id lexicograficamente mínimo; devolver seu
ponto/normal reais, sem média de alturas ou eleição pela ordem de iteração.
Occlusion sweep permanece completo, inclusive pisos ocultos; seleção não dá
permissão de movimento. Path/WorldMotion continuam conferindo corpo/direção/
colisão. Visibilidade, revisão e erro de raio preservam regras anteriores.
Nenhuma nova autoridade geométrica/parâmetro de produto é introduzido.

## Provas

Aresta plana e inclinada(não coplanar), vértice com várias faces conectadas,
ordem de surfaces/visible/links invertida; separação entre componentelocal e
contato/overlap/ligação remota/desativada/oneway/tipo incompatível. Pisos de cotas
distintas escolhem o primeiro visível, mas ocultar não remove colisão/oclusão.
Stale/raio inválido e ponto interior continuam. Caminhada através de aresta com
corpo real/folga e retomada13 mantêm alvo780/780. Coletar os hits no mapa real,
sem deslocar teste. SnapshotSources antigo será preservado e rejeitado após
mudança de script; recriar Native20 e sessão antes de Resume13, sem forjar hashes.


## Precisão de projeção confirmada no pacote real

Probe adicional com a primeira implementação local mostrouX750/Z780:
hits(750.0029297,207.1960297,780.0029297) e
(750.0019531,207.1947327,780.0019531). Ligação física correta, mas nenhum
hitf32 estava exatamente na aberturaX750; orçamento existente do raio0.0095692.
Por isso a comparação apenas dos hits brutos/on_opening era insuficiente.

Resolver gera âncoras no apoio do dono: hit bruto, ponto mais próximo em cada
abertura local e seus vértices, ordenados por distância e coordenadas estáveis.
Só aceitar uma âncora dentro do orçamento de projeção JÁ existente de cada hit;
TODAS as faces devem conter essa MESMA âncora segundo Kernel.contains (plano e
borda com precisão local), e o componente bidirecional local deve existir nesse
ponto por SupportPatch.on_opening. Devolver ponto real do apoio, nunca médiaY.
Não aumentarEPS, largura ou tolerância física. Esta construção corrige apenas
incerteza numérica de projeção e ainda rejeita pisos independentes/distintos,
componentes incompletos/rogue, links remotos/oneway e oclusão.
SurfacePick24 inclui os raios isométricos plano/inclinado, não só verticais.
