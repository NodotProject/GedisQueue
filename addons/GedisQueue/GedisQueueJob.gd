extends RefCounted

class_name GedisJob

## Represents a job in a GedisQueue.
##
## This class holds information about a job, such as its ID, data, and status.
## It also provides methods for interacting with the job, such as updating its
## progress and removing it from the queue.

var id: String
var data: Dictionary
var queue_name: String
var status: String

var _gedis_queue

func _init(p_gedis_queue, p_queue_name: String, p_id: String, p_data: Dictionary, p_status: String = GedisQueue.STATUS_WAITING):
	_gedis_queue = p_gedis_queue
	queue_name = p_queue_name
	id = p_id
	data = p_data
	status = p_status

## Updates the progress of the job.
##
## @param value The new progress value (0.0 to 1.0).
func progress(value: float) -> void:
	_gedis_queue.update_job_progress(queue_name, id, value)

## Removes the job from the queue.
func remove() -> void:
	_gedis_queue.remove_job(queue_name, id)

## Marks the job as completed.
##
## This should be called by a worker's processor function when the job has
## been successfully processed.
##
## @param return_value An optional value to store as the result of the job.
func complete(return_value: Variant = null) -> void:
	_gedis_queue._job_completed(self, return_value)

## Marks the job as failed.
##
## This should be called by a worker's processor function when the job has
## failed to be processed.
##
## @param error_message The error message to store for the failed job.
func fail(error_message: String) -> void:
	_gedis_queue._job_failed(self, error_message)