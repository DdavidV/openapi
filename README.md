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

## TODO:
- Better definition merge (maybe conflict errors?)

# License

MIT
