# Alchemy


[![Hex.pm](https://img.shields.io/hexpm/v/alchemy.svg?style=flat-square)](https://hex.pm/packages/alchemy)
[![Hex.pm](https://img.shields.io/hexpm/dt/alchemy.svg?style=flat-square)](https://hex.pm/packages/alchemy)
[![Build Status](https://travis-ci.org/keathley/alchemy.svg?branch=master)](https://travis-ci.org/keathley/alchemy)

Perform refactoring experiments in production. Inspired by [Scientist](https://github.com/github/scientist)

---

## Installation

``` elixir
def deps do
  [{:alchemy, "~> 0.0.1"}]
end
```

## Perform some experiments

Lets say that you have a controller that returns a list of users, and you want to change how that list of users is fetched from the database. Unit tests can help you but they can only account for examples that you've currently considered. Alchemy allows you to test your new code live in production.

```elixir
defmodule MyApp.UserController do
  alias Alchemy.Experiment

  def index(conn) do
    users =
      Experiment.experiment("users-query")
      |> Experiment.control(&old_query/0)
      |> Experiment.candidate(&new_query/0)
      |> Experiment.run

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
  require Logger
  alias Alchemy.Result

  def publish(result=%Alchemy.Result{}) do
    name       = result.experiment.name
    control    = result.control
    candidate  = hd(result.observations)
    mismatched = Result.mismatched?(result)

    Logger.debug """
    Test: #{name}
    Match?: #{!Result.mismatched?(result)}
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

config :alchemy, publish_module: MyApp.ExperimentPublisher

# configure alchemy's await timeout
# default await timeout: 5_000
config :alchemy, await_timeout: 100_000
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
