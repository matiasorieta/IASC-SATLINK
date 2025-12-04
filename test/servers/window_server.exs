defmodule Satlink.Servers.WindowServerTest do
  use ExUnit.Case

  alias Satlink.Servers.WindowServer
  alias Satlink.Models.Window

  setup do
    now = DateTime.utc_now()
    w = %Window{
      id: "wt1",
      satellite: "SAT",
      mission_type: :optical,
      resources: %{optical: ["cam1"]},
      starts_at: now,
      ends_at: DateTime.add(now, 10),
      offer_deadline: DateTime.add(now, 5)
    }

    {:ok, _pid} = WindowServer.start_link(w)
    :ok
  end

  test "get returns window" do
    assert {:ok, w} = WindowServer.get("wt1")
    assert w.id == "wt1"
  end

  test "reserve workflow" do
    assert {:ok, _} = WindowServer.reserve("wt1", "u1")
    {:ok, w} = WindowServer.get("wt1")
    assert w.reservations["u1"].status == :pending
  end

  test "select workflow" do
    WindowServer.reserve("wt1", "u1")
    {:ok, _} = WindowServer.select("wt1", "u1", {:optical, "cam1"})
    {:ok, w} = WindowServer.get("wt1")
    assert w.reservations["u1"].status == :confirmed
  end
end
