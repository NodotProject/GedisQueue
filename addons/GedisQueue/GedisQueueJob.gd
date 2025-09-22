extends RefCounted

class_name GedisJob

var id: String
var data: Dictionary
var queue_name: String
var status: String

var _gedis_queue

func _init(p_gedis_queue, p_queue_name: String, p_id: String, p_data: Dictionary, p_status: String = GedisQueue.STATUS_WAITING):
	_gedis_queue = p_gedis_queue
	queue_name = p_queue_name
	id = p_id
	data = p_data
	status = p_status

func progress(value: float) -> void:
	_gedis_queue.update_job_progress(queue_name, id, value)

func remove() -> void:
	_gedis_queue.remove_job(queue_name, id)