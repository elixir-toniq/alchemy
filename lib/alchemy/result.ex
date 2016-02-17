defmodule Alchemy.Result do
  defstruct experiment: nil, control: nil, observations: []

  alias Alchemy.Result

  def control_value(%Result{control: control}) do
    control.value
  end

  def control_duration(%Result{control: control}) do
    control.duration
  end

  def mismatched?(%Result{experiment: exp, observations: observations, control: control}) do
    observations
    |> Enum.map(fn(observation) -> !exp.compare.(control, observation) end)
    |> Enum.all?
  end
end
