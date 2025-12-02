defmodule Satlink.Models.Window do
  @moduledoc """
  Representa una ventana de uso del satélite.
  """
  alias Satlink.Servers.AlertManager

  @enforce_keys [:id, :satellite, :mission_type, :resources, :starts_at, :ends_at, :offer_deadline]
  defstruct [
    :id,
    :satellite,
    :mission_type,
    :resources,
    :starts_at,
    :ends_at,
    :offer_deadline,
    reservations: %{},
    allocated: %{},
    status: :open,
    version: 0
  ]

  def bump_version(%__MODULE__{} = w) do
    %__MODULE__{w | version: w.version + 1}
  end

  def open?(%__MODULE__{status: :open}), do: true

  def open?(_), do: false

  def full?(%__MODULE__{} = window, allocated) do
    total_resources =
      window.resources
      |> Enum.flat_map(fn {t, ids} -> Enum.map(ids, &{t, &1}) end)
      |> MapSet.new()

    allocated_resources =
      allocated
      |> Map.keys()
      |> MapSet.new()

    MapSet.equal?(total_resources, allocated_resources)
  end

  def reserve(%__MODULE__{} = window, user_id) do
    with {:open?, true} <- {:open?, open?(window)},
         {:not_reserved?, false} <- {:not_reserved?, Map.has_key?(window.reservations, user_id)} do
      reservations =
        Map.put(window.reservations, user_id, %{status: :pending, taken: nil})

      window2 = %__MODULE__{window | reservations: reservations}
      {:ok, window2}
    else
      {:open?, false} -> {:error, :closed}
      {:not_reserved?, true} -> {:error, :already_reserved}
    end
  end

  def select(%__MODULE__{} = window, user_id, {type, resource_id}) do
    with {:open?, true} <- {:open?, open?(window)},
        {:taken?, false} <- {:taken?, Map.has_key?(window.allocated, {type, resource_id})},
        {:reservation, %{} = res} <- {:reservation, Map.get(window.reservations, user_id)} do
      allocated = Map.put(window.allocated, {type, resource_id}, user_id)

      reservations =
        Map.put(window.reservations, user_id, %{
          res
          | status: :confirmed,
            taken: {type, resource_id}
        })

      new_window = %__MODULE__{window | allocated: allocated, reservations: reservations}

      if full?(new_window, allocated) do
        close(new_window, :resources_exhausted)
      else
        {:ok, bump_version(new_window)}
      end
    else
      {:open?, false} -> {:error, :closed, window}
      {:taken?, true} -> {:error, :already_taken, window}
      {:reservation, nil} -> {:error, :no_reservation, window}
    end
  end

  def cancel_reservation(%__MODULE__{} = window, user_id) do
    {reservation, reservations2} = Map.pop(window.reservations, user_id)
    reservations3 = Map.put(reservations2, user_id, %{reservation | status: :cancelled})

    window2 = %__MODULE__{window | reservations: reservations3}
    bump_version(window2)
  end

  def close(%__MODULE__{} = window, reason \\ :manual) do
    msg =
      case reason do
        :resources_exhausted ->
          "Ventana #{window.id} cerrada automáticamente por agotamiento de recursos"

        :timeout ->
          "Ventana #{window.id} cerrada automáticamente por timeout"

        :manual ->
          "Ventana #{window.id} cerrada manualmente"
      end

    IO.puts(msg)

    window2 = %__MODULE__{window | status: :closed}
    window3 = cancel_pending_reservations(window2)

    AlertManager.notify_window_closed(window3)

    {:ok, bump_version(window3)}
  end

  defp cancel_pending_reservations(%__MODULE__{} = window) do
    reservations2 =
      window.reservations
      |> Enum.map(fn {user_id, res} ->
        case res.status do
          :pending -> {user_id, %{res | status: :cancelled}}
          _ -> {user_id, res}
        end
      end)
      |> Enum.into(%{})

    %__MODULE__{window | reservations: reservations2}
  end

end
