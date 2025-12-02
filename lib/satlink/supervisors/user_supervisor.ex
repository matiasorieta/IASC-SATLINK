defmodule Satlink.Supervisors.UserSupervisor do
  use Horde.DynamicSupervisor

  def start_link(_opts) do
    Horde.DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_opts) do
    Horde.DynamicSupervisor.init(
      strategy: :one_for_one,
      distribution_strategy: Horde.UniformQuorumDistribution,
      process_redistribution: :active,
      members: :auto
    )
  end

  def start_user_server(user) do
    spec = {Satlink.Servers.UserServer, user}
    Horde.DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
