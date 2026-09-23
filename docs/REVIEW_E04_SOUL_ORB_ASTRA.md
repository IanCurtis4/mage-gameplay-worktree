# Impacto das Almas — revisão da integração visual

23/09/2026. Entrega 92b342c sobre 9b04978. Revisão proporcional do ajuste:
bitmap de 64×64, alpha preservado, nearest, desenho acima do alvo e pulsação
de escala/opacidade por impacto. Alteração do timer visual é independente
do timer de emissão; dano, número de pulsos, targeting e cadência preservados.
Sem achados bloqueadores na leitura do código.

APROVADO tecnicamente: validação independente completa com Godot 4.7.2 passou
53 suítes / 2.472 checks e smoke. Após fast-forward do playtest, importação
das novas texturas passou e MG4 passou novamente seus 64 checks no diretório
habitual. O primeiro teste local, antes de importar, indicou textura ausente;
a importação resolveu essa dependência sem alteração de código.
Não foi possível comprovar a legibilidade in-game por captura headless;
playtest do usuário deve confirmar tamanho e contraste sobre os inimigos.
Aceite técnico deste ajuste não encerra MGI nem autoriza merge de produto.
