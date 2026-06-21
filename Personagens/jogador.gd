extends CharacterBody2D
class_name JogadorBase

# Sinais para o HUD e a tela de Game Over reagirem às mudanças de status
signal vida_mudou(atual, maximo)
signal sanidade_mudou(atual, maximo)
signal morreu

@export var acceleration = 800.0
@export var friction = 1000.0
@export var tempo_para_empurrar = 0.5
@export var forca_empurrao_reduzida = 0.2


# ==========================================
# STATUS DO JOGADOR
# ==========================================
@export var vida_maxima: int = 100
@export var vida: int = vida_maxima

@export var sanidade_maxima: int = 100
@export var sanidade: int = sanidade_maxima

# ==========================================
# MOVIMENTAÇÃO E FUGA
# ==========================================
@export var velocidade_caminhada: float = 120.0
@export var velocidade_corrida: float = 220.0
var speed: float = velocidade_caminhada
var esta_correndo: bool = false

# ==========================================
# COMBATE CORPO A CORPO (golpe na direção em que o jogador olha)
# ==========================================
@export var dano_golpe: int = 20          # dano causado por golpe
@export var alcance_golpe: float = 40.0   # distância máxima que o golpe alcança
@export var cooldown_golpe: float = 0.4   # tempo (s) entre um golpe e outro
var pode_atacar: bool = true

# Invulnerabilidade temporária após tomar dano (i-frames), p/ não levar dano em sequência
@export var tempo_invulneravel: float = 0.6
var invulneravel: bool = false

# Trava a animação de andar/parado enquanto o golpe toca
var atacando: bool = false

# ========================================
# Variaveis do mundo
# ========================================
var inimigos_perto: int = 0


var cronometro_empurrao = 0.0
var esta_subindo: bool = false
var inventario: Array[ItemData] = []

@onready var raycast_interacao = $raycast_interacao
@onready var anim = $AnimatedSprite2D

# Guarda a última direção para o idle ficar correto
var ultima_direcao: String = "baixo"

# Som de passos: toca um "passo" a cada intervalo enquanto anda
@export var intervalo_passo: float = 0.35
var tempo_passo: float = 0.0

func _ready():
	# Sincroniza o HUD com os valores iniciais de vida e sanidade
	vida_mudou.emit(vida, vida_maxima)
	sanidade_mudou.emit(sanidade, sanidade_maxima)


