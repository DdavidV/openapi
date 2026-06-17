defmodule Openapi.ValidatorPlug do
  @moduledoc """
  A plug that validates incoming requests against OpenAPI schemas.

  Reads the pre-compiled schemas embedded in `conn.private.openapi.schemas`. These are
  resolved at compile time by `Openapi.SchemaCompiler` and attached to each route by the
  OpenAPI router.

  If the request was not matched by an OpenAPI route (no `conn.private.openapi`), it passes
  through unchanged.

  ## Options

  - `:validate` — list of parts to validate. Defaults to `[:body, :query, :path]`.
  - `:on_error` — `fun/2` called with `(conn, errors)` on validation failure. Must return
    a `Plug.Conn`. Defaults to a 400 JSON response with error details.

  ## Usage
  ```elixir
  pipeline :api do
    plug :accepts, ["json"]
    plug Openapi.ValidatorPlug
  end

  # Only validate body, skip params
  plug Openapi.ValidatorPlug, validate: [:body]

  # Custom error handler
  plug Openapi.ValidatorPlug, on_error: &MyApp.Errors.handle_validation/2
  ```

  ## Error format (default)
  ```json
  {
    "errors": [
      {"source": "body", "path": "#/name", "message": "Required property name was not present."},
      {"source": "query", "param": "page", "message": "Type mismatch. Expected Integer but got String."}
    ]
  }
  ```
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      validate: Keyword.get(opts, :validate, [:body, :query, :path]),
      on_error: Keyword.get(opts, :on_error, &__MODULE__.default_error/2)
    }
  end

  @impl true
  def call(
        %{private: %{openapi: %{server: server, operation_id: operation_id, schemas: schemas}}} =
          conn,
        %{validate: parts, on_error: on_error}
      )
      when is_map(schemas) do
    :telemetry.span(
      [:openapi, :request, :validation],
      %{conn: conn, operation_id: operation_id, server: server},
      fn ->
        conn = if :query in parts, do: fetch_query_params(conn), else: conn

        body_errs = if :body in parts, do: body_errors(conn, schemas.body), else: []

        query_errs =
          if :query in parts,
            do: param_errors(conn.query_params, schemas.parameters, "query"),
            else: []

        path_errs =
          if :path in parts,
            do: param_errors(conn.path_params, schemas.parameters, "path"),
            else: []

        errors = body_errs ++ query_errs ++ path_errs

        result =
          case errors do
            [] -> conn
            _ -> on_error.(conn, errors) |> halt()
          end

        {result, %{conn: result, operation_id: operation_id, server: server, errors: errors}}
      end
    )
  end

  def call(conn, _opts), do: conn

  @doc false
  def default_error(conn, errors) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, JSON.encode!(%{errors: errors}))
  end

  defp body_errors(_conn, nil), do: []

  defp body_errors(%{body_params: %Plug.Conn.Unfetched{}}, _schema), do: []

  defp body_errors(conn, schema) do
    content_type = conn |> get_req_header("content-type") |> List.first("")

    if String.contains?(content_type, "application/json") do
      case ExJsonSchema.Validator.validate(schema, conn.body_params) do
        :ok ->
          []

        {:error, errors} ->
          Enum.map(errors, fn {msg, path} -> %{source: "body", path: path, message: msg} end)
      end
    else
      []
    end
  end

  defp param_errors(params, parameter_schemas, location) do
    parameter_schemas
    |> Enum.filter(&(&1.in == location))
    |> Enum.flat_map(fn %{name: name, schema: schema, required: required} ->
      value = Map.get(params, name)

      cond do
        is_nil(value) and required ->
          [%{source: location, param: name, message: "is required"}]

        is_nil(value) ->
          []

        is_nil(schema) ->
          []

        true ->
          coerced = coerce(value, schema)

          case ExJsonSchema.Validator.validate(schema, coerced) do
            :ok ->
              []

            {:error, errors} ->
              Enum.map(errors, fn {msg, path} ->
                %{source: location, param: name, path: path, message: msg}
              end)
          end
      end
    end)
  end

  # Coerces string path/query param values to the type declared in the schema,
  # since all path/query params arrive as strings from Phoenix.
  defp coerce(value, %ExJsonSchema.Schema.Root{schema: schema}) when is_binary(value) do
    case schema["type"] do
      "integer" ->
        case Integer.parse(value) do
          {int, ""} -> int
          _ -> value
        end

      "number" ->
        case Float.parse(value) do
          {float, ""} -> float
          _ -> value
        end

      "boolean" when value in ["true", "1"] ->
        true

      "boolean" when value in ["false", "0"] ->
        false

      _ ->
        value
    end
  end

  defp coerce(value, _schema), do: value
end
