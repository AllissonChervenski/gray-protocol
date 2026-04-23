#class_name Level extends Node2D
extends  Node

var current_tilemap_bounds : Array[Vector2]
signal TileMapBoundsChanged(bounds : Array[Vector2])


func ChangeTilemapBounds(bounds: Array[Vector2]) -> void:
	current_tilemap_bounds = bounds
	TileMapBoundsChanged.emit( bounds )

#func _ready() -> void:
	#self.y_sort_enabled = true
	#PlayerManager.set_as_parent(self)
	#pass # Replace with function body.
#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	##PlayerManager.unparent_player(self)
	#pass
