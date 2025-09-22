extends GutTest

func test_job_instantiation():
	var job = GedisJob.new(null, "test_queue", "123", {"data": "test"})
	assert_eq(job.id, "123", "Job ID should be set correctly.")
	assert_eq(job.data, {"data": "test"}, "Job data should be set correctly.")
	assert_eq(job.status, "waiting", "Job status should be waiting by default.")

func test_job_status():
	var job = GedisJob.new(null, "test_queue", "123", {"data": "test"}, "active")
	assert_eq(job.status, "active", "Job status should be set correctly.")