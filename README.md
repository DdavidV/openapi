# Openapi

A lightweight OpenAPI-first routing, validation and documentation layer for Elixir/Phoenix
applications.

It parses OpenAPI (YAML/JSON) definitions, generates Phoenix routes, optionally validates requests
using JSON Schema, and provides built-in Swagger UI integration for interactive API documentation.

## Usage

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import Openapi.Phoenix

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

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `openapi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:openapi, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/openapi>.

## TODO:
- JSON schema validation
- Better definition merge (maybe conflict errors?)

# License

MIT
