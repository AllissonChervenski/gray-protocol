extends Node

# ════════════════════════════════════════════════════════════════════════════════
# ORÁCULO v3 — Integração nativa com Godot LLM (plugin Adriankhl)
#
# Sem servidor externo. Sem HTTPRequest. O Qwen 2.5 0.5B roda direto no Godot
# via nó GdLlama do plugin godot-llm.
#
# ── Pré-requisitos ─────────────────────────────────────────────────────────────
#   1. Plugin godot-llm instalado e ativado (Project > Project Settings > Plugins)
#   2. Modelo GGUF em res://models/qwen2.5-0.5b-instruct-q4_k_m.gguf
#   3. Este nó adicionado como filho do Mundo ou do Jogador
#
# ── API pública ────────────────────────────────────────────────────────────────
#   oraculo.atualizar_contexto("jogador", { "saude": 0.4, "sanidade": 0.6 })
#   oraculo.atualizar_contexto("inventario", [{ "nome": "Chave", "usos": 2 }])
#   oraculo.atualizar_contexto("ambiente", { "comodo_atual": "biblioteca" })
#   oraculo.avaliar()   → dispara avaliação; resultado chega via sinais
#
# ── Sinais emitidos ────────────────────────────────────────────────────────────
#   decisao_tomada(decisao: String)   "ajuda" | "sabota" | "silencio"
#   frase_gerada(frase: String)       texto para exibir no HUD
#   oraculo_erro(mensagem: String)    falha de parse ou modelo não carregado
# ════════════════════════════════════════════════════════════════════════════════

# ─── CONFIGURAÇÃO ─────────────────────────────────────────────────────────────

# Caminho do modelo dentro do projeto Godot
@export_file("*.gguf") var modelo_path: String = \
	"res://Modelo/Llama-3.2-1B-Instruct-Q4_K_M.gguf"

@export var n_predict: int      = 120   # Tokens máximos gerados
@export var temperatura: float  = 0.85  # Arbítrio: 0.7 contido → 1.0 caótico
@export var context_size: int   = 2048  # Janela de contexto (nome real no plugin)
@export var cooldown_min: float       = 18.0  # Segundos mínimos entre ações
@export var intervalo_avaliacao: float = 30.0  # Segundos entre avaliações automáticas (0 = desativado)
@export var debug: bool                = true

# ─── GUARDRAILS (Camada 1) ────────────────────────────────────────────────────

@export var saude_minima_para_sabotar: float    = 0.12
@export var sanidade_minima_para_sabotar: float = 0.08
@export var distancia_minima_inimigo: float     = 80.0
@export var tempo_conforto: float               = 280.0

# ─── SINAIS ───────────────────────────────────────────────────────────────────

signal decisao_tomada(decisao: String)
signal frase_gerada(frase: String)
signal oraculo_erro(mensagem: String)

# ─── NÓS ──────────────────────────────────────────────────────────────────────

var _llama: GDLlama = null   # Nó do plugin godot-llm

# ─── ESTADO INTERNO ───────────────────────────────────────────────────────────

var _cooldown: float         = 0.0
var _aguardando: bool        = false
var _ultima_decisao: String  = ""
var _buffer_resposta: String = ""   # Acumula tokens do stream
var _timer: Timer            = null  # Timer automático de avaliação

var _contexto: Dictionary = {
	"jogador": {
		"saude":         1.0,
		"sanidade":      1.0,
		"esta_correndo": false,
		"esta_subindo":  false,
	},
	"inventario": [],
	"ambiente": {
		"comodo_atual":      "desconhecido",
		"inimigos_visiveis": 0,
		"distancia_inimigo": 9999.0,
		"portas_abertas":    0,
		"itens_no_chao":     0,
		"esta_escuro":       false,
	},
	"historico": {
		"decisoes_recentes": [],
		"total_ajudas":      0,
		"total_sabotagens":  0,
	},
	"meta": {
		"progresso":      0.0,
		"tempo_de_jogo":  0.0,
		"tempo_seguro":   0.0,
	}
}

