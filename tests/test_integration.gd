extends GutTest

var _queue: GedisQueue

func before_each():
	_queue = GedisQueue.new()
	add_child(_queue)
	_queue.setup()

func after_each():
	if is_instance_valid(_queue):
		_queue.queue_free()

func test_job_lifecycle():
	var processor = func(job):
		return "processed"

	var worker = await _queue.process("test_queue", processor)
	var job = _queue.add("test_queue", {"data": "test"})

	await worker.completed
	
	var completed_jobs = _queue.get_jobs("test_queue", [GedisQueue.STATUS_COMPLETED])
	assert_eq(completed_jobs.size(), 1, "There should be one completed job.")
	assert_eq(completed_jobs[0].id, job.id, "Completed job ID should match.")
	
	var waiting_jobs = _queue.get_jobs("test_queue", [GedisQueue.STATUS_WAITING])
	assert_eq(waiting_jobs.size(), 0, "There should be no waiting jobs.")
