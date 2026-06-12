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
      routes = Openapi.Route.from_definition(definition)
      handler = Keyword.get(options, :handler)
      _strict = Keyword.get(options, :strict, true)
      IO.inspect(routes, limit: :infinity)
      IO.inspect(server, label: "server name")
      for route <- routes do
        Phoenix.Router.match(
          route.method,
          route.path,
          Openapi.DispatchPlug,
          [],
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

end
