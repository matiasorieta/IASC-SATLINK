defmodule SatlinkTest do
  use ExUnit.Case
  doctest Satlink

  test "greets the world" do
    assert Satlink.hello() == :world
  end
end
