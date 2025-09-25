extends Node

class_name GedisWorker

## Processes jobs from a GedisQueue.
##
## A worker is responsible for fetching jobs from a specific queue and executing
## a processor function for each job.
##
## The processor function receives the job and is responsible for calling
## `job.complete()` or `job.fail()` to finish the job. The worker itself does
## not handle the return value of the processor.

signal completed(job: GedisJob, return_value)
signal failed(job: GedisJob, error_message: String)
signal progress(job: GedisJob, value: float)
signal _batch_completed

var _gedis_queue: GedisQueue
var _queue_name: String
var _processor: Callable
var _is_running = false
var _gedis: Gedis
var _jobs_in_progress = {}

var batch_size = 1

func _init(p_gedis_queue: GedisQueue, p_queue_name: String, p_processor: Callable):
	_gedis_queue = p_gedis_queue
	_gedis = _gedis_queue._gedis
	_queue_name = p_queue_name
	_processor = p_processor
	
	_gedis_queue.completed.connect(_on_job_completed)
	_gedis_queue.failed.connect(_on_job_failed)
	_gedis_queue.progress.connect(func(job: GedisJob, value: float): progress.emit(job, value))

## Starts the worker.
func start():
	_is_running = true
	_process_jobs()

## Stops the worker.
func close():
	_is_running = false

func _on_job_completed(job: GedisJob, return_value):
	if _jobs_in_progress.has(job.id):
		_jobs_in_progress.erase(job.id)
		if _jobs_in_progress.is_empty():
			_batch_completed.emit()
	completed.emit(job, return_value)

func _on_job_failed(job: GedisJob, error_message: String):
	if _jobs_in_progress.has(job.id):
		_jobs_in_progress.erase(job.id)
		if _jobs_in_progress.is_empty():
			_batch_completed.emit()
	failed.emit(job, error_message)

func _process_jobs():
	await get_tree().process_frame
	while _is_running:
		if _gedis_queue.is_paused(_queue_name):
			await get_tree().create_timer(1.0).timeout
			continue

		var job_ids = []
		for i in range(batch_size):
			var job_id = _gedis.lpop(_gedis_queue._get_queue_key(_queue_name, GedisQueue.STATUS_WAITING))
			if not job_id:
				break
			job_ids.append(job_id)

		if job_ids.is_empty():
			if Engine.is_editor_hint():
				await get_tree().process_frame
			else:
				if get_tree():
					await get_tree().process_frame
			continue

		for job_id in job_ids:
			_gedis.lpush(_gedis_queue._get_queue_key(_queue_name, GedisQueue.STATUS_ACTIVE), job_id)
			var job = _gedis_queue.get_job(_queue_name, job_id)
			if not job:
				push_warning("GedisQueueWorker: Job with id %s not found." % job_id)
				continue
			
			_jobs_in_progress[job_id] = job
			var job_key = _gedis_queue._get_job_key(_queue_name, job_id)
			_gedis.hset(job_key, "status", GedisQueue.STATUS_ACTIVE)
			_gedis_queue._gedis.publish(_gedis_queue._get_event_channel(_queue_name, "active"), {"job_id": job.id})
			var result = await _processor.call(job)
			if result is Object and result.has_method("is_valid"):
				result = await result
			
			if job.status == GedisQueue.STATUS_ACTIVE:
				job.complete(result)
		
		if not _jobs_in_progress.is_empty():
			await _batch_completed
