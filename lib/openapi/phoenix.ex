defmodule Openapi.Phoenix do
  @moduledoc """
  Basic Phoenix integration helpers for OpenAPI support.

  This module provides macros that help integrate OpenAPI definition tracking into Phoenix routers
  and applications.

  It enables routers to declare OpenAPI files and participate in automatic discovery and aggregation
  of API definitions across the system.
  """

  require Phoenix.Router

  @doc """
  Injects OpenAPI router functionality into a module.

  When used, the module:
  - Registers itself in `:persistent_term` as an OpenAPI router on load
  - Enables accumulation of `@openapi_files` module attributes
  - Exposes `__openapi_files__/0` for retrieving declared OpenAPI files
  - Imports `Openapi.Phoenix` helpers

  This allows the module to participate automatically in OpenAPI definition discovery and generation.
  """
  defmacro __using__(_) do
    quote do
      import Openapi.Phoenix
      @on_load :__register_openapi_router__

      Module.register_attribute(__MODULE__, :openapi_files,
        accumulate: true,
        persist: true
      )

      def __register_openapi_router__ do
        routers = :persistent_term.get({:openapi, :routers}, [])
        :persistent_term.put({:openapi, :routers}, [__MODULE__ | routers])
      end

      def __openapi_files__ do
        __MODULE__.__info__(:attributes)
        |> Keyword.get_values(:openapi_files)
        |> List.flatten()
      end
    end
  end

  @doc """
  Register an OpenAPI spec and its routes with the application.

  Options:
    - `handler`: Default handler of the routes can be overwritten with `x-handler`
    - `strict` (Default `true`): Validates routes at compile time.
    - `server`: The server/namespace for this spec. Auto-detected from router module if not provided.
    - `prefix`: Explicit route prefix applied to all generated OpenAPI paths.
  """
  defmacro openapi(path, options \\ []) do
    server =
      Keyword.get_lazy(options, :server, fn ->
        __CALLER__.module
        |> Module.split()
        |> hd()
        |> String.to_atom()
      end)

    quote bind_quoted: [server: server, path: path, options: options] do
      handler = Keyword.get(options, :handler)
      server = Keyword.get(options, :server, server)
      strict? = Keyword.get(options, :strict, true)
      prefix = Keyword.get(options, :prefix)

      definition = Openapi.read_file!(path)
      routes = Openapi.Definition.phoenix_routes(definition)
      if strict?, do: Openapi.RouteValidator.validate(routes, server, handler)

      for route <- routes do
        Phoenix.Router.match(
          route.method,
          route.path,
          Openapi.DispatchPlug,
          [],
          alias: false,
          private: %{
            openapi: %{
              server: server,
              handler: route.handler || handler,
              operation_id: route.operation_id
            }
          }
        )
      end

      @openapi_files %{
        server: server,
        file: path,
        prefix: prefix
      }
    end
  end

  @doc """
  Register swagger-ui to a given path.

  Options:
    - `server`: The server/namespace whose spec will be served on swagger-ui.
    - `prefix`: Explicit route prefix applied to the path.
  """
  defmacro swagger_docs(path, options \\ []) do
    server =
      Keyword.get_lazy(options, :server, fn ->
        __CALLER__.module
        |> Module.split()
        |> hd()
        |> String.to_atom()
      end)

    quote bind_quoted: [server: server, path: path, options: options] do
      scope path do
        server = Keyword.get(options, :server, server)
        prefix = Keyword.get(options, :prefix)
        path = "#{prefix}#{path}"
        Phoenix.Router.match(:get, "/", Openapi.DocsPlug, {:index, server, path}, alias: false)

        Phoenix.Router.match(:get, "/openapi.json", Openapi.DocsPlug, {:spec, server, path},
          alias: false
        )

        Phoenix.Router.match(:get, "/*path", Openapi.DocsPlug, {:asset, server, path},
          alias: false
        )
      end
    end
  end
end
