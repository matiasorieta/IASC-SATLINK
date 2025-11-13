defmodule Satlink.WindowSupervisor do
  use Horde.DynamicSupervisor
  alias Satlink.WindowServer

  def start_link(_arg) do
    Horde.DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    Horde.DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_window_server(%Satlink.Window{} = window) do
    spec = {WindowServer, window}
    Horde.DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