func _physics_process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		if esta_subindo:
			tentar_descer()
		else:
			tentar_interagir()

	# Ataque corpo a corpo: só virado para a frente (a arte de ataque é só de frente),
	# precisa da arma e não funciona em cima de uma caixa.
	if Input.is_action_just_pressed("atacar") and pode_atacar and not esta_subindo:
		if not tem_item("arma"):
			print("Você não tem uma arma para atacar.")
		elif ultima_direcao == "baixo":
			atacar()
		else:
			print("Só é possível atacar virado para a frente.")

	if esta_subindo:
		return

	var input_direction = Input.get_vector("esquerda", "direita", "cima", "baixo")

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		raycast_interacao.target_position = input_direction * 30
		_atualizar_animacao_movimento(input_direction)
		_processar_passos(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if not atacando:
			_tocar_anim("idle")
		tempo_passo = 0.0

	move_and_slide()

	# Checa se o jogador está segurando o botão de correr E está se movendo
	if Input.is_action_pressed("correr") and input_direction != Vector2.ZERO:
		speed = velocidade_corrida
		esta_correndo = true
		anim.speed_scale = 1.5 # Acelera a animação da perna
	else:
		speed = velocidade_caminhada
		esta_correndo = false
		anim.speed_scale = 1.0 # Velocidade normal

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
	# Define a direção do olhar (também usada pelo cone de ataque)
	if abs(dir.y) >= abs(dir.x):
		ultima_direcao = "baixo" if dir.y > 0 else "cima"
	else:
		ultima_direcao = "direita" if dir.x > 0 else "esquerda"
	if not atacando:
		_tocar_anim("walk")

# Toca a animação certa pela direção e estado (com/sem barra).
# A arte de lado olha para a direita; "esquerda" usa a mesma espelhada (flip_h).
# Lado e costas ainda não têm versão "parado", então o idle deles é uma pose fixa.
func _tocar_anim(acao: String):
	var com = tem_item("arma")
	match ultima_direcao:
		"baixo":
			anim.flip_h = false
			if acao == "walk":
				anim.play("walk_baixo_com" if com else "walk_baixo_sem")
			else:
				anim.play("idle_baixo_com" if com else "idle_baixo_sem")
		"cima":
			anim.flip_h = false
			if acao == "walk":
				anim.play("walk_cima_com" if com else "walk_cima_sem")
			else:
				anim.play("idle_cima_com" if com else "idle_cima")
		_:  # direita / esquerda
			var dir_d = (ultima_direcao == "direita")
			if acao == "walk":
				# Lado tem quadros próprios para cada direção (não espelha)
				anim.flip_h = false
				if com:
					anim.play("walk_lado_com_dir" if dir_d else "walk_lado_com_esq")
				else:
					anim.play("walk_lado_sem_dir" if dir_d else "walk_lado_sem_esq")
			else:
				# Parado de lado: pose fixa virada para a direção certa (com/sem barra)
				if com:
					anim.flip_h = false
					anim.play("idle_lado_com_dir" if dir_d else "idle_lado_com_esq")
				else:
					anim.flip_h = not dir_d
					anim.play("idle_lado")


# Toca o som de passos em intervalos enquanto o jogador anda (mais rápido correndo).
func _processar_passos(delta: float):
	var intervalo = intervalo_passo * (0.6 if esta_correndo else 1.0)
	tempo_passo += delta
	if tempo_passo >= intervalo:
		tempo_passo = 0.0
		AudioManager.sfx("passo")


# ─── COMBATE ──────────────────────────────────────────────────────────────────

# Converte a direção que o jogador está olhando (texto) para um vetor.
func _direcao_para_vetor() -> Vector2:
	match ultima_direcao:
		"cima":     return Vector2.UP
		"baixo":    return Vector2.DOWN
		"esquerda": return Vector2.LEFT
		"direita":  return Vector2.RIGHT
		_:          return Vector2.DOWN

# Golpeia inimigos que estejam à frente, dentro do alcance.
func atacar():
	pode_atacar = false
	atacando = true
	var direcao_golpe = _direcao_para_vetor()
	print("Golpe! Direção: ", ultima_direcao)
	# Animação de ataque (arte de frente por enquanto, em qualquer direção)
	anim.flip_h = false
	anim.play("atacar_baixo")
	AudioManager.sfx("golpe")

	for inimigo in get_tree().get_nodes_in_group("inimigo"):
		# O grupo "inimigo" pode conter nós sem vida (ex.: o CollisionShape);
		# só acerta quem souber tomar dano.
		if not inimigo.has_method("tomar_dano"):
			continue
		var para_inimigo = global_position.direction_to(inimigo.global_position)
		var distancia = global_position.distance_to(inimigo.global_position)
		# (a) está dentro do alcance E (b) está no cone à frente do jogador
		if distancia <= alcance_golpe and para_inimigo.dot(direcao_golpe) > 0.3:
			inimigo.tomar_dano(dano_golpe)

	# Espera a animação do golpe terminar antes de voltar a andar
	await anim.animation_finished
	atacando = false
	# Cooldown: espera antes de poder atacar de novo
	await get_tree().create_timer(cooldown_golpe).timeout
	pode_atacar = true

# Desenha um arco branco curto à frente, na direção do golpe, e o some rapidinho.
func _mostrar_golpe(direcao: Vector2):
	var arco = Line2D.new()
	arco.width = 4.0
	arco.default_color = Color(1, 1, 1, 0.9)
	# Monta um pequeno arco (~90°) perpendicular à direção do golpe
	var angulo_base = direcao.angle()
	for i in range(7):
		var t = lerp(-0.4, 0.4, i / 6.0)  # de -0.4 a +0.4 rad
		arco.add_point(Vector2(alcance_golpe, 0).rotated(angulo_base + t))
	add_child(arco)
	# Some por transparência e depois se remove
	var tween = create_tween()
	tween.tween_property(arco, "modulate:a", 0.0, 0.15)
	tween.tween_callback(arco.queue_free)


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
	AudioManager.sfx("coleta")

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
	
	
	# ==========================================
# FUNÇÕES DE STATUS (Dano e Sanidade)
# ==========================================
func tomar_dano(quantidade: int):
	# Durante a invulnerabilidade, ignora o dano
	if invulneravel:
		return
	vida -= quantidade
	if vida < 0:
		vida = 0
	print("Jogador tomou ", quantidade, " de dano. Vida: ", vida)
	vida_mudou.emit(vida, vida_maxima)
	AudioManager.sfx("dano_jogador")
	_piscar_dano()
	_ativar_invulnerabilidade()
	if vida <= 0:
		morrer()

# Feedback visual: o jogador pisca em vermelho ao tomar dano
func _piscar_dano():
	modulate = Color(1, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)

# Liga a invulnerabilidade por um curto período (i-frames)
func _ativar_invulnerabilidade():
	invulneravel = true
	await get_tree().create_timer(tempo_invulneravel).timeout
	invulneravel = false

func perder_sanidade(quantidade: int):
	sanidade -= quantidade
	if sanidade < 0: sanidade = 0
	print("A sua mente fraqueja... Sanidade: ", sanidade)
	sanidade_mudou.emit(sanidade, sanidade_maxima)

func morrer():
	print("Você morreu.")
	AudioManager.sfx("morte_jogador")
	morreu.emit()  # A tela de Game Over escuta este sinal

# ==========================================
# SINAIS DO SENSOR DE INIMIGOS
# ==========================================
func _on_sensor_inimigos_body_entered(body):
	# Garante que o que entrou no radar é realmente um inimigo
	if body.is_in_group("inimigo"):
		inimigos_perto += 1
		print("Inimigo detectado! Total por perto: ", inimigos_perto)

func _on_sensor_inimigos_body_exited(body):
	if body.is_in_group("inimigo"):
		inimigos_perto -= 1
