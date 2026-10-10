# Untitled

Jogo 3D de terror psicológico em primeira pessoa (Godot 4.3, GDScript).
Uma casa térrea num cul-de-sac suburbano americano, à noite, ao longo de **no máximo cinco noites**. Nenhuma explicação, nenhum objetivo marcado na tela, nenhum narrador. O mundo segue funcionando com ou sem o jogador — e às vezes alguma coisa está lá. Há **dois finais**, e nenhum deles explica nada.

> Este README é para quem desenvolve. Ele **revela** o funcionamento de tudo. Não leia se quiser jogar às cegas.

---

## Como abrir e jogar

1. Instale o **Godot 4.3 stable** (versão padrão, não a .NET): https://godotengine.org/download/archive/4.3-stable/
2. Abra o Godot → **Import** → `Untitled/project.godot` → **F5**.
3. Executável Windows: `Project → Export… → Windows Desktop` (preset pronto, dados embutidos em `build/Untitled.exe`).

### Controles
| Tecla | Ação |
|---|---|
| WASD / setas | andar · Shift corre · Ctrl/C agacha |
| Mouse | olhar |
| E ou clique esquerdo | interagir · soltar o que está carregando · (com o saco de lixo, olhando para a lixeira: jogar fora) |
| Tab ou N | ler a lista de tarefas (depois de pegá-la no criado-mudo) |
| Esc | pausa · sair do computador · fechar papel |

Configurações (menu e pausa): volume geral, **ambiente**, **efeitos**, **sustos**, sensibilidade, FOV, granulação, VHS (opcional), legendas, inverter mouse, tela cheia.

---

## Estrutura de uma noite

- Você acorda no quarto. A **lista de tarefas** está no criado-mudo (E para pegar, Tab para ler depois).
- As tarefas são feitas com interações reais: tirar o saco da lixeira da cozinha e levá-lo à lixeira de rua junto à garagem; lavar 3 pratos **com a torneira aberta**; abrir a caixa de correio na calçada; fechar as janelas de guilhotina (cozinha, sala, quarto da frente); apagar o fogo do fogão; girar o trinco das portas da frente/fundos (só pelo lado de dentro); apagar as luzes do térreo; levar as canecas para a pia; fechar a garagem. A lista risca o que foi feito.
- **Toda tarefa que está na lista da noite começa por fazer**, mesmo que você a tenha feito na noite anterior: as janelas reabrem, o fogão volta aceso (a janelinha do forno fica laranja), as trancas destrancam, as luzes do térreo voltam acesas, a garagem reabre, as canecas se espalham.
- Janelas: a cortina não bloqueia mais a janela (pegue a cortina pelas laterais). Canecas: com uma caneca na mão, olhe para a pia — "Put in the sink". Garagem: botão na parede ao lado da porta da cozinha, ou E no vão do portão.
- **Noite 3, 3:12 da manhã**: ao dormir na noite 3 você é acordado por uma porta estourando; há uma figura do lado de fora da janela do quarto. Chegue perto (ou encare por alguns segundos) e ela some. Volte para a cama para continuar.
- **Noite 4, a silhueta no corredor** (`horror/hall_scene.gd`, obrigatória): com as tarefas feitas e você longe dos quartos, uma figura preta está parada no corredor, entre as portas dos quartos, olhando para quem vem. Sem música, sem susto. Ela deixa você se aproximar, fica imóvel alguns segundos e então caminha devagar para dentro do **seu** quarto. Quem a segue encontra o quarto vazio — e um papel sobre o travesseiro: *"Don't wake him up."* O papel some na noite seguinte. Se tentar dormir antes da cena, a TV da sala liga sozinha e não deixa (é preciso descer). A câmera nunca é forçada: dá para perder metade da cena.
- Com as tarefas essenciais feitas, **deitar na cama** (E) encerra a noite: a tela escurece, o som some, aparece "Night N", e você acorda na noite seguinte. Ninguém obriga a dormir; dá para continuar explorando. **Não existe noite 6**: deitar ao fim da noite 5 leva ao FINAL 2.
- O mundo **não é reiniciado**: cadeira deslocada continua deslocada, foto torta continua torta, portas ficam como estavam, objetos ficam onde caíram. Durante o sono a lixeira enche, a louça acumula, chega correspondência, e 1–2 coisas mudam (uma porta aberta, uma foto torta, a cadeira, a luz do corredor acesa...).
- Instruções estranhas aparecem na lista em algumas noites (às vezes em outra letra, às vezes adicionadas no meio da noite): "Check the kitchen window", "Don't leave the back door open", "Turn off the hallway light", "Don't look at house number 6", "don't answer the phone"… Algumas têm consequência (talvez, e às vezes muito depois); outras não têm nenhuma.

