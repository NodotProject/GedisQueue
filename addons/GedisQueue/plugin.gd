@tool
extends EditorPlugin

const GedisQueueDebuggerPanel = preload("res://addons/GedisQueue/debugger/gedis_queue_debugger_panel.tscn")

var queue_debugger_plugin

func _enter_tree():
	queue_debugger_plugin = GedisQueueDebuggerPlugin.new()
	add_debugger_plugin(queue_debugger_plugin)
	
	var timer = Timer.new()
	timer.wait_time = 1
	timer.one_shot = false # Check periodically
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	timer.start()

func _on_timer_timeout():
	var editor_node = EditorInterface.get_base_control()
	var dashboard = editor_node.find_child("Gedis", true, false)
	
	if dashboard and not dashboard.find_child("Queue", true, false):
		var debugger = dashboard.plugin
		if debugger:
			var tab_container = dashboard.find_child("TabContainer", true, false)
			if tab_container:
				var queue_panel = GedisQueueDebuggerPanel.instantiate()
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

class GedisQueueDebuggerPlugin extends EditorDebuggerPlugin:
	var queue_panels = {}

	func set_queue_panel(session_id, panel):
		queue_panels[session_id] = panel

	func _has_capture(capture):
		return capture == "gedis_queue"

	func _capture(message, data, session_id):
		var parts = message.split(":")
		var kind = parts[1] if parts.size() > 1 else ""

		if session_id in queue_panels:
			var queue_panel = queue_panels[session_id]
			match kind:
				"queue_data":
					if queue_panel:
						queue_panel.update_queues(data[0])
					return true
				"job_data":
					if queue_panel:
						queue_panel.update_jobs(data[0])
					return true
		return false
