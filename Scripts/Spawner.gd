class_name Spawner extends Marker2D

@export var patron_scene: PackedScene


func _on_timer_timeout() -> void:
	var patron_instance = patron_scene.instantiate() as Patron
	get_parent().add_child(patron_instance)
	patron_instance.global_position = self.global_position
