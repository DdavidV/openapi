# Openapi

A lightweight OpenAPI-first routing, validation and documentation layer for Elixir/Phoenix
applications.

It parses OpenAPI (YAML/JSON) definitions, generates Phoenix routes, optionally validates requests
using JSON Schema, and provides built-in Swagger UI integration for interactive API documentation.

## Usage

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Openapi.Phoenix

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :api

    openapi "priv/swagger.yaml"
    swagger_docs "/api-docs"
  end
end
```

The `openapi` macro is responsible for turning an OpenAPI definition into live Phoenix routes.

When used in a router, it performs the following steps at compile time:
- Reads the provided OpenAPI file (`.yaml`, `.yml`, or `.json`)
- Normalizes all paths to Phoenix format (e.g. `/user/{id}` → `/user/:id`)
- Generates Phoenix routes for every HTTP method defined under each path
- Attaches routing metadata for later dispatch

At runtime, requests are dispatched based on the generated metadata:
- If a global `handler` option is provided, it is used as the default module
- Otherwise, the macro uses the per-operation `x-handler` value from the OpenAPI file
- The `operationId` determines the function to call inside the handler module

### Spec file paths

The OpenAPI file is read both at compile time (to generate routes) and at runtime (to serve the
spec via Swagger UI). A plain string is resolved relative to the current working directory, which
works in development but breaks in most releases where the working directory differs from the
application's installation path.

For release-safe paths, pass an `{app, relative_path}` tuple instead. It is resolved against the
OTP application's `priv` directory via `:code.priv_dir/1` at call time:

```elixir
openapi {:my_app, "swagger.yaml"}
```

This reads `swagger.yaml` from `MyApp`'s `priv/` directory regardless of the working directory.

## Request validation

`Openapi.ValidatorPlug` validates incoming requests against the schemas defined in your
OpenAPI document, using [`ex_json_schema`](https://hex.pm/packages/ex_json_schema).

Add it to any pipeline. It validates only the operations that actually define schemas, and
passes everything else through untouched:

```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug Openapi.ValidatorPlug
end
```

The schemas are resolved once at compile time and embedded into each route, so validation
works in any environment without relying on the spec ever being served.

Given an OpenAPI operation like:

```yaml
paths:
  /pets:
    post:
      operationId: createPet
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/NewPet'
components:
  schemas:
    NewPet:
      type: object
      required: [name]
      properties:
        name: { type: string }
        age: { type: integer }
```

A request with an invalid body is rejected with a `400` JSON response before reaching your
handler:

```json
{
  "errors": [
    {"source": "body", "path": "#/name", "message": "Required property name was not present."}
  ]
}
```

What gets validated:
- **Request body** — the `application/json` `requestBody` schema
- **Query parameters** — declared `parameters` with `in: query`
- **Path parameters** — declared `parameters` with `in: path`

Path and query parameters arrive as strings; the plug coerces them to the declared type
(`integer`, `number`, `boolean`) before validating.

### Options

- `:validate` — which parts to validate. Defaults to `[:body, :query, :path]`:

  ```elixir
  # Only validate request bodies, skip params
  plug Openapi.ValidatorPlug, validate: [:body]
  ```

- `:on_error` — a `fun(conn, errors)` returning a `Plug.Conn`, used to customize the failure
  response. Defaults to a `400` JSON response with error details:

  ```elixir
  plug Openapi.ValidatorPlug, on_error: &MyApp.Errors.handle_validation/2
  ```


## Telemetry

`openapi` emits [Telemetry](https://hexdocs.pm/telemetry) span events at key points in the
request lifecycle, following the same convention as Phoenix. Attach a handler once at
application startup and you get timing, operation identity, and error information for every
OpenAPI-routed request.

### Validation events

Emitted by `Openapi.ValidatorPlug` around request schema validation:

| Event | When |
|-------|------|
| `[:openapi, :request, :validation, :start]` | Before validation runs |
| `[:openapi, :request, :validation, :stop]` | After validation completes |

The `:stop` event metadata includes `operation_id`, `server`, and `errors` — an empty list
when validation passed, a list of error maps when it failed:

```elixir
:telemetry.attach("log-validation", [:openapi, :request, :validation, :stop], fn _event, _measurements, metadata, _config ->
  if metadata.errors != [] do
    Logger.warning("Validation failed for #{metadata.operation_id}: #{inspect(metadata.errors)}")
  end
end, nil)
```

### Dispatch events

Emitted by `Openapi.DispatchPlug` around every handler invocation:

| Event | When |
|-------|------|
| `[:openapi, :request, :dispatch, :start]` | Before the handler is called |
| `[:openapi, :request, :dispatch, :stop]` | After the handler returns |
| `[:openapi, :request, :dispatch, :exception]` | If the handler raises |

Measurements: `system_time` (start), `duration` (stop/exception). Metadata:
`%{conn, operation_id, server, handler}`.

```elixir
:telemetry.attach("log-dispatch", [:openapi, :request, :dispatch, :stop], fn _event, measurements, metadata, _config ->
  Logger.info("#{metadata.operation_id} dispatched in #{div(measurements.duration, 1_000)}µs")
end, nil)
```

## Response validation

`Openapi.ResponseValidatorPlug` validates that your handler's response body matches the
schema declared in the spec's `responses` section for each HTTP status code.

It uses `Plug.Conn.register_before_send/2` to inspect the response after the handler runs,
so it never blocks or alters the response — it just calls `on_error` if there is a mismatch.

Best used in **dev and test** pipelines to catch spec drift before API consumers do:

```elixir
# config/dev.exs or a test-only pipeline
pipeline :api do
  plug :accepts, ["json"]
  plug Openapi.ValidatorPlug
  plug Openapi.ResponseValidatorPlug
end
```

The default `on_error` logs a warning. In tests you can make it raise to fail fast:

```elixir
plug Openapi.ResponseValidatorPlug, on_error: fn conn, errors ->
  raise "Response mismatch for #{conn.private.openapi.operation_id}: #{inspect(errors)}"
end
```

Response schemas are compiled at the same time as request schemas — at route-generation time
— so there is no runtime spec file dependency.

## Installation

The package can be installed by adding `openapi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:openapi, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and is published on [HexDocs](https://hexdocs.pm/openapi).

# License

MIT
