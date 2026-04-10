extends CharacterBody2D

const SPEED = 200.0

func _physics_process(_delta):
	# Usa as ações que acabamos de criar no Mapa de Entrada
	var direction = Input.get_vector("esquerda", "direita", "cima", "baixo")
	
	# Multiplicamos direto! Se você soltar as teclas, a direção vira (0,0) 
	# e a velocidade zera na mesma hora, parando o personagem.
	velocity = direction * SPEED
		
	# Move o personagem e lida com as colisões
	move_and_slide()
