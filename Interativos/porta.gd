extends StaticBody2D

@export var esta_trancada: bool = false
@export var id_da_chave: String = "Chave da Biblioteca" # Caso precise de uma chave específica

var esta_aberta: bool = false
@export var fechavel: bool = true
@onready var animation_player = $AnimationPlayer
@onready var collision = $CollisionShape2D
@onready var colisao_fisica = $CorpoFisico/ColisaoFisica
@onready var colisao_interacao = $ColisaoInteracao

# Esta é a função que o jogador vai chamar
func interagir():
	if esta_trancada and not esta_aberta:
		tocar_som_trancado()
		print("Está trancada...")
		var jogador = get_tree().get_first_node_in_group("jogador")
		if jogador and jogador.tem_item(id_da_chave):
			print("Você usou a ", id_da_chave)
			var item_usado = jogador.get_item(id_da_chave)
			item_usado.usos = item_usado.usos - 1
			if item_usado.usos < 1:
				jogador.remover_item(item_usado)
			esta_trancada = false
			abrir_porta()
	else:
		if esta_aberta:
			fechar_porta()
		else:
			abrir_porta()

func abrir_porta():
		esta_aberta = true
		#esta_trancada = false
		animation_player.play("abrir")
		# Desativamos a colisão para o jogador passar
		colisao_fisica.set_deferred("disabled", true)

	

func fechar_porta():
	if fechavel:
		esta_aberta = false
		animation_player.play("fechar")
		# Reativamos a colisão
		colisao_fisica.set_deferred("disabled", false)

func tocar_som_trancado():
	# Aqui você colocaria seu AudioStreamPlayer
	pass
