class_name State extends Node

# Reference to player of this state
static var player : Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# When the player enter the state
func Enter() -> void:
	pass
	
func Exit() -> void:
	pass
	

func Process( _delta : float ) -> State:
	return null
	
func Physics( _delta : float) -> State:
	return null
	
	
func HandleInput( _event : InputEvent ) -> State:
	return null	
	
