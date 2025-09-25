@tool
extends VBoxContainer

# UI references will be set from the scene
@export var queues_tree: Tree
@export var jobs_tree: Tree
@export var job_details_text: TextEdit
@export var refresh_button: Button

var plugin

func _ready() -> void:
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)

func set_plugin(p) -> void:
	plugin = p

func _on_refresh_pressed() -> void:
	if plugin:
		# This assumes the main dashboard has an instance selector
		var selected_id = get_parent().get_parent().instance_selector.get_item_id(get_parent().get_parent().instance_selector.selected)
		var session_id = plugin.get_current_session_id()
		if session_id != -1:
			var session = plugin.get_session(session_id)
			if session and session.is_active():
				session.send_message("gedis:request_instance_data", [selected_id])

func update_queues(data: Dictionary) -> void:
	queues_tree.clear()
	var root = queues_tree.create_item()
	queues_tree.hide_root = true

	for queue_name in data:
		var queue_item = queues_tree.create_item(root)
		queue_item.set_text(0, queue_name)
		queue_item.set_text(1, str(data[queue_name].size()))

func update_jobs(jobs: Array) -> void:
	jobs_tree.clear()
	var root = jobs_tree.create_item()
	jobs_tree.hide_root = true

	for job in jobs:
		var job_item = jobs_tree.create_item(root)
		job_item.set_text(0, job.id)
		job_item.set_text(1, job.type)
		job_item.set_text(2, job.status)
		job_item.set_meta("details", job.details)

func _on_jobs_tree_item_selected() -> void:
	var selected_item = jobs_tree.get_selected()
	if selected_item:
		job_details_text.text = selected_item.get_meta("details")
