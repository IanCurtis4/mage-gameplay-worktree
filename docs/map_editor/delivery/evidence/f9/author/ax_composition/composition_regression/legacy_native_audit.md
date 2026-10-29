# Diagnóstico da fixture nativa M3 histórica

O runner histórico passou importação, Composition63, dois processos CLI com o
mesmo pacote e Document70. Sua Native24 falhou e terminou por proteção60s:
render_two_piece_layers espera exatamente2 filhos; discardable_profile_starts
espera canvas.testing/motion; em seguida chama motion.has_route() em Nil.

Essas duas suposições são anteriores à apresentação F9. Confirmado contra
bbd3597b (última entrega aprovada antes da fatia de composição): MapCanvas inteiro,
M3 UI test inteiro e MapPanel.toggle_test são idênticos. O toggle já abria o jogo
por GameplayTools, em processo separado. Nada disso foi alterado para esconder a
falha. A fixture atual de composição13 verifica malhas, canvas e formulário reais;
a prova atual GameplayNative52 será usada para o contrato de App, sem certificar
Native24. A fixture histórica precisa ser migrada/retirada no tooling final;
seu timeout/erro permanecem publicados e não contam como PASS.

O processo do runner terminou com timeout. Após .NET GetProcessesByName retornar
0 para o engine, o atalho descartável two_rooms deixado pela fixture foi movido
para legacy_two_rooms_reference.json. Conteúdo e SHA preservados no recibo,
sem apagar sessão, janela ou perfil, sem tocar diretório pessoal. Isso evita que
um atalho órfão interfira nas próximas provas; não é certificação de recuperação
do produto nem prova de que um lock antigo significa processo ativo.
