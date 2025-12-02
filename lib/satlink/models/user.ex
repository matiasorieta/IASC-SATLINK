defmodule Satlink.Models.User do
  defstruct [
    :id,
    :name,
    notifications: [],
    alerts: [],
    reservations: []
  ]
end
