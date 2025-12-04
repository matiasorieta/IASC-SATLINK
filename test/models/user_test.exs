defmodule Satlink.Models.UserTest do
  use ExUnit.Case
  alias Satlink.Models.User

  test "user struct holds notifications" do
    u = %User{id: "u1", name: "Alice", notifications: []}
    n = %{message: "hola"}

    u2 = %{u | notifications: [n | u.notifications]}
    assert length(u2.notifications) == 1
  end

  test "user stores alert ids" do
    u = %User{id: "u1", alerts: []}
    a = "alert-123"

    u2 = %{u | alerts: [a | u.alerts]}
    assert a in u2.alerts
  end

  test "user stores reservations" do
    u = %User{id: "u1", reservations: []}
    r = %{window_id: "w1"}

    u2 = %{u | reservations: [r | u.reservations]}
    assert r in u2.reservations
  end
end
