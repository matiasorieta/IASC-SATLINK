defmodule Satlink.Stores.UserStoreTest do
  use ExUnit.Case

  alias Satlink.Stores.UserStore
  alias Satlink.Models.User

setup do
  UserStore.put(%User{})
  :ok
end


  test "put and get" do
    u = %User{id: "u10", name: "Bob", notifications: [], alerts: [], reservations: []}
    UserStore.put(u)

    assert u == UserStore.get("u10")
  end
end
