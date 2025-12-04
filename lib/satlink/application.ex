defmodule Satlink.Application do
  use Application

  @impl true
  def start(_type, _args) do
    topologies = [
      gossip: [
        strategy: Cluster.Strategy.Gossip
      ]
    ]

    children = [
      {Cluster.Supervisor, [topologies, [name: Satlink.ClusterSupervisor]]},
      Satlink.Supervisors.StoreSupervisor,
      Satlink.Registries.UserRegistry,
      Satlink.Supervisors.UserSupervisor,
      Satlink.Registries.WindowRegistry,
      Satlink.Supervisors.WindowSupervisor,
      Satlink.Supervisors.AlertSupervisor,
      Satlink.Supervisors.NodeObserver.Supervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Satlink.Supervisor)
  end
end
