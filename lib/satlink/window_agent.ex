defmodule Satlink.WindowAgent do
  use Agent
  alias Satlink.{Window, WindowStore}

  def via_name(id), do: {:via, Horde.Registry, {Satlink.WindowRegistry, {:agent, id}}}

  def start_link(%Window{id: id} = window) do
    window2 = sync_from_store(id, window)
    Agent.start_link(fn -> window2 end, name: via_name(id))
  end

  def get(id), do: Agent.get(via_name(id), & &1)

  def update(id, fun) do
    Agent.get_and_update(via_name(id), fn window ->
      case fun.(window) do
        {:ok, new_window} ->
          WindowStore.put(new_window)
          {:ok, new_window}

        {:error, reason, same_window} ->
          {{:error, reason}, same_window}

        {:error, reason} ->
          {{:error, reason}, window}
      end
    end)
  end

  def put(%Window{id: id} = window) do
    WindowStore.put(window)
    Agent.update(via_name(id), fn _ -> window end)
  end

  # --- Auxiliar ---
  defp sync_from_store(id, fallback) do
    wait_for_store()
    case WindowStore.get(id) do
      nil ->
        WindowStore.put(fallback)
        fallback
      replicated -> replicated
    end
  end

  defp wait_for_store(attempts \\ 5)
  defp wait_for_store(0), do: :timeout
  defp wait_for_store(n) do
    if Process.whereis(:window_store_crdt) do
      :ok
    else
      Process.sleep(20)
      wait_for_store(n - 1)
    end
  end
end
