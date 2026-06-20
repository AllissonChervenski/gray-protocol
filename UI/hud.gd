extends CanvasLayer

# HUD: mostra as barras de vida e sanidade do jogador na tela.
# Os valores são atualizados via sinais emitidos pelo jogador (jogador.gd).

@onready var barra_vida: ProgressBar = $Control/BarraVida
@onready var barra_sanidade: ProgressBar = $Control/BarraSanidade


func _ready():
	# Espera a cena montar para garantir que o jogador já existe
	await get_tree().process_frame
	var jogador = get_tree().get_first_node_in_group("jogador")
	if not jogador:
		push_error("HUD: nenhum nó no grupo 'jogador' encontrado.")
		return

	jogador.vida_mudou.connect(_on_vida_mudou)
	jogador.sanidade_mudou.connect(_on_sanidade_mudou)

	# Inicializa as barras com os valores atuais
	_on_vida_mudou(jogador.vida, jogador.vida_maxima)
	_on_sanidade_mudou(jogador.sanidade, jogador.sanidade_maxima)


func _on_vida_mudou(atual, maximo):
	barra_vida.max_value = maximo
	barra_vida.value = atual


func _on_sanidade_mudou(atual, maximo):
	barra_sanidade.max_value = maximo
	barra_sanidade.value = atual
