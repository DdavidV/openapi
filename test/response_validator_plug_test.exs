defmodule Openapi.ResponseValidatorPlugTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn

  @server :response_validator_test

  setup_all do
    definition = Openapi.read_file!("test/resources/validation.yaml")

    schemas =
      definition
      |> Openapi.Definition.phoenix_routes()
      |> Map.new(&{&1.operation_id, &1.schemas})

    {:ok, schemas: schemas}
  end

  defp plug_opts(opts \\ []), do: Openapi.ResponseValidatorPlug.init(opts)

  defp build_conn(method, path, operation_id, schemas) do
    conn(method, path)
    |> put_private(:openapi, %{
      server: @server,
      operation_id: operation_id,
      schemas: schemas[operation_id]
    })
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, JSON.encode!(body))
  end

  test "response schemas are compiled for operations with responses", %{schemas: schemas} do
    assert %{201 => %ExJsonSchema.Schema.Root{}} = schemas[:create_pet].responses
  end

  test "response schemas are nil for responses with no body schema", %{schemas: schemas} do
    assert schemas[:get_pet].responses == %{200 => nil}
  end

  test "valid response passes through unchanged", %{schemas: schemas} do
    conn =
      build_conn(:post, "/pets", :create_pet, schemas)
      |> Openapi.ResponseValidatorPlug.call(plug_opts())
      |> send_json(201, %{"id" => 1, "name" => "Max"})

    assert conn.status == 201
    refute conn.halted
  end

  test "invalid response calls on_error with errors", %{schemas: schemas} do
    on_error = fn conn, errors ->
      send(self(), {:response_error, errors})
      conn
    end

    build_conn(:post, "/pets", :create_pet, schemas)
    |> Openapi.ResponseValidatorPlug.call(plug_opts(on_error: on_error))
    |> send_json(201, %{"age" => 3})

    assert_received {:response_error, [_ | _]}
  end

  test "default on_error logs a warning and does not halt", %{schemas: schemas} do
    import ExUnit.CaptureLog

    log =
      capture_log(fn ->
        build_conn(:post, "/pets", :create_pet, schemas)
        |> Openapi.ResponseValidatorPlug.call(plug_opts())
        |> send_json(201, %{"age" => 3})
      end)

    assert log =~ "ResponseValidatorPlug"
    assert log =~ "create_pet"
  end

  test "passes through when no schema defined for the returned status code", %{schemas: schemas} do
    on_error = fn conn, _errors ->
      send(self(), :unexpected_error)
      conn
    end

    build_conn(:post, "/pets", :create_pet, schemas)
    |> Openapi.ResponseValidatorPlug.call(plug_opts(on_error: on_error))
    |> send_json(200, %{"whatever" => true})

    refute_received :unexpected_error
  end

  test "is a no-op when operation has no response schemas", %{schemas: schemas} do
    on_error = fn conn, _errors ->
      send(self(), :unexpected_error)
      conn
    end

    conn =
      build_conn(:get, "/pets/1", :get_pet, schemas)
      |> Openapi.ResponseValidatorPlug.call(plug_opts(on_error: on_error))
      |> send_resp(200, "ok")

    refute_received :unexpected_error
    assert conn.status == 200
  end

  test "skips validation when response body is not valid JSON", %{schemas: schemas} do
    on_error = fn conn, _errors ->
      send(self(), :unexpected_error)
      conn
    end

    build_conn(:post, "/pets", :create_pet, schemas)
    |> Openapi.ResponseValidatorPlug.call(plug_opts(on_error: on_error))
    |> put_resp_content_type("application/json")
    |> send_resp(201, "not json {")

    refute_received :unexpected_error
  end

  test "skips validation for non-JSON response content-type", %{schemas: schemas} do
    on_error = fn conn, _errors ->
      send(self(), :unexpected_error)
      conn
    end

    build_conn(:post, "/pets", :create_pet, schemas)
    |> Openapi.ResponseValidatorPlug.call(plug_opts(on_error: on_error))
    |> put_resp_content_type("text/plain")
    |> send_resp(201, "created")

    refute_received :unexpected_error
  end

  test "passes through when conn has no openapi private" do
    conn =
      conn(:post, "/pets")
      |> Openapi.ResponseValidatorPlug.call(plug_opts())
      |> send_resp(201, "ok")

    assert conn.status == 201
  end
end
