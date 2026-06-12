defmodule Openapi.Route do
  defstruct [
    :method,
    :path,
    :handler,
    :operation_id
  ]

  def from_definition(definition) do
    for {path, operations} <- Map.get(definition, "paths", %{}),
        {method, operation} <- operations,
        method in ["get", "post", "put", "patch", "delete", "head", "options", "trace"] do
      %__MODULE__{
        method: String.to_atom(method),
        path: normalize_path(path),
        handler: Map.get(operation, "x-handler"),
        operation_id: Map.get(operation, "operationId")
      }
    end
  end

  defp normalize_path(path), do: Regex.replace(~r/\{([^}]+)\}/, path, ":\\1")
end
