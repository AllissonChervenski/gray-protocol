extends CharacterBody2D

@export var speed = 150.0
@export var acceleration = 800.0
@export var friction = 1000.0
@export var tempo_para_empurrar = 0.5
@export var forca_empurrao_reduzida = 0.2

var cronometro_empurrao = 0.0
var esta_subindo: bool = false
var inventario: Array[ItemData] = []

@onready var raycast_interacao = $raycast_interacao
@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer

# Guarda a última direção para o idle ficar correto
var ultima_direcao: String = "baixo"

func _physics_process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		if esta_subindo:
			tentar_descer()
		else:
			tentar_interagir()

	if esta_subindo:
		return

	var input_direction = Input.get_vector("esquerda", "direita", "cima", "baixo")

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		raycast_interacao.target_position = input_direction * 30
		_atualizar_animacao_movimento(input_direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		animation_player.play("idle_" + ultima_direcao)

	move_and_slide()

	# Lógica de empurrão DEPOIS do move_and_slide
	if raycast_interacao.is_colliding():
		var obj = raycast_interacao.get_collider()
		if not obj:
			cronometro_empurrao = 0.0
			return

		if obj.has_method("empurrar") and input_direction != Vector2.ZERO:
			cronometro_empurrao += delta

			if cronometro_empurrao >= tempo_para_empurrar:
				var direcao_travada = Vector2.ZERO
				if abs(input_direction.x) > abs(input_direction.y):
					direcao_travada = Vector2(sign(input_direction.x), 0)
				else:
					direcao_travada = Vector2(0, sign(input_direction.y))

				obj.empurrar(direcao_travada * (speed * forca_empurrao_reduzida))
		else:
			cronometro_empurrao = 0.0
	else:
		cronometro_empurrao = 0.0


func _atualizar_animacao_movimento(dir: Vector2):
	# Decide qual animação tocar baseado na direção dominante
	if abs(dir.y) >= abs(dir.x):
		# Movimento vertical é dominante
		if dir.y > 0:
			ultima_direcao = "baixo"
			sprite.flip_h = false
			animation_player.play("walk_down")
		else:
			ultima_direcao = "cima"
			sprite.flip_h = false
			# Se não tiver walk_up ainda, usa walk_down espelhado verticalmente
			if animation_player.has_animation("walk_up"):
				animation_player.play("walk_up")
			else:
				animation_player.play("walk_down")
	else:
		# Movimento horizontal é dominante
		# Usamos walk_right e espelhamos para a esquerda
		if dir.x > 0:
			ultima_direcao = "direita"
			sprite.flip_h = false
			if animation_player.has_animation("walk_right"):
				animation_player.play("walk_right")
			else:
				animation_player.play("walk_down")
		else:
			ultima_direcao = "esquerda"
			sprite.flip_h = true
			if animation_player.has_animation("walk_right"):
				animation_player.play("walk_right")
			else:
				animation_player.play("walk_down")


# ─── INTERAÇÃO ────────────────────────────────────────────────────────────────

func tentar_interagir():
	if raycast_interacao.is_colliding():
		var obj = raycast_interacao.get_collider()
		if not obj:
			return

		if obj.is_in_group("subivel"):
			subir_na_caixa(obj)
		elif obj.has_method("interagir"):
			obj.interagir()


# ─── SUBIR / DESCER ───────────────────────────────────────────────────────────

func subir_na_caixa(obj_caixa):
	esta_subindo = true
	velocity = Vector2.ZERO
	z_index = 1
	set_collision_mask_value(2, false)

	var ponto_destino: Vector2
	if obj_caixa.has_node("PontoTopo"):
		ponto_destino = obj_caixa.get_node("PontoTopo").global_position
	else:
		ponto_destino = obj_caixa.global_position + Vector2(0, -50)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", ponto_destino, 0.4)
	await tween.finished
	print("Subida concluída!")


func tentar_descer():
	var direcao_descida = raycast_interacao.target_position.normalized()
	if direcao_descida == Vector2.ZERO:
		direcao_descida = Vector2(0, 1)

	var ponto_chao = global_position + (direcao_descida * 40)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", ponto_chao, 0.3)
	await tween.finished

	z_index = 0
	set_collision_mask_value(2, true)
	esta_subindo = false
	print("De volta ao chão!")


# ─── INVENTÁRIO ───────────────────────────────────────────────────────────────

func adicionar_item(item: ItemData):
	inventario.append(item)
	print("Item coletado: ", item.nome)

func remover_item(item: ItemData):
	if item in inventario:
		inventario.erase(item)
		print("Item removido: ", item.nome)

func tem_item(id: String) -> bool:
	for item in inventario:
		if item.id_unico == id:
			return true
	return false

func remover_item_por_id(id: String):
	for item in inventario:
		if item.id_unico == id:
			inventario.erase(item)
			break

func get_item(target_nome: String) -> ItemData:
	for item in inventario:
		if item.nome == target_nome:
			return item
	return null
