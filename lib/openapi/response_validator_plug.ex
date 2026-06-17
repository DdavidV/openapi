defmodule Openapi.ResponseValidatorPlug do
  @moduledoc """
  A plug that validates handler responses against the `responses` schemas defined in the
  OpenAPI document.

  Registers a `before_send` callback that fires after the handler has produced its response.
  If the response body does not conform to the compiled schema for that HTTP status code,
  the configured `on_error` callback is called. The default is to log a warning and leave
  the response unchanged — this plug never halts or alters the response on its own, because
  the response body is already committed by the time validation runs.

  Best suited for **dev and test** pipelines to catch spec drift early.

  ## Options

  - `:on_error` — `fun/2` called with `(conn, errors)` on a schema mismatch. Must return
    a `Plug.Conn`. Defaults to logging a warning at the `:warning` level and returning the
    conn unchanged.

  ## Usage
  ```elixir
  # In dev/test only
  pipeline :api do
    plug :accepts, ["json"]
    plug Openapi.ValidatorPlug
    plug Openapi.ResponseValidatorPlug
  end

  # Custom error handler (e.g. raise in tests)
  plug Openapi.ResponseValidatorPlug, on_error: fn conn, errors ->
    raise "Response for \#{conn.private.openapi.operation_id} is invalid: \#{inspect(errors)}"
  end
  ```
  """

  @behaviour Plug

  require Logger
  import Plug.Conn

  @impl true
  def init(opts) do
    %{on_error: Keyword.get(opts, :on_error, &__MODULE__.default_error/2)}
  end

  @impl true
  def call(
        %{private: %{openapi: %{schemas: %{responses: responses}}}} = conn,
        %{on_error: on_error}
      )
      when map_size(responses) > 0 do
    register_before_send(conn, fn response_conn ->
      validate_response(response_conn, responses, on_error)
    end)
  end

  def call(conn, _opts), do: conn

  @doc false
  def default_error(conn, errors) do
    operation_id = conn.private.openapi.operation_id

    Logger.warning(
      "[Openapi.ResponseValidatorPlug] Response for #{operation_id} does not match the schema: #{inspect(errors)}"
    )

    conn
  end

  defp validate_response(conn, responses, on_error) do
    schema = Map.get(responses, conn.status)
    content_type = conn |> get_resp_header("content-type") |> List.first("")

    if schema && String.contains?(content_type, "application/json") do
      case JSON.decode(conn.resp_body) do
        {:ok, body} ->
          case ExJsonSchema.Validator.validate(schema, body) do
            :ok ->
              conn

            {:error, errors} ->
              formatted = Enum.map(errors, fn {msg, path} -> %{path: path, message: msg} end)
              on_error.(conn, formatted)
          end

        {:error, _} ->
          conn
      end
    else
      conn
    end
  end
end
