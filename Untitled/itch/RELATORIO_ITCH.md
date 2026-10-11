# UNTITLED — relatório do jogo para publicação no itch.io

Versão 1.0.0 · Windows 64-bit · feito em Godot 4.3 · idioma do jogo: inglês

> Para quem vai montar a página: este relatório **revela** a história e os finais (seções 4 e 5) para você entender o jogo. **Não coloque spoilers na página.** O jogo foi pensado para ser jogado às cegas: nada é explicado, os finais não são anunciados e a fita é opcional.

---

## 1. Em uma frase

Terror psicológico em primeira pessoa: você passa até cinco noites sozinho numa casa de subúrbio americano, fazendo tarefas simples de casa, enquanto alguma coisa começa a aparecer.

## 2. O que tem no jogo

- **Uma casa térrea inteira e explorável**, sem portas falsas: quartos, banheiro, lavanderia, closet, cozinha, sala, garagem, quintal. Fora dela há um cul-de-sac com vizinhos, postes, carros e uma rua que sai do bairro.
- **Tarefas reais a cada noite**, numa lista de papel que fica no criado-mudo:
  - tirar o lixo e levar até a lixeira da rua;
  - lavar os pratos com a torneira aberta;
  - pegar a correspondência;
  - fechar as janelas;
  - apagar o fogão;
  - trancar as portas;
  - apagar as luzes;
  - levar as canecas para a pia.
- **Um mundo que continua**: o que você mexe fica mexido de uma noite para outra. A casa e o bairro funcionam sozinhos (vizinhos chegando, vento, telefone, TV, cachorros) com ou sem você olhando.
- **Mais de 25 acontecimentos de terror**, sorteados e com ritmo de sobe e desce:
  - silhuetas na rua e em janelas;
  - figuras atravessando o corredor;
  - passos correndo;
  - respiração ao seu lado;
  - batidas e pancadas no vidro;
  - portas que se abrem sozinhas;
  - luzes que falham;
  - cânticos vindos de uma casa vizinha;
  - símbolos que aparecem e somem;
  - a TV ligando sozinha e mostrando coisas;
  - olhos que te seguem no escuro;
  - sustos que só começam a partir da noite 3.
- **Escalada ao longo das noites**: a noite 1 é tranquila e familiar; na noite 5 a casa fica sem energia a noite inteira.
- **Pistas narrativas espalhadas, nunca explicadas**: cartas, um livro de história local com páginas cortadas, uma foto antiga, um arquivo no computador, uma fita VHS.
- **Dois finais diferentes**, nenhum anunciado.
- **Áudio 100% original**:
  - quase tudo sintetizado por código;
  - vozes curtas feitas com espeak-ng/MBROLA;
  - posicionamento 3D e abafamento entre dentro e fora de casa.
- **Configurações**:
  - volume geral, de ambiente, de efeitos e de sustos;
  - sensibilidade do mouse;
  - campo de visão;
  - granulação;
  - filtro VHS opcional;
  - legendas;
  - inverter o mouse;
  - tela cheia.
- **Menu com um olho que acompanha o cursor.**

## 3. Controles

| Tecla | Ação |
|---|---|
| WASD / setas | andar |
| Shift | correr |
| Ctrl ou C | agachar |
| Mouse | olhar |
| E / clique esquerdo | interagir, pegar, soltar |
| Tab ou N | ler a lista de tarefas |
| Esc | pausa, configurações, sair |

## 4. As noites (SPOILER — não usar na página)

| Noite | Clima | O que acontece |
|---|---|---|
| 1 | familiar | vida normal do bairro, pequenas estranhezas, nenhum susto |
| 2 | estranho | primeiros sinais de um culto, silhuetas distantes, cânticos, um olho na TV |
| 3 | presença | figuras dentro de casa; às 3:33 você é acordado e há alguém na janela do quarto |
| 4 | paranoia | uma silhueta entra no seu quarto e deixa um bilhete no travesseiro: "Don't wake him up." |
| 5 | fim | sem luz na casa a noite inteira; na lista: "Make sure you're alone." |

## 5. Os finais (SPOILER — não usar na página)

- **FINAL 1 — The Tape**:
  - a fita "UNTITLED — 1986" fica na mesinha da sala; colocá-la no videocassete é opcional;
  - ela mostra a própria casa sendo gravada: uma pessoa passa, apaga a luz e vai dormir;
  - aparece uma figura preta, que entra no quarto da pessoa; vem um grito;
  - a figura sai correndo direto para a câmera; tela preta, "Untitled...", volta ao menu.
