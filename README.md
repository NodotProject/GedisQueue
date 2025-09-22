# GedisQueue

GedisQueue is a powerful and flexible job queue system for Godot, built on top of Gedis. It allows you to manage and process asynchronous jobs in your Godot projects, making it ideal for handling tasks like background processing, notifications, and more.

## Features

- **Persistent Job Queues**: Jobs are stored in Gedis, ensuring they are not lost even if the application closes.
- **Job Lifecycle Management**: Track jobs through various statuses, including `waiting`, `active`, `completed`, and `failed`.
- **Flexible Job Processors**: Define custom logic for processing jobs using simple functions.
- **Delayed Jobs**: Schedule jobs to be executed at a future time.
- **Job Retries**: Automatically retry failed jobs with configurable retry attempts.

## Installation

To use GedisQueue, you need to have the Gedis addon installed and enabled in your Godot project. You can download Gedis from the Godot Asset Library or from its [GitHub repository](https://github.com/Jummit/Gedis).

Once Gedis is set up, install the GedisQueue addon by copying the contents of the `addons/GedisQueue` directory into your project's `addons` folder. Then, enable the "GedisQueue" plugin in your Project Settings.

## Usage

### Creating a Queue

To get started, you need to create an instance of the `GedisQueue` class. It's recommended to add it to your scene tree as an autoloaded singleton for easy access throughout your project.

```gdscript
# In your main script or an autoloaded singleton
var queue = GedisQueue.new()

# Optionally pass your existing gedis instance
# queue.setup(my_gedis_instance)

add_child(queue)
```

### Adding Jobs

You can add a job to a queue using the `add` method. Each job is identified by a unique ID and can carry any data you need. For example, you could add a job to grant a player a daily reward.

```gdscript
var job = queue.add("player_rewards", {
    "player_id": "player123",
    "reward_type": "daily_login_bonus",
    "items": ["gold_coins", "health_potion"],
    "quantity": [100, 2]
})

print("Reward job added with ID: ", job.id)
```

### Processing Jobs

To process jobs, you need to define a worker that executes your custom logic. The `process` method takes a queue name and a processor function as arguments. This function will handle the logic for granting the reward.

```gdscript
var processor = func(job):
    var reward_data = job.data
    var player = get_player(reward_data.player_id)
    print("Granting reward to: ", player.name)
    
    for i in range(reward_data.items.size()):
        player.inventory.add_item(reward_data.items[i], reward_data.quantity[i])
        
    return "Reward granted successfully"

var worker = queue.process("player_rewards", processor)
```

The processor function receives the job as an argument and can return a result that will be stored in the completed job.

### Job Lifecycle

You can monitor the status of jobs using the `get_jobs` method. This allows you to retrieve jobs in different states, such as `waiting`, `active`, `completed`, or `failed`. This is useful for tracking game events.

```gdscript
# Get all completed reward jobs
var completed_jobs = queue.get_jobs("player_rewards", [GedisQueue.STATUS_COMPLETED])
for job in completed_jobs:
    print("Job %s completed with result: %s" % [job.id, job.return_value])

# Get all failed jobs
var failed_jobs = queue.get_jobs("player_rewards", [GedisQueue.STATUS_FAILED])
for job in failed_jobs:
    print("Job %s failed with error: %s" % [job.id, job.failed_reason])
```

### Delayed Jobs

You can schedule a job to be executed after a certain delay using the `delay` option. This is perfect for time-based game mechanics, like a power-up that activates after a cooldown.

```gdscript
# This job will be processed after a 10-second delay
var job = queue.add("game_events", {"event": "spawn_boss", "level": 5}, {
    "delay": 10000 # in milliseconds
})
```

### Retrying Failed Jobs

GedisQueue can automatically retry failed jobs. You can configure the number of retry attempts using the `attempts` option. This is useful for critical operations like saving player progress, where a temporary network issue might cause a failure.

```gdscript
var processor = func(job):
    var save_successful = PlayerData.save_to_cloud(job.data)
    if not save_successful:
        # Simulate a random failure
        return GedisQueue.ERR_FAILED
    return "Player data saved"

# This job will be retried up to 3 times if it fails
var job = queue.add("save_game", {"player_id": "player123", "level": 10}, {
    "attempts": 3
})

queue.process("save_game", processor)
```

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue on the [GitHub repository](https://github.com/Jummit/GedisQueue).

## License

GedisQueue is licensed under the MIT License. See the `LICENSE` file for more details.
