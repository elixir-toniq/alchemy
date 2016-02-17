defmodule Alchemy.Observation do
  @milliseconds 1_000

  def run({type, function}) do
    {duration, value} = measure(function)
    {type, %{duration: duration, value: value}}
  end

  def measure(function) do
    {duration, value} = :timer.tc(function)
    {duration / @milliseconds, value}
  end
end
