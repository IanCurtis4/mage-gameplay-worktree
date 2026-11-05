# F10 Q5 — terreno no minimapa, muitos inimigos e preparação

Autorização humana de 5/11/2026: corrigir a leitura do terreno no minimapa,
o lag com muitos inimigos e experimentar outra tática para reduzir construção
e execução. Base `f06a383782078eb2030cb1fc2ecccea2bb11662e`, branch
`codex/map-editor-f10`, checkout `.tools/map-editor-m5`. Mesmo marco autorizado.

## Resultado e fronteiras

- Minimapa usa os triângulos reais da grade e sua máscara canônica de declive,
  com altura/relevo legíveis, distinção entre terreno caminhável, íngreme e
  obstáculos. Mesma projeção dos atores, bounds incluindo picos internos,
  mapa inteiro quadrado e zoom anterior. Não criar outro cálculo de navegação.
  O desenho informa terreno; não promete uma rota nem substitui o corpo,
  headroom e a validação de movimento pelo WorldGeometry.
- Medir separadamente CPU, animação, desenho e mundo numa cena com muitos
  inimigos. Otimizar trabalho repetido sem reduzir população, frequência de
  simulação, efeitos de combate, elegibilidade, LoS, colisão ou segurança do save.
- Comparar outra tática de preparação/instalação com a base. Preferir derivados
  estáticos reutilizáveis ou trabalho redundante removido, com chave completa,
  limites e fallback. Cache jamais substitui validação de entrada ou vira
  estado de campanha; nenhum checkpoint antigo é reinterpretado.
- Congelar fontes durante medições. Mesma engine standard 4.7.2, uma fixture,
  perfis descartáveis; preservar o checkout habitual, quatro backups, builds
  e saves antigos. Não presumir aceite humano de Q5/master/push.

## Propriedade e conclusão

Sol assume integração, scripts/ui/expedition/stage_minimap{,_data}.gd,
scripts/world, scripts/actors, fronteiras de preparação identificadas pelo
perfil, testes/runners correspondentes, documentação e novo executável.
Mudanças de autoridade além deste escopo exigem contrato explícito antes dos
consumidores. Luna acompanha testes automatizados após congelar a engine e
os inputs, em pacote delimitado e sem editar runtime/expectativas. Nenhum
outro escritor trabalha em paralelo nesses arquivos.

Exigir prova do relevo/declive e alinhamento de marcadores; medição antes/depois
reproduzível de muitos inimigos; caso frio/quente da nova tática, invalidação,
integridade e fallback; tools/verify.ps1 por impacto; janela nativa/captura e
novo Windows release. Evidências distinguem testes de ganho de desempenho e
amostras de garantias de fluidez. Q5 continua aberto até o aceite humano.

## Tática selecionada após diagnóstico

Sonda imutável do PCK anterior: preparação serial 39,381 s e duas lanes
24,429 s; manifesto e regras completos idênticos. Limitar a duas lanes,
com resultados privados, join obrigatório, ordem original e primeiro erro
pela ordem dos mapas. Falha de criar a thread mantém o caminho serial.
Caches compartilhados continuam guardados por mutex; contadores também.

O perfil expôs outra repetição: MapRelease.load_package valida integralmente
o RPP fixado; Candidate.create e Candidate.prepare refazem a mesma validação
do mesmo pacote, em sequência, antes de qualquer publicação ou mutação.
Autoriza-se transferência privada e imediata desse resultado já validado:
MapRelease.prepare cria o candidato e prepara seu conteúdo por helpers
internos, mantendo todos os checks do loader e todas as provas de gameplay.
Candidate.create/valid/prepare públicos continuam validando entradas externas.
Sem flag externa de confiança, DTO ou cache persistido que dispense checks.
O hash do candidato e o manifesto final devem permanecer exatamente iguais.
Os limites anteriores de 5 MiB, tanto do pacote quanto do envelope completo
do candidato, continuam conferidos explicitamente no handoff interno: o teto
de transporte do RPP é maior e não substitui esse limite de admissão.
Um pacote que falha no loader jamais chega aos helpers internos; alteração
de fonte/pins/dependências continua recusada pelo caminho público.

No controle móvel, 96 atores sobre grade plana custaram mediana 22,628 ms por
quadro: a sombra recriava seu recorte e ArrayMesh em cada passo. Sol assume
`scripts/world/ground_shadow.gd` e prova dirigida: compartilhar a malha radial
somente com projeção canônica e pegada retangular inteira dentro de um único
quad horizontal, ambos os triângulos canonicamente caminháveis, altura exata
e mesma época/configuração/revisão/superfície/raios. Cache por ator contém a
região provada; até 128 malhas compartilhadas por raios. Bordas, emendas,
rampas, declives, outra projeção ou invalidação voltam ao recorte anterior.
Sem arredondar posição física, reduzir frequência de simulação ou mudar luz,
corpo, alpha/UV, terreno, ocupação ou campanha. Comparar cobertura/UV e imagem,
com tolerância só de apresentação para o arredondamento f32 da projeção.
