defmodule Satlink.Servers.WindowServer do
  use GenServer
  alias Satlink.Models.Window
  alias Satlink.Stores.WindowStore
  alias Satlink.Servers.AlertManager

  def via_name(id), do: {:via, Horde.Registry, {Satlink.Registries.WindowRegistry, {:server, id}}}

  # --- Public API -----------------------------------------------------

  def start_link(%Window{id: id} = window) do
    GenServer.start_link(__MODULE__, window, name: via_name(id))
  end

  def get(id), do: GenServer.call(via_name(id), :get)
  def reserve(id, user_id), do: GenServer.call(via_name(id), {:reserve, user_id})
  def select(id, user_id, res), do: GenServer.call(via_name(id), {:select, user_id, res})
  def cancel_reservation(id, user_id), do: GenServer.call(via_name(id), {:cancel_reservation, user_id})
  def close(id, reason \\ :manual), do: GenServer.call(via_name(id), {:close, reason})

  # --- GenServer lifecycle --------------------------------------------

  @impl true
  def init(%Window{id: id} = initial_window) do
    # Intento leer del CRDT si ya existe
    window =
      case WindowStore.get(id) do
        nil ->
          WindowStore.put(initial_window)
          AlertManager.notify_new_window(initial_window)
          initial_window

        replicated ->
          replicated
      end

    program_timeout(window)
    {:ok, window}
  end

  @impl true
  def handle_call(:get, _from, window) do
    {:reply, {:ok, window}, window}
  end

  @impl true
  def handle_call({:reserve, user_id}, _from, window) do
    case Window.reserve(window, user_id) do
      {:ok, new_window} ->
        WindowStore.put(new_window)
        {:reply, :ok, new_window}

      {:error, reason} ->
        {:reply, {:error, reason}, window}
    end
  end

  @impl true
  def handle_call({:select, user_id, res}, _from, window) do
    case Window.select(window, user_id, res) do
      {:ok, new_window} ->
        WindowStore.put(new_window)
        {:reply, :ok, new_window}

      {:error, reason, _} ->
        {:reply, {:error, reason}, window}
    end
  end

  @impl true
  def handle_call({:cancel_reservation, user_id}, _from, window) do
    new_window = Window.cancel_reservation(window, user_id)
    WindowStore.put(new_window)
    {:reply, :ok, new_window}
  end

  @impl true
  def handle_call({:close, reason}, _from, window) do
    case Window.close(window, reason) do
      {:ok, new_window} ->
        WindowStore.put(new_window)
        {:reply, :ok, new_window}

      {:error, reason2} ->
        {:reply, {:error, reason2}, window}
    end
  end

  @impl true
  def handle_info(:timeout, window) do
    window2 =
      case window.status do
        :closed -> window
        _ ->
          {:ok, closed} = Window.close(window, :timeout)
          WindowStore.put(closed)
          closed
      end

    {:noreply, window2}
  end

  defp program_timeout(window) do
    ms =
      window.offer_deadline
      |> DateTime.diff(DateTime.utc_now(), :millisecond)
      |> max(0)

    Process.send_after(self(), :timeout, ms)
  end
end
