# Untitled

Jogo 3D de terror psicológico em primeira pessoa (Godot 4.3, GDScript).
Uma casa térrea num cul-de-sac suburbano americano, à noite, ao longo de noites consecutivas. Nenhuma explicação, nenhum objetivo marcado na tela, nenhum narrador. O mundo segue funcionando com ou sem o jogador — e às vezes alguma coisa está lá.

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
- Com as tarefas essenciais feitas, **deitar na cama** (E) encerra a noite: a tela escurece, o som some, aparece "Night N", e você acorda na noite seguinte. Ninguém obriga a dormir; dá para continuar explorando.
- O mundo **não é reiniciado**: cadeira deslocada continua deslocada, foto torta continua torta, portas ficam como estavam, objetos ficam onde caíram. Durante o sono a lixeira enche, a louça acumula, chega correspondência, e 1–2 coisas mudam (uma porta aberta, uma foto torta, a cadeira, a luz do corredor acesa...).
- Instruções estranhas aparecem na lista em algumas noites (às vezes em outra letra, às vezes adicionadas no meio da noite): "Check the kitchen window", "Don't leave the back door open", "Turn off the hallway light", "Don't look at house number 6", "don't answer the phone"… Algumas têm consequência (talvez, e às vezes muito depois); outras não têm nenhuma.

### Progressão
| Noite | Clima | O que se torna possível |
|---|---|---|
| 1 | normalidade | eventos originais, vida do bairro, portas que se abrem rangendo, luz que falha no cômodo onde você está |
| 2 | desconfiança | figuras distantes (rua, janelas vizinhas), cânticos na casa nº 6, objetos caindo |
| 3 | medo | primeiros sustos intensos (até 1), figura na cerca do quintal e no fim do corredor, batidas fortes, luzes que se apagam; símbolo de giz aparece na porta dos fundos |
| 4 | paranoia | até 2 sustos, figura cruzando portas, sussurros; a foto do corredor muda; velas acesas na garagem; linha nova na lista |
| 5+ | incerteza | probabilidades maiores, mais conexões; nada termina — depois da 5ª noite as tarefas e acontecimentos se recombinam |

A progressão muda **probabilidades e possibilidades**, nunca um roteiro minuto a minuto.

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
  horror/    shadow_figure (modelo + estados + animação) · figure_pool · perception (o que o jogador vê)
             scare_director · scares/ (hallway, door, window, behind, tv)
  sim/       event_director · mystery_event (base) · ambient_manager · task_manager · night_manager
  events/    ev_* (os 10 originais) · ap_* (aparições) · ev_chant, ev_object_fall, ev_lights_out, ev_bang, ev_whisper
  ui/        hud · main_menu · pause_menu · settings_panel · debug_panel
