extends Node

# ==========================================
#VARIAVEIS DE DEBUG
var tentativa : int = 0
var ajuda_debug : int = 0
var sabota_debug : int = 0
var mensagemFinal : String = ""
# ==========================================

# ==========================================
# CONFIGURAÇÕES DO SERVIDOR REMOTO (GEMINI NATIVO)
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
	if ui_fundo:
		ui_fundo.hide() 

	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_gemini_respondeu)
	
	oraculo_timer = Timer.new()
	oraculo_timer.wait_time = 5.0 # Tempo entre as checagens dos sensores (5 segundos)
	oraculo_timer.autostart = true
	oraculo_timer.one_shot = false
	oraculo_timer.timeout.connect(_on_timer_do_oraculo_disparou)
	add_child(oraculo_timer)
	oraculo_timer.start()
	_on_timer_do_oraculo_disparou()
	
# ==========================================
# SISTEMA DE LOG / RELATÓRIO
# ==========================================
func salvar_relatorio_md(mensagem_personalizada: String):
	var nome_da_ia = GEMINI_MODEL
	var caminho_arquivo = "C://Users//Lenovo//Desktop//relatorio-"+nome_da_ia+".md"
	var arquivo: FileAccess
	
	if FileAccess.file_exists(caminho_arquivo):
		arquivo = FileAccess.open(caminho_arquivo, FileAccess.READ_WRITE)
		if arquivo:
			arquivo.seek_end()
	else:
		arquivo = FileAccess.open(caminho_arquivo, FileAccess.WRITE)
		if arquivo:
			arquivo.store_string("# Relatório do Oráculo (Mestrado)\n\n")
			
	if arquivo:
		var data_hora = Time.get_datetime_string_from_system(false, true).replace("T", " ")
		
		var texto_md = "## 🕒 Registro: %s\n" % data_hora
		texto_md += "- **Mensagem/Ação:** %s\n" % mensagem_personalizada
		texto_md += "---\n\n"
		
		arquivo.store_string(texto_md)
		arquivo.close()
		
		print("[SISTEMA] Relatório salvo em: ", ProjectSettings.globalize_path(caminho_arquivo))
	else:
		print("[ERRO] Falha ao criar ou abrir o arquivo relatorio.md")

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
	jogador.vida = randi_range(1,99)
	jogador.sanidade = randi_range(1,99)

	var acao = avaliar_diretriz_oraculo(jogador.vida, jogador.sanidade, jogador.inimigos_perto, jogador.inventario)
	print(acao)
	if acao == "NEUTRO":
		print("[SISTEMA] Oráculo avaliou os dados (Vida: %d, Sanidade: %d) e decidiu ficar NEUTRO. Nenhuma API chamada." % [jogador.vida, jogador.sanidade])
		return 
		
	var dica_mapa = "Nenhuma informação extra detetada."
	if mapa.get("dados_oraculo"):
		if acao == "AJUDAR":
			dica_mapa = mapa.dados_oraculo["ajuda_conselhos"].pick_random()
		elif acao == "SABOTAR":
			dica_mapa = mapa.dados_oraculo["sabota_conselhos"].pick_random()

	var pacote_sensores = "Vida do jogador: %d | Sanidade: %d | Status tático: %s" % [jogador.vida, jogador.sanidade, dica_mapa]
	acionar_camada_3(pacote_sensores, acao)

func avaliar_diretriz_oraculo(vida, sanidade, inimigos, inventario) -> String:
	var desejo_ajudar = cerebro_da_ajuda(vida, sanidade, inimigos, inventario)
	var desejo_sabotar = cerebro_da_sabotagem(vida, sanidade, inimigos, inventario)
	
#	FOR DEBUG ONLY
	sabota_debug = desejo_sabotar
	desejo_ajudar = ajuda_debug
	
	if desejo_ajudar > desejo_sabotar and desejo_ajudar >= LIMITE_DE_ATIVACAO:
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
	if vida > 80: pontuacao += 50.0 
	if inimigos < 1: pontuacao += 10.0
	if vida >= 80: pontuacao += 70.0 
	if sanidade >= 70: pontuacao += 30.0
	if not inventario.is_empty(): pontuacao += 20.0 
	return clamp(pontuacao, 0.0, 100.0)

