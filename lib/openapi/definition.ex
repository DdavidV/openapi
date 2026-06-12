defmodule Openapi.Definition do

  @doc """
  Converts an OpenAPI/Swagger `paths` definition into a list of Phoenix-compatible routes.

  This function extracts HTTP operations from the OpenAPI document and transforms them
  into `Openapi.Route` structs that can later be used to generate Phoenix router entries
  or dispatch metadata.
  """
  def phoenix_routes(definition) do
    for {path, operations} <- Map.get(definition, "paths", %{}),
        {method, operation} <- operations,
        method in ["get", "post", "put", "patch", "delete", "head", "options", "trace"] do
      operation_id = Map.get(operation, "operationId")
      operation_id = if operation_id, do: Macro.underscore(operation_id) |> String.to_atom()
      handler = Map.get(operation, "x-handler")
      handler = if handler, do: String.to_atom(handler)
      %Openapi.Route{
        method: String.to_atom(method),
        path: Regex.replace(~r/\{([^}]+)\}/, path, ":\\1"),
        handler: handler,
        operation_id: operation_id
      }
    end
  end

  @doc """
  Deep merges two OpenAPI/Swagger definition maps.

  Rules:
  - `paths` are merged per path + method
  - `components` are deeply merged
  - `tags` are concatenated (deduped by name)
  - `servers` are concatenated (deduped by url)
  - everything else: right side overrides left
  """
  def merge(def1, def2) do
    Map.merge(def1, def2, fn
      "paths", v1, v2 -> merge_paths(v1, v2)
      "components", v1, v2 -> deep_merge_maps(v1, v2)
      "tags", v1, v2 -> merge_unique_by(v1, v2, & &1["name"])
      "servers", v1, v2 -> merge_unique_by(v1, v2, & &1["url"])
      _k, _v1, v2 -> v2
    end)
  end

  defp merge_paths(p1, p2) do
    Map.merge(p1 || %{}, p2 || %{}, fn _path, ops1, ops2 ->
      Map.merge(ops1, ops2, fn _method, o1, o2 ->
        deep_merge_maps(o1, o2)
      end)
    end)
  end

  defp deep_merge_maps(m1, m2) do
    Map.merge(m1 || %{}, m2 || %{}, fn
      _k, v1, v2 when is_map(v1) and is_map(v2) ->
        deep_merge_maps(v1, v2)

      _k, _v1, v2 ->
        v2
    end)
  end

  defp merge_unique_by(list1, list2, fun) do
    list1 = list1 || []
    list2 = list2 || []
    (list1 ++ list2)
    |> Enum.uniq_by(fun)
  end

end
