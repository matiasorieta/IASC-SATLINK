ExUnit.start()
{:ok, _} = Application.ensure_all_started(:satlink)
Application.put_env(:libcluster, :topologies, [])
