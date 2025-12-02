defmodule Satlink.Servers.AlertManager do
  @moduledoc """
  Maneja alertas de usuarios y notifica cuando aparece una ventana que matchea.
  """

  use GenServer
  alias Satlink.Models.{Alert, Window}
  alias Satlink.Stores.{AlertStore, WindowStore}

  ## API pública

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Crea una alerta y devuelve {:ok, alert_id}.
  attrs debe tener: :user_id, :mission_type, :from, :to
  """
  def create_alert(attrs) do
    GenServer.call(__MODULE__, {:create_alert, attrs})
  end

  def list_alerts do
    AlertStore.list() |> Map.values()
  end

  def notify_new_window(%Window{} = window) do
    GenServer.cast(__MODULE__, {:new_window, window})
  end

  def notify_window_closed(%Window{} = window) do
    GenServer.cast(__MODULE__, {:window_closed, window})
  end

  ## GenServer callbacks

  @impl true
  def init(:ok) do
    wait_for_crdt(:alert_store_crdt)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_alert, attrs}, _from, state) do
    # ID robusto distribuido
    id =
      {node(), System.unique_integer([:monotonic, :positive])}
      |> :erlang.term_to_binary()
      |> Base.encode16(case: :lower)

    alert = struct!(Alert, Map.put(attrs, :id, id))
    AlertStore.put(alert)

    # Opcional: buscar ventanas existentes que matcheen
    notify_for_existing_windows(alert)

    {:reply, {:ok, id}, state}
  end

  @impl true
  def handle_cast({:new_window, window}, state) do
    for {_id, alert} <- AlertStore.list(), matches?(alert, window) do
      notify_alert(alert, window)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:window_closed, window}, state) do
    for {user_id, %{status: :cancelled}} <- window.reservations do
      msg = "Tu reserva en la ventana #{window.id} ha sido cancelada debido al cierre de la ventana."
      send_notification(user_id, msg)
    end

    {:noreply, state}
  end

  ## Helpers

  defp matches?(%Alert{} = alert, %Window{} = window) do
    mission_ok? = alert.mission_type == window.mission_type

    time_overlaps? =
      DateTime.compare(window.ends_at, alert.from) in [:gt, :eq] and
        DateTime.compare(window.starts_at, alert.to) in [:lt, :eq]

    mission_ok? and time_overlaps?
  end

  defp notify_alert(%Alert{id: id, user_id: user}, %Window{id: win_id}) do
    msg = "Nueva ventana disponible: #{win_id} que coincide con tu alerta #{id}"
    send_notification(user, msg)
  end

  defp send_notification(user_id, message) do
    notification = %{
      at: DateTime.utc_now(),
      message: message
    }

    Satlink.Servers.UserServer.notify(user_id, notification)
  end


  defp notify_for_existing_windows(%Alert{} = alert) do
    for {_id, w} <- WindowStore.list(), matches?(alert, w) do
      notify_alert(alert, w)
    end
  end

  defp wait_for_crdt(name, attempts \\ 10)
  defp wait_for_crdt(_name, 0), do: :timeout
  defp wait_for_crdt(name, attempts) do
    if Process.whereis(name) do
      :ok
    else
      Process.sleep(50)
      wait_for_crdt(name, attempts - 1)
    end
  end
end
