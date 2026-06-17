defmodule Openapi.ValidationIntegrationTest do
  use ExUnit.Case
  import Plug.Test

  alias Openapi.ValidationRouter

  test "valid path parameter dispatches to handler" do
    conn = ValidationRouter.call(conn(:get, "/pets/42"), [])

    assert conn.status == 200
    refute conn.halted
  end

  test "invalid path parameter is rejected with 400" do
    conn = ValidationRouter.call(conn(:get, "/pets/abc"), [])

    assert conn.status == 400
    body = JSON.decode!(conn.resp_body)
    assert Enum.any?(body["errors"], &(&1["param"] == "id"))
  end

  test "valid query parameters dispatch to handler" do
    conn = ValidationRouter.call(conn(:get, "/pets?status=available"), [])

    assert conn.status == 200
  end

  test "missing required query parameter is rejected with 400" do
    conn = ValidationRouter.call(conn(:get, "/pets"), [])

    assert conn.status == 400
    body = JSON.decode!(conn.resp_body)
    assert Enum.any?(body["errors"], &(&1["param"] == "status"))
  end

  test "invalid enum query parameter is rejected with 400" do
    conn = ValidationRouter.call(conn(:get, "/pets?status=nope"), [])

    assert conn.status == 400
  end
end
