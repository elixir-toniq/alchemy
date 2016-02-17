defmodule Alchemy.ExperimentTest do
  use ExUnit.Case
  doctest Alchemy

  import Alchemy.Experiment

  test "experiment/1 assigns a name" do
    assert experiment("test").name == "test"
  end

  test "experiment/1 generates a unique identifier" do
    assert experiment("test").uuid
  end

  test "experiment/1 generates a default comparator" do
    assert experiment("test").compare
  end

  test "comparator/2 updates the comparison for the experiment" do
    exp =
      experiment("test")
      |> comparator(fn(a, b) -> a.value == b.value end)

    assert exp.compare.(%{uuid: 1, value: 1337}, %{uuid: 2, value: 1337})
  end

  test "control/2 assigns the control" do
    result =
      experiment("Test experiment")
      |> control(fn -> IO.puts "Hello world" end)

    assert Enum.count(result.behaviors) == 1
  end

  test "candidate/2 can assign multiple candidates" do
    result =
      experiment("test")
      |> candidate(fn -> 1 end)
      |> candidate(fn -> 2 end)
      |> candidate(fn -> 3 end)

    assert Enum.count(result.behaviors) == 3
  end

  test "run/1 yields the controls result" do
    result =
      experiment("Test experiment")
      |> control(fn -> 3 + 3 end)
      |> candidate(fn -> 3 + 4 end)
      |> run

    assert result == 6
  end

  test "run/1 does not require a candidate" do
    result =
      experiment("Test experiment")
      |> control(fn -> 3 + 3 end)
      |> run

    assert result == 6
  end
end
