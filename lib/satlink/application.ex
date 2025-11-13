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
      {Horde.Registry, [keys: :unique, name: Satlink.WindowRegistry, members: :auto]},
      {Horde.DynamicSupervisor, [name: Satlink.WindowSupervisor, strategy: :one_for_one, members: :auto]},
      Satlink.AlertManager,
      Satlink.WindowStore
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Satlink.Supervisor)
  end
end
