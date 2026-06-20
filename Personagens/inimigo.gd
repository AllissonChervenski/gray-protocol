extends CharacterBody2D
class_name InimigoBase
@export var velocidade: float = 80.0 #mais lento que o jogador (120)
@export var dano_ataque: int = 20
@export var distancia_visao: float = 150.0

# ==========================================
# VIDA DO INIMIGO (para poder ser derrotado em combate)
# ==========================================
@export var vida_maxima: int = 60
var vida: int = vida_maxima

# Empurrão (knockback) ao ser atingido
@export var forca_knockback: float = 180.0
@export var amortecimento_knockback: float = 600.0
var knockback: Vector2 = Vector2.ZERO

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
func _physics_process(delta):
	if not jogador: return
	var distancia = global_position.distance_to(jogador.global_position)

	if distancia < distancia_visao:
		perseguindo = true
	elif distancia > distancia_visao * 1.5:
		perseguindo = false

	# Velocidade de perseguição (ou parado se não estiver perseguindo)
	if perseguindo:
		var direcao = global_position.direction_to(jogador.global_position)
		velocity = direcao * velocidade
	else:
		velocity = Vector2.ZERO

	# Soma o empurrão e o amortece gradualmente a cada frame
	velocity += knockback
	knockback = knockback.move_toward(Vector2.ZERO, amortecimento_knockback * delta)

	move_and_slide()
		
func _on_area_ataque_body_entered(body):
	if body.is_in_group("jogador"):
		if body.has_method("tomar_dano"):
			body.tomar_dano(dano_ataque)
			body.perder_sanidade(10)

# ==========================================
# RECEBER DANO E MORRER (chamado pelo golpe do jogador)
# ==========================================
func tomar_dano(quantidade: int) -> void:
	vida -= quantidade
	print("Inimigo tomou ", quantidade, " de dano. Vida restante: ", vida)
	AudioManager.sfx("impacto")
	_piscar_dano()
	# Empurra o inimigo para longe do jogador
	if jogador:
		knockback = (global_position - jogador.global_position).normalized() * forca_knockback
	if vida <= 0:
		morrer()

# Feedback visual: pisca em vermelho e volta ao normal
func _piscar_dano() -> void:
	modulate = Color(1, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)

func morrer() -> void:
	print("Inimigo derrotado!")
	AudioManager.sfx("morte_inimigo")
	queue_free()
			
# No script do Inimigo Cego (inimigo_cego.gd)
var dados_oraculo = {
	"nome_alvo": "Criatura Desconhecida",
	"ajuda_fatos": ["Forma de vida hostil padrão."],
	"ajuda_conselhos": ["Mantenha distância e evite contato."],
	"sabota_fatos": ["Alvo frágil e inofensivo."],
	"sabota_conselhos": ["Pode ser ignorado com segurança."]
}

	