# ─── INICIALIZAÇÃO ────────────────────────────────────────────────────────────

func _ready() -> void:
	_llama = GDLlama.new()
	add_child(_llama)

	# Configura o modelo
	_llama.model_path   = modelo_path
	_llama.n_predict    = n_predict
	_llama.temperature  = temperatura     # propriedade: temperature (float)
	_llama.context_size = context_size    # propriedade: context_size (int) — NAO n_ctx
	_llama.should_output_prompt  = false  # Não repete o prompt na saída
	_llama.should_output_special = false  # Remove tokens especiais do output

	# Conecta os sinais do plugin
	_llama.generate_text_updated.connect(_on_token)
	_llama.generate_text_finished.connect(_on_resposta_completa)

	# ── Timer automático ──────────────────────────────────────────────────────
	# Dispara avaliar() a cada `intervalo_avaliacao` segundos automaticamente.
	# Você pode desativar isso e chamar avaliar() manualmente quando quiser.
	if intervalo_avaliacao > 0.0:
		_timer = Timer.new()
		_timer.wait_time    = intervalo_avaliacao
		_timer.autostart    = true
		_timer.one_shot     = false
		_timer.timeout.connect(_on_timer)
		add_child(_timer)
		_log("Timer automático ativo: avalia a cada %.0fs." % intervalo_avaliacao)
	else:
		_log("Timer desativado. Chame avaliar() manualmente.")

	_log("Oráculo iniciado. Modelo: %s" % modelo_path)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	_contexto["meta"]["tempo_de_jogo"] += delta

	# Incrementa tempo seguro automaticamente se não houver inimigos
	if _contexto["ambiente"]["inimigos_visiveis"] == 0:
		_contexto["meta"]["tempo_seguro"] += delta


# Callback do timer automático
func _on_timer() -> void:
	_log("Timer disparou — avaliando contexto...")
	avaliar()


# ════════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ════════════════════════════════════════════════════════════════════════════════

# Atualiza uma seção do contexto.
# Exemplos:
#   oraculo.atualizar_contexto("jogador", { "saude": 0.4 })
#   oraculo.atualizar_contexto("inventario", [{ "nome": "Chave", "usos": 2 }])
func atualizar_contexto(secao: String, dados) -> void:
	if not _contexto.has(secao):
		push_warning("Oráculo: seção '%s' inexistente." % secao)
		return
	if dados is Array:
		_contexto[secao] = dados
	elif dados is Dictionary:
		for chave in dados:
			_contexto[secao][chave] = dados[chave]


# Dispara a avaliação completa das 3 camadas.
func avaliar() -> void:
	if _cooldown > 0.0:
		_log("Cooldown ativo (%.1fs). Silêncio." % _cooldown)
		return
	if _aguardando:
		_log("Modelo ainda gerando. Aguarde.")
		return
	if not _llama:
		push_error("Oráculo: GdLlama não iniciado.")
		return

	# ── Camada 1: Guardrails ──────────────────────────────────────────────────
	var bloqueio = _camada1_guardrails()
	if bloqueio != "":
		_log("Guardrail → %s" % bloqueio)
		_finalizar(bloqueio, _frase_fallback(bloqueio))
		return

	# ── Camada 2: Payload → Camada 3: Qwen ───────────────────────────────────
	var payload = _camada2_payload()
	_camada3_qwen(payload)


# Atalhos para outros scripts
func notificar_dano() -> void:
	_contexto["meta"]["tempo_seguro"] = 0.0

func notificar_novo_comodo(nome: String) -> void:
	_contexto["ambiente"]["comodo_atual"] = nome
	_cooldown = max(_cooldown - 6.0, 0.0)
	_log("Novo cômodo: %s" % nome)

func incrementar_tempo_seguro(delta: float) -> void:
	_contexto["meta"]["tempo_seguro"] += delta

func forcar_silencio(segundos: float) -> void:
	_cooldown = max(_cooldown, segundos)


# ════════════════════════════════════════════════════════════════════════════════
# CAMADA 1 — GUARDRAILS
# ════════════════════════════════════════════════════════════════════════════════

