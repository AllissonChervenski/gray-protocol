extends StaticBody2D

@export var dados: ItemData

func interagir():
	# Busca o jogador na cena (ou via sinal)
	var jogador = get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.adicionar_item(dados)
		queue_free() # Remove o item do mapa após coletar
