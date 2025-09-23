extends Node

class_name GedisWorker

## Processes jobs from a GedisQueue.
##
## A worker is responsible for fetching jobs from a specific queue and executing
## a processor function for each job. It runs in a loop and can be started and
## stopped.

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
	_gedis = _gedis_queue._gedis
	_queue_name = p_queue_name
	_processor = p_processor

## Starts the worker.
func start():
	_is_running = true
	_process_jobs()

## Stops the worker.
func close():
	_is_running = false

func _process_jobs():
	await get_tree().process_frame
	while _is_running:
		if _gedis_queue.is_paused(_queue_name):
			await get_tree().create_timer(1.0).timeout
			continue

		var job_id = _gedis.lpop(_gedis_queue._get_queue_key(_queue_name, GedisQueue.STATUS_WAITING))
		if not job_id:
			if Engine.is_editor_hint():
				await get_tree().process_frame
			else:
				if get_tree():
					await get_tree().create_timer(1.0).timeout
			continue

		_gedis.lpush(_gedis_queue._get_queue_key(_queue_name, GedisQueue.STATUS_ACTIVE), job_id)
		var job = _gedis_queue.get_job(_queue_name, job_id)
		if not job:
			continue

		_gedis_queue._gedis.publish(_gedis_queue._get_event_channel(_queue_name, "active"), {"job_id": job.id})

		var result = _processor.call(job)

		if result is int and result != OK:
			var error_message = "Job failed with error code: %s" % result
			_gedis_queue._mark_job_failed(job, error_message)
			failed.emit(job, error_message)
		else:
			if result is Object and result.has_method("is_valid"): # A way to check for awaitable signals
				result = await result
			_gedis_queue._mark_job_completed(job, result)
			completed.emit(job, result)