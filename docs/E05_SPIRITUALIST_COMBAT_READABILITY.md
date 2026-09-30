# Espiritualista — leitura de combate e sucesso do combo

Feedback e escopo autorizados pelo usuário após playtest do candidato1d169ef.
A linguagem estética foi considerada boa, mas não comunica suficientemente
estados, debuffs, causalidade e sucesso. Este documento de direção visual Astra
complementa E05_SPIRITUALIST_VISUAL; progresso e evidências continuam no único
E05_SPIRITUALIST_CHECKPOINT. Sol implementa apresentação e ligação aos eventos.
Não altera dano, tempo, alcance, proc, árvore, save ou progressão.

## Linguagem visual definida por Astra

Preservar sprites, wisps e paleta espectral já aprovados. Compor formas simples
code-native, tipografia curta com contraste e animação sobre os assets existentes.
O efeito comunica estado pelo movimento, silhueta e texto, além da cor.

| Estado real | Leitura no alvo/personagem | Confirmação curta |
|---|---|---|
| Maldição aplicada | Sigilo aberto persistente sobre o alvo, separado da barra de HP; arco de duração5s decrescendo. Ícone de elo aberto distingue preparação de impacto. | AMALDIÇOADO na aplicação; alvo focado informa próximo acerto direto elegível gera Eco. |
| Marca consumida e eco agendado | Elo fecha, dois arcos convergem no alvo durante os0,35s reais. Manter este estado visível depois que a marca some. | ECO PREPARADO, uma vez por gatilho. |
| Eco realmente causou dano | Burst espectral mais incisivo, duas ondas curtas consecutivas visuais do mesmo impacto, contorno breve no alvo. Uma única resolução de dano. | ECO! acompanhado do dano real; identificar esse número sem duplicar o número comum. |
| Eco não causou dano ou foi invalidado | Sem confirmação de sucesso. Absorção/erro conforme resultado; morte/invalidação encerra antecipação. | ABSORVIDO quando houver absorção total; eco dissipado pode aparecer discretamente para o alvo focado, sem notificação de sucesso. |
| Marca expirou sem conversão | Sigilo se desfaz para fora e perde intensidade; nada de burst de acerto. | MALDIÇÃO EXPIROU, discreto e apenas para alvo focado. |
| Rito consome marca | Sigilo rompe em fragmentos radiais, diferente dos arcos de antecipação do Eco. | MARCA DISSIPADA após dano positivo; jamais ECO!, pois o Rito não cria eco próprio. |
| Drenagem | Vínculo + wisps existentes; indicador de canal com4 segmentos junto ao HUD/player. Atualizar por ticks resolvidos, não por timer cosmético independente. | CANALIZANDO0/4→4/4, cura real +HP quando existir; interrupção limpa vínculo/segmentos e indica CANAL INTERROMPIDO brevemente. |
| Foco concedido | Pequeno losango cheio junto ao personagem e ícone no HUD com expiração5s; distinto do elo de maldição. | FOCO PRONTO: próxima Maldição ou Rito fortalecido. Só quando passiva equipada e carga realmente concedida. |
| Foco consumido/expirado | No consumo, losango viaja/contrai até o início do cast; expiração apenas apaga. | FOCO CONSUMIDO no commit válido; nunca confirmar dano antes de acertar. |
| Recolhimento | Wisp retorna do alvo como já implementado; número curto de SP recebido no caster. | +N SP somente pela quantia realmente restituída. |
| Enfraquecimento | Ícone de arma com seta para baixo sobre inimigos afetados; no alvo focado mostrar dano causado reduzido e duração efetiva disponível. | DANO CAUSADO −15%/−20% conforme estado real; fontes de mesmo stat usam maior redução, nunca soma. |

Separar alvo focado (selecionado/perseguido, com hover como fallback) de demais
inimigos: todos têm marcadores compactos, apenas foco recebe detalhe textual.
Textos de transição aparecem uma vez, não a cada frame de refresh do Véu.
Durabilidade dos textos pode superar o impacto brevemente para leitura, mas não
pode sugerir que uma marca/debuff continua ativo depois de acabar.

## Entendimento do combo dentro do jogo

Acrescentar painel compacto próprio do Espiritualista, sem disputar a mensagem
de movimento/erro e sem cobrir controles/vida. Mostrar estado de alvo e de Foco,
com uma dica contextual que usa somente skills aprendidas/equipadas:

- Sem marca: aplicar Maldição prepara o próximo acerto direto.
- Com marca: autoataque/acerto direto elegível converte em Eco. Se Drenagem ou
  Procissão estiver equipada, pode citá-la; apenas o primeiro tick/impacto é raiz.
- Eco pendente: anunciar preparo; confirmar sucesso só na resolução.
- Com Foco: indicar Maldição/Rito equipado como consumidor da carga.
- Com Rito equipado e alvo marcado: explicitar alternativa de romper marca
  para fortalecer o Rito, sem gerar Eco. Não impor isso como sequência obrigatória.

Uma ajuda curta expansível da classe explica dois caminhos:
Maldição → acerto direto → Eco; Maldição → Rito → conversão da marca.
Explicar Drenagem completa → Foco somente quando a passiva for conhecida,
e que dano recebido/movimento/controle interrompem a canalização.
Não exibir dicas de skills que o personagem não possui como ações disponíveis.
No treino, esse feedback deve funcionar sobre boss/adds e com suas resistências.

## Integração e invariantes

Ligar ao estado e resultados autoritativos existentes: marcas e pending do
SpiritualistEchoState, resultados de dano actual_damage/absorbed_damage,
canal/ticks resolvidos, charge grant/consume e AttributeDebuffState.
Apresentação não calcula procs, dano ou empilhamento; recebe valores finais.
Não mudar regras para facilitar os efeitos. Se faltar metadado, expor evento
de apresentação mínimo com IDs/resultado, mantendo dados de catálogo imutáveis.
Sprites novos não são necessários; necessidades adicionais de bitmap voltam a Astra.

Pausa congela duração/animação; cancelar, morrer, trocar alvo, encerrar treino,
reiniciar e sair limpam referências adequadas. Fila finita de feedback; evitar
spam de ticks e efeitos que permaneçam por falta de redraw. Vários alvos e ecos
simultâneos têm estado independente, sem sobrescrever uns aos outros.

## Aceite integrado

Testar aplicação, marca mantida em miss/escudo, preparo, eco positivo/absorvido,
expiração, consumo alternativo por Rito, interrupção0–3ticks versus canal completo,
Foco ausente/equipado/consumido/expirado, HP/SP realmente recuperados, fonte
mais forte de enfraquecimento/expiração, pausa/cleanup e ecos simultâneos.
Cobrir caminhos reais de callbacks e UI; labels isolados não bastam.
Capturar no renderer uma sequência antes/preparo/sucesso e Rito, sobre cena de
treino com boss/adds, garantindo HUD sem sobreposição. Executar verify integral
no fechamento. Revisão Astra somente do pacote integrado; correções automáticas.
Preparar playtest só após aceite técnico; produto/master/Arqueiro aguardam usuário.
