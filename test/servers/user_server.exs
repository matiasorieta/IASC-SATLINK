defmodule Satlink.Servers.UserServerTest do
  use ExUnit.Case

  alias Satlink.Servers.UserServer
  alias Satlink.Models.User

  setup do
    u = %User{id: "u1", name: "Alice", notifications: [], alerts: [], reservations: []}
    {:ok, _pid} = UserServer.start_link(u)
    :ok
  end

  test "get returns struct" do
    u = UserServer.get("u1")
    assert u.id == "u1"
  end

  test "notify adds message" do
    UserServer.notify("u1", %{msg: "hola"})
    u = UserServer.get("u1")
    assert length(u.notifications) == 1
  end

  test "add reservation" do
    UserServer.add_reservation("u1", %{window_id: "w1"})
    u = UserServer.get("u1")
    assert %{window_id: "w1"} in u.reservations
  end

  test "add alert" do
    UserServer.add_alert("u1", "a1")
    u = UserServer.get("u1")
    assert "a1" in u.alerts
  end
end
