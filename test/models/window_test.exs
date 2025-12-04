defmodule Satlink.Models.WindowTest do
  use ExUnit.Case

  alias Satlink.Models.Window

  setup do
    now = DateTime.utc_now()

    window = %Window{
      id: "wtest",
      satellite: "SAT-AR-1",
      mission_type: :optical,
      resources: %{optical: ["cam1", "cam2"]},
      starts_at: now,
      ends_at: DateTime.add(now, 3600),
      offer_deadline: DateTime.add(now, 1200),
      reservations: %{},
      allocated: %{},
      status: :open
    }

    {:ok, window: window}
  end

  test "reserve user", %{window: w} do
    {:ok, w2} = Window.reserve(w, "u1")
    assert w2.reservations["u1"].status == :pending
  end

  test "cannot double reserve", %{window: w} do
    {:ok, w2} = Window.reserve(w, "u1")
    assert {:error, :already_reserved} = Window.reserve(w2, "u1")
  end

  test "select resource", %{window: w} do
    {:ok, w2} = Window.reserve(w, "u1")
    {:ok, w3} = Window.select(w2, "u1", {:optical, "cam1"})
    assert w3.reservations["u1"].status == :confirmed
  end

  test "resource becomes taken after select", %{window: w} do
    {:ok, w2} = Window.reserve(w, "u1")
    {:ok, w3} = Window.select(w2, "u1", {:optical, "cam1"})

    assert w3.allocated == %{{:optical, "cam1"} => "u1"}
  end

  test "full window auto-close" do
    now = DateTime.utc_now()
    w = %Window{
      id: "wX",
      satellite: "SAT",
      mission_type: :optical,
      resources: %{optical: ["one"]},
      starts_at: now,
      ends_at: DateTime.add(now, 10),
      offer_deadline: DateTime.add(now, 5)
    }

    {:ok, w2} = Window.reserve(w, "u1")
    {:ok, closed} = Window.select(w2, "u1", {:optical, "one"})
    assert closed.status == :closed
  end
end
