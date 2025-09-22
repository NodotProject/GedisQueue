extends GutTest

var _queue: GedisQueue

func before_all():
	var gedis_instance = Gedis.new()
	gedis_instance.name = "Gedis"
	get_tree().get_root().add_child(gedis_instance)

	var queue_instance = GedisQueue.new()
	queue_instance.name = "GedisQueue"
	get_tree().get_root().add_child(queue_instance)
	
	_queue = queue_instance
	assert_not_null(_queue, "GedisQueue instance should be created.")

func after_all():
	var gedis_instance = get_tree().get_root().get_node("Gedis")
	if gedis_instance:
		gedis_instance.flushall()
		gedis_instance.queue_free()
	
	if is_instance_valid(_queue):
		_queue.queue_free()