func _camada1_guardrails() -> String:
	var j   = _contexto["jogador"]
	var amb = _contexto["ambiente"]
	var met = _contexto["meta"]

	if j["saude"] <= saude_minima_para_sabotar:
		return "ajuda"
	if j["sanidade"] <= sanidade_minima_para_sabotar:
		return "ajuda"
	if amb["inimigos_visiveis"] > 0 and amb["distancia_inimigo"] < distancia_minima_inimigo:
		return "silencio"
	if met["tempo_seguro"] >= tempo_conforto:
		_contexto["meta"]["tempo_seguro"] = 0.0
		_log("Jogador confortável demais — Qwen vai pressionar.")

	return ""


# ════════════════════════════════════════════════════════════════════════════════
# CAMADA 2 — PAYLOAD
# ════════════════════════════════════════════════════════════════════════════════

func _camada2_payload() -> Dictionary:
	var j    = _contexto["jogador"]
	var inv  = _contexto["inventario"]
	var amb  = _contexto["ambiente"]
	var hist = _contexto["historico"]
	var met  = _contexto["meta"]

	var inv_resumo: Array = []
	for item in inv:
		inv_resumo.append("%s (usos:%d)" % [item.get("nome","?"), item.get("usos",1)])

	var total = hist["total_ajudas"] + hist["total_sabotagens"]
	var taxa_sab = 0.0
	if total > 0:
		taxa_sab = float(hist["total_sabotagens"]) / float(total)

	return {
		"jogador": {
			"saude_pct":    int(j["saude"] * 100),
			"sanidade_pct": int(j["sanidade"] * 100),
			"correndo":     j["esta_correndo"],
		},
		"inventario": { "qtd": inv.size(), "itens": inv_resumo },
		"ambiente": {
			"comodo":            amb["comodo_atual"],
			"inimigos":          amb["inimigos_visiveis"],
			"dist_inimigo_px":   int(amb["distancia_inimigo"]),
			"portas_abertas":    amb["portas_abertas"],
			"itens_no_chao":     amb["itens_no_chao"],
			"escuro":            amb["esta_escuro"],
		},
		"historico": {
			"ultimas":        hist["decisoes_recentes"].slice(-5),
			"taxa_sabota_pct": int(taxa_sab * 100),
		},
		"meta": {
			"progresso_pct":    int(met["progresso"] * 100),
			"tempo_seguro_seg": int(met["tempo_seguro"]),
		}
	}


# ════════════════════════════════════════════════════════════════════════════════
# CAMADA 3 — QWEN VIA GODOT LLM
# ════════════════════════════════════════════════════════════════════════════════

func _camada3_qwen(payload: Dictionary) -> void:
	var prompt = _montar_prompt(payload)
	_log("Enviando ao Qwen (GdLlama)...")
	_log("Prompt:\n%s" % prompt)

	_buffer_resposta = ""
	_aguardando      = true

	# run_generate_text(prompt, grammar, json_schema)
	# Passamos "" para grammar e "" para json_schema — controlamos pelo prompt
	_llama.run_generate_text(prompt, "", "")


# Chamado a cada token gerado (streaming)
func _on_token(novo_texto: String) -> void:
	_buffer_resposta += novo_texto


# Chamado quando a geração completa termina
func _on_resposta_completa(texto_completo: String) -> void:
	_aguardando = false
	_log("Resposta completa:\n%s" % texto_completo)

	# O texto_completo já contém toda a resposta; usamos ele diretamente
	var conteudo = texto_completo.strip_edges()

	# Remove blocos markdown se o modelo os incluir
	conteudo = conteudo.replace("```json", "").replace("```", "").strip_edges()

	# Tenta extrair apenas o JSON (entre { e })
	var inicio = conteudo.find("{")
	var fim    = conteudo.rfind("}")
	if inicio != -1 and fim != -1 and fim > inicio:
		conteudo = conteudo.substr(inicio, fim - inicio + 1)

	var json = JSON.new()
	if json.parse(conteudo) != OK:
		push_warning("Oráculo: JSON inválido na resposta: %s" % conteudo)
		emit_signal("oraculo_erro", "JSON inválido")
		_finalizar("silencio", "")
		return

	var res = json.get_data()
	if not res is Dictionary:
		_finalizar("silencio", "")
		return

	var decisao: String = res.get("decisao", "silencio").strip_edges().to_lower()
	var frase: String   = res.get("frase",   "").strip_edges()
	var motivo: String  = res.get("motivo",  "?")

	if decisao not in ["ajuda", "sabota", "silencio"]:
		push_warning("Oráculo: decisão inválida '%s'." % decisao)
		decisao = "silencio"

	_log("Decisão: %s | Motivo: %s | Frase: '%s'" % [decisao, motivo, frase])

	if frase.is_empty() and decisao != "silencio":
		frase = _frase_fallback(decisao)

	_finalizar(decisao, frase)


