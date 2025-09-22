extends Node

class_name GedisWorker

signal completed(job: GedisJob, return_value)
signal failed(job: GedisJob, error_message: String)
signal progress(job: GedisJob, value: float)

var _gedis_queue: GedisQueue
var _queue_name: String
var _processor: Callable
var _is_running = false
var _gedis: Gedis

func _init(p_gedis_queue: GedisQueue, p_queue_name: String, p_processor: Callable):
	_gedis_queue = p_gedis_queue
	_gedis = p_gedis_queue._gedis
	_queue_name = p_queue_name
	_processor = p_processor

func start():
	_is_running = true
	_process_jobs()

func close():
	_is_running = false

func _process_jobs():
	while _is_running:
		if _gedis_queue.is_paused(_queue_name):
			await get_tree().create_timer(1.0).timeout
			continue

		var job_id = _gedis.lpop(_gedis_queue._get_queue_key(_queue_name, GedisQueue.STATUS_WAITING))
		if not job_id:
			await get_tree().create_timer(1.0).timeout
			continue

		var job = _gedis_queue.get_job(_queue_name, job_id)
		if not job:
			continue

		var result = _processor.call(job)
		if result is Object and result.has_method("is_valid"): # A way to check for awaitable signals
			result = await result

		# Simplified error handling. A robust implementation would require more checks.
		_gedis_queue._mark_job_completed(job, result)
		completed.emit(job, result)