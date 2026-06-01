extends Resource
class_name ItemData  # Isso faz o Godot reconhecer como um novo tipo no editor

@export var nome: String = ""
@export var descricao: String = ""
@export var icone: Texture2D  # Para mostrar no inventário futuramente
@export var id_unico: String = "" # Útil para checagens (ex: "chave_biblioteca")
@export var usos: int = 1
