defmodule Openapi.ResponseValidationHandler do
  import Plug.Conn

  def create_pet(conn, _params) do
    body = JSON.encode!(%{id: 1, name: "Max"})
    conn |> put_resp_content_type("application/json") |> send_resp(201, body)
  end

  def create_pet_invalid(conn, _params) do
    body = JSON.encode!(%{age: 3})
    conn |> put_resp_content_type("application/json") |> send_resp(201, body)
  end

  def create_pet_no_schema(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, JSON.encode!(%{whatever: true}))
  end

  def list_pets(conn, _params), do: send_resp(conn, 200, "ok")
  def get_pet(conn, _params), do: send_resp(conn, 200, "ok")
end
