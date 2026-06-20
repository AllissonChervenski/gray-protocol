# Áudio do jogo — como funciona e como trocar os sons

## Como funciona

Todo o áudio passa por um autoload chamado **`AudioManager`** (`Audio/audio_manager.gd`),
registrado em `project.godot` (`[autoload]`). De qualquer script dá para tocar:

- Efeito sonoro: `AudioManager.sfx("nome")`
- Música: `AudioManager.tocar_musica()` / `AudioManager.parar_musica()`

A música de fundo começa sozinha quando o jogo abre (no `_ready()` do AudioManager) e
toca em loop.

## Os arquivos atuais são PLACEHOLDERS

Os `.wav` desta pasta são sons sintéticos simples (bipes/ruídos), só para o sistema
funcionar. **Para trocar pelos sons definitivos, basta substituir o arquivo mantendo o
mesmo nome.** Não precisa mexer no código. Formatos aceitos pela Godot: `.wav` e `.ogg`
(se trocar a extensão, ajuste o `preload(...)` no `audio_manager.gd`).

## Tabela de sons (nome do arquivo → quando toca)

| Arquivo | Evento que dispara | Onde no código |
|---|---|---|
| `golpe.wav` | Jogador ataca (J / clique) | `jogador.gd` → `atacar()` |
| `impacto.wav` | Golpe acerta o inimigo | `inimigo.gd` → `tomar_dano()` |
| `dano_jogador.wav` | Jogador leva dano | `jogador.gd` → `tomar_dano()` |
| `morte_jogador.wav` | Jogador morre | `jogador.gd` → `morrer()` |
| `morte_inimigo.wav` | Inimigo é derrotado | `inimigo.gd` → `morrer()` |
| `coleta.wav` | Coletar qualquer item (arma, chave) | `jogador.gd` → `adicionar_item()` |
| `porta_abrir.wav` | Porta abre | `porta.gd` → `abrir_porta()` |
| `porta_fechar.wav` | Porta fecha | `porta.gd` → `fechar_porta()` |
| `porta_trancada.wav` | Tenta abrir porta trancada | `porta.gd` → `tocar_som_trancado()` |
| `passo.wav` | A cada passo ao andar | `jogador.gd` → `_processar_passos()` |
| `musica_ambiente.wav` | Música de fundo (loop) | `audio_manager.gd` → `tocar_musica()` |

## Onde conseguir sons livres (gratuitos)

Use sons com licença livre (CC0 de preferência) e **guarde o crédito/licença** quando exigido:

- **Kenney** — https://kenney.nl/assets?q=audio (CC0, ótimos pacotes de SFX de jogo)
- **OpenGameArt** — https://opengameart.org/ (filtre por CC0; tem SFX e músicas)
- **freesound.org** — https://freesound.org/ (conferir a licença de cada som)
- **Pixabay (música)** — https://pixabay.com/music/ (uso livre)

Dica: baixe, renomeie para o nome exato da tabela acima e jogue na pasta `Audio/`,
sobrescrevendo o placeholder.

## Ajustes rápidos

- Volume geral de efeitos e música: variáveis `volume_sfx` e `volume_musica` no
  `audio_manager.gd` (em dB; valores negativos = mais baixo).
- Velocidade dos passos: `intervalo_passo` em `jogador.gd`.
