extends GutTest

var _queue: GedisQueue
var _worker: GedisWorker

func before_each():
	_queue = GedisQueue.new()
	add_child(_queue)
	var gedis_instance = Gedis.new()
	gedis_instance.name = "Gedis"
	_queue.setup(gedis_instance)
	add_child(gedis_instance)

func after_each():
	if is_instance_valid(_worker):
		_worker.queue_free()
	if is_instance_valid(_queue):
		_queue.queue_free()
	var gedis_instance = get_node_or_null("Gedis")
	if is_instance_valid(gedis_instance):
		gedis_instance.queue_free()

func test_worker_processes_job_and_emits_completed():
	var processor = func(job: GedisJob):
		job.complete(job.data.value * 2)

	_worker = _queue.process("test_queue", processor)
	add_child(_worker)

	var received_events = []
	_queue._gedis.psub_message.connect(func(_pattern, channel, message):
		var parts = channel.split(":")
		var event_name = parts[parts.size() - 1]
		
		var event_data = {
			"event": event_name,
			"job_id": message.job_id
		}
		
		if message.has("return_value"):
			event_data["return_value"] = message.return_value
			
		received_events.append(event_data)
	)
	_queue._gedis.psubscribe("gedis_queue:test_queue:events:*", self)

	var job_data = {"value": 5}
	var gedis_job: GedisJob = _queue.add("test_queue", job_data)

	for i in range(5):
		await get_tree().process_frame

	assert_eq(received_events.size(), 3, "Should receive 3 events.")
	var completed_event = received_events[2]
	assert_eq(completed_event.event, "completed", "Last event should be 'completed'.")
	assert_eq(completed_event.job_id, gedis_job.id, "Job ID should match.")
	assert_eq(completed_event.return_value, 10, "Processor should have doubled the value.")


func test_worker_waits_for_batch_to_complete():
	var completed_jobs = []
	var processor = func(job: GedisJob):
		await get_tree().create_timer(0.1).timeout
		completed_jobs.append(job.id)
		job.complete()

	_worker = _queue.process("test_queue", processor)
	_worker.batch_size = 3
	add_child(_worker)

	var job1 = _queue.add("test_queue", {})
	var job2 = _queue.add("test_queue", {})
	var job3 = _queue.add("test_queue", {})

	# Wait long enough for all jobs to be processed
	await get_tree().create_timer(0.5).timeout

	assert_eq(completed_jobs.size(), 3, "Should have completed 3 jobs.")
	assert_has(completed_jobs, job1.id)
	assert_has(completed_jobs, job2.id)
	assert_has(completed_jobs, job3.id)
