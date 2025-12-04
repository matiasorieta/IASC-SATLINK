defmodule Satlink.Stores.AlertStore do
  use GenServer
  alias Satlink.Models.Alert

  @crdt_name :alert_store_crdt

  # ===== API =====

  def put(%Alert{id: id} = alert) do
    # Fan-out manual: escribimos en el CRDT de todos los nodos vivos
    for node <- [Node.self() | Node.list()] do
      case Node.ping(node) do
        :pong ->
          DeltaCrdt.mutate({@crdt_name, node}, :add, [id, alert])

        :pang ->
          :ok
      end
    end

    :ok
  end

  def get(id) do
    DeltaCrdt.read(@crdt_name)
    |> Map.get(id)
  end

  def list do
    DeltaCrdt.read(@crdt_name)
  end

  def delete(id) do
    for node <- [Node.self() | Node.list()] do
      case Node.ping(node) do
        :pong ->
          DeltaCrdt.mutate({@crdt_name, node}, :remove, [id])

        :pang ->
          if node == :nonode@nohost do # para tests locales
            DeltaCrdt.mutate(@crdt_name, :remove, [id])
          end
          :ok
      end
    end

    :ok
  end

  # ===== GenServer =====

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    {:ok, crdt_pid} =
      case DeltaCrdt.start_link(
             DeltaCrdt.AWLWWMap,
             sync_interval: 200,
             name: @crdt_name
           ) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
      end

    :net_kernel.monitor_nodes(true)
    connect_to_existing_nodes(crdt_pid)

    {:ok, crdt_pid}
  end

  @impl true
  def handle_info({:nodeup, node}, crdt_pid) do
    connect_to_existing_nodes(crdt_pid)
    {:noreply, crdt_pid}
  end

  @impl true
  def handle_info({:nodedown, node}, crdt_pid) do
    connect_to_existing_nodes(crdt_pid)
    {:noreply, crdt_pid}
  end

  @impl true
  def handle_info(msg, crdt_pid) do
    IO.puts("⚠️ AlertStore mensaje inesperado: #{inspect(msg)}")
    {:noreply, crdt_pid}
  end

  defp connect_to_existing_nodes(pid) do
    neighbours =
      Node.list()
      |> Enum.map(fn node -> {@crdt_name, node} end)

    DeltaCrdt.set_neighbours(pid, neighbours)
  end
end
