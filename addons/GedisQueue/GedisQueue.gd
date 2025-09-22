extends Node
class_name GedisQueue

const QUEUE_PREFIX = "gedis_queue:"

const STATUS_WAITING = "waiting"
const STATUS_ACTIVE = "active"
const STATUS_COMPLETED = "completed"
const STATUS_FAILED = "failed"

var _gedis: Gedis
var _workers: Array[GedisWorker] = []

func setup(gedis_instance: Gedis = null):
	if gedis_instance:
		_gedis = gedis_instance

func add(queue_name: String, job_data: Dictionary, opts: Dictionary = {}) -> GedisJob:
	_ensure_gedis_instance()

	var job_id = _generate_job_id()
	var job_key = _get_job_key(queue_name, job_id)
	var job = GedisJob.new(self, queue_name, job_id, job_data)

	var job_hash = {
		"id": job_id,
		"data": JSON.stringify(job_data),
		"status": STATUS_WAITING,
		"progress": 0.0
	}

	for key in job_hash:
		_gedis.hset(job_key, key, job_hash[key])
	
	_gedis.rpush(_get_queue_key(queue_name, STATUS_WAITING), job_id)

	return job

func get_job(queue_name: String, job_id: String) -> GedisJob:
	var job_key = _get_job_key(queue_name, job_id)
	var job_hash = _gedis.hgetall(job_key)

	if job_hash.is_empty():
		return null

	var job_data = JSON.parse_string(job_hash.get("data", "{}"))
	var job = GedisJob.new(self, queue_name, job_hash["id"], job_data)
	return job

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

func pause(queue_name: String) -> void:
	_ensure_gedis_instance()

	var state_key = _get_state_key(queue_name)
	_gedis.hset(state_key, "paused", "1")

func resume(queue_name: String) -> void:
	_ensure_gedis_instance()

	var state_key = _get_state_key(queue_name)
	_gedis.hdel(state_key, "paused")

func is_paused(queue_name: String) -> bool:
	_ensure_gedis_instance()

	var state_key = _get_state_key(queue_name)
	return _gedis.hexists(state_key, "paused")

func update_job_progress(queue_name: String, job_id: String, value: float):
	_ensure_gedis_instance()

	var job_key = _get_job_key(queue_name, job_id)
	_gedis.hset(job_key, "progress", value)

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

func _generate_job_id() -> String:
	var t = Time.get_unix_time_from_system()
	var r = randi() % 1000
	return "%s-%s" % [t, r]

func _ensure_gedis_instance():
	if !_gedis:
		setup()

func process(queue_name: String, processor: Callable) -> GedisWorker:
	var worker = GedisWorker.new(self, queue_name, processor)
	add_child(worker)
	_workers.append(worker)
	await worker.start()
	return worker

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
		_gedis = Gedis.new()
		_gedis.name = "GedisQueue"
		add_child(_gedis)

func _mark_job_completed(job: GedisJob, return_value):
	_ensure_gedis_instance()
	var job_key = _get_job_key(job.queue_name, job.id)
	_gedis.lrem(_get_queue_key(job.queue_name, STATUS_ACTIVE), 1, job.id)
	_gedis.hset(job_key, "status", STATUS_COMPLETED)
	_gedis.hset(job_key, "returnvalue", JSON.stringify(return_value))
	_gedis.lpush(_get_queue_key(job.queue_name, STATUS_COMPLETED), job.id)


func _mark_job_failed(job: GedisJob, error_message: String):
	_ensure_gedis_instance()
	var job_key = _get_job_key(job.queue_name, job.id)
	_gedis.lrem(_get_queue_key(job.queue_name, STATUS_ACTIVE), 1, job.id)
	_gedis.hset(job_key, "status", STATUS_FAILED)
	_gedis.hset(job_key, "failed_reason", error_message)
	_gedis.lpush(_get_queue_key(job.queue_name, STATUS_FAILED), job.id)