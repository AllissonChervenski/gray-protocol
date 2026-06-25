extends Node

# ==========================================
# CONFIGURAÇÕES DO SERVIDOR OLLAMA
# ==========================================
const OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
const OLLAMA_MODEL = "llama3.2:3b" # O modelo que está a correr no seu terminal

var http_request: HTTPRequest
var oraculo_timer: Timer

# ==========================================
# VARIÁVEIS DE ESTADO E MEMÓRIA
# ==========================================
var cooldown_ativo: bool = false
var ultima_acao_decidida: String = ""
const LIMITE_DE_ATIVACAO_AJUDA = 40.0
const LIMITE_DE_ATIVACAO_SABOTAGEM = 70.0

@onready var jogador = get_tree().get_first_node_in_group("jogador")

# ==========================================
# VARIÁVEIS DE INTERFACE (UI)
# ==========================================
@onready var ui_fundo = $UI_Oraculo/FundoPreto
@onready var label_texto = $UI_Oraculo/FundoPreto/TextoDisplay
@onready var som_digitacao = $UI_Oraculo/SomDigitacao

var tween_digitacao: Tween

func _ready():
	# 1. Esconde a UI quando o jogo começa
	if ui_fundo:
		ui_fundo.hide() 

	# 2. Cria o nó de comunicação Web automaticamente
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_ollama_respondeu)
	
	# 3. O RELÓGIO (A chave de ignição que faltava!)
	oraculo_timer = Timer.new()
	oraculo_timer.wait_time = 15.0 # A cada 15 segundos tenta agir
	oraculo_timer.autostart = true
	oraculo_timer.one_shot = false
	oraculo_timer.timeout.connect(_on_timer_do_oraculo_disparou)
	add_child(oraculo_timer)
	oraculo_timer.start()

# ==========================================
# O GATILHO E OS CÉREBROS (Utility AI)
# ==========================================
func _on_timer_do_oraculo_disparou():
	if not jogador:
		jogador = get_tree().get_first_node_in_group("jogador")
		if not jogador: return
		
	var mapa_atual = get_tree().get_first_node_in_group("mapa")
	if mapa_atual:
		escanear_ambiente_e_jogador(mapa_atual)
	else:
		print("[SISTEMA] Oráculo tentou agir, mas não encontrou a fase no grupo 'mapa'.")

func escanear_ambiente_e_jogador(mapa):
	if cooldown_ativo: return
	
	# 1. O Árbitro decide a ação baseada nos atributos
	var acao = avaliar_diretriz_oraculo(jogador.vida, jogador.sanidade, jogador.inimigos_perto, jogador.inventario)
	print(acao)
	if acao == "NEUTRO":
		return # Não faz nada se o jogador estiver num estado neutro/seguro
		
	# 2. Pega a dica (verdade ou mentira) do dicionário do mapa
	var dica_mapa = "Nenhuma informação extra detetada."
	if mapa.get("dados_oraculo"):
		if acao == "AJUDAR":
			dica_mapa = mapa.dados_oraculo["ajuda_conselhos"].pick_random()
		elif acao == "SABOTAR":
			dica_mapa = mapa.dados_oraculo["sabota_conselhos"].pick_random()

	# 3. Empacota os dados para a IA do Ollama ler
	var pacote_sensores = {
		"vida": jogador.vida,
		"sanidade": jogador.sanidade,
		"informacao_tática": dica_mapa
	}
	
	acionar_camada_3(JSON.stringify(pacote_sensores), acao)

func avaliar_diretriz_oraculo(vida, sanidade, inimigos, inventario) -> String:
	var desejo_ajudar = cerebro_da_ajuda(vida, sanidade, inimigos, inventario)
	var desejo_sabotar = cerebro_da_sabotagem(vida, sanidade, inimigos, inventario)
	print("ajuda", desejo_ajudar)
	print("Sabota", desejo_sabotar)
	if desejo_ajudar > desejo_sabotar and desejo_ajudar >= LIMITE_DE_ATIVACAO_AJUDA:
		return "AJUDAR"
	elif desejo_sabotar > desejo_ajudar and desejo_sabotar >= LIMITE_DE_ATIVACAO_SABOTAGEM:
		return "SABOTAR"
	return "NEUTRO"

func cerebro_da_ajuda(vida: int, sanidade: int, inimigos: int, _inventario: Array) -> float:
	var pontuacao = 0.0
	if vida < 70: pontuacao += 30.0 
	if sanidade < 40: pontuacao += 40.0
	if inimigos > 1 and vida < 50: pontuacao += 60.0
	if vida <= 30: pontuacao += 90.0
	return clamp(pontuacao, 0.0, 100.0)

func cerebro_da_sabotagem(vida: int, sanidade: int, inimigos: int, inventario: Array) -> float:
	var pontuacao = 0.0
	if inimigos < 1: pontuacao += 10.0
	if vida >= 80: pontuacao += 70.0 
	if sanidade >= 70: pontuacao += 30.0
	if not inventario.is_empty(): pontuacao += 20.0 
	return clamp(pontuacao, 0.0, 100.0)

