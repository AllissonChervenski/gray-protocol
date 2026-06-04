extends Node


# ==========================================
# VARIÁVEIS DE INTERFACE (UI)
# ==========================================

@onready var ui_fundo = $UI_Oraculo/FundoPreto
@onready var label_texto = $UI_Oraculo/FundoPreto/TextoDisplay
@onready var som_digitacao = $UI_Oraculo/SomDigitacao

var tween_digitacao: Tween
var sacolas_de_palavras = {}

var prefixos_oraculo = [
	"Escaneamento concluído.",
	"Análise tática:",
	"Leitura de ambiente:",
	"Dados processados.",
	"Atenção."
]

@onready var jogador = get_tree().get_first_node_in_group("jogador")

const LIMITE_DE_ATIVACAO = 50.0

var oraculo_timer: Timer

func _ready():
	if ui_fundo:
		ui_fundo.hide() # Esconde a UI quando o jogo começa

	oraculo_timer = Timer.new()
	oraculo_timer.wait_time = 15.0 # A cada 15 segundos ele decide agir
	oraculo_timer.autostart = true
	oraculo_timer.timeout.connect(_on_timer_do_oraculo_disparou)
	add_child(oraculo_timer)

# ==========================================
# O NOVO GATILHO (Automático por Tempo)
# ==========================================
func _on_timer_do_oraculo_disparou():
	if not jogador:
		jogador = get_tree().get_first_node_in_group("jogador")
		if not jogador: return
		
	# 1. RADAR: Procura os inimigos que estão no mapa
	var inimigos = get_tree().get_nodes_in_group("inimigos")
	var inimigo_mais_proximo = null
	var menor_distancia = 99999.0
	var alcance_do_radar = 400.0 # Distância máxima para o Oráculo "ver" o inimigo
	
	# Acha qual inimigo está mais perto do jogador neste exato momento
	for i in inimigos:
		var distancia = jogador.global_position.distance_to(i.global_position)
		if distancia < menor_distancia and distancia < alcance_do_radar:
			menor_distancia = distancia
			inimigo_mais_proximo = i
			
	# 2. SE ACHAR UM INIMIGO: Escaneia ele!
	if inimigo_mais_proximo != null:
		escanear_ambiente_e_jogador(inimigo_mais_proximo)
	else:
		# Opcional: O que o oráculo faz se não tiver nenhum inimigo perto?
		# Você pode escanear a sala, ou ele pode apenas dizer "Área segura".
		pass
		
func avaliar_diretriz_oraculo(vida, sanidade, inimigos_perto, inventario) -> String:
	# 1. O Cérebro da AJUDA olha para os dados
	var desejo_ajudar = cerebro_da_ajuda(vida, sanidade, inimigos_perto, inventario)
	
	# 2. O Cérebro da SABOTAGEM olha para os dados
	var desejo_sabotar = cerebro_da_sabotagem(vida, sanidade, inimigos_perto, inventario)
	
	# 3. O Árbitro (A Máquina de Estados) decide quem ganha
	if desejo_ajudar > desejo_sabotar and desejo_ajudar >= LIMITE_DE_ATIVACAO:
		return "AJUDAR"
		
	elif desejo_sabotar > desejo_ajudar and desejo_sabotar >= LIMITE_DE_ATIVACAO:
		return "SABOTAR"
		
	else:
		# 4. O Guardrail (Nenhum cérebro atingiu o limite de ativação)
		return "NEUTRO"
		
	# ==========================================
# CÉREBRO 1: Lógica de Ajuda
# ==========================================
func cerebro_da_ajuda(vida: int, sanidade: int, inimigos: int, inventario: Array) -> float:
	var pontuacao = 0.0
	
	if vida < 30: pontuacao += 60.0 # Quase morrendo! Precisa de ajuda urgente.
	if sanidade < 20: pontuacao += 40.0
	if inimigos > 1 and vida < 50: pontuacao += 30.0
	
	return clamp(pontuacao, 0.0, 100.0)

