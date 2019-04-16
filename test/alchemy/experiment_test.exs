defmodule Alchemy.ExperimentTest do
  use ExUnit.Case
  doctest Alchemy

  import Alchemy.Experiment

  alias Alchemy.Result

  test "experiment/1 assigns a name" do
    assert experiment("test").name == "test"
  end

  test "experiment/1 generates a unique identifier" do
    assert experiment("test").uuid
  end

  test "experiment/1 generates a default comparator" do
    assert experiment("test").compare
  end

  test "comparator/2 updates the comparison for the new" do
    exp =
      experiment("test")
      |> comparator(fn(a, b) -> a.value == b.value end)

    assert exp.compare.(%{uuid: 1, value: 1337}, %{uuid: 2, value: 1337})
  end

  test "control/2 assigns the control" do
    result =
      experiment("Test new")
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
      experiment("Test new")
      |> control(fn -> 3 + 3 end)
      |> candidate(fn -> 3 + 4 end)
      |> run

    assert result == 6
  end

  test "run/1 does not require a candidate" do
    result =
      experiment("Test new")
      |> control(fn -> 3 + 3 end)
      |> run

    assert result == 6
  end

  test "errors inside of control are rethrown" do
    assert_raise ArithmeticError, fn ->
      experiment("errors test")
      |> control(fn -> 42 / 0 end)
      |> run
    end
  end

  test "errors are compared between control and candidate" do
    pid = self()

    spawn(fn ->
      assert_raise ArithmeticError, fn ->
        experiment("errors test")
        |> control(fn -> 42 / 0 end)
        |> candidate(fn -> 1337 / 0 end)
        |> comparator(fn(control, candidate) ->
          result = control == candidate
          send(pid, {:result, result})
          result
        end)
        |> run
      end
    end)

    assert_receive {:result, true}
  end

  test "errors in control are returned but not raised" do
    result =
      experiment("errors test")
      |> control(fn -> 42 end)
      |> candidate(fn -> 1337 / 0 end)
      |> run

    assert result == 42
  end

  describe "clean/2" do
    test "defaults to the value" do
      pid = self()

      spawn(fn ->
        experiment("clean")
        |> control(fn -> %{name: "Chris"} end)
        |> candidate(fn -> %{name: "Andra"} end)
        |> publisher(fn result -> send(pid, {:result, result}) end)
        |> run
      end)

      assert_receive {:result, result}
      assert result.control.cleaned_value == %{name: "Chris"}
      assert Enum.at(result.candidates, 0).cleaned_value == %{name: "Andra"}
    end

    test "adds a cleaned value to the observation" do
      pid = self()

      spawn(fn ->
        experiment("clean")
        |> control(fn -> %{name: "Chris"} end)
        |> candidate(fn -> %{name: "Andra"} end)
        |> publisher(fn result -> send(pid, {:result, result}) end)
        |> clean(fn value -> value.name end)
        |> run
      end)

      assert_receive {:result, result}
      assert result.control.cleaned_value == "Chris"
      assert Enum.at(result.candidates, 0).cleaned_value == "Andra"
    end
  end

  describe "ignore/2" do
    test "can ignore value mismatches" do
      pid = self()

      spawn(fn ->
        experiment("clean")
        |> control(fn -> %{name: "Chris"} end)
        |> candidate(fn -> %{name: "Andra"} end)
        |> ignore(fn %{name: "Chris"}, %{name: "Andra"} -> true end)
        |> publisher(fn result -> send(pid, {:result, result}) end)
        |> run
      end)

      assert_receive {:result, result}
      assert Result.ignored?(result) == true
    end

    test "allows multiple clauses to be stacked together" do
      pid = self()

      spawn(fn ->
        experiment("clean")
        |> control(fn -> %{name: "Chris"} end)
        |> candidate(fn -> %{name: "Bob"} end)
        # This ignore should work
        |> ignore(fn control, _ -> control.name == "Chris" end)
        # This ignore will not so we can ensure that we're not shadowing it
        |> ignore(fn _, %{name: name} -> name == "Andra" end)
        |> publisher(fn result -> send(pid, {:result, result}) end)
        |> run
      end)

      assert_receive {:result, result}
      assert Result.ignored?(result) == true
    end
  end
end

