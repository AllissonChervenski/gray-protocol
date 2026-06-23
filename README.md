# IHC G7 — Jogo com Oráculo (LLM)

Jogo 2D em **Godot 4.6** com um "Oráculo": uma IA que, a cada poucos segundos,
avalia o estado do jogador (vida, sanidade, inimigos por perto) e decide **ajudar**
ou **sabotar**, gerando uma frase via um modelo de linguagem local (**Ollama /
`llama3.2:3b`**).

## Arquitetura

São dois processos:

- **Jogo (Godot)** — roda **nativo** na máquina, usando GPU/áudio/input normalmente.
- **Oráculo (Ollama + modelo)** — roda em um **container Docker**, exposto em
  `127.0.0.1:11434`. O jogo consome essa API por HTTP (ver `oraculo_3.gd`).

Esse modelo híbrido funciona em **qualquer SO** (Linux, macOS, Windows) e mantém o
jogo fluido, já que só o LLM fica conteinerizado.

## Pré-requisitos

O é necessário **apenas duas coisas instaladas**:

1. **Docker** (com Docker Compose v2) — cuida do Ollama e baixa o modelo sozinho.
2. **Godot 4.6** — o script localiza o binário automaticamente (veja abaixo).

> não é necessário instalar Ollama ou baixar o modelo na mão, o container faz isso no
> primeiro `up`.

### Como o script acha o Godot

O `run.sh`/`run.bat` procura o Godot nesta ordem:

1. **Variável `GODOT_BIN`** (tem prioridade) — aponte direto pro binário:
   ```bash
   GODOT_BIN=~/Godot/Godot_v4.6-stable_linux.x86_64 ./run.sh
   ```
2. **`godot` no PATH**, se existir.
3. **Auto-detecção** em locais comuns (`~/Godot/Godot_v4.*`, `~/Downloads/...`,
   `/Applications/Godot.app` no macOS, `%USERPROFILE%\Godot\...` no Windows, etc.).

Ou seja: se o seu Godot está num lugar razoável, **não precisa configurar nada**.
Só use `GODOT_BIN` (ou coloque no PATH) se a auto-detecção não encontrar.

## Como rodar (um comando)

Clone o repositório, entre na pasta e execute:

**Linux / macOS:**
```bash
./run.sh
```

**Windows:**
```bat
run.bat
```

O script:
1. confere se `docker` e `godot` estão disponíveis;
2. sobe o container do Ollama e **baixa o modelo** (na 1ª vez, ~2 GB — pode demorar);
3. espera o modelo ficar pronto (healthcheck);
4. lança o jogo;
5. ao fechar o jogo, encerra o container.

> A partir da segunda execução o modelo já fica em cache (volume Docker
> `ollama-models`), então sobe rápido.

## Detalhes / observações

- Para subir/derrubar o Oráculo manualmente, sem o jogo:
  ```bash
  docker compose up -d     # sobe
  docker compose down      # encerra
  docker compose logs -f   # acompanha o download do modelo / logs
  ```
