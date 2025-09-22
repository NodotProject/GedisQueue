@tool
extends EditorPlugin

var gedis_queue_singleton

func _enter_tree():
	gedis_queue_singleton = preload("res://addons/GedisQueue/GedisQueue.gd").new()
	gedis_queue_singleton.name = "GedisQueue"
	get_tree().root.add_child(gedis_queue_singleton)

func _exit_tree():
	if is_instance_valid(gedis_queue_singleton):
		gedis_queue_singleton.queue_free()
