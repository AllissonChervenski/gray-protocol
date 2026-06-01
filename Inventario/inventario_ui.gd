extends CanvasLayer

# ─── CONFIGURAÇÃO ─────────────────────────────────────────────────────────────

const TOTAL_SLOTS = 6       # Quantos slots exibir (múltiplo de 3 para o grid)
const COLUNAS = 3           # Colunas do GridContainer

# ─── NÓS ──────────────────────────────────────────────────────────────────────

@onready var grid = $Control/PanelContainer/VBoxContainer/GridContainer
@onready var label_titulo = $Control/PanelContainer/VBoxContainer/Label

var jogador: CharacterBody2D = null
var slots: Array = []       # Guarda referência a cada slot gerado

# ─── INICIALIZAÇÃO ────────────────────────────────────────────────────────────

func _ready():
	visible = false

	# Pega o jogador de forma segura (espera a cena estar pronta)
	await get_tree().process_frame
	jogador = get_tree().get_first_node_in_group("jogador")

	if not jogador:
		push_error("inventario_ui: nenhum nó no grupo 'jogador' encontrado.")
		return

	_gerar_slots()


func _gerar_slots():
	# Limpa slots antigos (caso _ready rode mais de uma vez)
	for filho in grid.get_children():
		filho.queue_free()
	slots.clear()

	for i in range(TOTAL_SLOTS):
		# Container do slot
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(64, 64)

		# Ícone do item
		var icone = TextureRect.new()
		icone.name = "Icone"
		icone.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.visible = false

		panel.add_child(icone)
		grid.add_child(panel)
		slots.append(panel)


# ─── INPUT ────────────────────────────────────────────────────────────────────

func _input(event):
	if event.is_action_pressed("ui_inventory"):
		toggle_inventario()


func toggle_inventario():
	visible = !visible
	if visible:
		atualizar_slots()


# ─── ATUALIZAÇÃO DOS SLOTS ────────────────────────────────────────────────────

func atualizar_slots():
	if not jogador:
		return

	for i in range(slots.size()):
		var panel = slots[i]
		var icone: TextureRect = panel.get_node("Icone")

		if i < jogador.inventario.size():
			var item: ItemData = jogador.inventario[i]
			icone.texture = item.icone
			icone.visible = true
			# Tooltip com nome + descrição + usos restantes
			panel.tooltip_text = "%s\n%s\nUsos: %d" % [item.nome, item.descricao, item.usos]
		else:
			icone.texture = null
			icone.visible = false
			panel.tooltip_text = "Vazio"


# ─── API PÚBLICA ──────────────────────────────────────────────────────────────

# Chame isso de qualquer lugar para forçar a UI a se atualizar
# Exemplo: após coletar um item, chamar get_node("CanvasLayer").refresh()
func refresh():
	if visible:
		atualizar_slots()