### Progressão
| Noite | Clima | O que se torna possível |
|---|---|---|
| 1 | normalidade | eventos originais, vida do bairro, portas que se abrem rangendo, luz que falha no cômodo onde você está |
| 2 | desconfiança | figuras distantes (rua, janelas vizinhas), cânticos na casa nº 6, objetos caindo |
| 3 | medo | primeiros sustos intensos (até 1), figura na cerca do quintal e no fim do corredor, batidas fortes, luzes que se apagam; símbolo de giz aparece na porta dos fundos |
| 4 | paranoia | até 2 sustos, figura cruzando portas, sussurros; a foto do corredor muda; velas acesas na garagem; linha nova na lista |
| 5 | a última | até 3 sustos; "Make sure you're alone." na lista (não tem como marcar e nunca impede de dormir); ao deitar: FINAL 2 |

A progressão muda **probabilidades e possibilidades**, nunca um roteiro minuto a minuto.

---

## Os dois finais

Os dois terminam a partida com **blackout total**, silêncio, e então surge devagar, centralizado: **Untitled...** — e o jogo volta ao menu (dá para começar uma partida nova). Nenhuma tela de vitória, nenhuma explicação.

### FINAL 1 — THE TAPE (`endings/tape_ending.gd`)
- A fita está **escondida e é opcional**: no chão do closet do corredor, no fundo, embaixo dos casacos. Etiqueta escrita à mão: **UNTITLED — 1986**. Nenhuma tarefa manda procurá-la.
- Com a fita na mão, olhe para o videocassete embaixo da TV da sala (ou para a própria TV): **"Put the tape in"**.
- A TV liga, a câmera se aproxima da tela e a gravação ocupa a tela inteira (4:3, granulação, ruído, chroma borrado, faixa de tracking, cores lavadas, áudio abafado no bus *Tape*, data da filmadora "OCT.30 1986").
- **A gravação mostra a casa atual**: uma segunda câmera, dentro de um `SubViewport`, renderiza o **mundo real** no momento em que a fita começa (mesmo `World3D`). Tudo que foi movido — por você ou pelas noites — aparece movido na fita "de 1986". Cada viewport tem sua câmera atual (sem conflito) e a câmera da fita nunca enxerga a TV (sem recursão).
- Sequência: 45–60 s de sala vazia (só o chiado) → uma pessoa comum sai do quarto, atravessa o hall até a cozinha, volta, apaga a luz da sala no interruptor do arco e entra no quarto → silêncio → uma figura preta aparece no corredor, parada → a cabeça vira devagar, em trancos, até a câmera → ela encara; a fita quase silencia → **ela corre absurdamente rápido até a câmera** (~5 m em 0,27 s, inclinada para frente, sem caminhada), sincronizada com um impacto sonoro forte no bus *Ending* (compressor + limiter do master) → **blackout instantâneo**, todo som cortado → "Untitled..." → menu.

### FINAL 2 — THE LAST TASK (`endings/last_task_ending.gd`)
- Acontece ao deitar no fim da **noite 5** sem ter assistido à fita.
- Parece a transição de sempre. Mas não há noite 6: a tela fica preta. Passos no corredor, se aproximando. A porta do quarto abre. Os passos entram, param. O colchão range — alguém sentou ao seu lado. Silêncio. Um sussurro no ouvido: **"You forgot to check the tape."** (legenda exata) → a figura surge colada ao rosto com um impacto → blackout, silêncio → "Untitled..." → menu.

---

## Sistemas

```
scripts/
  core/      GameManager (config, input, modo dev) · WorldState (WorldStateManager) · AudioManager (mixer)
  player/    Player — controlador FPS + interação, degraus, tremor de câmera, leitura da lista
  world/     world.gd (monta tudo) · house_builder · neighborhood · neighbor_house · props · cult (indícios)
             environment_manager (céu, lua, névoa, pós-processo, fade) · car · vehicles · build (B) · mats
  interact/  door (+ deadbolt) · light_fixture · light_switch · phone · tv · computer/terminal · readable
             pickup · picture_frame · clock · chair · faucet · garage_door · curtain
  chores/    trash (lixeira + saco) · outdoor_bin · dishes · mailbox · window_sash · stove · bed · notepad
  horror/    shadow_figure (modelo + estados + animação; modo "pessoa"; corrida) · figure_pool · perception
             scare_director · scares/ (hallway, door, window, behind, tv, runner, contort) · hall_scene (noite 4)
  endings/   tape_ending (FINAL 1) · last_task_ending (FINAL 2) · ending_overlay · vhs_tape · vcr
  sim/       event_director · mystery_event (base) · ambient_manager · task_manager · night_manager
  events/    ev_* (os 10 originais) · ap_* (aparições) · ev_chant, ev_object_fall, ev_lights_out, ev_bang, ev_whisper,
             ev_door_creak, ev_flicker, ev_glass_tap, ev_phone_once, ev_door_found_open, ev_room_drag, ev_manifest,
             ev_object_moved, ev_tv_on
  ui/        hud · main_menu · pause_menu · settings_panel · debug_panel
shaders/     sky · foliage · tv · crt · post · shadow_figure · shadow_shroud · vhs
tests/       run_tests · door_test · horror_test · menu_test · soak_test · tasks_test · story_test · screenshots
```

