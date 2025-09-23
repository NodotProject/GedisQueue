extends GutTest

const GedisJob = preload("res://addons/GedisQueue/GedisQueueJob.gd")
const GedisQueue = preload("res://addons/GedisQueue/GedisQueue.gd")

var _queue_double
var _job

func before_each():
	_queue_double = double(GedisQueue).new()
	_job = GedisJob.new(_queue_double, "test_queue", "123", {"data": "test"})

	stub(_queue_double, "_job_completed").to_call(Callable(self, "_stub_job_completed"))
	stub(_queue_double, "_job_failed").to_call(Callable(self, "_stub_job_failed"))

func _stub_job_completed(job, result):
	if not _queue_double.has_user_signal("completed"):
		_queue_double.add_user_signal("completed")
	_queue_double.emit_signal("completed", result, job)

func _stub_job_failed(job, error_message):
	if not _queue_double.has_user_signal("failed"):
		_queue_double.add_user_signal("failed")
	_queue_double.emit_signal("failed", error_message, job)

func test_job_instantiation():
	var job = GedisJob.new(null, "test_queue", "123", {"data": "test"})
	assert_eq(job.id, "123", "Job ID should be set correctly.")
	assert_eq(job.data, {"data": "test"}, "Job data should be set correctly.")
	assert_eq(job.status, "waiting", "Job status should be waiting by default.")

func test_job_status():
	var job = GedisJob.new(null, "test_queue", "123", {"data": "test"}, "active")
	assert_eq(job.status, "active", "Job status should be set correctly.")

func test_job_complete_emits_signal_from_queue():
	watch_signals(_queue_double)
	_job.complete("success")
	assert_signal_emitted_with_parameters(_queue_double, "completed", ["success", _job])

func test_job_fail_emits_signal_from_queue():
	watch_signals(_queue_double)
	_job.fail("failure")
	assert_signal_emitted_with_parameters(_queue_double, "failed", ["failure", _job])