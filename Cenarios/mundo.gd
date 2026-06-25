extends Node2D

# Cenas instanciadas em tempo de execução (UI e itens do mundo)
const HUD = preload("res://UI/hud.tscn")
const GAME_OVER = preload("res://UI/game_over.tscn")



func _ready() -> void:
	# Interface de vida/sanidade e tela de morte
	add_child(HUD.instantiate())
	add_child(GAME_OVER.instantiate())

	# Coloca a arma no chão, perto de onde o jogador começa (~Vector2(6, -36))
