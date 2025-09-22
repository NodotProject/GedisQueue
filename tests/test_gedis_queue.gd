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