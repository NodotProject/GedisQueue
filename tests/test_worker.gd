extends GutTest

var _queue: GedisQueue
var _worker: GedisWorker

func before_each():
	_queue = GedisQueue.new()
	add_child(_queue)
	# The Gedis instance must be set up for the queue to work.
	_queue.setup()

func after_each():
	if is_instance_valid(_worker):
		_worker.queue_free()
	if is_instance_valid(_queue):
		_queue.queue_free()

func test_worker_processes_job_and_emits_completed():
	var processor = func(job: GedisJob):
		return job.data.value * 2

	_worker = await _queue.process("test_queue", processor)

	var job_data = {"value": 5}
	var job: GedisJob = _queue.add("test_queue", job_data)

	var result: Array = await _worker.completed
	assert_eq(result[0].id, job.id, "Job ID should match.")
	assert_eq(result[1], 10.0, "Processor should have doubled the value.")
