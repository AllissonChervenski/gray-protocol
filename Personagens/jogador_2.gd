extends JogadorBase

@onready var oraculo = get_node("../Oraculo")  # ajuste o caminho

func _ready():
	oraculo.frase_gerada.connect(_on_frase_oraculo)
	oraculo.decisao_tomada.connect(_on_decisao_oraculo)

func _on_frase_oraculo(frase: String):
	# Exibe no HUD — exemplo com um Label no CanvasLayer
	print("TESTE DO PRINT:" + frase)

func _on_decisao_oraculo(decisao: String):
	if decisao == "sabota":
		# toque um som sinistro, efeito visual, etc.
		pass
		
func _physics_process(delta):
	super(delta)
	# Atualiza contexto (leve — só escreve em dicionário)
	oraculo.atualizar_contexto("jogador", {
		"vida":         vida / vida_maxima,
		"sanidade":      sanidade / 100.0,
		"esta_correndo": velocity.length() > speed * 0.8,
		"esta_subindo":  esta_subindo,
	})
	oraculo.atualizar_contexto("inventario",
		inventario.map(func(i): return {"nome": i.nome, "usos": i.usos})
	)
	# Tempo seguro (sem inimigos)
	if not raycast_interacao.is_colliding():
		oraculo.incrementar_tempo_seguro(delta)
	else:
		oraculo.notificar_dano()

func _on_entrar_comodo(nome: String):
	oraculo.notificar_novo_comodo(nome)
	oraculo.avaliar()  # Oráculo decide ao mudar de sala


func _on_inimigo_detectado(inimigo):
	oraculo.atualizar_contexto("ambiente", {
		"inimigos_visiveis": 1,
		"distancia_inimigo": global_position.distance_to(inimigo.global_position),
	})

func _on_inimigo_saiu():
	oraculo.atualizar_contexto("ambiente", {
		"inimigos_visiveis": 0,
		"distancia_inimigo": 9999.0,
	})
