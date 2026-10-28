# Sol — integração do snapshot compacto,28/10

Baseba15cf2; runtime44a0b36439de030ab48a64aff2a26adc856fbadd; testes posteriores
fac5db2f228d1f5bf11cf31a17e0b89709e730d8. Relatório Luna SHA256
5192E3832E7A44E9458FE076CF6C77DFCDD7EF4F758EA9B4E8EC97E0776D8983. Papéis: código/integração Sol; testes/supervisão Luna.
Não é auditoria semântica independente. Meta permanece TODO F9 e mapa finalAX.

## Resultado comprovado

Encoding estrutural sem perdas, ainda limitado a4MiB ANTES do DEFLATE. Grafo
semânticoF3 mantém IDs, ordem, alias, ciclos e tipos; transporte decheckpoint2
inclui digest comprimido além do digest dos bytes originais; legado1 permanece.
Capture usa bucket raso e is_same exato, sem hash recursivo ou fusão por igualdade.

Density33 PASS, Native20 PASS e quatro IDs oficiais PASS: F6snapshot40,
F3snapshot50, F3continuation2743/30cenários, F3lifecycle90. Não somar repetições
anteriores. Sol leu manifests/logs e inspecionou rounded_hill_gameplay_walk.png:
ator real sobre colina, HUD do jogo e caminho na mesma peçaGUI/AX. Native provou
posição/clique/movimento/corpo20x32 sem reduzir33x33/passo50/pico220/raio420.
Checkpoint persistido póswalk/suspend:3.594.152B <4.194.304B, formato2; recibo
metadata sem payload privado em dense_profile_metadata.json. O envelope lógico
anterior era10.309.084B. Isto não conta só bytescomprimidos nem remove estado.

Medição de uma rota real: pedido44,128ms, caminhada3,112s;120frames com mediana
17,421ms, p95 27,479ms, máximo136,137ms. Não é FPS geral. Preparo3,253s,
publicação27,949s, App.open50,196s, App.start30,614s. Os tempos de carregamento
continuam relevantes emF9-10, sem pretensão de responsividade completa.

## Retomada: estado restaurado, clique seguinte falhou

Novo processo abriu e retomou o perfil descartável;536 apoios/828 conexões,
mesmo candidato, posição salvaXZ760/780 elevada e corpo20x32 PASS. O alvo seguinte
XZ780/780 produz ambiguous_surface em resolve_surface: pick e requisição de
movimento falham.9 verificações emitidas/7PASS/13esperadas; sem captura da
retomada, caminhada concluída ou check de resuspend. Não declarar continuidade
integral nem candidato final validado. Close canônico preservou sessão; nenhum
profile pessoal foi tocado.

A inspeção de WorldGeometry.resolve_surface identifica o ramo que marca
ambiguous=true para hits cujos parâmetros de raio empatam na tolerância. Hipótese
é uma emenda entre faces conectadas (alvo X=Z), a confirmar com os hits reais,
normais/posições e vínculos. Código de geometria não mudou nesta integração:
não atribuir a falha ao codec sem reprodução. NÃO trocar alvo para passar, pegar
primeiro hit por ordem, relaxarEPS ou confundir pisos sobrepostos independentes.

Próxima ação: coletar candidatos do raio neste ponto, provar emendas contínuas
versus ambiguidade real; corrigir autoridade compartilhada preservando oclusão,
andares, direção e colisão. Acrescentar invariantes de ordem/arestas/vértices e
casos adversos. Se scripts mudarem, o checkpoint antigo deve ser preservado e
rejeitado por sources incompatíveis; recriar sessão com Native antes de Resume,
sem reescrever hashes do perfil. Depois retomarAX/Terra e restantes F9-01–12.

## Reuso, hashes e estado operacional

Sol rehashou os2014 inputs de density_final/resume: source=fixture=current sem
nenhuma divergência. Native_pooled histórico2012 tem só delta posterior em
Density test e runner, mais testeResume novo não listado; scripts/runtime iguais
44a0. Os quatro oficiais têm mesmo runtime. Reuso restrito, sem reatribuir runs.
Nenhum processo Godot/handle permanece; fixture liberada. Este checkpoint final
altera só documentos/evidência, sem repetir gameplay. Sem playtest/master/push.
