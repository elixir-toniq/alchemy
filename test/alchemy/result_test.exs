defmodule Alchemy.ResultTest do
  use ExUnit.Case, async: true

  alias Alchemy.Result
  import Alchemy.Experiment

  def get_result(exp) do
    parent = self()

    spawn(fn ->
      exp
      |> publisher(fn result -> send(parent, {:result, result}) end)
      |> run
    end)
    assert_receive {:result, result}

    result
  end

  describe "mismatched?/1" do
    test "returns true if there were any mismatches" do
      result =
        experiment("test")
        |> control(fn -> 42 end)
        |> candidate(fn -> 24 end)
        |> get_result

      refute Result.matched?(result)
      assert Result.mismatched?(result) == true
    end

    test "returns a mismatch if any of the candidates failed the test" do
      result =
        experiment("test")
        |> control(fn -> 42 end)
        |> candidate(fn -> 24 end)
        |> candidate(fn -> 42 end)
        |> get_result

      refute Result.matched?(result)
      assert Result.mismatched?(result) == true
    end

    test "doesn't count ignored candidates as mismatches" do
      result =
        experiment("test")
        |> control(fn -> 42 end)
        |> candidate(fn -> 24 end)
        |> candidate(fn -> 42 end)
        |> ignore(fn _, candidate -> candidate == 24 end)
        |> get_result

      assert Result.matched?(result)
      refute Result.mismatched?(result)
      assert Result.ignored?(result)
    end
  end
end

