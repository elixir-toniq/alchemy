defmodule Alchemy.Experiment do
  defstruct [
    name: "",
    uuid: nil,
    behaviors: [],
    compare: nil,
    result: nil,
    publisher: nil,
  ]

  alias __MODULE__
  alias Alchemy.Observation
  alias Alchemy.Result

  require Logger

  @doc """
  Generates a new experiment struct
  """
  def new(title) do
    %Experiment{name: title, uuid: uuid()}
    |> comparator(fn(a, b) -> a == b end)
  end

  @doc """
  Sets the module to use for publishing results.
  """
  def publisher(experiment, mod) when is_atom(mod) do
    %{experiment | publisher: mod}
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
    observations =
      experiment.behaviors
      |> Enum.shuffle
      |> Enum.map(&Observation.run(&1)) # lazily evaluate

    control =
      observations
      |> Enum.find(fn({c, _}) -> c == :control end)
      |> elem(1)

    candidates =
      observations
      |> Keyword.delete(:control)
      |> Enum.map(fn(a) -> elem(a, 1) end)

    result = Result.new(experiment, control, candidates)

    publish(result, experiment.publisher)

    case Result.raised?(control) do
      true ->
        reraise control.error.error, control.error.stacktrace

      false ->
        control.value
    end
  end

  defp publish(result, nil) do
    Logger.debug(fn -> "Finished experiment: #{inspect result}" end)
    result
  end

  defp publish(result, publisher) do
    publisher.publish(result)
    result
  end

  defp add_behavior(exp, type, thunk) do
    behaviors = exp.behaviors ++ [{type, thunk}]
    %Experiment{exp | behaviors: behaviors}
  end

  def control_value(%{control: control}) do
    case control.value do
      {:raised, e, stacktrace} ->
        reraise e, stacktrace

      value ->
        value
    end
  end

  defp uuid do
    UUID.uuid1()
  end
end

