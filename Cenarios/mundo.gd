extends Node2D

# Cenas instanciadas em tempo de execução (UI e itens do mundo)
const HUD = preload("res://UI/hud.tscn")
const GAME_OVER = preload("res://UI/game_over.tscn")
const ITEM_COLETAVEL = preload("res://Itens/item_coletavel.tscn")


func _ready() -> void:
	# Interface de vida/sanidade e tela de morte
	add_child(HUD.instantiate())
	add_child(GAME_OVER.instantiate())

	# Coloca a arma no chão, perto de onde o jogador começa (~Vector2(6, -36))
	var arma_no_chao = ITEM_COLETAVEL.instantiate()
	arma_no_chao.position = Vector2(60, -36)
	add_child(arma_no_chao)
