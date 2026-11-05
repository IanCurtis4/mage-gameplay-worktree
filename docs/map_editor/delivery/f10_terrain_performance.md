# F10 — terreno no minimapa e desempenho

Decisão humana posterior nesta data: [encerramento de produto E07/F10 com ressalvas](../../epics/e07/e07_closure_2026_11_05.md).
O recibo abaixo conserva a validação/medidas anteriores ao aceite; flags de
aceite pendente nos artefatos imutáveis não foram reescritas retroativamente.

5/11/2026. Pedido humano após o teste do minimapa: representar o relevo e os
locais onde não se pode andar, reduzir o lag com muitos inimigos e experimentar
outra tática para preparar/executar o jogo. [Contrato](../contracts/f10_terrain_performance.md).
Código `2ff1c00f923e3811b0aa7ebcbeddafe7731d640f`, base `f06a3837`.

## Jogar

Novo atalho no checkout habitual:
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\playtest_f10\Jogar RagRPG F10 - Terreno.lnk`.
Executável em `.tools/playtest_f10/terrain_2ff1c00f/RagRPG-F10-Q5-Terreno.exe`;
mantenha seu PCK ao lado dele. Crie um personagem e escolha a Floresta do Santuário.

O minimapa mostra os triângulos reais do terreno: verde para chão caminhável,
cobre para declive fechado, escuro para obstáculos/altura livre insuficiente.
Altura e iluminação das faces deixam morros, cristas e rampas legíveis; picos
internos entram nos limites do mapa. Inimigos continuam vermelhos e o jogador
é uma seta dourada. Mapa completo e câmera conservam escalas independentes.
Roda sobre o cenário ou −/+ mudam a câmera de 50% a 160%; percentual restaura 100%.

O desenho informa terreno. Contornos têm resolução de minimapa e não garantem
uma rota: corpo, folga lateral, alturas sobrepostas e elegibilidade de passagem
continuam sob a autoridade do WorldGeometry. A máscara de declive é a mesma
da simulação, sem outro limiar de inclinação ou busca de caminhos pelo HUD.

O perfil desta versão é **RagRPG F10 Q5 Terreno**, separado de **RagRPG F10 Q5
Mapa**, **RagRPG F10 Q5** e do pessoal **RagRPG**. Personagens/checkpoints antigos
continuam nos executáveis anteriores, inclusive no [build com minimapa](f10_minimap_zoom.md).
Não há migração de checkpoint entre hashes de scripts diferentes; nenhum save
foi limpo, reinterpretado ou copiado para liberar personagens.

## Implementação e medição

Terreno é uma malha de cores criada uma vez por configuração; marcadores
atualizam até 10 Hz. Alterar obstáculos temporários substitui só sua camada.
O HUD não cria um viewport do mundo nem refaz navegação por quadro.

Atores conservam os ticks de simulação e animação; redesenham quando muda a
imagem, a sombra, o equipamento ou a vida. Efeitos contínuos mantêm seus
redesenhos. Em movimento, sombras podem compartilhar uma malha radial dentro
de um único quad horizontal completamente coberto pela pegada. Bordas, emendas,
rampas, declives, projeções diferentes ou mudança de época usam o recorte anterior.
Não foram reduzidos população, AI, efeitos, colisão ou frequência de combate.

Preparação usa até duas lanes, resultados privados e join antes de compor na
ordem original. Falha de criação da thread mantém a execução serial; erros de
mapas preservam a ordem de decisão. O loader valida os bytes fixados; a passagem
interna imediata evita validar outra vez o mesmo pacote em create/prepare.
Entradas externas ainda passam pelas APIs públicas. Limites de 5 MiB de pacote
e envelope do candidato continuam, mesmo com transporte RPP de até 8 MiB.
Geometria, admissões, prova de ida/volta, hashes e regras permanecem integrais.

O ensaio inicial no PCK anterior mediu preparação serial **39,381 s**, contra
**24,429 s** com duas lanes. Manifesto completo `12271a4e…` e regras `369eaa4b…`
idênticos. Essa amostra isola concorrência; não é o carregamento completo.
As medidas finais do PCK constam no vínculo e nos recibos arquivados.

| Controle | PCK anterior | PCK final |
| --- | --- | --- |
| 96 atores em movimento sobre grade plana, mediana das médias de quadro | 22,628 ms | **9,572 ms** |
| Mesmo controle móvel, mediana dos p95 | 26,417 ms | **14,013 ms** |
| 96 atores parados, mediana das médias de quadro | 5,661 ms | **3,594 ms** |
| Mesmo controle parado, mediana dos p95 | 9,110 ms | **5,876 ms** |
| Entrada completa na floresta, mesmo roteiro nativo com vsync desligado | 72,952 s | **52,382 s** |

Crowd: três janelas de aproximadamente 3 s por lado, mesma engine/driver,
96 atores e 288 chamadas de desenho, com relógios preservados. O controle
móvel isola apresentação com posições seguras conhecidas; não é combate de
96 inimigos. Comparação final é PCK contra PCK, não a primeira amostra de fixture.
Uma janela parada final teve um pico de 156,011 ms. Na floresta com AI,
média 15,571→14,654 ms e p95 **19,831→21,769 ms**: não há ganho confirmado
nessa cauda nem certificação de ausência de lag/picos em todo o gameplay.
Construir a skin inteira continuou em aproximadamente 1–1,4 s por amostra.

Preparação do PCK final em processo novo: **17,077 s**, duas lanes,
14 acertos de prova/zero buscas; repetição no mesmo processo **11,167 s**,
24 acertos cumulativos/zero buscas. Manifesto completo e regras idênticos
aos controles. Essa sonda foi nativa; os controles iniciais de concorrência
foram headless. Não apresentar esses modos como comparação controlada de FPS.
São amostras individuais de carregamento, sem cache de disco do SO esvaziado.

O export Windows levou 57,664 s nesta rodada, sem comparação controlada de
compilação. Os ganhos entregues são de preparação/entrada e apresentação.
Não houve aumento relevante dos binários: PCK 94.914.128 B, contra 94.891.528 B
do build com minimapa anterior; o template exe continua 109.127.680 B.

## Validação e limites

- Seleção incremental de `tools/verify.ps1`: **16 IDs distintos/712 checks**,
  com fatias compatíveis e caudas novas registradas; plano final de 307 IDs.
  Inclui animação, minimapa/dados, atores, handoff/limites, AI, ameaças,
  população, falhas/retomada, integração espacial e snapshot.
- Interface nativa **31**, provas de preparação **23**, composição de fase
  **11**, sombras **28** e terreno do WorldGeometry **15** aprovados.
- Comparação nativa da sombra contra o recorte anterior: **6/6**, imagens
  com alpha visível, **zero bytes diferentes**, incluindo movimento, borda,
  emenda, rampa e coordenadas 9.056. Não significa equivalência de toda imagem
  possível; essas são as amostras verificadas do caminho novo e do fallback.
- Falhas intermediárias preservadas: inferência de tipos em testes e oráculo
  manual que usava eixos (1, 0,5), enquanto a projeção fixa (0,85, 0,425).
  Correção só dos tipos/oráculo confrontados com a autoridade; nenhum limiar
  físico, expectativa de sucesso de gameplay ou erro de engine foi ocultado.
- Pacote final: export/inspeção/menu/boot do exe aprovados; floresta **15/15**,
  46.078 triângulos caminháveis e 5.122 íngremes representados, 62 inimigos e
  zoom a 70%. Captura inspecionada. Na sonda funcional com vsync padrão,
  entrada 49,213 s, suspensão 9,033 s e retomada 23,481 s; manter distinta
  do protocolo de perfil acima. Configurações da fixture restauradas.

PCK SHA-256 `136d35e0d059572b633e2d743fba839e97273b1aaa11d7f41c28ad9b0b9dee3a`.
Fonte/fixture: **2.251 inputs** primários iguais, mais seis imports no lote de
conclusão (**2.257**). Engine e template Godot 4.7.2 standard fixados no vínculo.

Os ticks/relógios continuam iguais. Preferências e caches de desenho são
apresentação descartável; snapshot, perfil, diário e regras não mudaram de
formato. O limite global dos meshes compartilhados é 128, com descarte e
reconstrução; geometria de sombras não vira autoridade de movimento.

[Vínculo, hashes, logs, sondas e imagens](evidence/f10/reviewer/terrain_performance_2026_11_05/),
[supervisão Luna](evidence/f10/luna/terrain_performance_2026_11_05/supervision.md).
Sol integrou e validou contrato/invariantes; Luna conferiu execução, logs e
hashes, sem auditoria semântica independente. Boot real do exe é separado do
percurso pela engine standard nativa montando o PCK exato. Não é partida humana
completa. Q5 segue aberto para autoria/combate/leitura humanos e latência extrema.
Sem master/push ou alteração do checkout habitual. Documentação final validada
por coerência/links/hashes, sem repetir gameplay por edição documental.
