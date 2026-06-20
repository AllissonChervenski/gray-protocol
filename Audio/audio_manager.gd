extends Node

# Gerente de áudio global (autoload). Centraliza efeitos sonoros e música.
# Uso de qualquer script:
#   AudioManager.sfx("golpe")
#   AudioManager.tocar_musica()  /  AudioManager.parar_musica()

@export var volume_sfx: float = -6.0     # volume dos efeitos (em dB)
@export var volume_musica: float = -14.0 # volume da música (em dB)

# Sons pré-carregados. As chaves são os nomes usados em sfx("...").
var _sons := {
	"golpe":          preload("res://Audio/golpe.wav"),
	"impacto":        preload("res://Audio/impacto.wav"),
	"dano_jogador":   preload("res://Audio/dano_jogador.wav"),
	"morte_jogador":  preload("res://Audio/morte_jogador.wav"),
	"morte_inimigo":  preload("res://Audio/morte_inimigo.wav"),
	"coleta":         preload("res://Audio/coleta.wav"),
	"porta_abrir":    preload("res://Audio/porta_abrir.wav"),
	"porta_fechar":   preload("res://Audio/porta_fechar.wav"),
	"porta_trancada": preload("res://Audio/porta_trancada.wav"),
	"passo":          preload("res://Audio/passo.wav"),
	"game_over":      preload("res://Audio/game_over.wav"),
}

const MUSICA = preload("res://Audio/musica_ambiente.ogg")

var _player_musica: AudioStreamPlayer


func _ready() -> void:
	# Mantém o áudio tocando mesmo com o jogo pausado (ex.: tela de Game Over)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_musica = AudioStreamPlayer.new()
	add_child(_player_musica)
	# Música de fundo começa assim que o jogo abre (global, em qualquer cena)
	tocar_musica()


# Corta a música e toca o som de Game Over (clima de horror).
func tocar_game_over() -> void:
	parar_musica()
	sfx("game_over")


# Toca um efeito sonoro pelo nome. Cada chamada cria um player temporário,
# permitindo sons sobrepostos sem cortar uns aos outros.
func sfx(nome: String) -> void:
	var stream = _sons.get(nome)
	if stream == null:
		push_warning("AudioManager: som desconhecido '%s'" % nome)
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_sfx
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func tocar_musica() -> void:
	if _player_musica == null:
		return
	_player_musica.stream = MUSICA
	_player_musica.volume_db = volume_musica
	if not _player_musica.finished.is_connected(_repetir_musica):
		_player_musica.finished.connect(_repetir_musica)
	_player_musica.play()


func parar_musica() -> void:
	if _player_musica:
		_player_musica.stop()


# Loop simples: quando a faixa termina, toca de novo.
func _repetir_musica() -> void:
	if _player_musica:
		_player_musica.play()


# Para tudo ao fechar o jogo, evitando avisos de "recursos em uso na saída".
func _exit_tree() -> void:
	if _player_musica:
		_player_musica.stop()
	for filho in get_children():
		if filho is AudioStreamPlayer:
			filho.stop()
