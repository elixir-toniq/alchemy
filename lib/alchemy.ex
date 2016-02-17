defmodule Alchemy do
  @moduledoc ~S"""

  """

  use Application
  require Logger

  @doc """
  Start Alchemy.
  """
  def start(_type, _opts \\ []) do
    Alchemy.Supervisor.start_link()
  end

  @doc """
  Stop Alchemy.
  """
  def stop(_) do
    # Do nothing for now
  end
end
