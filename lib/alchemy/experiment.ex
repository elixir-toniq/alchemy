defmodule Alchemy.Experiment do
  defstruct name: "", uuid: nil, behaviors: [], compare: nil

  alias __MODULE__
  alias Alchemy.Observation
  alias Alchemy.Result
  alias Alchemy.Publisher

  @doc """
  Generates a new experiment struct
  """
  def experiment(title) do
    %Experiment{name: title, uuid: uuid}
    |> comparator(fn(a, b) -> a == b end)
  end

  @doc """
  Adds a control function to the experiment.
  Controls should be wrapped in a function in order to be lazily-evaluated
  """
  def control(experiment, thunk) when is_function(thunk) do
    add_behavior(experiment, :control, thunk)
  end

  @doc """
  Adds a candidate function to the experiment.
  The candidate needs to be wrapped in a function in order to be lazily-evaluated.
  When the experiment is run the candidate will be evaluated and compared to the
  control.
  """
  def candidate(experiment, thunk) when is_function(thunk) do
    add_behavior(experiment, :candidate, thunk)
  end

  @doc """
  Adds a comparator to use when comparing the candidate to the control.
  By default the comparator is:
  ``` elixir
  fn(control, candidate) -> control == candidate end
  ```
  """
  def comparator(experiment, thunk) when is_function(thunk) do
    %Experiment{experiment | compare: thunk}
  end

  @doc """
  Runs the experiment.

  If the `candidate` is provided then it will be run against the `control`. The
  `control` must be provided for the experiment to be run. The `control`
  is always returned. In order to optimize the overall execution time both the
  `candidate` and the `control` are executed concurrently. The execution order is
  randomized to account for any ordering issues.
  """
  def run(experiment=%Experiment{}) do
    experiment
    |> gather_result
    |> Publisher.publish
    |> Result.control_value
  end

  defp gather_result(experiment) do
    observations =
      experiment.behaviors
      |> Enum.shuffle
      |> Enum.map(&(fn -> Observation.run(&1) end)) # lazily evaluate
      |> Enum.map(&async/1)
      |> Enum.map(&await/1)

    control =
      observations
      |> Enum.find(fn({c, _}) -> c == :control end)
      |> elem(1)

    candidates =
      observations
      |> Keyword.delete(:control)
      |> Enum.map(fn(a) -> elem(a, 1) end)

    %Alchemy.Result{
      experiment: experiment,
      control: control,
      observations: candidates
    }
  end

  defp add_behavior(exp, type, thunk) do
    behaviors = exp.behaviors ++ [{type, thunk}]
    %Experiment{exp | behaviors: behaviors}
  end

  defp uuid do
    UUID.uuid1()
  end

  defp async(func) do
    Task.Supervisor.async(Alchemy.TaskSupervisor, func)
  end

  defp await(thunk) do
    Task.await(thunk)
  end
end
