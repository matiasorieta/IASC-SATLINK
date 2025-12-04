defmodule Satlink.Integration.CoreTest do
  use ExUnit.Case

  alias Satlink.Servers.{UserServer, WindowServer, AlertManager}
  alias Satlink.Supervisors.{UserSupervisor, WindowSupervisor}
  alias Satlink.Models.{User, Window}
  alias Satlink.Stores.{UserStore, WindowStore}

  # -----------------------------------------
  # SETUP BÁSICO PARA CADA TEST
  # -----------------------------------------

  defp kill_user(id) do
    case Horde.Registry.lookup(Satlink.Registries.UserRegistry, {:user, id}) do
      [{pid, _meta}] ->
        Horde.DynamicSupervisor.terminate_child(Satlink.Supervisors.UserSupervisor, pid)
        Process.sleep(20)
      _ ->
        :ok
    end
  end

  defp kill_window(id) do
    case Horde.Registry.lookup(Satlink.Registries.WindowRegistry, {:server, id}) do
      [{pid, _meta}] ->
        Horde.DynamicSupervisor.terminate_child(Satlink.Supervisors.WindowSupervisor, pid)
        Process.sleep(20)
      _ ->
        :ok
    end
  end


  setup do
    kill_user("u1")
    kill_window("wx")
    UserStore.list() |> Enum.each(fn {id, _} -> UserStore.delete(id) end)
    WindowStore.list() |> Enum.each(fn {id, _} -> WindowStore.delete(id) end)
    now = DateTime.utc_now()

    # Usuario
    u = %User{
      id: "u1",
      name: "Alice",
      notifications: [],
      alerts: [],
      reservations: []
    }

    {:ok, _} = UserSupervisor.start_user_server(u)

    # Ventana
    w = %Window{
      id: "wx",
      satellite: "SAT",
      mission_type: :optical,
      resources: %{optical: ["c1", "c2"]},
      starts_at: now,
      ends_at: DateTime.add(now, 10000),
      offer_deadline: DateTime.add(now, 10000)
    }

    {:ok, _} = WindowSupervisor.start_window_server(w)

    :ok
  end

  # -----------------------------------------
  # TEST 1: Reserva básica
  # -----------------------------------------

  test "user reserves and window updates" do
    assert {:ok, _} = WindowServer.reserve("wx", "u1")

    {:ok, w} = WindowServer.get("wx")
    assert Map.has_key?(w.reservations, "u1")
  end

  # -----------------------------------------
  # TEST 2: Confirmación de reservas
  # -----------------------------------------

  test "user confirmation updates window" do
    WindowServer.reserve("wx", "u1")
    {:ok, _} = WindowServer.select("wx", "u1", {:optical, "c1"})

    {:ok, w} = WindowServer.get("wx")
    assert w.reservations["u1"].status == :confirmed
    assert w.allocated == %{{:optical, "c1"} => "u1"}
  end

  # -----------------------------------------
  # TEST 3: Cancelación de reservas
  # -----------------------------------------

  test "cancelling reservation updates window state" do
    {:ok, _} = WindowServer.reserve("wx", "u1")
    {:ok, _} = WindowServer.cancel_reservation("wx", "u1")

    {:ok, w} = WindowServer.get("wx")
    assert w.reservations["u1"].status == :cancelled
  end

  # -----------------------------------------
  # TEST 4: Alertas notifican al usuario
  # -----------------------------------------

  test "alert triggers notification when matching window appears" do
    now = DateTime.utc_now()

    {:ok, alert_id} =
      AlertManager.create_alert(%{
        user_id: "u1",
        mission_type: :optical,
        from: now,
        to: DateTime.add(now, 50)
      })

    # Registrar alerta en el usuario
    UserServer.add_alert("u1", alert_id)

    # Forzar cast async
    Process.sleep(20)

    # Debe activar la notificación YA porque hay una ventana que matchea (wx)
    user = UserServer.get("u1")
    assert length(user.notifications) >= 1
  end

  # -----------------------------------------
  # TEST 5: Seleccionar dos veces está prohibido
  # -----------------------------------------

  test "user cannot select twice a resource" do
    {:ok, _} = WindowServer.reserve("wx", "u1")
    {:ok, _} = WindowServer.select("wx", "u1", {:optical, "c1"})

    # seleccionar de nuevo debe fallar
    assert {:error, :already_taken} =
      WindowServer.select("wx", "u1", {:optical, "c1"})
  end

  # -----------------------------------------
  # TEST 6: Usuarios inexistentes no pueden operar
  # -----------------------------------------

  test "unknown user cannot reserve" do
    assert {:error, :unknown_user} =
      Satlink.API.reserve("wx", "ghost")
  end

end
