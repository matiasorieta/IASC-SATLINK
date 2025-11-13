defmodule Satlink.Alert do
  @moduledoc """
  Alerta pedida por un usuario.

  - user_id: quién creó la alerta
  - mission_type: tipo que le interesa (:optical, :radar, etc.)
  - from/to: rango temporal en el que le interesa la ventana
  """

  @enforce_keys [:id, :user_id, :mission_type, :from, :to]
  defstruct [:id, :user_id, :mission_type, :from, :to]
end
