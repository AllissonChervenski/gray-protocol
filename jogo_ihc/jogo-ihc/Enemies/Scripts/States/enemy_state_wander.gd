class_name EnemyStateWander extends EnemyState

@export var anim_name : String = "walk"
@export var wander_speed : float = 20.0
@export_category("AI")
@export var state_animation_duration : float = 0.5
@export var states_cicles_min : int = 1
@export var states_cicles_max : int = 3
@export var next_state : EnemyState

var _timer : float = 0.0
var _direction : Vector2

func init() -> void:
	pass

# When the player enter the state
func Enter() -> void:
	_timer = randi_range( states_cicles_min, states_cicles_max) * state_animation_duration
	var rand = randi_range( 0, 3)
	_direction = enemy.DIR_4 [rand]
	enemy.velocity = _direction * wander_speed
	enemy.set_direction( _direction )
	enemy.update_animation( anim_name)
	pass
	
func Exit() -> void:
	pass
	
func Process( _delta : float ) -> EnemyState:
	_timer -= _delta
	if _timer <= 0:
		return next_state
	return null
	
func Physics( _delta : float) -> EnemyState:
	return null
