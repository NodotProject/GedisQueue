extends GutTest

var _queue: GedisQueue

func before_each():
	var gedis_instance = Gedis.new()
	add_child(gedis_instance)
	_queue = GedisQueue.new()
	add_child(_queue)
	_queue.setup(gedis_instance)

func after_each():
	if is_instance_valid(_queue):
		_queue.queue_free()
	var gedis_instance = get_node_or_null("Gedis")
	if is_instance_valid(gedis_instance):
		gedis_instance.queue_free()