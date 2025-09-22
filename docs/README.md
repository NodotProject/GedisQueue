# GedisQueue Documentation

GedisQueue is a BullMQ-like queue system for Godot, backed by the Gedis addon. It provides a simple yet powerful API for creating, processing, and managing background jobs in your Godot applications.

## Installation

### From Godot Asset Library

1.  Open the **AssetLib** tab in the Godot editor.
2.  Search for "GedisQueue" and click on the addon.
3.  Click the **Download** button, and then **Install**.
4.  Enable the addon in **Project > Project Settings > Plugins**.

### Manual Installation

1.  Download the latest release from the [GitHub repository](https://github.com/NodotProject/GedisQueue).
2.  Extract the `addons/GedisQueue` directory into your project's `addons` directory.
3.  Enable the addon in **Project > Project Settings > Plugins**.

## Getting Started

Once the addon is enabled, you can access the `GedisQueue` singleton globally in your scripts.

Here's a simple example of how to add a job to a queue and process it:

```gdscript
# In any of your scripts

func _ready():
    # Add a job to the 'image_processing' queue
    var job_data = {"image_path": "res://path/to/image.png"}
    var job = GedisQueue.add("image_processing", job_data)
    print("Added job with ID: ", job.id)

    # Start a worker to process jobs from the queue
    var worker = GedisQueue.process("image_processing", _process_image)
    worker.completed.connect(_on_job_completed)

func _process_image(job):
    print("Processing image: ", job.data.image_path)
    # ... your image processing logic here ...
    return "Image processed successfully"

func _on_job_completed(job, return_value):
    print("Job %s completed with result: %s" % [job.id, return_value])
```

## API Reference

### GedisQueue Class

The `GedisQueue` class is the main entry point for interacting with the queue system.

-   `func add(queue_name: String, job_data: Dictionary, opts: Dictionary = {}) -> Job`: Adds a new job to the specified queue.
-   `func process(queue_name: String, processor: Callable) -> Worker`: Starts a worker to process jobs from the queue.
-   `func get_job(queue_name: String, job_id: String) -> Job`: Retrieves a job by its ID.
-   `func get_jobs(queue_name: String, types: Array, start: int = 0, end: int = -1, asc: bool = false) -> Array[Job]`: Retrieves a list of jobs from the queue. `types` can be `["waiting", "completed", "failed"]`.
-   `func pause(queue_name: String) -> void`: Pauses the queue.
-   `func resume(queue_name: String) -> void`: Resumes a paused queue.
-   `func close(queue_name: String) -> void`: Closes the queue and its workers.

### Job Class

The `Job` class represents a single job in the queue.

-   `var id: String`: The unique ID of the job.
-   `var data: Dictionary`: The data associated with the job.
-   `var queue_name: String`: The name of the queue the job belongs to.
-   `func progress(value: float) -> void`: Updates the job's progress.
-   `func remove() -> void`: Removes the job from the queue.

### Worker Class

The `Worker` class is responsible for processing jobs.

-   `signal completed(job: Job, return_value)`: Emitted when a job is successfully completed.
-   `signal failed(job: Job, error_message: String)`: Emitted when a job fails.
-   `signal progress(job: Job, value: float)`: Emitted when a job's progress is updated.
-   `func close() -> void`: Closes the worker.