extends "res://tests/test_base.gd"

func test_add_job():
	var job = _queue.add("test_queue", {"data": "test"})
	assert_not_null(job, "Job should not be null.")
	assert_not_null(job.id, "Job ID should not be null.")