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
	var worker = await _queue.process("retention_queue", func(job): job.complete("done"))

	_queue.add("retention_queue", {})
	_queue.add("retention_queue", {})
	_queue.add("retention_queue", {})

	for i in range(3):
		await worker.completed

	var completed_jobs = _queue.get_jobs("retention_queue", [GedisQueue.STATUS_COMPLETED])
	assert_eq(completed_jobs.size(), 2, "Should only keep 2 completed jobs.")

func test_failed_job_retention():
	_queue.max_failed_jobs = 1
	var worker = await _queue.process("failed_retention", func(job): job.fail("error"))

	_queue.add("failed_retention", {})
	_queue.add("failed_retention", {})

	for i in range(2):
		await worker.failed

	var failed_jobs = _queue.get_jobs("failed_retention", [GedisQueue.STATUS_FAILED])
	assert_eq(failed_jobs.size(), 1, "Should only keep 1 failed job.")

func test_added_event():
	_subscribe_to_events("added_queue")
	var job = _queue.add("added_queue", {"data": "test"})
	await get_tree().create_timer(0.1).timeout

	assert_eq(_events.size(), 1)
	assert_eq(_events[0].channel, _queue._get_event_channel("added_queue", "added"))
	assert_eq(_events[0].message.job_id, job.id)

func test_active_event():
	_subscribe_to_events("active_queue")
	var worker = await _queue.process("active_queue", func(job): job.complete("done"))
	var job = _queue.add("active_queue", {"data": "test"})
	await worker.completed
	await get_tree().create_timer(0.1).timeout

	assert_eq(_events.size(), 3)
	assert_eq(_events[1].channel, _queue._get_event_channel("active_queue", "active"))
	assert_eq(_events[1].message.job_id, job.id)

func test_progress_event():
	_subscribe_to_events("progress_queue")
	var worker = await _queue.process("progress_queue", func(job):
		job.progress(50)
		job.complete("done")
	)
	var job = _queue.add("progress_queue", {"data": "test"})
	await worker.completed
	
	var progress_event = null
	for e in _events:
		if e.channel.ends_with(":progress"):
			progress_event = e
			break
	assert_not_null(progress_event, "Progress event not found")
	assert_eq(progress_event.message.job_id, job.id)
	assert_eq(progress_event.message.progress, 50.0)

func test_process_jobs_in_batches():
	var processed_jobs = []
	var worker = await _queue.process("batch_queue", func(job):
		processed_jobs.append(job.id)
		job.complete()
	, 3)

	var jobs = []
	for i in range(5):
		jobs.append(_queue.add("batch_queue", {}))

	for i in range(5):
		await worker.completed

	assert_eq(processed_jobs.size(), 5)

func test_waits_for_batch_to_complete():
	var processed_jobs = []
	var worker = await _queue.process("batch_wait_queue", func(job):
		processed_jobs.append(job.id)
		if processed_jobs.size() == 1:
			await get_tree().create_timer(0.2).timeout
		job.complete()
	, 2)

	var job1 = _queue.add("batch_wait_queue", {})
	var job2 = _queue.add("batch_wait_queue", {})
	var job3 = _queue.add("batch_wait_queue", {})

	await worker.completed
	assert_eq(processed_jobs.size(), 1)
	assert_eq(processed_jobs[0], job1.id)

	await worker.completed
	assert_eq(processed_jobs.size(), 2)
	assert_has(processed_jobs, job2.id)

	await worker.completed
	assert_eq(processed_jobs.size(), 3)
	assert_has(processed_jobs, job3.id)