extends "res://tests/test_base.gd"

func test_add_job():
	var job = _queue.add("test_queue", {"data": "test"})
	assert_not_null(job, "Job should not be null.")
	assert_not_null(job.id, "Job ID should not be null.")

func test_remove_job():
	var job = _queue.add("test_remove", {"data": "test"})
	assert_not_null(job, "Job should not be null.")

	_queue.remove_job("test_remove", job.id)

	var waiting_jobs = _queue.get_jobs("test_remove", [GedisQueue.STATUS_WAITING])
	assert_eq(waiting_jobs.size(), 0, "Waiting jobs should be empty after removal.")

	var job_from_gedis = _queue.get_job("test_remove", job.id)
	assert_null(job_from_gedis, "Job should be null after removal.")

func test_completed_job_retention():
	_queue.max_completed_jobs = 2
	var worker = await _queue.process("retention_queue", func(job): return "done")

	_queue.add("retention_queue", {})
	_queue.add("retention_queue", {})
	_queue.add("retention_queue", {})

	await worker.completed
	await worker.completed
	await worker.completed

	var completed_jobs = _queue.get_jobs("retention_queue", [GedisQueue.STATUS_COMPLETED])
	assert_eq(completed_jobs.size(), 2, "Should only keep 2 completed jobs.")

func test_failed_job_retention():
	_queue.max_failed_jobs = 1
	var worker = await _queue.process("failed_retention", func(job): return FAILED)

	_queue.add("failed_retention", {})
	_queue.add("failed_retention", {})

	await worker.failed
	await worker.failed

	var failed_jobs = _queue.get_jobs("failed_retention", [GedisQueue.STATUS_FAILED])
	assert_eq(failed_jobs.size(), 1, "Should only keep 1 failed job.")