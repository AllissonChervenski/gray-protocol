extends CanvasLayer

@onready var grid = $Control/PanelContainer/VBoxContainer/GridContainer
@onready var jogador = get_tree().get_first_node_in_group("jogador")

func _ready():
	visible = false

func _input(event):
	if event.is_action_pressed("ui_inventory"):
		toggle_inventory()

func toggle_inventory():
	visible = !visible
	if visible:
		atualizar_slots()

func atualizar_slots():
	# Pegamos todos os slots que já estão no Grid
	var slots = grid.get_children()
	
	# Percorremos os 6 slots fixos
	for i in range(slots.size()):
		var slot_atual = slots[i]
		var icone_rect = slot_atual.get_node("Icone")
		
		# Verificamos se o jogador tem um item para este índice
		if i < jogador.inventario.size():
			var item = jogador.inventario[i]
			icone_rect.texture = item.icone
			slot_atual.tooltip_text = item.nome + "\n" + item.descricao
			icone_rect.visible = true # Mostra o ícone
		else:
			# Slot vazio
			icone_rect.texture = null
			slot_atual.tooltip_text = "Vazio"
			icone_rect.visible = false # Esconde o ícone, mas mantém o slot visível
