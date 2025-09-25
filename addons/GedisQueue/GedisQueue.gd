extends Node
class_name GedisQueue

## Manages job queues and workers.
##
## This class provides a high-level interface for creating and managing job queues
## that are processed by workers. It uses Gedis (a Godot Redis-like in-memory
## data structure server) for storing job information and queue state.

## Emitted when a job is completed successfully.
signal completed(job: GedisJob, return_value)
## Emitted when a job fails.
signal failed(job: GedisJob, error_message: String)
## Emitted when a job's progress is updated.
signal progress(job: GedisJob, value: float)

const QUEUE_PREFIX = "gedis_queue:"

var max_completed_jobs := 0
var max_failed_jobs := 0

const STATUS_WAITING = "waiting"
const STATUS_ACTIVE = "active"
const STATUS_COMPLETED = "completed"
const STATUS_FAILED = "failed"

var _gedis: Gedis
var _workers: Array[GedisWorker] = []

## Sets up the GedisQueue with a Gedis instance.
##
## If no Gedis instance is provided, a new one will be created automatically
## when needed.
##
## @param gedis_instance The Gedis instance to use.
func setup(gedis_instance: Gedis = null):
	if gedis_instance:
		_gedis = gedis_instance
	else:
		_gedis = Gedis.new()
		_gedis.name = "Gedis"
		add_child(_gedis)

## Adds a new job to a queue.
##
## @param queue_name The name of the queue to add the job to.
## @param job_data A dictionary containing the data for the job.
## @param opts A dictionary of options for the job.
##             "add_to_front": (bool) If true, adds the job to the front of the queue.
## @return The newly created GedisJob.
func add(queue_name: String, job_data: Dictionary, opts: Dictionary = {}) -> GedisJob:
	_ensure_gedis_instance()

	var job_id = _generate_job_id()
	var job_key = _get_job_key(queue_name, job_id)
	var job = GedisJob.new(self, queue_name, job_id, job_data)

	var job_hash = {
		"id": job_id,
		"data": job_data,
		"status": STATUS_WAITING,
		"progress": 0.0
	}

	for key in job_hash:
		_gedis.hset(job_key, key, job_hash[key])
	
	if opts.get("add_to_front", false):
		_gedis.lpush(_get_queue_key(queue_name, STATUS_WAITING), job_id)
	else:
		_gedis.rpush(_get_queue_key(queue_name, STATUS_WAITING), job_id)

	_gedis.publish(_get_event_channel(queue_name, "added"), {"job_id": job_id, "data": job_data})

	return job

## Retrieves a job from a queue by its ID.
##
## @param queue_name The name of the queue.
## @param job_id The ID of the job to retrieve.
## @return The GedisJob if found, otherwise null.
func get_job(queue_name: String, job_id: String) -> GedisJob:
	var job_key = _get_job_key(queue_name, job_id)
	var job_hash = _gedis.hgetall(job_key)

	if job_hash.is_empty():
		return null

	var job_data = job_hash.get("data", {})
	var job_status = job_hash.get("status", GedisQueue.STATUS_WAITING)
	var job = GedisJob.new(self, queue_name, job_id, job_data, job_status)
	return job

## Retrieves a list of jobs from a queue.
##
## @param queue_name The name of the queue.
## @param types An array of job statuses to retrieve (e.g., ["waiting", "active"]).
## @param start The starting index.
## @param end The ending index.
## @param asc Whether to sort in ascending order (currently unused).
## @return An array of GedisJob objects.
func get_jobs(queue_name: String, types: Array, start: int = 0, end: int = -1, asc: bool = false) -> Array[GedisJob]:
	var jobs: Array[GedisJob] = []
	for type in types:
		var queue_key = _get_queue_key(queue_name, type)
		var job_ids = _gedis.lrange(queue_key, start, end)
		for job_id in job_ids:
			var job = get_job(queue_name, job_id)
			if job:
				jobs.append(job)
	return jobs

## Pauses a queue.
##
## When a queue is paused, workers will not process any new jobs from it.
##
## @param queue_name The name of the queue to pause.
func pause(queue_name: String) -> void:
	_ensure_gedis_instance()

	var state_key = _get_state_key(queue_name)
	_gedis.hset(state_key, "paused", "1")

## Resumes a paused queue.
##
## @param queue_name The name of the queue to resume.
func resume(queue_name: String) -> void:
	_ensure_gedis_instance()

	var state_key = _get_state_key(queue_name)
	_gedis.hdel(state_key, "paused")

## Checks if a queue is paused.
##
## @param queue_name The name of the queue.
## @return True if the queue is paused, otherwise false.
func is_paused(queue_name: String) -> bool:
	_ensure_gedis_instance()

	var state_key = _get_state_key(queue_name)
	return _gedis.hexists(state_key, "paused")

