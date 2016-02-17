defmodule Alchemy.Publisher do
  @moduledoc """
  """
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def publish(result) do
    GenServer.call(__MODULE__, {:publish, result})
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:publish, result}, _from, state) do
    user_defined_publisher.publish(result)
    {:reply, result, state}
  end

  defp user_defined_publisher do
    Application.fetch_env!(:alchemy, :publish_module)
  end
end