### Três camadas de acontecimentos
| Camada | Quem cuida | Exemplos |
|---|---|---|
| **A — vida cotidiana** (frequente, não assusta) | `AmbientActivityManager` | carros, cachorros, vento, geladeira, rangidos, luzes de vizinhos, **vizinho chegando em casa** (pessoa andando até a porta, luz acende), **passos do lado de fora** junto à parede, **rajada que mexe uma porta**, **TV estalando** |
| **B — estranheza** (dúvida) | `EventDirector` (trilhas principal e secundária) | os 10 originais + silhueta na rua, figura em janela, porta que abre sozinha, luz que falha, **batidas no vidro**, **telefone que toca uma vez**, **porta que estava fechada aparece aberta (às vezes com a luz acesa)**, **arrasto de móvel num cômodo vazio**, **símbolo que aparece onde você não olhava**, **objeto que muda de lugar**, **TV liga sozinha** |
| **C — terror intenso** (raro) | `ScareDirector` | hallway, door, window, behind, tv, **runner** (a silhueta cruza seu campo de visão absurdamente rápido), **contort** (imóvel no fundo do cômodo; o pescoço cresce, a cabeça tomba de lado, a luz morre, some) |

**Ritmo**: a noite respira em ciclos — *calm → build → peak → release* (durações sorteadas). Na calmaria só passam eventos leves e com intervalos longos; na subida e no pico os intervalos encurtam e os perturbadores são liberados; sustos intensos só são armados em *build/peak*. A tensão sobe e desce em vez de ficar constante. Nada é um jumpscare a cada dois minutos.

### EventDirector (o sistema original, preservado)
- **Trilha principal**: os 10 eventos originais. Em cada noite, o primeiro 1,5–2,5 min após acordar, depois a cada 3–5 min sorteados; ordem aleatória; continuam de noite para noite até os dez acontecerem; depois, repetições mais raras. Nada depende de tarefas nem de onde o jogador está.
- **Trilha secundária**: aparições e acontecimentos liberados por noite, em ritmo próprio e irregular (modulado pelo ritmo calm/build/peak/release).
- **Intensidade**: 0 cotidiano · 1 estranho · 2 perturbador · 3 terror intenso. Eventos ≥ 2 nunca se sobrepõem a outro ≥ 2 nem a um susto, e esperam o fim do período de recuperação do ScareDirector.
- Novo evento: crie `scripts/events/x.gd` (`extends MysteryEvent`), defina `id`, `track`, `intensity`, `min_night`, `max_per_night`, `resources`, implemente `_start()`/`finish()` e adicione o caminho em `EVENT_SCRIPTS`.

### ScareDirector
- Nunca agenda sustos em horário fixo. A cada ~20 s (ritmo irregular) avalia: noite atual (cota: 0 na noite 1, 1 nas noites 2–3, 2 na 4, 3 na 5), **tensão** acumulada pelos eventos, o **ritmo** do EventDirector (só em *build/peak*), **recuperação** (5–9 min de normalidade após cada susto; toda noite começa com 4 min calmos), se o jogador está **fazendo uma tarefa** (nada nos 20 s seguintes a uma tarefa), e nunca repete o mesmo susto em seguida nem na mesma noite.
- Quando decide, **arma** um susto compatível com o contexto (dentro/fora de casa, portas fechadas disponíveis…). O susto espera o próprio gatilho e, se ele não vier, desarma em silêncio.
- Depois de um susto: batimento cardíaco grave por alguns segundos, depois silêncio.

