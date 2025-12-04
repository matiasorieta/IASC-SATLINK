defmodule Satlink.Servers.UserServer do
  use GenServer
  alias Satlink.Models.User
  alias Satlink.Stores.UserStore

  # ---------- VIA TUPLE PARA HORDE ----------
  def via(id) do
    {:via, Horde.Registry, {Satlink.Registries.UserRegistry, {:user, id}}}
  end

  # ---------- CHILD SPEC ----------
  # Horde necesita esto para poder reiniciar procesos correctamente.
  def child_spec(user) do
    %{
      id: {:user, user.id},
      start: {__MODULE__, :start_link, [user]},
      restart: :transient,
      type: :worker
    }
  end

  # ---------- START ----------
  def start_link(%User{id: id} = fallback) do
    user = load_from_store_or_fallback(id, fallback)
    GenServer.start_link(__MODULE__, user, name: via(id))
  end

  def init(user), do: {:ok, user}

  # ---------- API ----------
  def get(id), do: GenServer.call(via(id), :get)
  def notify(id, msg), do: GenServer.cast(via(id), {:notify, msg})
  def add_alert(id, alert_id), do: GenServer.cast(via(id), {:add_alert, alert_id})
  def add_reservation(id, window_id), do: GenServer.cast(via(id), {:add_reservation, window_id})

  # ---------- CALLBACKS ----------
  def handle_call(:get, _from, user), do: {:reply, user, user}

  def handle_cast({:notify, msg}, user) do
    new = %{user | notifications: [msg | user.notifications]}
    UserStore.put(new)
    {:noreply, new}
  end

  def handle_cast({:add_alert, alert_id}, user) do
    new = %{user | alerts: [alert_id | user.alerts]}
    UserStore.put(new)
    {:noreply, new}
  end

  def handle_cast({:add_reservation, window_id}, user) do
    new = %{user | reservations: [window_id | user.reservations]}
    UserStore.put(new)
    {:noreply, new}
  end

  # ---------- HELPERS ----------
  defp load_from_store_or_fallback(id, fallback) do
    case UserStore.get(id) do
      nil ->
        UserStore.put(fallback)
        fallback

      stored ->
        stored
    end
  end

  def exists?(id) do
    case Horde.Registry.lookup(Satlink.Registries.UserRegistry, {:user, id}) do
      [{_pid, _meta}] ->
        true

      [] ->
        case UserStore.get(id) do
          %User{} -> true
          _ -> false
        end
    end
  end
end
