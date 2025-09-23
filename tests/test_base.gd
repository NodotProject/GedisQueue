extends GutTest

var _queue: GedisQueue
var _events = []
var _subscribed_patterns = []

func _on_psub_message(p, c, m):
	_events.append({"pattern": p, "channel": c, "message": m})

func before_each():
	_events.clear()
	var gedis_instance = Gedis.new()
	gedis_instance.name = "Gedis"
	add_child(gedis_instance)
	_queue = GedisQueue.new()
	add_child(_queue)
	_queue.setup(gedis_instance)
	if _queue._gedis.psub_message.is_connected(_on_psub_message):
		_queue._gedis.psub_message.disconnect(_on_psub_message)

func after_each():
	if is_instance_valid(_queue):
		for pattern in _subscribed_patterns:
			_queue._gedis.punsubscribe(pattern, self)
		if _queue._gedis.psub_message.is_connected(Callable(self, "_on_psub_message")):
			_queue._gedis.psub_message.disconnect(_on_psub_message)
		_queue.queue_free()
	var gedis_instance = get_node_or_null("Gedis")
	if is_instance_valid(gedis_instance):
		gedis_instance.queue_free()
	_subscribed_patterns.clear()

func _subscribe_to_events(queue_name):
	var pattern = "gedis_queue:%s:events:*" % queue_name
	_queue._gedis.psubscribe(pattern, self)
	_subscribed_patterns.append(pattern)
	_queue._gedis.psub_message.connect(_on_psub_message)