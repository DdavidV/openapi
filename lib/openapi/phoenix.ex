defmodule Openapi.Phoenix do
require Phoenix.Router

  @doc """
  Options:
    - handler: Default handler of the routes can be overwritten with `x-handler`
    - strict (Default `true`): Validates routes on compile time.
      - Raises an exception if route is already defined by this application.
      - Raises an exception when a route does not have `x-handler` in definition and handler is not
        defined in options.

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
      definition = Openapi.read_file!(path)
      :persistent_term.put(:openapi, definition)
      routes = Openapi.Route.from_definition(definition)
      handler = Keyword.get(options, :handler)
      _strict = Keyword.get(options, :strict, true)
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
              operation_id: Macro.underscore(route.operation_id) |> String.to_atom()
            }
          }
        )
      end
    end
  end

  defmacro api_docs(path) do
    quote bind_quoted: [path: path] do
      scope "/api-docs" do
        pipe_through [:api]
        get "/", Openapi.DocsPlug, :index, alias: false
        get "/openapi.json", Openapi.DocsPlug, :spec, alias: false
        get "/*path", Openapi.DocsPlug, :asset, alias: false
      end
    end
  end

end
