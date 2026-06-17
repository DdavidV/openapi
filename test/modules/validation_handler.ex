defmodule Openapi.ValidationHandler do
  def create_pet(conn, _params), do: Plug.Conn.send_resp(conn, 201, "created")
  def list_pets(conn, _params), do: Plug.Conn.send_resp(conn, 200, "ok")
  def get_pet(conn, _params), do: Plug.Conn.send_resp(conn, 200, "ok")
end
