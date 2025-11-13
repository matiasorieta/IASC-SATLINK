defmodule Satlink.WindowStore do
  use GenServer
  alias Satlink.Window

  @crdt_name :window_store_crdt

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # ===== API =====

  def put(%Window{id: id} = window) do
    DeltaCrdt.mutate(@crdt_name, :add, [id, window])
  end

  def get(id) do
    DeltaCrdt.read(@crdt_name)
    |> Map.get(id)
  end

  def list do
    DeltaCrdt.read(@crdt_name)
  end

  # ===== Callbacks =====

  @impl true
  def init(:ok) do
    {:ok, crdt_pid} =
      case DeltaCrdt.start_link(DeltaCrdt.AWLWWMap, sync_interval: 200, name: @crdt_name) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
      end

    # Configurar monitoreo de nodos y conectarse automáticamente
    :net_kernel.monitor_nodes(true)
    connect_to_existing_nodes(crdt_pid)

    {:ok, crdt_pid}
  end

  @impl true
  def handle_info({:nodeup, _node}, crdt_pid) do
    connect_to_existing_nodes(crdt_pid)
    {:noreply, crdt_pid}
  end

  defp connect_to_existing_nodes(pid) do
    neighbours =
      Node.list()
      |> Enum.map(fn node -> {@crdt_name, node} end)

    DeltaCrdt.set_neighbours(pid, neighbours)
  end
end