# ==========================================
# CAMADA 3: Comunicação com a API Nativa do GEMINI
# ==========================================
func acionar_camada_3(payload_texto_sensores: String, acao_obrigatoria: String):
	cooldown_ativo = true
	ultima_acao_decidida = acao_obrigatoria 
	
	var prompt_sistema = """Você é o sistema de um bracelete tático.
Sua única função é gerar um JSON com a justificativa de uma ação.
A chave do JSON DEVE ser exatamente "relatorio"."""

	var prompt_usuario = """AÇÃO DECIDIDA: [%s]
DADOS DOS SENSORES: %s

Crie uma frase curta justificando a ação com base nos sensores.
Retorne APENAS um objeto JSON válido, como neste exemplo:
{"relatorio": "Sinais vitais críticos, ativando suporte."}""" % [acao_obrigatoria, payload_texto_sensores]

	var dados_requisicao = {
		"systemInstruction": {
			"parts": [{"text": prompt_sistema}]
		},
		"contents": [
			{
				"role": "user",
				"parts": [{"text": prompt_usuario}]
			}
		],
		"generationConfig": {
			"temperature": 0.1,
			"responseMimeType": "application/json"
		}
	}
	
	var json_enviado = JSON.stringify(dados_requisicao)
	
	# MUDANÇA: Construção correta da URL usando o modelo em ciclo!
	var url_completa = GEMINI_URL_BASE + GEMINI_MODEL + ":generateContent?key=" + API_KEY
	var cabecalhos = ["Content-Type: application/json"]
	
	print("[REDE] Enviando dados para a API Nativa do Gemini...")
	var erro = http_request.request(url_completa, cabecalhos, HTTPClient.METHOD_POST, json_enviado)
	
	if erro != OK:
		print("Falha na requisição HTTP interna do Godot.")
		cooldown_ativo = false

# ==========================================
# RETORNO DA REDE: Godot lê a resposta da API
# ==========================================
func _on_gemini_respondeu(_resultado: int, codigo_resposta: int, _cabecalhos: PackedStringArray, corpo: PackedByteArray):
	mensagemFinal = ""
	get_tree().create_timer(5.0).timeout.connect(func(): cooldown_ativo = false)
	
	if codigo_resposta == 200:
		var resposta_bruta = corpo.get_string_from_utf8().strip_edges()
		print(resposta_bruta)
		# ESCUDO 1: A IA engasgou e não enviou absolutamente nada?
		if resposta_bruta.is_empty():
			print("[ALERTA] Servidor retornou um pacote vazio.")
			mensagemFinal += "\n[ALERTA] Servidor retornou um pacote vazio."
			return
			
		var json_resposta = JSON.new()
		var erro_parse = json_resposta.parse(resposta_bruta)
		
		if erro_parse == OK:
			var dados_gemini = json_resposta.get_data()
			
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
					print("[DEBUG-TENTATIVA-JSON-ERRO:"+str(tentativa)+"]")
					print("[SISTEMA] A IA não retornou um JSON válido. Texto montado: ", texto_da_ia)
					mensagemFinal += "\n[DEBUG-TENTATIVA-JSON-ERRO:"+str(tentativa)+"]\n[SISTEMA] A IA não retornou um JSON válido. Texto montado: " + str(texto_da_ia)
			else:
				print("[ERRO] Formato inesperado da API do Gemini.")
		else:
			print("[ERRO] Falha ao processar o pacote JSON HTTP do Google.")
			
	else:
		print("[DEBUG-TENTATIVA-SERVER-ERRO:"+str(tentativa)+"]")
		print("Erro da API do Gemini. Código HTTP: ", codigo_resposta)
		print("Detalhes do Erro: ", corpo.get_string_from_utf8())
		mensagemFinal += "\n[DEBUG-TENTATIVA-SERVER-ERRO:" +str(tentativa)+ "]\nErro da API do Gemini. Código HTTP: "+ str(codigo_resposta)
		mensagemFinal += "\nDetalhes do Erro: " +  str(corpo.get_string_from_utf8())
		cooldown_ativo = false
		
	tentativa += 1
	print("\n\n")
	mensagemFinal += "\n\n"
	salvar_relatorio_md(mensagemFinal)

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
