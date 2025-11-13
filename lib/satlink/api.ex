defmodule Satlink.API do
  @moduledoc """
  API de alto nivel para crear, consultar y operar sobre ventanas.
  Usa `Satlink.WindowServer` (un GenServer por ventana).
  """

  alias Satlink.{WindowServer, WindowSupervisor, Window}

  # -------------------------------------------------
  # DEMO
  # -------------------------------------------------
  def demo_window(id \\ "demo-1") do
    now = DateTime.utc_now()

    attrs = %{
      id: id,
      satellite: "SAT-AR-1",
      mission_type: :optical,
      resources: %{optical: ["cam1", "cam2"]},
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second),
      offer_deadline: DateTime.add(now, 600, :second)
    }

    window = struct!(Window, attrs)

    case WindowSupervisor.start_window_server(window) do
      {:ok, _pid} -> {:ok, window.id}
      {:error, {:already_started, _pid}} -> {:error, :already_exists}
      other -> other
    end
  end

  # -------------------------------------------------
  # API DE OPERACIONES
  # -------------------------------------------------
  def reserve(id, user_id), do: WindowServer.reserve(id, user_id)

  def select(id, user_id, res), do: WindowServer.select(id, user_id, res)

  def cancel(id, user_id), do: WindowServer.cancel_reservation(id, user_id)

  def close(id), do: WindowServer.close(id)

  def get(id), do: WindowServer.get(id)

  def list() do
    Horde.Registry.select(Satlink.WindowRegistry, [{{{:"$1", :_}, :_, :_}, [], [:"$1"]}])
  end

  # -------------------------------------------------
  # UTILIDAD PARA VER DETALLES
  # -------------------------------------------------
  def show(id) do
    case WindowServer.get(id) do
      {:error, :not_found} ->
        IO.puts("Ventana #{id} no encontrada")
        {:error, :not_found}

      {:ok, %Window{} = w} ->
        IO.puts("Ventana #{w.id} (#{w.satellite})")
        IO.puts("  misión: #{inspect(w.mission_type)}")
        IO.puts("  estado: #{inspect(w.status)}")
        IO.puts("  recursos: #{inspect(w.resources)}")
        IO.puts("  allocated: #{inspect(w.allocated)}")
        IO.puts("  reservas:")
        Enum.each(w.reservations, fn {user_id, res} ->
          IO.puts("    - #{user_id}: #{inspect(res)}")
        end)
        :ok
    end
  end
end
