defmodule Satlink.WindowServer do
  use GenServer
  alias Satlink.{Window, WindowAgent}

  # GenServer global por ventana (Horde.Registry)
  def via_name(id), do: {:via, Horde.Registry, {Satlink.WindowRegistry, {:server, id}}}

  ## API

  def start_link(%Window{id: id} = window) do
    GenServer.start_link(__MODULE__, window, name: via_name(id))
  end

  def get(id), do: GenServer.call(via_name(id), :get)
  def reserve(id, user_id), do: GenServer.call(via_name(id), {:reserve, user_id})
  def select(id, user_id, res), do: GenServer.call(via_name(id), {:select, user_id, res})
  def cancel_reservation(id, user_id), do: GenServer.call(via_name(id), {:cancel_reservation, user_id})
  def close(id, reason \\ :manual), do: GenServer.call(via_name(id), {:close, reason})

  ## Callbacks

  @impl true
  def init(%Window{id: id} = window_from_attrs) do
    # si ya hay Agent (por recovery), leo de ahí; si no, creo uno con el window inicial
    window =
      case Horde.Registry.lookup(Satlink.WindowRegistry, {:agent, id}) do
        [] ->
          {:ok, _pid} = WindowAgent.start_link(window_from_attrs)
          window_from_attrs

        [{pid, _meta}] ->
          WindowAgent.get(id)
      end

    # Programar timeout según offer_deadline
    ms =
      window.offer_deadline
      |> DateTime.diff(DateTime.utc_now(), :millisecond)
      |> max(0)

    Process.send_after(self(), :timeout, ms)

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
        WindowAgent.put(new_window)
        {:reply, :ok, new_window}

      {:error, reason} ->
        {:reply, {:error, reason}, window}
    end
  end

  @impl true
  def handle_call({:select, user_id, res}, _from, window) do
    case Window.select(window, user_id, res) do
      {:ok, new_window} ->
        WindowAgent.put(new_window)
        {:reply, :ok, new_window}

      {:error, reason, _same_window} ->
        {:reply, {:error, reason}, window}
    end
  end

  @impl true
  def handle_call({:cancel_reservation, user_id}, _from, window) do
    new_window = Window.cancel_reservation(window, user_id)
    WindowAgent.put(new_window)
    {:reply, :ok, new_window}
  end

  @impl true
  def handle_call({:close, reason}, _from, window) do
    case Window.close(window, reason) do
      {:ok, new_window} ->
        WindowAgent.put(new_window)
        {:reply, :ok, new_window}

      {:error, reason2} ->
        {:reply, {:error, reason2}, window}
    end
  end

  @impl true
  def handle_info(:timeout, window) do
    window2 =
      case window.status do
        :closed ->
          window

        _ ->
          {:ok, closed} = Window.close(window, :timeout)
          WindowAgent.put(closed)
          closed
      end

    {:noreply, window2}
  end
end
