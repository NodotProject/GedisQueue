extends GutTest

var _queue: GedisQueue

func before_each():
	var gedis_instance = Gedis.new()
	gedis_instance.name = "Gedis"
	add_child(gedis_instance)
	_queue = GedisQueue.new()
	_queue.max_completed_jobs = 1
	_queue.max_failed_jobs = 1
	add_child(_queue)
	_queue.setup(gedis_instance)

func after_each():
	if is_instance_valid(_queue):
		_queue.queue_free()
	var gedis_instance = get_node_or_null("Gedis")
	if is_instance_valid(gedis_instance):
		gedis_instance.queue_free()

func test_job_lifecycle():
	var processor = func(job):
		job.complete("processed")

	var worker = await _queue.process("test_queue", processor)
	var job = _queue.add("test_queue", {"data": "test"})

	for i in range(5): await get_tree().process_frame
	
	var completed_jobs = _queue.get_jobs("test_queue", [GedisQueue.STATUS_COMPLETED])
	assert_eq(completed_jobs.size(), 1, "There should be one completed job.")
	assert_eq(completed_jobs[0].id, job.id, "Completed job ID should match.")
	
	var waiting_jobs = _queue.get_jobs("test_queue", [GedisQueue.STATUS_WAITING])
	assert_eq(waiting_jobs.size(), 0, "There should be no waiting jobs.")

func test_pubsub_events():
	var events = []
	_queue._gedis.psubscribe("gedis_queue:pubsub_test:events:*", self)
	_queue._gedis.psub_message.connect(func(pattern, channel, message): events.append(message))

	var worker = await _queue.process("pubsub_test", func(job): job.complete("result"))
	var job = _queue.add("pubsub_test", {"data": "test"})

	for i in range(5): await get_tree().process_frame

	assert_eq(events.size(), 3, "Should have received 3 events (added, active, completed).")
	assert_eq(events[0].job_id, job.id, "Added event job ID should match.")
	assert_eq(events[1].job_id, job.id, "Active event job ID should match.")
	assert_eq(events[2].job_id, job.id, "Completed event job ID should match.")
