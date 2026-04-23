class_name EnemyStateStun extends EnemyState

@export var anim_name : String = "stun"
@export var knockback_speed : float = 200.0
@export var decelerate_speed : float = 10.0
@export_category("AI")
@export var next_state : EnemyState

var _direction : Vector2
var _animation_finished : bool = false

func init() -> void:
	pass

# When the player enter the state
func Enter() -> void:
	_animation_finished == false
	#_direction = enemy.DIR_4 [rand]
	
	enemy.set_direction( _direction )
	enemy.velocity = _direction * -knockback_speed
	
	enemy.update_animation( anim_name)
	pass
	
func Exit() -> void:
	pass
	
func Process( _delta : float ) -> EnemyState:
	if _animation_finished == true:
		return next_state
	enemy.velocity -= enemy.velocity * decelerate_speed * _delta
	return null
	
func Physics( _delta : float) -> EnemyState:
	return null