## Updates the progress of a job.
##
## @param queue_name The name of the queue.
## @param job_id The ID of the job.
## @param value The new progress value (0.0 to 1.0).
func update_job_progress(queue_name: String, job_id: String, value: float):
	_ensure_gedis_instance()

	var job_key = _get_job_key(queue_name, job_id)
	_gedis.hset(job_key, "progress", value)
	_gedis.publish(_get_event_channel(queue_name, "progress"), {"job_id": job_id, "progress": value})
	progress.emit(get_job(queue_name, job_id), value)

## Removes a job from a queue.
##
## @param queue_name The name of the queue.
## @param job_id The ID of the job to remove.
func remove_job(queue_name: String, job_id: String):
	_ensure_gedis_instance()

	var job_key = _get_job_key(queue_name, job_id)
	_gedis.del(job_key)

	# Remove the job ID from all possible status lists
	for status in [STATUS_WAITING, STATUS_ACTIVE, STATUS_COMPLETED, STATUS_FAILED]:
		var queue_key = _get_queue_key(queue_name, status)
		_gedis.lrem(queue_key, 0, job_id)

func _get_queue_key(queue_name: String, status: String = STATUS_WAITING) -> String:
	return "%s%s:%s" % [QUEUE_PREFIX, queue_name, status]

func _get_job_key(queue_name: String, job_id: String) -> String:
	return QUEUE_PREFIX + queue_name + ":job:" + job_id

func _get_state_key(queue_name: String) -> String:
	return QUEUE_PREFIX + queue_name + ":state"

func _get_event_channel(queue_name: String, event: String) -> String:
	return "%s%s:events:%s" % [QUEUE_PREFIX, queue_name, event]

func _generate_job_id() -> String:
	var t = Time.get_unix_time_from_system()
	var r = randi() % 1000
	return "%s-%s" % [t, r]

func _ensure_gedis_instance():
	if not _gedis:
		var gedis_instance = Gedis.new()
		gedis_instance.name = "Gedis"
		add_child(gedis_instance)
		setup(gedis_instance)

## Starts a worker to process jobs from a queue.
##
## @param queue_name The name of the queue to process.
## @param processor A callable that will be executed for each job.
## @return The newly created GedisWorker.
func process(queue_name: String, processor: Callable, p_batch_size: int = 1) -> GedisWorker:
	var worker = GedisWorker.new(self, queue_name, processor, p_batch_size)
	add_child(worker)
	_workers.append(worker)
	worker.start()
	return worker

## Closes all workers for a specific queue.
##
## @param queue_name The name of the queue.
func close(queue_name: String) -> void:
	var workers_to_remove: Array[GedisWorker] = []
	for worker in _workers:
		if worker._queue_name == queue_name:
			workers_to_remove.append(worker)

	for worker in workers_to_remove:
		worker.close()
		_workers.erase(worker)
		worker.queue_free()

func _enter_tree() -> void:
	if !_gedis:
		var gedis_instance = Gedis.new()
		gedis_instance.name = "Gedis"
		add_child(gedis_instance)
		_gedis = gedis_instance

func _exit_tree():
	for worker in _workers:
		if is_instance_valid(worker):
			worker.close()

## Marks a job as completed.
##
## @param job The job to mark as completed.
## @param return_value The return value of the job.
func _job_completed(job: GedisJob, return_value):
	_ensure_gedis_instance()
	var job_key = _get_job_key(job.queue_name, job.id)
	_gedis.lrem(_get_queue_key(job.queue_name, STATUS_ACTIVE), 1, job.id)

	completed.emit(job, return_value)
	_gedis.publish(_get_event_channel(job.queue_name, "completed"), {"job_id": job.id, "return_value": return_value})

	if max_completed_jobs == 0:
		_gedis.del(job_key)
	else:
		_gedis.hset(job_key, "status", STATUS_COMPLETED)
		_gedis.hset(job_key, "returnvalue", return_value)
		_gedis.lpush(_get_queue_key(job.queue_name, STATUS_COMPLETED), job.id)
		if max_completed_jobs > 0:
			_gedis.ltrim(_get_queue_key(job.queue_name, STATUS_COMPLETED), 0, max_completed_jobs - 1)


## Marks a job as failed.
##
## @param job The job to mark as failed.
## @param error_message The error message.
func _job_failed(job: GedisJob, error_message: String):
	_ensure_gedis_instance()
	var job_key = _get_job_key(job.queue_name, job.id)
	_gedis.lrem(_get_queue_key(job.queue_name, STATUS_ACTIVE), 1, job.id)

	failed.emit(job, error_message)
	_gedis.publish(_get_event_channel(job.queue_name, "failed"), {"job_id": job.id, "error_message": error_message})

	if max_failed_jobs == 0:
		_gedis.del(job_key)
	else:
		_gedis.hset(job_key, "status", STATUS_FAILED)
		_gedis.hset(job_key, "failed_reason", error_message)
		_gedis.lpush(_get_queue_key(job.queue_name, STATUS_FAILED), job.id)
		if max_failed_jobs > 0:
			_gedis.ltrim(_get_queue_key(job.queue_name, STATUS_FAILED), 0, max_failed_jobs - 1)