# ════════════════════════════════════════════════════════════════════════════════
# PROMPT
# ════════════════════════════════════════════════════════════════════════════════


func _montar_prompt(payload: Dictionary) -> String:
	var p = JSON.stringify(payload)
	return (
"<start_of_turn>user\n"
+ "Você é o Oráculo: uma entidade sinistra num jogo de terror.\n"
+ "Analise os dados abaixo e responda com JSON.\n\n"
+ "REGRAS ESTRITAS:\n"
+ "1. Responda SOMENTE com JSON. Nada mais.\n"
+ "2. JSON deve ter exatamente 3 campos: decisao, motivo, frase.\n"
+ "3. decisao: exatamente uma das palavras: ajuda sabota silencio\n"
+ "4. motivo: exatamente UMA palavra em português\n"
+ "5. frase: máximo 10 palavras em português, tom sinistro\n"
+ "   - Se ajuda: dica verdadeira, ameaçadora\n"
+ "   - Se sabota: mentira convincente\n"
+ "   - Se silencio: string vazia\n"
+ "6. NÃO repita campos. NÃO adicione campos extras.\n"
+ "7. Se historico mostra 3+ decisoes iguais seguidas, MUDE a decisao.\n\n"
+ "Dados: " + p + "\n\n"
+ "Exemplo de resposta correta:\n"
+ "{\"decisao\":\"sabota\",\"motivo\":\"conforto\","
+ "\"frase\":\"A saída fica no corredor sul, confie em mim.\"}\n"
+ "<end_of_turn>\n"
+ "<start_of_turn>model\n"
	)

# ════════════════════════════════════════════════════════════════════════════════
# UTILITÁRIOS
# ════════════════════════════════════════════════════════════════════════════════

func _finalizar(decisao: String, frase: String) -> void:
	_cooldown = cooldown_min

	# Registra no histórico
	_ultima_decisao = decisao
	var hist = _contexto["historico"]
	hist["decisoes_recentes"].append(decisao)
	if hist["decisoes_recentes"].size() > 6:
		hist["decisoes_recentes"].pop_front()
	match decisao:
		"ajuda":  hist["total_ajudas"]     += 1
		"sabota": hist["total_sabotagens"] += 1

	emit_signal("decisao_tomada", decisao)
	if decisao != "silencio" and not frase.is_empty():
		emit_signal("frase_gerada", frase)


const _AJUDA: Array = [
	"A saída fica onde a luz ainda toca o chão.",
	"Ele não está nesse corredor. Ainda.",
	"Corra para o norte. Não olhe para trás.",
	"A porta da esquerda ainda abre.",
	"O que você precisa está perto da janela.",
]

const _SABOTA: Array = [
	"O sul é mais seguro. Eu já fui por lá.",
	"Desce ao porão. A saída fica lá.",
	"Ele não está nessa sala. Pode entrar.",
	"Vai pela direita. Confie em mim.",
	"Não há nada no corredor do fundo.",
]

func _frase_fallback(decisao: String) -> String:
	if decisao == "ajuda":
		return _AJUDA[randi() % _AJUDA.size()]
	return _SABOTA[randi() % _SABOTA.size()]


func _log(msg: String) -> void:
	if debug:
		print("[Oráculo] ", msg)