shaders/     sky · foliage · tv · crt · post · shadow_figure · shadow_shroud
tests/       run_tests · door_test · horror_test · menu_test · soak_test · screenshots
```

### EventDirector (o sistema original, preservado)
- **Trilha principal**: os 10 eventos originais. Em cada noite, o primeiro 2–3 min após acordar, depois a cada 4–6 min sorteados; ordem aleatória; continuam de noite para noite até os dez acontecerem; depois, repetições mais raras. Nada depende de tarefas nem de onde o jogador está.
- **Trilha secundária**: aparições e acontecimentos liberados por noite, em ritmo próprio e irregular.
- **Intensidade**: 0 cotidiano · 1 estranho · 2 perturbador · 3 terror intenso. Eventos ≥ 2 nunca se sobrepõem a outro ≥ 2 nem a um susto, e esperam o fim do período de recuperação do ScareDirector.
- Novo evento: crie `scripts/events/x.gd` (`extends MysteryEvent`), defina `id`, `track`, `intensity`, `min_night`, `max_per_night`, `resources`, implemente `_start()`/`finish()` e adicione o caminho em `EVENT_SCRIPTS`.

### ScareDirector
- Nunca agenda sustos em horário fixo. A cada ~20 s (ritmo irregular) avalia: noite atual (cota: 0 nas noites 1–2, 1 na 3, 2 a partir da 4), **tensão** acumulada pelos eventos, **recuperação** (7–12 min de normalidade após cada susto; toda noite começa com 4 min calmos), se o jogador está **fazendo uma tarefa** (nada nos 20 s seguintes a uma tarefa), e nunca repete o mesmo susto em seguida nem na mesma noite.
- Quando decide, **arma** um susto compatível com o contexto (dentro/fora de casa, portas fechadas disponíveis…). O susto espera o próprio gatilho e, se ele não vier, desarma em silêncio.
- Depois de um susto: batimento cardíaco grave por alguns segundos, depois silêncio.

| Susto | Gatilho | O que acontece |
|---|---|---|
| **hallway** (A) | olhar ao longo do corredor | a luz do corredor apaga por um instante, a figura surge a ~2 m, avança, some; impacto sonoro |
| **door** (B) | abrir uma porta interna sorteada (uma vez por porta, por partida) | a figura está atrás dela, dá um tranco em direção ao jogador, recua rápido e some; às vezes a porta bate sozinha depois |
| **window** (C) | ficar olhando por uma janela (cortina aberta) | a figura aparece colada ao vidro, mãos no vidro, batida forte; some |
| **behind** (D) | parado/andando devagar | respiração bem atrás da cabeça; se virar em até ~10 s, a figura está ali; se não virar, a respiração some e nada acontece |
| **tv** (E) | olhar a TV na sala | estática; olhando por alguns segundos, um rosto pálido interrompe o sinal com um estouro; depois estática ou desliga (habilitado só em ~55% das partidas) |

### Figuras escuras
Silhueta humana estilizada (cabeça, pescoço, tronco, quadril, braços e pernas em dois segmentos, mãos longas), postura levemente curvada, material que "engole" a luz, contorno frio tênue e uma casca de fumaça que deixa a borda irregular. Estados: oculta, aparecendo, observando, movendo, recuando, desaparecendo, susto. Aparecem/somem por dissolução, instantaneamente ou piscando — muitas vezes só quando o jogador não está olhando.

Aparições sem susto (trilha secundária): parada do outro lado da rua sob um poste (some ou caminha para trás de uma casa), silhueta na janela iluminada de um vizinho, perto da cerca do quintal (pode sumir quando você entra), parada no fim do corredor no escuro (some quando você desvia o olhar, recua para o banheiro ou vira a cabeça e some), cruzando uma passagem do outro lado do cômodo.

### Áudio
Todos os arquivos são normalizados (−1 dBFS de pico). Os níveis ficam numa **tabela única** (`AudioManager.MIX`: ganho, distância de referência, distância máxima, categoria). Buses: **Master** (compressor + limiter a −1 dB, protege fones) ← **Ambience** (AmbIn/AmbOut), **SFX** (SFXIn/SFXOut, Room = reverb da casa, Phone), **Horror** (compressor próprio), **Music**, **UI**. Sons de dentro ficam abafados quando você está fora e vice-versa. A proximidade pode somar no máximo +3 dB ao nível de mixagem.

Novos sons sintetizados: impactos de susto (3), grito curto, estouro da TV, respiração próxima, sussurro, batida na janela, pancadas na porta, cântico distante, drone grave, corrida, zumbido elétrico, batimento, trinco, maçaneta, louça, esfregar, saco plástico, tampa de lixeira, caixa de correio, janela correndo, botão do fogão, gás, objetos caindo.

### O culto (sem explicação)
Mais presente a cada noite: **noite 2** um altar no quarto vazio (velas acesas, tigela, o símbolo na parede, círculo de giz no chão); **noite 3** cruz invertida acima do altar, arquivo `CIRCLE.TXT` no computador ("14 HALLOWAY — pending"), cânticos também pelo telefone; **noite 4** velas acesas nos degraus das casas 6 e 9; **noite 5** círculo de velas na ilha da rotatória e o símbolo em giz no asfalto; cânticos na casa 6 até 3 vezes por noite.
Desde o início: um símbolo riscado dentro do closet, a foto da Associação em 1974 na parede da garagem (o verso lista sobrenomes do bairro), um livro de história local na estante (as últimas páginas foram cortadas), tocos de vela no canto do pátio. Correspondência a cada noite (conta de luz; carta da Associação "guardamos sua cadeira"; bilhete "não diga em voz alta, soletre — eles só ouvem palavras"; recorte sobre o incêndio de 1979 na casa nº 6; envelope vazio com o símbolo). Durante o sono: giz na porta dos fundos (noite 3), alguém a mais na foto do corredor e velas acesas na garagem (noite 4), o símbolo dentro do guarda-roupa (noite 5). Cânticos e janelas à luz de vela na casa nº 6 (Leland). A ligação entre isso, as figuras e os eventos originais **não é confirmada em lugar nenhum**.

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
- **Nights**: ver a lista, completar tarefas, dormir agora, adicionar linha estranha.
- **Audio**: tocar qualquer som a 1/5/15/40 m (mostra ganho, distância e bus), layout dos buses; medidores de pico na barra de status.
- **World**: estado do mundo, interações, reset, teleportes, teste da porta dos fundos por dentro e por fora.

### Testes automatizados
```bash
godot --headless --path . -s tests/run_tests.gd    # 62: mundo, jogador, interações, os 10 eventos, persistência, PRESS ENTER
godot --headless --path . -s tests/door_test.gd    # portas externas nos dois sentidos + trinco
godot --headless --path . -s tests/horror_test.gd  # 66: buses, tarefas reais, sono até a noite 6, figuras, 5 sustos (forçados e por gatilho real), aparições
godot --headless --path . -s tests/menu_test.gd    # menu → PLAY → mundo → sair → jogar de novo
godot --headless --path . -s tests/tasks_test.gd   # noites 1–9 fazendo TODAS as tarefas pela mira + E (inclui janelas, fogão, trancas, garagem, canecas, despertar das 3h)
godot --headless --path . -s tests/soak_test.gd    # noite 5, relógios acelerados, jogador vagando por minutos
godot --path . -s tests/screenshots.gd -- pasta    # capturas (precisa de GPU/Xvfb)
```

### Regenerar assets
```bash
pip install numpy scipy pillow     # + espeak-ng e mbrola (us1/us2/us3) para vozes e cânticos
python3 tools/gen_textures.py && python3 tools/gen_textures.py night
python3 tools/gen_audio.py
```
