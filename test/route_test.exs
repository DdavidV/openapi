defmodule Openapi.RouteTest do
  use ExUnit.Case
  alias Openapi.Route
  alias Openapi.RouteValidator

  test "Valid route without global handler" do
    route =
      %Route{
        method: :get,
        path: "/users",
        handler: Openapi.TestHandler,
        operation_id: :handle_request
      }

    assert :ok == RouteValidator.validate([route], :server, nil)
  end

  test "nil handler with global handler" do
    route =
      %Route{
        method: :get,
        path: "/users",
        handler: nil,
        operation_id: :handle_request
      }

    assert :ok == RouteValidator.validate([route], :server, Openapi.TestHandler)
  end

  test "nil handler without global handler" do
    route =
      %Route{
        method: :get,
        path: "/users",
        handler: nil,
        operation_id: :handle_request
      }

    assert_raise Openapi.Error, fn ->
      RouteValidator.validate([route], :server, nil)
    end
  end

  test "Handler is not a valid module" do
    route =
      %Route{
        method: :get,
        path: "/users",
        handler: nil,
        operation_id: :handle_request
      }

    assert_raise Openapi.Error, fn ->
      RouteValidator.validate([route], :server, :invalid_module)
    end

    assert_raise Openapi.Error, fn ->
      RouteValidator.validate([route], :server, "Not a module")
    end
  end

  test "Handler does not export operationId" do
    route =
      %Route{
        method: :get,
        path: "/users",
        handler: nil,
        operation_id: :other
      }

    assert_raise Openapi.Error, fn ->
      RouteValidator.validate([route], :server, Openapi.TestHandler)
    end
  end

end