- **FINAL 2 — The Last Task**:
  - dormir na noite 5 sem ter visto a fita;
  - passos, a porta abre, alguém senta na cama; um sussurro: "You forgot to check the tape.";
  - susto final, tela preta, "Untitled...", volta ao menu.
- Não existe noite 6.

## 6. Dados técnicos

- **Plataforma:** Windows 10/11, 64-bit.
- **Arquivo:** um único `Untitled.exe` (~112 MB, já com todos os dados dentro). Não precisa instalar nada.
- **Placa de vídeo:** precisa suportar **Vulkan**, como praticamente qualquer GPU de 2016 para cá. Placas de vídeo integradas muito antigas podem não abrir o jogo.
- **Duração estimada:** cerca de 1 hora para chegar a um final. Isso é uma estimativa, não foi medido com jogadores.
- **Save:** não há save de partida. O jogo é feito para ser jogado de uma vez; as configurações ficam salvas.
- **O Windows SmartScreen** pode avisar "editor desconhecido", porque o .exe não tem assinatura digital. É normal em jogos indie: "Mais informações → Executar assim mesmo".

## 7. Como subir no itch.io

1. **Arquivo do jogo**:
   - extraia `Untitled-windows.7z.001` (as duas partes precisam estar na mesma pasta) para obter `Untitled.exe`;
   - compacte o `Untitled.exe` num **.zip**;
   - envie esse .zip em *Uploads*, marcando **Windows**.
2. **Kind of project:** Downloadable.
3. **Imagens** (pasta `Untitled/itch/` do repositório):
   - **capa** (Cover image, 630×500): `cover_630x500.png`;
   - **screenshots**: `screenshot_menu.png`, `screenshot_living.png`, `screenshot_kitchen.png`, `screenshot_street.png`, `screenshot_hall_figure.png` e `screenshot_note.png`.
4. **Preço:** publicar **grátis**. A licença de algumas vozes MBROLA (us1, us2, us3) só permite uso não comercial. Para cobrar, essas falas teriam de ser substituídas antes.
5. **Classificação de conteúdo:** terror, sustos repentinos, luzes piscando (flashes rápidos), temas de culto e de ocultismo. Sem sangue explícito, mas há um grito e uma cena de morte implícita.

### Campos sugeridos

- **Title:** Untitled
- **Short description / tagline:** Five nights in the same house. Do your chores. Don't ask.
- **Genre:** Interactive Fiction (ou Adventure)
- **Tags:** horror, psychological-horror, first-person, atmospheric, exploration, 3d, singleplayer, short, retro, vhs, suburban, godot
- **Content warnings:** jumpscares, flashing lights, occult themes

### Texto sugerido para a página (inglês)

> **Untitled**
>
> A quiet house at the end of a cul-de-sac. A list of chores on the nightstand. Take out the trash. Wash the dishes. Lock the doors. Turn off the lights. Go to bed.
>
> Then do it again the next night.
>
> Nothing is explained. Nobody tells you what to do beyond the list. The house and the neighbourhood keep living with or without you — and sometimes something else is there too.
>
> - A fully explorable house and street, with no fake doors
> - Real, physical chores that change from night to night
> - A world that remembers what you moved
> - Events that are never the same twice
> - Original, fully synthesized sound design
>
> Play with headphones, in the dark.
>
> *Windows 64-bit · around 1 hour · flashing lights and jumpscares*

### Texto sugerido para a página (português)

> Uma casa silenciosa no fim de uma rua sem saída. Uma lista de tarefas no criado-mudo. Tire o lixo. Lave a louça. Tranque as portas. Apague as luzes. Vá dormir.
>
> E faça tudo de novo na noite seguinte.
>
> Nada é explicado. Ninguém diz o que fazer além da lista. A casa e o bairro seguem vivos com ou sem você — e às vezes tem mais alguém lá.
>
> Jogue de fone, no escuro.

## 8. Limitações conhecidas

- O ícone do `.exe` no Windows Explorer é o padrão do Godot. O ícone da janela e da barra de tarefas é o olho.
- Não houve teste em um computador Windows real nem audição do som em fones. Os testes automáticos rodaram em Linux.
- Sem save de partida no meio do jogo.
- O texto dos bilhetes usa fontes do Windows: Segoe Print, com outras fontes do sistema como alternativa.
- O painel de debug (F1) está desligado na versão final. Para usá-lo, rode o jogo com `Untitled.exe -- --debug`.
