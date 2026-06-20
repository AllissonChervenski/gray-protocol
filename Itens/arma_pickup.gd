extends Area2D

# Pega o item automaticamente quando o jogador chega perto.
# Usa distância (não depende de camadas de colisão, que no projeto não estão
# configuradas — o jogador está em collision_layer = 0).

@export var dados: ItemData
@export var raio_coleta: float = 20.0

var jogador: Node2D


func _ready():
	jogador = get_tree().get_first_node_in_group("jogador")


func _physics_process(_delta):
	if not jogador:
		jogador = get_tree().get_first_node_in_group("jogador")
		return
	if global_position.distance_to(jogador.global_position) <= raio_coleta:
		jogador.adicionar_item(dados)
		print("Item coletado: ", dados.nome)
		queue_free()
