defmodule Alchemy.Result do
  defstruct [
    name: nil,
    control: nil,
    candidates: [],
    uuid: nil,
    mismatched: []
  ]

  alias Alchemy.Result

  def new(experiment, control, candidates) do
    mismatched = Enum.filter(candidates, fn(candidate) ->
      !experiment.compare.(control, candidate)
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
end