# ==========================================
# CAMADA 3: Comunicação com o Servidor Ollama
# ==========================================
# ==========================================
# CAMADA 3: Comunicação com o Servidor Ollama
# ==========================================
func acionar_camada_3(payload_json_sensores: String, acao_obrigatoria: String):
	cooldown_ativo = true
	ultima_acao_decidida = acao_obrigatoria 
	
	# 1. O Prompt (Agora com a cábula/template no final)
	var prompt_sistema = "Você é um bracelete tático. O sistema DECIDIU: [%s]. Justifique esta ação em apenas 1 frase curta incorporando este dado: %s\n\nResponda EXATAMENTE neste formato de exemplo:\n{\"relatorio\": \"texto do relatório aqui\"}" % [acao_obrigatoria, payload_json_sensores]
	
	# 2. O Payload (Agora com a temperatura quase a zero para forçar a formatação)
	var dados_requisicao = {
		"model": OLLAMA_MODEL,
		"prompt": prompt_sistema,
		"system": "Você é uma máquina. Retorne APENAS um JSON válido contendo a chave 'relatorio' e absolutamente mais nenhum texto.",
		"stream": false,
		"format": "json",
		"options": {
			"temperature": 0.1 # Remove a criatividade para evitar quebra do JSON
		}
	}
	
	var json_enviado = JSON.stringify(dados_requisicao)
	var cabecalhos = ["Content-Type: application/json"]
	
	print("[REDE] Enviando dados para o Ollama...")
	var erro = http_request.request(OLLAMA_URL, cabecalhos, HTTPClient.METHOD_POST, json_enviado)
	
	if erro != OK:
		print("Falha ao tentar conectar com o Ollama. O servidor está a correr?")
		cooldown_ativo = false
# ==========================================
# RETORNO DA REDE: Godot lê a resposta do Ollama
# ==========================================
# ==========================================
# RETORNO DA REDE: Godot lê a resposta do Ollama (Blindado)
# ==========================================
func _on_ollama_respondeu(_resultado: int, codigo_resposta: int, _cabecalhos: PackedStringArray, corpo: PackedByteArray):
	get_tree().create_timer(30.0).timeout.connect(func(): cooldown_ativo = false)
	
	if codigo_resposta == 200:
		var resposta_bruta = corpo.get_string_from_utf8().strip_edges()
		print(resposta_bruta)
		# ESCUDO 1: A IA engasgou e não enviou absolutamente nada?
		if resposta_bruta.is_empty():
			print("[ALERTA DO SISTEMA] O servidor Ollama retornou um pacote vazio.")
			return
			
		# ESCUDO 2: O pacote da rede é um JSON válido? (Parse seguro)
		var json_rede = JSON.new()
		var erro_rede = json_rede.parse(resposta_bruta)
		
		if erro_rede != OK:
			print("[ALERTA DO SISTEMA] O pacote recebido corrompeu. Texto: ", resposta_bruta)
			return
			
		var resposta_json = json_rede.get_data()
		
		if typeof(resposta_json) == TYPE_DICTIONARY and resposta_json.has("response"):
			var texto_da_ia = resposta_json["response"].strip_edges()
			
			# ESCUDO 3: A IA gerou o JSON interno que pedimos no prompt?
			var json_ia = JSON.new()
			var erro_ia = json_ia.parse(texto_da_ia)
			
			if erro_ia == OK:
				var relatorio_json = json_ia.get_data()
				
				if typeof(relatorio_json) == TYPE_DICTIONARY and relatorio_json.has("relatorio"):
					# Extrai e converte forçosamente para String
					var relatorio_final = str(relatorio_json["relatorio"])
					
					# Executa a mecânica no jogo
					if ultima_acao_decidida == "AJUDAR":
						executar_ajuda_no_jogo(relatorio_final)
					elif ultima_acao_decidida == "SABOTAR":
						executar_sabotagem_no_jogo(relatorio_final)
						
					# Exibe no ecrã com efeito visual
					mostrar_mensagem_na_tela(relatorio_final)
				else:
					print("[SISTEMA] A chave 'relatorio' não foi encontrada. Resposta da IA: ", texto_da_ia)
			else:
				print("[SISTEMA] A IA não formatou a resposta como JSON. Resposta: ", texto_da_ia)
	else:
		print("Erro do Servidor Ollama. Código HTTP: ", codigo_resposta)
		cooldown_ativo = false

# ==========================================
# MECÂNICAS DE JOGO E INTERFACE
# ==========================================
func executar_ajuda_no_jogo(relatorio: String):
	print("[MECÂNICA] Executando AJUDA física no jogador...")
	print("[RELATORIO] ", relatorio)
func executar_sabotagem_no_jogo(relatorio: String):
	print("[MECÂNICA] Executando SABOTAGEM física no jogador...")
	print("[RELATORIO] ", relatorio)
func mostrar_mensagem_na_tela(mensagem_final: String):
	if not ui_fundo:
		print("--- ORÁCULO DIZ: ---")
		print(mensagem_final)
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
