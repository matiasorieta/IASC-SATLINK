defmodule Satlink.API do
  @moduledoc """
  API de alto nivel para crear y operar sobre usuarios, ventanas y alertas.
  Incluye toda la validación de negocio antes de invocar a los actores.
  """

  alias Satlink.Models.{User, Window, Alert}
  alias Satlink.Servers.{UserServer, WindowServer}
  alias Satlink.Supervisors.{UserSupervisor, WindowSupervisor}
  alias Satlink.Servers.AlertManager

  # ==========================================
  # USUARIOS
  # ==========================================

  @doc """
  Crea un usuario del sistema.
  Requiere: :id, :name
  """
  def create_user(attrs) when is_map(attrs) do
    required = [:id, :name]
    missing = Enum.filter(required, &(Map.get(attrs, &1) == nil))

    if missing != [] do
      {:error, {:missing_fields, missing}}
    else
      user =
        struct!(User, Map.merge(%{notifications: [], alerts: [], notifications: [], reservations: []}, attrs))

      case UserSupervisor.start_user_server(user) do
        {:ok, _pid} ->
          IO.puts("✔ Usuario #{user.id} creado")
          {:ok, user.id}

        {:error, {:already_started, _pid}} ->
          IO.puts("⚠ Usuario #{user.id} ya existe")
          {:error, :already_exists}
      end
    end
  end

  @doc "Obtiene un usuario"
  def get_user(id) do
    UserServer.get(id)
  end

  @doc "Notifica al usuario con un mensaje genérico"
  def notify_user(id, message) do
    notification = %{
      at: DateTime.utc_now(),
      message: message
    }

    UserServer.notify(id, notification)
  end

  @doc "Lista las notificaciones del usuario"
  def list_user_notifications(id) do
    case UserServer.get(id) do
      %User{} = user ->
        Enum.each(user.notifications, &IO.inspect(&1, label: "Notificación"))
        user.notifications

      _ ->
        {:error, :not_found}
    end
  end

  # ==========================================
  # WINDOWS
  # ==========================================

  @doc """
  Crea una ventana completa a partir de un mapa.
  """
  def create_window(attrs) when is_map(attrs) do
    required = [
      :id,
      :satellite,
      :mission_type,
      :resources,
      :starts_at,
      :ends_at,
      :offer_deadline
    ]

    missing = Enum.filter(required, &(Map.get(attrs, &1) == nil))

    if missing != [] do
      {:error, {:missing_fields, missing}}
    else
      window = struct!(Window, attrs)

      case WindowSupervisor.start_window_server(window) do
        {:ok, _pid} ->
          IO.puts("✔ Ventana #{window.id} creada")
          {:ok, window.id}

        {:error, {:already_started, _pid}} ->
          IO.puts("⚠ Ventana #{window.id} ya existe")
          {:error, :already_exists}

        other ->
          other
      end
    end
  end

  @doc """
  Lista ventanas activas por ID.
  """
  def list_windows do
    Horde.Registry.select(Satlink.Registries.WindowRegistry, [{{{:"$1", :_}, :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Reserva una ventana para un usuario.
  Con validación de existencia del usuario.
  """
  def reserve(window_id, user_id) do
    if not user_exists?(user_id) do
      {:error, :unknown_user}
    else
      case WindowServer.reserve(window_id, user_id) do
        {:ok, _} ->
          UserServer.add_reservation(user_id, %{window_id: window_id})
          {:ok, :reserved}

        other -> other
      end
    end
  end


  @doc "Selecciona recursos dentro de una ventana"
  def select(window_id, user_id, res) do
    if not user_exists?(user_id) do
      {:error, :unknown_user}
    else
      WindowServer.select(window_id, user_id, res)
    end
  end

  def cancel(window_id, user_id) do
    if not user_exists?(user_id) do
      {:error, :unknown_user}
    else
      WindowServer.cancel_reservation(window_id, user_id)
    end
  end

  def close(id), do: WindowServer.close(id)
  def get(id), do: WindowServer.get(id)

  def show(id) do
    case get(id) do
      {:error, :not_found} ->
        IO.puts("❌ Ventana #{id} no encontrada")
        {:error, :not_found}

      {:ok, w} ->
        IO.puts("ID: #{w.id}")
        IO.puts("Satélite: #{w.satellite}")
        IO.puts("Misión: #{inspect(w.mission_type)}")
        IO.puts("Estado: #{inspect(w.status)}")
        IO.puts("Recursos: #{inspect(w.resources)}")
        IO.puts("Asignados: #{inspect(w.allocated)}")
        IO.puts("Reservas:")
        Enum.each(w.reservations, fn {user, r} ->
          IO.puts("  - #{user}: #{inspect(r)}")
        end)
        :ok
    end
  end

  # ==========================================
  # ALERTAS
  # ==========================================

  def create_alert(attrs) when is_map(attrs) do
    required = [:user_id, :mission_type, :from, :to]
    missing = Enum.filter(required, &(Map.get(attrs, &1) == nil))

    if missing != [] do
      {:error, {:missing_fields, missing}}
    else
      # Validar existencia del usuario
      case UserServer.get(attrs.user_id) do
        {:error, :not_found} ->
          {:error, :unknown_user}

        _ ->
          {:ok, alert_id} = AlertManager.create_alert(attrs)
          UserServer.add_alert(attrs.user_id, alert_id)
          {:ok, alert_id}
      end
    end
  end

  def list_alerts do
    alerts = AlertManager.list_alerts()
    Enum.each(alerts, fn a ->
      IO.puts("- #{a.id}: #{a.user_id}, #{a.mission_type}, #{a.from} → #{a.to}")
    end)
    alerts
  end

  defp user_exists?(id) do
    case Horde.Registry.lookup(Satlink.Registries.UserRegistry, {:user, id}) do
      [] -> false
      _  -> true
    end
  end

end
