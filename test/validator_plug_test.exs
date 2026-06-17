defmodule Openapi.ValidatorPlugTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn

  @server :validator_plug_test

  setup_all do
    definition = Openapi.read_file!("test/resources/validation.yaml")

    schemas =
      definition
      |> Openapi.Definition.phoenix_routes()
      |> Map.new(&{&1.operation_id, &1.schemas})

    {:ok, schemas: schemas}
  end

  defp plug_opts(opts \\ []), do: Openapi.ValidatorPlug.init(opts)

  defp build_conn(method, path, operation_id, schemas) do
    conn(method, path)
    |> put_private(:openapi, %{
      server: @server,
      operation_id: operation_id,
      schemas: schemas[operation_id]
    })
  end

  test "passes valid body", %{schemas: schemas} do
    conn =
      build_conn(:post, "/pets", :create_pet, schemas)
      |> Map.put(:body_params, %{"name" => "Max", "age" => 3})
      |> put_req_header("content-type", "application/json")
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "rejects missing required body field", %{schemas: schemas} do
    conn =
      build_conn(:post, "/pets", :create_pet, schemas)
      |> Map.put(:body_params, %{"age" => 3})
      |> put_req_header("content-type", "application/json")
      |> Openapi.ValidatorPlug.call(plug_opts())

    assert conn.halted
    assert conn.status == 400
    body = JSON.decode!(conn.resp_body)
    assert [%{"source" => "body"} | _] = body["errors"]
  end

  test "rejects body field with wrong type", %{schemas: schemas} do
    conn =
      build_conn(:post, "/pets", :create_pet, schemas)
      |> Map.put(:body_params, %{"name" => "Max", "age" => "not-a-number"})
      |> put_req_header("content-type", "application/json")
      |> Openapi.ValidatorPlug.call(plug_opts())

    assert conn.halted
    assert conn.status == 400
  end

  test "skips body validation when content-type is not application/json", %{schemas: schemas} do
    conn =
      build_conn(:post, "/pets", :create_pet, schemas)
      |> Map.put(:body_params, %{})
      |> put_req_header("content-type", "text/plain")
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "skips body validation when body_params is unfetched", %{schemas: schemas} do
    conn =
      build_conn(:post, "/pets", :create_pet, schemas)
      |> put_req_header("content-type", "application/json")
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "passes valid query parameters", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets?status=available&limit=10", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "rejects missing required query parameter", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    assert conn.halted
    assert conn.status == 400
    body = JSON.decode!(conn.resp_body)
    assert Enum.any?(body["errors"], &(&1["param"] == "status"))
  end

  test "rejects query parameter with invalid enum value", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets?status=unknown", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    assert conn.halted
    assert conn.status == 400
  end

  test "coerces integer query parameter from string", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets?status=available&limit=5", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "rejects non-integer value for integer query parameter", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets?status=available&limit=abc", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    assert conn.halted
    assert conn.status == 400
  end

  test "coerces and accepts a valid number query parameter", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets?status=available&max_weight=2.5", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "rejects a non-numeric number query parameter", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets?status=available&max_weight=heavy", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    assert conn.halted
    assert conn.status == 400
  end

  test "coerces and accepts boolean query parameters", %{schemas: schemas} do
    for value <- ["true", "false"] do
      conn =
        build_conn(:get, "/pets?status=available&verified=#{value}", :list_pets, schemas)
        |> Openapi.ValidatorPlug.call(plug_opts())

      refute conn.halted
    end
  end

  test "accepts an array query parameter (non-binary value)", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets?status=available&tags[]=a&tags[]=b", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "skips validation for a parameter without a schema", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets?status=available&note=anything", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "passes valid path parameter", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets/42", :get_pet, schemas)
      |> Map.put(:path_params, %{"id" => "42"})
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "rejects non-integer path parameter", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets/abc", :get_pet, schemas)
      |> Map.put(:path_params, %{"id" => "abc"})
      |> Openapi.ValidatorPlug.call(plug_opts())

    assert conn.halted
    assert conn.status == 400
    body = JSON.decode!(conn.resp_body)
    assert Enum.any?(body["errors"], &(&1["param"] == "id"))
  end

  test "passes through when conn has no openapi private" do
    conn =
      conn(:get, "/")
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "passes through when operation has no schemas", %{schemas: schemas} do
    conn =
      build_conn(:get, "/", :unknown_operation, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts())

    refute conn.halted
  end

  test "calls custom on_error when validation fails", %{schemas: schemas} do
    on_error = fn conn, errors ->
      send(self(), {:validation_error, errors})
      send_resp(conn, 400, "bad request")
    end

    conn =
      build_conn(:post, "/pets", :create_pet, schemas)
      |> Map.put(:body_params, %{})
      |> put_req_header("content-type", "application/json")
      |> Openapi.ValidatorPlug.call(plug_opts(on_error: on_error))

    assert conn.halted
    assert conn.status == 400
    assert_received {:validation_error, [_ | _]}
  end

  test "validate: [:body] skips query param validation", %{schemas: schemas} do
    conn =
      build_conn(:get, "/pets", :list_pets, schemas)
      |> Openapi.ValidatorPlug.call(plug_opts(validate: [:body]))

    refute conn.halted
  end

  test "validate: [:query] skips body validation", %{schemas: schemas} do
    conn =
      build_conn(:post, "/pets", :create_pet, schemas)
      |> Map.put(:body_params, %{})
      |> put_req_header("content-type", "application/json")
      |> Openapi.ValidatorPlug.call(plug_opts(validate: [:query]))

    refute conn.halted
  end
end
