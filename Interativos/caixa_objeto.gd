extends CharacterBody2D


func empurrar(force: Vector2):
	velocity = force
	move_and_slide()
