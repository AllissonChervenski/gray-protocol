extends InimigoBase # <-- Ele herda TUDO do inimigo comum! Movimento, ataque, tudo!

func _ready() -> void:
	super() # Chama o _ready do pai (para achar o jogador e adicionar ao grupo)
	
	# Sobrescrevemos as características únicas desse inimigo
	velocidade = 140.0 # O cego corre muito mais rápido
	distancia_visao = 300.0 # A "audição" dele vai muito longe
	
	dados_oraculo = {
		"nome_alvo": "Inimigo Rastreador",
	
	# FRAGMENTOS PARA AJUDAR (Verdade)
	"ajuda_fatos": [
		"Entidade com audição hiper-desenvolvida.",
		"O alvo é cego, mas mapeia o som.",
		"Visão ausente. Foco auditivo extremo.",
		"Sensores indicam cegueira, mas alta sensibilidade acústica."
	],
	"ajuda_conselhos": [
		"A furtividade é sua única vantagem.",
		"Ande devagar para sobreviver.",
		"Emita zero ruídos e passe despercebido.",
		"Mantenha-se agachado e em silêncio."
	],
	
	# FRAGMENTOS PARA SABOTAR (Mentira)
	"sabota_fatos": [
		"Entidade letárgica e surda.",
		"O alvo possui falhas auditivas severas.",
		"Anomalia acústica detectada: o alvo não escuta bem.",
		"Sensores não detectam perigo iminente."
	],
	"sabota_conselhos": [
		"Passe correndo, não haverá reação.",
		"Acelere o passo para economizar tempo.",
		"Corra. O alvo é incapaz de te rastrear.",
		"Movimentação rápida é recomendada."
	]
}
