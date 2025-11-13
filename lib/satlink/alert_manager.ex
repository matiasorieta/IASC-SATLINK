defmodule Satlink.AlertManager do
  @moduledoc """
  Maneja alertas de usuarios y notifica cuando aparece una ventana que matchea.
  """

  use GenServer
  alias Satlink.Alert
  alias Satlink.Window

  ## API pública

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{alerts: %{}, next_id: 1}, name: __MODULE__)
  end

  @doc """
  Crea una alerta y devuelve {:ok, alert_id}.
  attrs debe tener: :user_id, :mission_type, :from, :to
  """
  def create_alert(attrs) do
    GenServer.call(__MODULE__, {:create_alert, attrs})
  end

  def list_alerts do
    GenServer.call(__MODULE__, :list_alerts)
  end

  @doc """
  Llamado por Satlink.Windows cuando se publica una nueva ventana.
  """
  def notify_new_window(%Window{} = window) do
    GenServer.cast(__MODULE__, {:new_window, window})
  end

  def notify_window_closed(%Window{} = window) do
    GenServer.cast(__MODULE__, {:window_closed, window})
  end

  ## GenServer callbacks

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:create_alert, attrs}, _from, %{alerts: alerts, next_id: next_id} = state) do
    id = Integer.to_string(next_id)
    alert = struct!(Alert, Map.put(attrs, :id, id))

    # Opcional: chequear ventanas ya existentes
    notify_for_existing_windows(alert)

    new_alerts = Map.put(alerts, id, alert)
    {:reply, {:ok, id}, %{state | alerts: new_alerts, next_id: next_id + 1}}
  end

  def handle_call(:list_alerts, _from, state) do
    {:reply, Map.values(state.alerts), state}
  end

  @impl true
  def handle_cast({:new_window, window}, state) do
    for {_id, alert} <- state.alerts, matches?(alert, window) do
      notify(alert, window)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:window_closed, window}, state) do
    # Notificar a los usuarios cuya reserva quedó cancelada
    for {user_id, %{status: :cancelled}} <- window.reservations do
      IO.puts(
        "Notificando a usuario #{user_id} que su reserva en la ventana #{window.id} fue cancelada."
      )
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

  defp notify(%Alert{id: id, user_id: user}, %Window{id: win_id}) do
    IO.puts("ALERTA #{id}: usuario #{user} notificado por ventana #{win_id}")
    # más adelante: mandar PubSub, HTTP callback, etc.
  end

  defp notify_for_existing_windows(%Alert{} = alert) do
    # Si querés que al crear una alerta también se checkeen ventanas ya publicadas:
    case function_exported?(Satlink.WindowManager, :list_windows, 0) do
      true ->
        for w <- Satlink.WindowManager.list_windows(), matches?(alert, w) do
          notify(alert, w)
        end

      false ->
        :ok
    end
  end
end