# ==========================================
# CÉREBRO 2: Lógica de Sabotagem
# ==========================================
func cerebro_da_sabotagem(vida: int, sanidade: int, inimigos: int, inventario: Array) -> float:
	var pontuacao = 0.0
	
	if inimigos < 1: pontuacao += 10.0
	if vida > 80: pontuacao += 50.0 # Está muito confortável, vamos testá-lo.
	if sanidade > 70: pontuacao += 30.0
	if not inventario.is_empty(): pontuacao += 20.0 # Tem itens de sobra, pode sofrer um pouco.
	
	return clamp(pontuacao, 0.0, 100.0)


func escanear_ambiente_e_jogador(objeto_alvo):
	if not jogador:
			jogador = get_tree().get_first_node_in_group("jogador")
			
			# Se MESMO ASSIM não achar, cancela a função para não dar erro (crash)
			if not jogador:
				print("[SISTEMA] Oráculo tentou escanear, mas o Elias não está na cena!")
				return
			
	var acao_decidida = avaliar_diretriz_oraculo(jogador.vida, jogador.sanidade, jogador.inimigos_perto, jogador.inventario)
	
	# Manda gerar a dica procedimental sobre o objeto_alvo (que pode ser uma sala ou um inimigo)
	gerar_dica_do_oraculo(acao_decidida, objeto_alvo)

# ==========================================
# O GERADOR PROCEDURAL
# ==========================================
func pegar_palavra_unica(chave: String, lista_original: Array) -> String:
	if not sacolas_de_palavras.has(chave) or sacolas_de_palavras[chave].is_empty():
		sacolas_de_palavras[chave] = lista_original.duplicate()
		sacolas_de_palavras[chave].shuffle() 
	return sacolas_de_palavras[chave].pop_back()

func gerar_dica_do_oraculo(acao: String, objeto_alvo):
	if objeto_alvo == null or not objeto_alvo.get("dados_oraculo"):
		return
		
	var dicionario = objeto_alvo.dados_oraculo
	var prefixo = pegar_palavra_unica("prefixos", prefixos_oraculo)
	
	var lista_fatos = []
	var lista_conselhos = []
	var chave_memoria = objeto_alvo.name 
	
	if acao == "AJUDAR":
		lista_fatos = dicionario["ajuda_fatos"]
		lista_conselhos = dicionario["ajuda_conselhos"]
	elif acao == "SABOTAR":
		lista_fatos = dicionario["sabota_fatos"]
		lista_conselhos = dicionario["sabota_conselhos"]
		
	var fato = pegar_palavra_unica(chave_memoria + "_fatos", lista_fatos)
	var conselho = pegar_palavra_unica(chave_memoria + "_conselhos", lista_conselhos)
	
	var mensagem_final = "[SISTEMA] %s %s %s" % [prefixo, fato, conselho]
	
	# AGORA SIM, exibe na tela do jogador!
	mostrar_mensagem_na_tela(mensagem_final)

# ==========================================
# A INTERFACE VISUAL (Typewriter Effect)
# ==========================================
func mostrar_mensagem_na_tela(mensagem_final: String):
	if not ui_fundo:
		print("UI não encontrada! Imprimindo no console: ", mensagem_final)
		return
		
	ui_fundo.show()
	label_texto.text = mensagem_final
	label_texto.visible_characters = 0 
	
	if tween_digitacao and tween_digitacao.is_valid():
		tween_digitacao.kill()
		
	tween_digitacao = create_tween()
	
	var velocidade_digitacao = 0.03 
	var tempo_total = mensagem_final.length() * velocidade_digitacao
	
	tween_digitacao.tween_property(label_texto, "visible_characters", mensagem_final.length(), tempo_total)
	
	if som_digitacao:
		som_digitacao.play()
	
	tween_digitacao.finished.connect(_on_digitacao_concluida)

func _on_digitacao_concluida():
	if som_digitacao:
		som_digitacao.stop() 
	
	await get_tree().create_timer(4.0).timeout
	ui_fundo.hide()
