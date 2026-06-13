defmodule Openapi.TestHandler do
  def handle_request(conn, params) do
    send(self(), {:openapi, conn.request_path, params})
    Plug.Conn.send_resp(conn, 200, "ok")
  end
end
