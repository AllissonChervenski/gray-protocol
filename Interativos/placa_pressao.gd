extends Area2D

# Arraste a porta da sua cena para este campo no Inspetor
@export var porta_alvo: StaticBody2D 

func _ready():
	# Conectamos os sinais do Area2D via código (ou pelo painel Nó)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	# Verificamos se o objeto que entrou tem o método de empurrar
	if body.has_method("empurrar"): 
		print("Caixa posicionada!")
		if porta_alvo and porta_alvo.has_method("abrir_porta"):
			porta_alvo.abrir_porta()

func _on_body_exited(body):
	if body.has_method("empurrar"):
		print("Caixa removida!")
		if porta_alvo and porta_alvo.has_method("fechar_porta"):
			porta_alvo.fechar_porta()
