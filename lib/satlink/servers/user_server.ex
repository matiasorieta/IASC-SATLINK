defmodule Satlink.Servers.UserServer do
  use GenServer
  alias Satlink.Models.User
  alias Satlink.Stores.UserStore

  def via(id),
    do: {:via, Horde.Registry, {Satlink.Registries.UserRegistry, {:user, id}}}

  # ==============================
  # Start
  # ==============================

  def start_link(%User{id: id} = fallback_user) do
    user = load_from_store_or_fallback(id, fallback_user)
    GenServer.start_link(__MODULE__, user, name: via(id))
  end

  def init(user), do: {:ok, user}

  # ==============================
  # API
  # ==============================

  def get(id), do: GenServer.call(via(id), :get)

  def notify(id, msg),
    do: GenServer.cast(via(id), {:notify, msg})

  def add_alert(id, alert_id),
    do: GenServer.cast(via(id), {:add_alert, alert_id})

  def add_reservation(id, window_id),
    do: GenServer.cast(via(id), {:add_reservation, window_id})

  # ==============================
  # Callbacks
  # ==============================

  def handle_call(:get, _from, user), do: {:reply, user, user}

  def handle_cast({:notify, msg}, user) do
    new_user = %{user | notifications: [msg | user.notifications]}
    UserStore.put(new_user)
    IO.puts("Notificación para usuario #{user.id}: #{inspect(msg)}")
    {:noreply, new_user}
  end

  def handle_cast({:add_alert, alert_id}, user) do
    new_user = %{user | alerts: [alert_id | user.alerts]}
    UserStore.put(new_user)
    {:noreply, new_user}
  end

  def handle_cast({:add_reservation, window_id}, user) do
    new_user = %{user | reservations: [window_id | user.reservations]}
    UserStore.put(new_user)
    {:noreply, new_user}
  end

  # ==============================
  # Helpers
  # ==============================

  defp load_from_store_or_fallback(id, fallback) do
    case UserStore.get(id) do
      nil ->
        UserStore.put(fallback)
        fallback

      stored_user ->
        stored_user
    end
  end
end