| Susto | Gatilho | O que acontece |
|---|---|---|
| **hallway** (A) | olhar ao longo do corredor | a luz do corredor apaga por um instante, a figura surge a ~2 m, avança, some; impacto sonoro |
| **door** (B) | abrir uma porta interna sorteada (uma vez por porta, por partida) | a figura está atrás dela, dá um tranco em direção ao jogador, recua rápido e some; às vezes a porta bate sozinha depois |
| **window** (C) | ficar olhando por uma janela (cortina aberta) | a figura aparece colada ao vidro, mãos no vidro, batida forte; some |
| **behind** (D) | parado/andando devagar | respiração bem atrás da cabeça; se virar em até ~10 s, a figura está ali; se não virar, a respiração some e nada acontece |
| **tv** (E) | olhar a TV na sala | estática; olhando por alguns segundos, um rosto pálido interrompe o sinal com um estouro; depois estática ou desliga (habilitado só em ~55% das partidas) |
| **runner** (F, noite 2+) | olhar através de um cômodo aberto | uma silhueta curvada cruza o campo de visão a 4–6 m em 0,3 s, com deslocamento de ar e passos descalços |
| **contort** (G, noite 3+) | virar-se para o fundo de um cômodo | ela está lá, imóvel; olhando, o pescoço se alonga e a cabeça tomba de lado; a luz apaga, algo cai, a luz volta: nada |

### Figuras escuras
Silhueta humana estilizada (cabeça, pescoço, tronco, quadril, braços e pernas em dois segmentos, mãos longas), postura levemente curvada, material que "engole" a luz, contorno frio tênue e uma casca de fumaça que deixa a borda irregular. Estados: oculta, aparecendo, observando, movendo, recuando, desaparecendo, susto. Aparecem/somem por dissolução, instantaneamente ou piscando — muitas vezes só quando o jogador não está olhando.

Aparições sem susto (trilha secundária): parada do outro lado da rua sob um poste (some ou caminha para trás de uma casa), silhueta na janela iluminada de um vizinho, perto da cerca do quintal (pode sumir quando você entra), parada no fim do corredor no escuro (some quando você desvia o olhar, recua para o banheiro ou vira a cabeça e some), cruzando uma passagem do outro lado do cômodo.

### Áudio
Todos os arquivos são normalizados (−1 dBFS de pico). Os níveis ficam numa **tabela única** (`AudioManager.MIX`: ganho, distância de referência, distância máxima, categoria). Buses: **Master** (compressor + limiter a −1 dB, protege fones) ← **Ambience** (AmbIn/AmbOut), **SFX** (SFXIn/SFXOut, Room = reverb da casa, Phone), **Horror** (compressor próprio), **Music**, **UI**. Sons de dentro ficam abafados quando você está fora e vice-versa. A proximidade pode somar no máximo +3 dB ao nível de mixagem.

Novos sons sintetizados: impactos de susto (3), grito curto, estouro da TV, respiração próxima, sussurro, batida na janela, pancadas na porta, cântico distante, drone grave, corrida, zumbido elétrico, batimento, trinco, maçaneta, louça, esfregar, saco plástico, tampa de lixeira, caixa de correio, janela correndo, botão do fogão, gás, objetos caindo.

### O culto (sem explicação) — pistas permanentes × manifestações temporárias
`world/cult.gd` separa duas coisas:

**Pistas narrativas (permanentes)** — objetos comuns com história: o livro de história local (páginas cortadas), a foto da Associação em 1974 na garagem, a correspondência de cada noite (conta de luz; "guardamos sua cadeira"; "não diga em voz alta, soletre"; o incêndio de 1979 na casa nº 6; o envelope com o símbolo), o arquivo `CIRCLE.TXT` no computador (noite 3+), alguém a mais na foto do corredor (noite 4+), um risco antigo no batente do closet, tocos de vela velhos no pátio, a fita VHS. Mudanças comuns (cadeira deslocada, foto torta) também persistem.

**Manifestações (temporárias)** — altares, velas, giz, símbolos, escrita. Nunca viram decoração. Cada uma tem seu tempo de vida:
| Vida | Comportamento |
|---|---|
| `night` | fica a noite toda |
| `timed` | dura alguns minutos e some na próxima vez que ninguém estiver olhando |
| `return` | depois de vista, se você sai do cômodo, ao voltar ela não está mais lá |
| `glance` | some no instante em que você desvia o olhar |

E **todas** são apagadas na transição entre noites (`clear_temporary`), por um sistema de estados — nada de exclusões aleatórias.

