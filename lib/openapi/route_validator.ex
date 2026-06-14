defmodule Openapi.RouteValidator do
  alias Openapi.Route

  @doc """
  Validates a list of openapi route.

  This function performs compile-time validation of a list of openapi route

  ## Validation steps

  1. **Handler validation**
     - If a `global_handler` is provided, it is validated to ensure it is a valid module.
     - Each route is checked to ensure its handler (or fallback global handler)
       is a valid module when required.

  2. **Operation ID validation**
     - Ensures every route has a valid `operationId`.
     - Verifies that the resolved handler module exports a function matching
       the normalized operation id with arity 2 (`operation_id(conn, params)`).
  """
  def validate(routes, _server, global_handler) do
    global_handler
    |> valid_module?()
    |> validate_handlers(routes)

    validate_operation_id(global_handler, routes)
    :ok
  end

  defp validate_handlers(has_global_handler?, routes) do
    invalid =
      Enum.filter(routes, fn %Route{handler: route_handler} ->
        if is_nil(route_handler) do
          not has_global_handler?
        else
          not valid_module?(route_handler)
        end
      end)

    if invalid != [] do
      raise Openapi.Error,
        message:
          "Invalid handler definition found.\n" <>
            "Ensure each handler has a valid x-handler or a valid global_handler.",
        details: %{routes: invalid}
    end
  end

  defp valid_module?(nil), do: false

  defp valid_module?(mod) when is_atom(mod) do
    case Code.ensure_compiled(mod) do
      {:module, _} -> true
      {:error, _} -> false
    end
  end

  defp valid_module?(_), do: false

  defp validate_operation_id(global_handler, routes) do
    invalid =
      Enum.filter(routes, fn %Route{handler: route_handler, operation_id: operation_id} ->
        handler = route_handler || global_handler
        is_nil(operation_id) or not function_exported?(handler, operation_id, 2)
      end)

    if invalid != [] do
      raise Openapi.Error,
        message:
          "Invalid operationId definition found.\n" <>
            "Ensure each route have an operationId and " <>
            "the handler module exports handler.operation_id/2.",
        details: %{routes: invalid}
    end
  end
end
