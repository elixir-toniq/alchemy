defmodule Alchemy.Result do
  defstruct [
    name: nil,
    control: nil,
    candidates: [],
    uuid: nil,
    mismatched: [],
    ignored: [],
  ]

  alias Alchemy.{Result, Observation}

  def new(experiment, control, candidates) do
    ignored =
      candidates
      |> Enum.filter(fn(candidate) -> value_mismatch?(control, candidate) end)
      |> Enum.filter(fn(candidate) -> ignored?(experiment, control, candidate) end)

    mismatched =
      candidates
      |> Enum.reject(fn(can) -> can in ignored end)
      |> Enum.reject(fn(can) -> observations_match?(experiment, control, can) end)

    %Result{
      name: experiment.name,
      uuid: experiment.uuid,
      control: control,
      candidates: candidates,
      mismatched: mismatched,
      ignored: ignored
    }
  end

  def matched?(%{mismatched: mismatched}), do: mismatched == []

  def mismatched?(%{mismatched: mismatched}) do
    Enum.any?(mismatched)
  end

  def ignored?(%{ignored: ignored}) do
    Enum.any?(ignored)
  end

  def raised?(%Observation{error: nil}), do: false
  def raised?(_), do: true

  defp observations_match?(experiment, control, candidate) do
    c1 = control.value || control.error.error
    c2 = candidate.value || candidate.error.error
    experiment.compare.(c1, c2)
  end

  defp value_mismatch?(%{value: value}, %{value: value}), do: false
  defp value_mismatch?(_, _), do: true

  defp ignored?(%{ignores: ignores}, control, candidate) do
    ignores
    |> Enum.any?(fn f -> f.(control.value, candidate.value) == true end)
  end
end
