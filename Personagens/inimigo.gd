extends CharacterBody2D
class_name InimigoBase
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
	add_to_group("inimigo")
 # Replace with function body.
	
	# CHAMA O ORÁCULO PARA ESCANEAR ESTE INIMIGO ESPECÍFICO!
	var oraculo = get_tree().get_first_node_in_group("oraculo") # Certifique-se de que o nó do oráculo está no grupo "oraculo"
	if oraculo:
		oraculo.call_deferred("escanear_ambiente_e_jogador", self)


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
			
# No script do Inimigo Cego (inimigo_cego.gd)
var dados_oraculo = {
	"nome_alvo": "Criatura Desconhecida",
	"ajuda_fatos": ["Forma de vida hostil padrão."],
	"ajuda_conselhos": ["Mantenha distância e evite contato."],
	"sabota_fatos": ["Alvo frágil e inofensivo."],
	"sabota_conselhos": ["Pode ser ignorado com segurança."]
}

	
