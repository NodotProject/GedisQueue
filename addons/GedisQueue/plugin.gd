@tool
extends EditorPlugin

const GedisQueueDebuggerPanel = preload("res://addons/GedisQueue/debugger/gedis_queue_debugger_panel.tscn")

var queue_debugger_plugin
var queue_panel
var dashboard

func _enter_tree():
	queue_debugger_plugin = GedisQueueDebuggerPlugin.new()
	add_debugger_plugin(queue_debugger_plugin)
	
	var timer = Timer.new()
	timer.wait_time = 1
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	timer.start()

func _on_timer_timeout():
	var editor_node = EditorInterface.get_base_control()
	dashboard = editor_node.find_child("Gedis", true, false)
	
	if dashboard:
		var debugger = dashboard.plugin
		if debugger:
			var tab_container = dashboard.find_child("TabContainer", true, false)
			if tab_container:
				queue_panel = dashboard.find_child("Queue", true, false)
				if !queue_panel:
					queue_panel = GedisQueueDebuggerPanel.instantiate()
					queue_panel.name = "Queue"
					tab_container.add_child(queue_panel)
					queue_panel.set_plugin(debugger)
				
				var session_id = debugger.get_current_session_id()
				if session_id != -1:
					queue_debugger_plugin.set_queue_panel(session_id, queue_panel)


func _exit_tree():
	if queue_debugger_plugin:
		remove_debugger_plugin(queue_debugger_plugin)
		queue_debugger_plugin = null
	if queue_panel:
		queue_panel.queue_free()

class GedisQueueDebuggerPlugin extends EditorDebuggerPlugin:
	var queue_panels = {}

	func set_queue_panel(session_id, panel):
		queue_panels[session_id] = panel

	func _has_capture(capture):
		return capture == "gedis"

	func _capture(message, data, session_id):
		var parts = message.split(":")
		var kind = parts[1] if parts.size() > 1 else ""

		if session_id in queue_panels:
			var queue_panel = queue_panels[session_id]
			match kind:
				"snapshot_data":
					if queue_panel:
						var snapshot = data[0]
						var queues = {}
						var jobs = []
						
						for key in snapshot:
							var value = snapshot[key]
							if "job" in key:
								var job_data = value["value"]
								var key_parts = key.split(":")
								if key_parts.size() > 2:
									job_data["queue_name"] = key_parts[1]
								jobs.append(job_data)
							else:
								var queue_name = key.replace("gedis_queue:", "").replace(":waiting", "").replace(":active", "")
								if not queue_name in queues:
									queues[queue_name] = []
								queues[queue_name].append_array(value["value"])
						
						queue_panel.update_queues(queues)
						queue_panel.update_jobs(jobs)
					return true
		return false
