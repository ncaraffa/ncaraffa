# Untitled

Jogo 3D de terror psicológico em primeira pessoa (Godot 4.3, GDScript).
Uma casa térrea num cul-de-sac suburbano americano, à noite. Nenhuma explicação, nenhum objetivo na tela, nenhum narrador. O mundo segue funcionando com ou sem o jogador.

> Este README é para quem desenvolve. Ele **revela** o funcionamento dos eventos — não leia se quiser jogar às cegas.

---

## Como abrir e jogar

1. Instale o **Godot 4.3 stable** (versão padrão, não a .NET): https://godotengine.org/download/archive/4.3-stable/
2. Abra o Godot → **Import** → selecione `Untitled/project.godot`.
3. Na primeira abertura o editor importa texturas e sons (alguns segundos).
4. Pressione **F5** (Run Project). A tela inicial mostra só **PLAY**.

### Gerar um executável Windows
`Project → Export… → Windows Desktop → Export Project` (o preset já está configurado em `export_presets.cfg`; o Godot pede para baixar os *export templates* na primeira vez). Saída: `build/Untitled.exe`, com os dados embutidos.

### Controles
| Tecla | Ação |
|---|---|
| WASD / setas | andar |
| Mouse | olhar |
| Shift | andar mais rápido |
| Ctrl / C | agachar |
| E ou clique esquerdo | interagir / soltar objeto carregado |
| Esc | pausa (libera o cursor); sai do computador / fecha uma carta |

Volume, sensibilidade, campo de visão, granulação, VHS (opcional, desligado por padrão), legendas, inverter mouse e tela cheia ficam em **settings** (menu inicial e pausa).

---

## O que existe nesta versão

**Casa** (`scripts/world/house_builder.gd`): quarto inicial, segundo quarto, banheiro, corredor, lavanderia, closet, hall de entrada, sala de estar, sala de jantar, cozinha, garagem anexa, varanda da frente, pátio dos fundos e quintal cercado (portão lateral). Portas abrem/fecham (incluindo a da geladeira e o portão da garagem), 14 interruptores controlam 15 luminárias, abajures ligam direto, cortinas abrem/fecham, torneiras correm água, cadeiras da cozinha podem ser puxadas, fotos podem ser ajeitadas, canecas/controle remoto podem ser carregados, cartas e bilhetes podem ser lidos, o telefone pode ser atendido ou tirado do gancho, a TV liga, o computador funciona com teclado de verdade.

**Bairro** (`scripts/world/neighborhood.gd`): rua sem saída circular (Larkspur Ct) com ilha central, 8 casas vizinhas variadas (cor, telhado, garagem, venezianas, tijolo, caixa de correio com sobrenome), calçadas, meio-fio, postes com luz de sódio, gramados, arbustos, árvores, cercas, lixeiras, carros estacionados, rua de acesso de ~140 m terminando numa transversal fechada por obras (cavaletes com luzes piscando, placas ROAD CLOSED, guard-rail e mata). Os limites invisíveis ficam escondidos atrás da mata e das obras.

**Visual**: céu de fim de crepúsculo (gradiente roxo/âmbar, nuvens, estrelas, lua), luz da lua com sombras, luzes internas quentes com sombras suaves, SSAO, glow leve, névoa leve, cores levemente dessaturadas, granulação fina e vinheta; VHS opcional. Todas as texturas e sons são gerados proceduralmente por `tools/` — nenhum asset de terceiros.

**Áudio espacial**: passos do jogador por superfície (madeira, piso, grama, concreto, carpete), portas, interruptores, geladeira (ciclo do compressor), relógios com tique-taque, grilos, vento, rajadas, folhas, cães, coruja, sininho de vento, trânsito distante, carros com efeito doppler, telefone, TV, estalos da casa, canos. Sons de dentro ficam abafados quando o jogador está na rua e vice-versa (buses Indoor/Outdoor com filtro passa-baixa) e a casa tem reverberação própria.

---

## Arquitetura

