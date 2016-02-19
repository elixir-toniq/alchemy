# Alchemy


[![Hex.pm](https://img.shields.io/hexpm/v/alchemy.svg?style=flat-square)](https://hex.pm/packages/alchemy)
[![Hex.pm](https://img.shields.io/hexpm/dt/alchemy.svg?style=flat-square)](https://hex.pm/packages/alchemy)

Perform refactoring experiments in production. Based on [Scientist](https://github.com/github/scientist)

---

## Installation

1. Add alchemy to your list of dependencies in `mix.exs`:
``` elixir
def deps do
  [{:alchemy, "~> 0.0.1"}]
end
```

2. Ensure that alchemy is started before your application:
``` elixir
def application do
  [applications: [:alchemy]]
end
```

## Perform some experiments

Lets say that you have a controller that returns a list of users, and you want to change how that list of users is fetched from the database. Unit tests can help you but they can only account for examples that you've currently considered. Alchemy allows you to test your new code live in production.

```elixir
defmodule MyApp.UserController do
  import Alchemy.Experiment

  def index(conn) do
    users =
      experiment("users-query")
      |> control(&old_query/0)
      |> candidate(&new_query/0)
      |> run

    render(conn, "index.json", users: users)
  end

  defp old_query do
    # ...
  end

  defp new_query do
    # ...
  end
end
```

Both the control and the candidate are randomized and run concurrently. Once all of the behaviours have been observed the control is returned so that its easy to continue pipelining with other functions. All of the execution times for the duractions are also measured.

### Publish results

The experiment is now running but its not being published anywhere. To do that we'll need to create a new module with a publish function:

``` elixir
defmodule MyApp.ExperimentPublisher do
  def publish(result=%Alchemy.Result{}) do
    name       = result.experiment.name
    control    = result.control
    candidate  = hd(result.observations)
    mismatched = Result.mismatched?(result)

    Logger.debug """
    Test: #{experiment.name}
    Mismatch?: #{Result.mismatched?(result)}
    Control - value: #{control.value} | duration: #{control.duration}
    Candidate - value: #{candidate.value} | duration: #{candidate.duration}
    """
  end
end
```

And tell Alchemy where to send your results:

``` elixir
# config/config.exs
use Mix.Config

config :alchemy,
  publish_module: MyApp.ExperimentPublisher
```

The publish function allows you to publish your results in whatever makes most sense for your application. You could persist them in ETS tables or stash them in Redis.

### Multiple Candidates

It's possible to create experiments with multiple candidates:

``` elixir
def some_query do
  experiment("test multiple candidates")
  |> control(&old_query/0)
  |> candidate(&foo_query/0)
  |> candidate(&bar_query/0)
  |> candidate(&baz_query/0)
  |> run
end
```

### Comparing results

By default alchemy compares results with `==`. You can override this by supplying your own comparator:

``` elixir
def user_name do
  experiment("test name is correct")
  |> control(fn -> %{id: 1, name: "Alice"} end)
  |> candidate(fn -> %{id: 2, name: "Alice"} end)
  |> comparator(fn(control, candidate) -> control.name == candidate.name end)
  |> run
end
```

## Contributing

Pull Requests and Issues are greatly appreciated!
