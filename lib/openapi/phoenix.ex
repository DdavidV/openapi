defmodule Openapi.Phoenix do
require Phoenix.Router

  @doc """
  Register an OpenAPI spec and its routes with the application.

  Options:
    - handler: Default handler of the routes can be overwritten with `x-handler`
    - strict (Default `true`): Validates routes on compile time.
      - Raises an exception if route is already defined by this application.
      - Raises an exception when a route does not have `x-handler` in definition and handler is not
        defined in options.
    - server: The server/namespace for this spec. Auto-detected from router module if not provided.

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
      _strict = Keyword.get(options, :strict, true)

      definition = Openapi.read_file!(path)
      Openapi.save_definition(server, definition)

      for route <- Openapi.Definition.phoenix_routes(definition) do
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
              operation_id: Macro.underscore(route.operation_id) |> String.to_atom()
            }
          }
        )
      end
    end
  end

  defmacro swagger_docs(path, options \\ []) do
    server =
      Keyword.get_lazy(options, :server, fn ->
        __CALLER__.module
        |> Module.split()
        |> hd()
        |> String.to_atom()
      end)

    quote bind_quoted: [path: path, server: server] do
      scope path do
        Phoenix.Router.match(:get, "/", Openapi.DocsPlug, {:index, server}, alias: false)
        Phoenix.Router.match(:get, "/openapi.json", Openapi.DocsPlug, {:spec, server}, alias: false)
        Phoenix.Router.match(:get, "/*path", Openapi.DocsPlug, {:asset, server}, alias: false)
      end
    end
  end

end
