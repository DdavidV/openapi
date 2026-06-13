defmodule Openapi.PhoenixIntegrationTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn

  alias Openapi.TestEndpoint

  setup_all do
    start_supervised!(Openapi.TestEndpoint)
    :ok
  end

  test "GET /users dispatches to OpenAPI handler" do
    conn =
      conn(:get, "/users")
      |> TestEndpoint.call([])

    assert conn.status == 200
    assert_received {:openapi, "/users", %{"context" => %{operation_id: :handle_request}}}
  end

  test "GET /api-docs returns swagger ui html" do
    conn =
      conn(:get, "/api-docs")
      |> Openapi.TestRouter.call([])

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]

    assert conn.resp_body =~ "<div id=\"swagger-ui\""
    assert conn.resp_body =~ "<div id=\"swagger-ui\""
    assert conn.resp_body =~ "swagger-ui-bundle.js"
    assert conn.resp_body =~ "swagger-initializer.js"
  end

  test "GET /api-docs/openapi.json returns spec JSON" do
    conn =
      conn(:get, "/api-docs/openapi.json")
      |> Openapi.TestRouter.call([])

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
  end

  test "GET swagger assets are served via wildcard route" do
    conn =
      conn(:get, "/api-docs/swagger-ui.css")
      |> Openapi.TestRouter.call([])

    assert conn.status == 200

    assert get_resp_header(conn, "content-type") == ["text/css; charset=utf-8"]
  end

  test "GET swagger initializer js" do
    conn =
      conn(:get, "/api-docs/swagger-initializer.js")
      |> Openapi.TestRouter.call([])

    assert conn.status == 200

    assert get_resp_header(conn, "content-type") == ["application/javascript; charset=utf-8"]

    assert conn.resp_body =~ "url: \"/api-docs/openapi.json\""
  end

  test "GET swagger favicon" do
    conn =
      conn(:get, "/api-docs/favicon-16x16.png")
      |> Openapi.TestRouter.call([])

    assert conn.status == 200

    assert get_resp_header(conn, "content-type") == ["image/png; charset=utf-8"]
  end

  test "GET swagger unknown file" do
    conn =
      conn(:get, "/api-docs/unkown.js")
      |> Openapi.TestRouter.call([])

    assert conn.status == 404

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]

    assert %{"error" => "Not found"} == Jason.decode!(conn.resp_body)
  end

  test "GET swagger file from any directory" do
    conn =
      conn(:get, "/api-docs/../../README.md")
      |> Openapi.TestRouter.call([])

    assert conn.status == 403

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]

    assert %{"error" => "forbidden"} == Jason.decode!(conn.resp_body)
  end

  test "Swagger serverd at \"/\"" do
    conn =
      conn(:get, "/")
      |> Openapi.TestRouter.call([])

    assert conn.status == 200

    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
  end
end
