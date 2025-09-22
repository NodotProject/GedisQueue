# GedisQueue

<p align="center">
    <img width="512" height="512" alt="image" src="https://github.com/NodotProject/GedisQueue/blob/main/addons/GedisQueue/icon.png?raw=true" />
</p>

<p align="center">
    A powerful and flexible job queue system for Godot, built on top of Gedis.
</p>

<p align="center">
    <a href="https://nodotproject.github.io/GedisQueue/"><img src="https://img.shields.io/badge/documentation-blue?style=for-the-badge&logo=readthedocs&logoColor=white" alt="Documentation"></a>
</p>

[![Discord](https://img.shields.io/discord/1089846386566111322)](https://discord.gg/Rx9CZX4sjG) [![Mastodon](https://img.shields.io/mastodon/follow/110106863700290562?domain=mastodon.gamedev.place)](https://mastodon.gamedev.place/@krazyjakee) [![Youtube](https://img.shields.io/youtube/channel/subscribers/UColWkNMgHseKyU7D1QGeoyQ)](https://www.youtube.com/@GodotNodot) [![GitHub Sponsors](https://img.shields.io/github/sponsors/krazyjakee)](https://github.com/sponsors/krazyjakee) [![GitHub Stars](https://img.shields.io/github/stars/NodotProject/GedisQueue)](https://github.com/NodotProject/GedisQueue)

![Stats](https://repobeats.axiom.co/api/embed/2a34f9ee10e86a04db97091d90c892c07c8314d1.svg "Repobeats analytics image")

GedisQueue allows you to manage and process asynchronous jobs in your Godot projects, making it ideal for handling tasks like background processing, notifications, and more.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [Support Me](#-support-me)
- [License](#license)

## Features

- **Job Lifecycle Management**: Track jobs through various statuses, including `waiting`, `active`, `completed`, and `failed`.
- **Flexible Job Processors**: Define custom logic for processing jobs using simple functions.
- **Tooling**: Gedis debugger tool can be used to assist development.

## Installation

To use GedisQueue, you need to have the Gedis addon installed and enabled in your Godot project. You can download Gedis from the Godot Asset Library or from its [GitHub repository](https://github.com/NodotProject/Gedis).

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

### Known Issues

- `remove_job` does not currently remove the job ID from the queue lists in Gedis. This means a removed job might still appear in `get_jobs` results if it was in a `waiting`, `completed`, or `failed` list.

## Contributing

This addon is implemented in GDScript and does not require native compilation. To work on or test the addon, follow these steps:

1.  **Clone the repository**:

    ```sh
    git clone --recursive https://github.com/NodotProject/GedisQueue.git
    cd GedisQueue
    ```

2.  **Develop & Test**:

    - The addon code lives under `addons/GedisQueue`. Copy that folder into your Godot project's `addons` directory to test changes.
    - Run the project's test suite with `./run_tests.sh`.

3.  **Contribute**:

    Create a branch, make your changes, and open a pull request describing the work.

## 💖 Support Me
Hi! I’m krazyjakee 🎮, creator and maintain­er of the *NodotProject* - a suite of open‑source Godot tools (e.g. Nodot, Gedis etc) that empower game developers to build faster and maintain cleaner code.

I’m looking for sponsors to help sustain and grow the project: more dev time, better docs, more features, and deeper community support. Your support means more stable, polished tools used by indie makers and studios alike.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/krazyjakee)

Every contribution helps maintain and improve this project. And encourage me to make more projects like this!

*This is optional support. The tool remains free and open-source regardless.*

---

**Created with ❤️ for Godot Developers**
For contributions, please open issues on GitHub

## License

GedisQueue is licensed under the MIT License. See the `LICENSE` file for more details.