| Noite | Ao acordar | Mais tarde na noite (só onde você não está olhando) |
|---|---|---|
| 2 | altar no quarto da frente (`night`) | símbolo vermelho no espelho do banheiro (`glance`) |
| 3 | giz na porta dos fundos e no pátio (`night`) | cruz invertida no quarto da frente (`return`), círculo de giz com velas no chão da cozinha (`timed`) |
| 4 | velas na bancada da garagem (`night`), velas nos degraus das casas 6 e 9 (`timed`) | objetos ritualísticos na mesa de jantar (`return`), símbolo no guarda-roupa (`timed`) |
| 5 | círculo de velas na ilha da rotatória + símbolo de giz no asfalto (`night`), "QVATTVORDECIM / XIV" escrito na parede do quarto da frente (`return`) | espelho (`glance`), cozinha (`timed`), mesa (`return`) |

Além disso, o evento `manifest` desenha pequenos símbolos em paredes fora do seu campo de visão (`glance` ou `timed`). Cânticos e janelas à luz de vela na casa nº 6 (Leland). A ligação entre isso, as figuras e os eventos originais **não é confirmada em lugar nenhum**.

### Os 10 eventos originais
Inalterados (cadeira, casa vizinha, batidas, telefone, carro, TV, passos, relógio, foto, PRESS ENTER). PRESS ENTER continua resolvido digitando **E-N-T-E-R**, com a pista na carta da geladeira.

---

## Correção da porta dos fundos
**Causa**: havia um desnível de 2 a 14 cm exatamente sob o batente. Para entrar o jogador precisava subir o degrau encostado no batente; o teste de subida colidia com o batente e falhava. Além disso, a porta aberta vista de lado pelo lado de fora quase não era atingida pelo raio de interação. A porta da cozinha→garagem tinha o mesmo problema.
**Correção**: patamares nivelados com o piso interno (o degrau ficou na borda externa), degraus mínimos passam a ser escaláveis, o vão da porta é interativo pelos dois lados, a folha não colide enquanto gira e só volta a ser sólida quando ninguém está no caminho, raio do jogador 0,25 m. `tests/door_test.gd` sai, fecha por fora, reabre por fora e entra, 3 vezes, nas portas da frente, dos fundos e da garagem, e testa o trinco.

---

## Ferramentas de desenvolvimento (F1)
Só existem rodando pelo editor ou com `-- --dev` (ex.: atalho para `Untitled.exe -- --dev`).
- **Events**: velocidade do relógio (1×/10×/60×/300×), próximo evento principal/secundário agora, disparar qualquer evento, log, simulação de ordens, avisos.
- **Horror**: disparar cada susto agora ou armar (espera o gatilho real), encerrar recuperação, ligar/desligar o ScareDirector, criar figura em posições (à frente, atrás, fim do corredor, cerca, rua, janela da cozinha) e mandar andar/avançar/tremer/sumir.
- **Nights**: ver a lista, completar tarefas, dormir agora, adicionar linha estranha, despertar das 3h, silhueta do corredor (noite 4) agora, criar qualquer manifestação do culto / listar / limpar, **me dar a fita**, **tocar a fita agora (FINAL 1)**, **última tarefa agora (FINAL 2)**. A barra de status mostra o ritmo atual (calm/build/peak/release).
- **Audio**: tocar qualquer som a 1/5/15/40 m (mostra ganho, distância e bus), layout dos buses; medidores de pico na barra de status.
- **World**: estado do mundo, interações, reset, teleportes, teste da porta dos fundos por dentro e por fora.

### Testes automatizados
```bash
godot --headless --path . -s tests/run_tests.gd    # 62: mundo, jogador, interações, os 10 eventos, persistência, PRESS ENTER
godot --headless --path . -s tests/door_test.gd    # portas externas nos dois sentidos + trinco
godot --headless --path . -s tests/horror_test.gd  # 65: buses, tarefas reais, sono até a noite 5, figuras, sustos (forçados e por gatilho real), aparições
godot --headless --path . -s tests/menu_test.gd    # menu → PLAY → mundo → sair → jogar de novo
godot --headless --path . -s tests/tasks_test.gd   # as 5 noites fazendo TODAS as tarefas pela mira + E: despertar das 3h, silhueta da noite 4 (bilhete no travesseiro), FINAL 2 (sussurro exato, sem noite 6)
godot --headless --path . -s tests/story_test.gd   # manifestações e seus tempos de vida, limpeza entre noites, eventos/sustos novos, a fita no closet, FINAL 1 de ponta a ponta
godot --headless --path . -s tests/soak_test.gd    # noite 5, relógios acelerados, jogador vagando por minutos
godot --path . -s tests/screenshots.gd -- pasta    # capturas (precisa de GPU/Xvfb)
```

### Regenerar assets
```bash
pip install numpy scipy pillow     # + espeak-ng e mbrola (us1/us2/us3) para vozes e cânticos
python3 tools/gen_textures.py && python3 tools/gen_textures.py night
python3 tools/gen_audio.py
```
