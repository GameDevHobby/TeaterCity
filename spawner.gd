class_name Spawner extends Marker2D

@export var PatronScene: PackedScene



func _on_timer_timeout() -> void:
	var patronInstance = PatronScene.instantiate() as Patron
	get_parent().add_child(patronInstance)
	patronInstance.global_position = self.global_position
