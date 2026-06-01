extends CharacterBody2D

@export var velocidade: float = 80.0 #mais lento que o jogador (120)
@export var dano_ataque: int = 20
@export var distancia_visao: float = 150.0

var jogador: Node2D
var perseguindo: bool = false

@onready var area_ataque = $AreaAtaque

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Encontra o jogador
	jogador = get_tree().get_first_node_in_group("jogador")
	
	area_ataque.body_entered.connect(_on_area_ataque_body_entered)
 # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	if not jogador: return
	var distancia = global_position.distance_to(jogador.global_position)
	
	if distancia < distancia_visao:
		perseguindo = true
	elif distancia > distancia_visao * 1.5:
		perseguindo = false
		
	if perseguindo:
		var direcao = global_position.direction_to(jogador.global_position)
		velocity = direcao * velocidade
		move_and_slide()
		
func _on_area_ataque_body_entered(body):
	if body.is_in_group("jogador"):
		if body.has_method("tomar_dano"):
			body.tomar_dano(dano_ataque)
			body.perder_sanidade(10)
	
