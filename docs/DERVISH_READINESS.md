# Dervixe — Prontidão e mobilidade

13/09/2026. Proposta de Astra após o usuário delegar a solução. Referências de
fantasia fornecidas pelo usuário: Combat Rogue, Akshan e swashbuckler. Mecânica
original proposta abaixo; não pretende reproduzir habilidades atuais desses jogos.
Somente planejamento. Implementação em E10d após liberação.

## Três pilares

1. Autos com pequeno cleave e prontidão contra uma vítima prioritária.
2. Gancho: âncora em obstáculo cria órbita; âncora no chão puxa frontalmente.
3. Eliminações alimentam variação de buffs, enquanto chefe sustenta ritmo por acertos.

## Prontidão: proposta inicial para protótipo

Acerto direto primário no alvo prioritário concede uma carga, no máximo uma a
cada 0,5 s. Cada carga dá +3% de ASPD, limite dez (+30%), passando pelo mesmo
pipeline de stats e teto global. Erro, DoT, dano de servo ou alvo secundário do
cleave não gera carga. Assim ASPD não se realimenta sem limite e packs não concedem
prontidão instantânea. Valores são iniciais para playtest, não balanceamento final.

Acertar a mesma vítima renova janela de 4 s. Sem acerto depois disso, perde duas
cargas/s. Uma esquiva ou órbita curta não apaga o recurso. Trocar voluntariamente
de vítima conserva metade das cargas; a morte da vítima conserva todas por 4 s,
permitindo escolher a próxima sem punir a eliminação. Ao morrer/finalizar run,
limpar recurso. Ganhar alvo novo não concede carga sem acerto.

Boss funciona sem adds: cada acerto mantém/constrói prontidão até o teto.
Invulnerabilidade prolongada drena gradualmente; não há incentivo a receber dano
de propósito. Buff de ASPD não acelera timers de recarga ou cast automaticamente.

## Fortuna de combate, separada da prontidão

Eliminar inimigo rerrola um buff de curto prazo de um conjunto visível e limitado
(ex.: alcance de cleave, recuperação de gancho, defesa durante movimento). Não
empilhar rerolls, nem substituir o mesmo buff por uma cópia que reinicia procs.
Não atrelar a sustentação single-target a esse sorteio. Augment opcional pode
permitir rerrolagem manual consumindo prontidão, útil em boss sem adds.

## Passivas e ativas de exemplo

Guarda em movimento: defesa temporária após deslocamento voluntário, com duração
e intervalo explícitos, não invulnerabilidade permanente. Corte de abordagem
gera a primeira abertura; Gancho pendular reposiciona; Salva de lâminas consome
parte da prontidão para área, trocando pressão single-target por limpeza.

## Casos de aceite

Boss sem adds permite atingir/manter teto; 20 inimigos no cleave não multiplicam
cargas; parar/pausar congela contadores; erro não gera carga; alvo que morre ou é
liberado deixa recurso válido; cancelar gancho restaura input; colisão nunca corta
obstáculo; alternar alvos tem custo previsível; DPS permanece sob teto com augments.
Telegráficos do boss continuam prioritários mesmo com órbita ativa.
