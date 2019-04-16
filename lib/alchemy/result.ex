defmodule Alchemy.Result do
  defstruct [
    name: nil,
    control: nil,
    candidates: [],
    uuid: nil,
    mismatched: []
  ]

  alias Alchemy.{Result, Observation}

  def new(experiment, control, candidates) do
    mismatched = Enum.filter(candidates, fn(candidate) ->
      c1 = control.value || control.error.error
      c2 = candidate.value || candidate.error.error
      !experiment.compare.(c1, c2)
    end)

    %Result{
      name: experiment.name,
      uuid: experiment.uuid,
      control: control,
      candidates: candidates,
      mismatched: mismatched
    }
  end

  def matched?(%{mismatched: mismatched}), do: mismatched == []

  def mismatched?(%{mismatched: mismatched}) do
    Enum.any?(mismatched)
  end

  def raised?(%Observation{error: nil}), do: false
  def raised?(_), do: true
end