```
project.godot
scenes/        main_menu.tscn, world.tscn (raízes mínimas; o mundo é construído por código)
scripts/
  core/        GameManager (configurações, fluxo, modo dev), WorldState (WorldStateManager),
               AudioManager (buses, biblioteca de sons, sons posicionais)          ← autoloads
  player/      player.gd — PlayerController + InteractionSystem
  world/       world.gd (bootstrap), house_builder.gd, house.gd, neighborhood.gd,
               neighbor_house.gd, props.gd (móveis), build.gd (B: geometria),
               mats.gd (materiais), vehicles.gd, car.gd, environment_manager.gd
  interact/    door, light_fixture, light_switch, phone, tv, computer + terminal,
               readable, pickup, picture_frame, clock, chair, faucet, garage_door, curtain
  sim/         event_director.gd, mystery_event.gd (base), ambient_manager.gd
  events/      ev_*.gd — um arquivo por acontecimento
  ui/          hud, main_menu, pause_menu, settings_panel, debug_panel
shaders/       sky, foliage, tv, crt, post
assets/        textures/*.png, audio/*.wav (gerados por tools/)
tools/         gen_textures.py, gen_audio.py
tests/         run_tests.gd, menu_test.gd, screenshots.gd
```

* **WorldState** (`core/world_state.gd`): registro de objetos por id, estado (`door/…`, `light/…`, `obj/…`, `clock/…`, `photo/…`, `tv/…`, `computer/…`, `neighbor/…`, `consequence/…`), log de eventos e de interações, *locks* de recursos, relógio do mundo (começa entre 22:41 e 23:19 e anda em tempo real).
* **EventDirector** (`sim/event_director.gd`): relógio invisível; 1º evento entre 2 e 3 min, os seguintes a cada 4–6 min (sorteado a cada vez); ordem aleatória por partida; nunca roda dois eventos que usem o mesmo objeto; depois dos dez, entra numa fase posterior com repetições mais raras (5–10 min) dos eventos repetíveis. Nada termina, não há tela de vitória.
* **AmbientActivityManager** (`sim/ambient_manager.gd`): vida normal com temporizadores próprios — janelas e varandas dos vizinhos acendendo/apagando, cães (às vezes um responde ao outro), coruja, rajadas de vento, sininho, carro distante, vizinho chegando em casa (entra na rua, estaciona e fica lá), geladeira, estalos da casa, canos, lâmpadas tremulando.

### Adicionar um evento novo
1. Crie `scripts/events/ev_algo.gd` com `extends MysteryEvent`.
2. Em `_init()`, defina `id`, `resources` (objetos que ele controla), `repeatable`.
3. Implemente `_start()`; chame `finish()` quando ele não controlar mais nada. Use `after(seg, fn)` (relógio do diretor, acelerável) para esperas longas e `await wait(seg)` para ritmo natural.
4. Adicione o caminho em `EventDirector.EVENT_SCRIPTS`. Pronto.

---

## Os dez acontecimentos (spoilers)

| # | id | O que acontece | Tipo | Variações |
|---|---|---|---|---|
| 1 | `chair` | uma das cadeiras da mesinha da cozinha fica afastada e/ou girada | persistente | puxada / girada / ambas; silenciosa ou arrastando |
| 2 | `neighbor_lights` | a casa dos Whitcomb (ou dos Leland), do outro lado, acende quase tudo de uma vez; minutos depois algumas apagam | temporário | qual casa, varanda, quantas apagam |
| 3 | `knock` | três batidas na porta (áudio espacial) | temporário/reativo | rua vazia; caixa na varanda para "D. WHITCOMB, 9 Larkspur Ct"; panfleto da associação de moradores; a varanda dos Pruitt acende logo depois; batidas na porta dos fundos |
| 4 | `phone` | o telefone toca exatamente 4 vezes; não repete | temporário/reativo | silêncio na linha; "What time do you have?"; engano ("Is Dana there?"); linha aberta com grilos e um cão — que late no bairro ao mesmo tempo |
| 5 | `car` | um sedã escuro entra, contorna a rotatória e vai embora | temporário | passa; para em frente à casa com o motor ligado; dá duas voltas; 50% de voltar minutos depois |
| 6 | `tv` | a TV da sala liga sozinha | temporário/persistente | estática; imagem rolando; tela azul "CH 03" que fica ligada até o jogador desligar |
| 7 | `footsteps` | passos com posição real percorrem um caminho e somem | temporário | corredor, sala→cozinha, cozinha→jantar, até a porta do quarto inicial, garagem, pátio de fora (evita caminhos a menos de 3 m do jogador) |
| 8 | `clock` | o relógio da cozinha passa a marcar 9 minutos a menos que os outros | persistente | raramente 11 |
| 9 | `photo` | uma foto fica torta (corredor ou sala); se endireitada, fica endireitada | persistente/reativo | ângulo, lado, de uma vez ou devagar |
| 10 | `press_enter` | o computador do quarto mostra PRESS ENTER | persistente/reativo | — |

