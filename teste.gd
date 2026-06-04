extends Node2D

@onready var llm = $GDLlama # Ajuste o nome se precisar

func _ready():
	# Vamos dar 2 segundos para o motor carregar e depois forçar a fala
	await get_tree().create_timer(2.0).timeout
	print("Tentando ligar o motor da IA...")
	llm.run_generate_text("Diga 'Olá Mundo' e nada mais.", "", "")
	print("Motor aceitou o comando!")
