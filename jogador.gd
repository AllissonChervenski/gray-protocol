extends CharacterBody2D

@export var speed = 150.0
@export var acceleration = 800.0
@export var friction = 1000.0

@onready var raycast_interacao = $raycast_interacao
@onready var sprite = $Sprite2D

func _physics_process(delta):
	# 1. Obter a direção do input (Garante vetor normalizado automaticamente)
	var input_direction = Input.get_vector("esquerda", "direita", "cima", "baixo")
	
	# 2. Lógica de Movimentação e Inércia
	if input_direction != Vector2.ZERO:
		# Acelera em direção ao input
		velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		raycast_interacao.target_position = input_direction * 30
		# 3. Orientação do Sprite (Feedback Visual)
		if input_direction.x != 0:
			sprite.flip_h = input_direction.x < 0
	else:
		# Aplica atrito para parar suavemente
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		# 4. Executa o movimento tratando colisões (importante para deslizar na caixa)
	move_and_slide()
	
	if Input.is_action_just_pressed("ui_accept"): # 'ui_accept' costuma ser Espaço/Enter
		tentar_subir()

	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var obj = collision.get_collider()
		
		# Se o objeto tiver o método "empurrar", nós o chamamos
		if obj.has_method("empurrar"):
			# Passamos a direção do jogador e a força
			obj.empurrar(-collision.get_normal() * (speed * 0.5))
			
var esta_em_cima: bool = false

func tentar_subir():
	# Se houver uma caixa na frente (use um RayCast2D ou Area2D)
	if raycast_interacao.is_colliding():
		var obj = raycast_interacao.get_collider()
		if obj.is_in_group("subivel"):
			subir_na_caixa(obj.global_position)

func subir_na_caixa(pos_caixa):
	esta_em_cima = true
	z_index = 1 # Fica visualmente acima
	
	# Desativa colisão com a camada da caixa (ex: layer 2)	
	set_collision_mask_value(2, false) 
	
	# Tween para mover o jogador suavemente para cima da caixa
	var tween = create_tween()
	tween.tween_property(self, "global_position", pos_caixa, 0.3)