**PRESS ENTER**: apertar Enter não faz nada (a tela só pisca). A pista está desde o início na carta presa na porta da geladeira: o pai de Dana "soletra tudo", inclusive comandos para máquinas (*S-T-A-R-T*, *O-F-F*). Digitar as letras **E N T E R** em sequência (com ou sem separadores) na tela do computador faz: a tela responde lentamente `OK.` e `the kitchen clock is right.`; uma luz em outra parte da casa se apaga com um clique de interruptor (corredor, abajur da sala, varanda ou pia — a primeira que estiver acesa); ~9 s depois, ao longe, do lado da casa dos Whitcomb, uma voz soletra *E… X… I… T*. Digitar `EXIT` no terminal desliga o computador (um comando comum, sem nada especial).

### Conexões planejadas e falsas pistas
* Reais (discretas): a mensagem do PRESS ENTER fala do relógio da cozinha (evento 8); o telefonema pergunta as horas; o cão na linha late no bairro no mesmo instante; a caixa entregue é dos Whitcomb, cuja casa acende sozinha e de onde vem a voz; o diário no computador diz que os Whitcomb estão em Tucson até novembro e que a porta do quarto da frente "fica fechada" — ela começa aberta.
* Explicações banais possíveis: o bilhete na garagem diz que o relógio da cozinha "still loses time" mesmo com pilha nova; o diário fala de um carro "provavelmente perdido"; vizinhos comuns também chegam de carro; lâmpadas tremulam; a casa estala; a geladeira liga e desliga.
* Contradições sem resposta: Dana, Ruth, "M", R. Halloway (nome nas contas), D. Whitcomb — quem mora aqui?

---

## Ferramentas de desenvolvimento

Só existem quando o jogo roda **pelo editor** ou com `--dev` (`godot --path . -- --dev`). Num executável exportado normal, nada aparece.

**F1** abre o painel: acelerar o relógio de eventos (1×/10×/60×/300×), "next event now", disparar qualquer evento individualmente (mostra por que está bloqueado, se estiver), estado do mundo completo, log de eventos com posição/local do jogador no momento, interações registradas, avisos/conflitos, simulação de ordens aleatórias, teletransporte (quarto, cozinha, sala, varanda, rotatória, fim da rua, quintal) e reset do mundo.

### Testes automatizados (headless)
```bash
godot --headless --path . -s tests/run_tests.gd   # 62 verificações: mundo, jogador, degraus, interações, terminal,
                                                  # os 10 eventos com o jogador fora de casa, persistência, PRESS ENTER,
                                                  # fase posterior
godot --headless --path . -s tests/menu_test.gd   # menu → PLAY → mundo → sair → jogar de novo
godot --path . -s tests/screenshots.gd -- pasta   # capturas de tela de pontos fixos (precisa de GPU/Xvfb)
```

### Regenerar assets
```bash
pip install numpy scipy pillow     # + espeak-ng e mbrola (vozes us1/us2/us3) para as falas
python3 tools/gen_textures.py
python3 tools/gen_audio.py         # ou: python3 tools/gen_audio.py voices
```
