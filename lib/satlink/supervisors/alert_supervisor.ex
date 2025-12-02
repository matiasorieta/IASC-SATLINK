defmodule Satlink.Supervisors.AlertSupervisor do
  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
    Satlink.Servers.AlertManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
