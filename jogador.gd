extends CharacterBody2D

@export var speed = 150.0
@export var acceleration = 800.0
@export var friction = 1000.0
@export var tempo_para_empurrar = 0.5 # Quantos segundos ele precisa forçar antes de mover
@export var forca_empurrao_reduzida = 0.2 # 20% da velocidade normal do jogador

var cronometro_empurrao = 0.0 # Contador interno

@onready var raycast_interacao = $raycast_interacao
@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer



var esta_subindo: bool = false
var inventario: Array[ItemData] = []



func _physics_process(delta):
	
	if Input.is_action_just_pressed("ui_accept"): 
		if esta_subindo:
			tentar_descer() # Se já está em cima, a ação é descer
		else:
			tentar_interagir() # Se está no chão, a ação é tentar subir
	if esta_subindo:
		return

	# 1. Obter a direção do input (Garante vetor normalizado automaticamente)
	var input_direction = Input.get_vector("esquerda", "direita", "cima", "baixo")
	
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		raycast_interacao.target_position = input_direction * 30
		
		# --- ADICIONE ESTE BLOCO PARA A ANIMAÇÃO ---
		if input_direction.y > 0:
			animation_player.play("walk_down")
		elif input_direction.y < 0:
			# Se você tiver a de cima, coloque aqui. Se não, use a de baixo por enquanto
			animation_player.play("walk_down") 
		elif input_direction.x != 0:
			# Para os lados, você usa a de baixo e o flip_h que você já tem
			animation_player.play("walk_down")
			sprite.flip_h = input_direction.x < 0
			
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		# QUANDO PARAR: Para a animação ou volta para o frame 0
		animation_player.play("idle_baixo")
		# 4. Executa o movimento tratando colisões (importante para deslizar na caixa)
	move_and_slide()
	
	if raycast_interacao.is_colliding():
		var obj = raycast_interacao.get_collider()
		if not obj:
			return
		if obj.has_method("empurrar") and input_direction != Vector2.ZERO:
			cronometro_empurrao += delta # Começa a contar o tempo de esforço
			
			if cronometro_empurrao >= tempo_para_empurrar:
		
				# Trava em 4 direções
				var direcao_travada = Vector2.ZERO
				if abs(input_direction.x) > abs(input_direction.y):
					direcao_travada = Vector2(sign(input_direction.x), 0)
				else:
					direcao_travada = Vector2(0, sign(input_direction.y))
				
				# Envia a ordem para a caixa
				obj.empurrar(direcao_travada * (speed * forca_empurrao_reduzida))
		else:
			if cronometro_empurrao > 0:
			
				cronometro_empurrao = 0.0 # Se parar de empurrar ou desviar o olhar, reseta
	else:
		cronometro_empurrao = 0.0 # Se não houver nada na frente, reseta

	

			
var esta_em_cima: bool = false
func tentar_interagir():
	if raycast_interacao.is_colliding():
		var obj = raycast_interacao.get_collider()
		
		# 1. Checa se é algo para subir (o que você já tinha) 
		if obj.is_in_group("subivel"):
			subir_na_caixa(obj)
		
		# 2. Checa se é uma porta ou algo interativo
		elif obj.has_method("interagir"):
			obj.interagir()
			
func tentar_subir():
	# Se houver uma caixa na frente (use um RayCast2D ou Area2D)
	if raycast_interacao.is_colliding():
		var obj = raycast_interacao.get_collider()
		if obj.is_in_group("subivel"):
			subir_na_caixa(obj)

func subir_na_caixa(obj_caixa):
	esta_subindo = true
	velocity = Vector2.ZERO
	
	# 1. MUDANÇA DE PROFUNDIDADE
	# Ao colocar o z_index em 1, o jogador será desenhado SOBRE qualquer 
	# objeto que esteja no z_index 0, ignorando o Y-Sort.
	z_index = 1
	
	# Desativa a colisão para a movimentação do Tween ser limpa
	set_collision_mask_value(2, false)
	
	var ponto_destino : Vector2
	if obj_caixa.has_node("PontoTopo"):
		ponto_destino = obj_caixa.get_node("PontoTopo").global_position
	else:
		ponto_destino = obj_caixa.global_position + Vector2(0, -50) # Ajuste manual se não houver marcador

	var tween = create_tween()
	# Transição "Out" dá a sensação de que ele ganha velocidade ao subir e para suave
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Move o personagem para o ponto de cima
	tween.tween_property(self, "global_position", ponto_destino, 0.4)
	
	await tween.finished
	finalizar_subida()
	
func finalizar_subida():
	# Aqui você pode decidir se ele recupera a colisão ou se fica "intocável" em cima da caixa
	# Para o terror, talvez ele precise descer.
	print("Subida concluída!")
	# esta_subindo = false # Se você reativar isso agora, ele pode cair da caixa se a colisão voltar
func tentar_descer():
	print("Iniciando descida...")
	
	# 1. Define a direção da descida baseada para onde o jogador olha
	# Se o raycast estiver apontando para algum lugar, usamos essa direção
	var direcao_descida = raycast_interacao.target_position.normalized()
	if direcao_descida == Vector2.ZERO:
		direcao_descida = Vector2(0, 1) # Padrão: desce para baixo se estiver parado
		
	# 2. Calcula o ponto no chão (distância de 40 pixels à frente)
	var ponto_chao = global_position + (direcao_descida * 40)
	
	# 3. Tween para animação de pulo/descida
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Move o personagem para o chão
	tween.tween_property(self, "global_position", ponto_chao, 0.3)
	
	# 4. Durante a descida, esperamos o movimento acabar
	await tween.finished
	
	# 5. RESET DE ESTADOS
	z_index = 0             # Volta para a profundidade do chão [cite: 5]
	set_collision_mask_value(2, true) # Reativa colisão com a camada da caixa [cite: 3]
	esta_subindo = false    # Libera o movimento e o _physics_process [cite: 1]
	print("De volta ao chão!")

func adicionar_item(item: ItemData):
	inventario.append(item)
	print(inventario)
	print("Item coletado: ", item.nome)
	# Aqui você poderia disparar um som de "pick-up"

func remover_item(item: ItemData):
	if item in inventario:
		inventario.erase(item)
		print("Item removido do inventário: ", item.nome)
		# Aqui você poderia atualizar sua futura UI de inventário
		
func tem_item(id: String) -> bool:
	# Busca no inventário se existe algum item com esse ID
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
	return null # Return null if not found

	
