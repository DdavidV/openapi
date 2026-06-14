defmodule Openapi.Phoenix do
  require Phoenix.Router

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

      definition = Openapi.Definition.prefix_routes(definition, prefix)
      Openapi.save_definition(server, definition)
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
        Phoenix.Router.match(:get, "/openapi.json", Openapi.DocsPlug, {:spec, server, path}, alias: false)
        Phoenix.Router.match(:get, "/*path", Openapi.DocsPlug, {:asset, server, path}, alias: false)
      end
    end
  end

end
