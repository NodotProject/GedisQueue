extends GutTest

func test_job_instantiation():
	var job = GedisJob.new(null, "test_queue", "123", {"data": "test"})
	assert_eq(job.id, "123", "Job ID should be set correctly.")
	assert_eq(job.data, {"data": "test"}, "Job data should be set correctly.")