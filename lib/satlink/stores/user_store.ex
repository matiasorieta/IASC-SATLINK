defmodule Satlink.Stores.UserStore do
  use GenServer
  alias Satlink.Models.User

  @crdt_name :user_store_crdt

  # ==============================
  # API
  # ==============================

  @doc """
  Inserta o actualiza un usuario en el CRDT con fan-out manual.
  """
  def put(%User{id: id} = user) do
    for node <- [Node.self() | Node.list()] do
      case Node.ping(node) do
        :pong ->
          DeltaCrdt.mutate({@crdt_name, node}, :add, [id, user])

        :pang ->
          :ok
      end
    end

    :ok
  end

  @doc """
  Obtiene un usuario del CRDT (si existe, no levanta proceso).
  """
  def get(id) do
    DeltaCrdt.read(@crdt_name)
    |> Map.get(id)
  end

  @doc """
  Lista todos los usuarios del CRDT.
  """
  def list do
    DeltaCrdt.read(@crdt_name)
  end

  # ==============================
  # GenServer / CRDT setup
  # ==============================

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
  def handle_info({:nodeup, _node}, crdt_pid) do
    connect_to_existing_nodes(crdt_pid)
    {:noreply, crdt_pid}
  end

  @impl true
  def handle_info({:nodedown, _node}, crdt_pid) do
    connect_to_existing_nodes(crdt_pid)
    {:noreply, crdt_pid}
  end

  @impl true
  def handle_info(msg, crdt_pid) do
    IO.puts("⚠️ UserStore mensaje inesperado: #{inspect(msg)}")
    {:noreply, crdt_pid}
  end

  defp connect_to_existing_nodes(pid) do
    neighbours =
      Node.list()
      |> Enum.map(fn node -> {@crdt_name, node} end)

    DeltaCrdt.set_neighbours(pid, neighbours)
  end
end
