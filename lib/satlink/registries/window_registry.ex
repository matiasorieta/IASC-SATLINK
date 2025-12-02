  defmodule Satlink.Registries.WindowRegistry do
    use Horde.Registry

    def start_link(_) do
      Horde.Registry.start_link(__MODULE__, [keys: :unique], name: __MODULE__)
    end

    def init(_opts) do
      Horde.Registry.init(
      keys: :unique,
      members: :auto
      )
    end
end
