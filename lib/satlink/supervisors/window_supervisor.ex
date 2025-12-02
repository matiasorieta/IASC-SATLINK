defmodule Satlink.Supervisors.WindowSupervisor do
  use Horde.DynamicSupervisor
  alias Satlink.Servers.WindowServer

  ## ——————————————
  ## Start
  ## ——————————————

  def start_link(opts) do
    Horde.DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## ——————————————
  ## Init
  ## ——————————————

  def init(_opts) do
    Horde.DynamicSupervisor.init(
    strategy: :one_for_one,
    distribution_strategy: Horde.UniformQuorumDistribution,
    process_redistribution: :active,
    members: :auto
    )
  end

  ## ——————————————
  ## Public API
  ## ——————————————

  def start_window_server(%Satlink.Models.Window{} = window) do
    spec = {WindowServer, window}
    Horde.DynamicSupervisor.start_child(__MODULE__, spec)
  end

end
