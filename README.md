# Alchemy

[![Hex.pm](https://img.shields.io/hexpm/v/alchemy.svg?style=flat-square)](https://hex.pm/packages/alchemy)
[![Hex.pm](https://img.shields.io/hexpm/dt/alchemy.svg?style=flat-square)](https://hex.pm/packages/alchemy)
[![Build Status](https://travis-ci.org/keathley/alchemy.svg?branch=master)](https://travis-ci.org/keathley/alchemy)

Safely perform refactoring experiments in production.

---

## Installation

``` elixir
def deps do
  [{:alchemy, "~> 0.2.0"}]
end
```

## Perform some experiments

Lets say that you have a controller that returns a list of users, and you want to change how that list of users is fetched from the database. Unit tests can help you but they can only account for examples that you've currently considered. Alchemy allows you to test your new code live in production.

```elixir
defmodule MyApp.UserController do
  alias Alchemy.Experiment

  def index(conn) do
    users =
      Experiment.new("users-query")
      |> Experiment.control(&old_slow_query/0)
      |> Experiment.candidate(&new_fast_query/0)
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

Both the control and the candidate are randomized. Once all of the observations
have been made the control is returned so that its easy to continue pipelining
with other functions. Along with this Alchemy does a few other things:

* Compares the results of the control against the candidates looking for mismatches
* Measures the execution time of both the control and the candidates
* Captures and records any errors thrown by the candidates
* Publishes all of these results

### Publish results

The experiment is now running but the results aren't being published. In order
to publish the results We can pass a publisher function to our experiment.

``` elixir
defmodule MyApp.UserController do
  require Logger

  alias Alchemy.{Experiment, Result}

  def index(conn) do
    users =
      Experiment.new("users-query")
      |> Experiment.control(&old_slow_query/0)
      |> Experiment.candidate(&new_fast_query/0)
      |> Experiment.publisher(&publish/1)
      |> Experiment.run

    render(conn, "index.json", users: users)
  end

  def publish(result=%Alchemy.Result{}) do
    name      = result.name
    control   = result.control
    candidate = hd(result.candidates)
    matched   = Result.matched?(result)

    Logger.debug """
    Test: #{name}
    Match?: #{!Result.mismatched?(result)}
    Control - value: #{control.value} | duration: #{control.duration}
    Candidate - value: #{candidate.value} | duration: #{candidate.duration}
    """
  end
end
```

If you want to share your publishing logic across multiple experiments then we
can pass a module as the producer. Alchemy will assume that there is a `publish/1`
function available on the specified module.

```elixir
def index(conn) do
  users =
    Experiment.new("users-query")
    |> Experiment.control(&old_slow_query/0)
    |> Experiment.candidate(&new_fast_query/0)
    |> Experiment.publisher(Publisher)
    |> Experiment.run
end

defmodule Publisher do
  alias Alchemy.Result

  def publish(%{name: name} = result) do
    Statix.timing("alchemy.#{name}.control.duration.ms", result.control.duration)

    candidate_duration =
      result.candidates
      |> Enum.at(0)
      |> Map.get(:duration)

    Statix.timing("alchemy.#{name}.candidate.duration.ms", candidate_duration)

    # and counts for match/ignore/mismatch:
    cond do
      Result.matched?(result) ->
        Statix.increment("alchemy.#{name}.matched.total")

      Result.ignored?(result) ->
        Statix.increment("alchemy.#{name}.ignored.total")

      true ->
        Statix.increment("alchemy.#{name}.mismatched.total")
        store_result(result)
    end
  end

  # Store final results in a public ets table for analysis
  defp store_result(result) do
    payload = %{
      name: result.name,
      control: observation_payload(result.control),
      candidate: observation_payload(Enum.at(result.candidates, 0))
    }

    :ets.insert(:alchemy, {result.name, result.uuid, payload})
  end

  # If this observation raised an error then store the error
  # otherwise store the "cleaned" value.
  defp observation_payload(observation) do
    cond do
      Result.raised?(observation) ->
        %{
          error: observation.error,
          stacktrace: observation.stacktrace
        }

      true ->
        %{value: observation.cleaned_value}
    end
  end
end
```

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

### Cleaning values

Often you won't want to publish the full value that is returned from the observation.
For instance if you're comparing 2 large structs you may just want to store the
`id` fields so you can analysize them later. You can pass a cleaner function to
your experiment to define how these cleaned values are created (by default the
cleaner is an identity function).

```elixir
def users do
  experiment("user-list")
  |> control(fn -> Repo.all(User) end)
  |> candidate(fn -> UserContext.list() end)
  |> clean(fn user -> user.id end)
  |> run
end
```

### Ignoring results

If you have certain scenarios that you know will always result in mismatches
then you can ignore them so that they don't end up in your published results.
Multiple ignore clauses can be stacked together.

```elixir
def staff?(id) do
  user = User.get(id)

  experiment("staff?")
  |> control(fn -> old_role_check(user) end)
  |> candidate(fn -> Roles.staff?(user) end)
  |> ignore(fn control, candidate ->
    # If the control passed but the candidate didn't check to see if its because
    # the user has no email. We haven't implemented that in our new system yet.
    control && !candidate && user.email == ""
  end)
  # Admin users are always considered staff.
  |> ignore(fn _, _, -> Roles.admin?(user) end)
end
```

## Exception handling

Alchemy tries to be as transparent as possible. Because of this *all* errors
raised in either the control or the candidate are rescued and stored in the result.
This allows you to see any errors in your candidates or control when you publish your results.

Once the results have been published the control value is returned. If the control
raised an error during its execution that error *will be reraised* with its original stacktrace.

## Execution details

Executing the control, candidates, and publishing are all done *sequentially*
within the calling process. Trying to run these operations concurrently introduces
multiple failure conditions and possibility for timeouts. These failure scenarios
tend to surprise users and breaks one of Alchemy's core goals of being transparent
and making refactors safe. If you want to run any of these operations concurrently
then its best to do that in your own code so that you aren't surprised and can
handle failures in the way that makes the most sense for your application.

## Prior Art

Practically all of the concepts and many of the examples are shamelessly stolen
from Github's amazing [Scientist](https://github.com/github/scientist) project.
All credit goes to them for popularizing this idea and creating such a smart api.

## Contributing

Pull Requests and Issues are greatly appreciated!
