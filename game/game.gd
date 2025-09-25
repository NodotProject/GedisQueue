extends Control

var queue: GedisQueue
var job_nodes = {}
var worker: GedisWorker

@onready var jobs_container = $JobsContainer
@onready var batch_size_spinbox = $VBoxContainer/HBoxContainer/BatchSizeSpinBox

func _ready():
	queue = GedisQueue.new()
	add_child(queue)
	_start_worker()
	queue.completed.connect(_on_job_completed)
	queue.progress.connect(_on_job_progress)

func _process_job(job: GedisJob):
	print("Processing job: ", job.id)
	var duration = randf_range(1.0, 3.0)
	var steps = 10
	for i in range(steps):
		await get_tree().create_timer(duration / steps).timeout
		job.progress(float(i + 1) / steps)
	print("Completed job: ", job.id)
	job.complete({"result": "success", "duration": duration})

func _on_add_job_button_pressed():
	var job_data = {"timestamp": Time.get_unix_time_from_system()}
	var job = queue.add("default", job_data)
	print("Added job to queue: ", job.id)
	
	var progress_bar = ProgressBar.new()
	progress_bar.value = 0
	jobs_container.add_child(progress_bar)
	job_nodes[job.id] = progress_bar

func _on_job_completed(job: GedisJob, return_value):
	if job_nodes.has(job.id):
		var progress_bar = job_nodes[job.id]
		progress_bar.value = 100
		# Create a stylebox with a green background
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color.GREEN
		progress_bar.add_theme_stylebox_override("fill", style_box)


func _on_job_progress(job: GedisJob, value: float):
	if job_nodes.has(job.id):
		var progress_bar = job_nodes[job.id]
		progress_bar.value = value * 100

func _on_batch_size_spin_box_value_changed(value):
	_start_worker()

func _start_worker():
	if worker:
		worker.close()
	var batch_size = batch_size_spinbox.value
	worker = queue.process("default", _process_job, batch_size)

func _on_clear_queue_button_pressed():
	var jobs = queue.get_jobs("default", ["waiting", "active", "completed", "failed"], 0, -1)
	for job in jobs:
		job.remove()
	
	for node in jobs_container.get_children():
		node.queue_free()
	job_nodes.clear()
