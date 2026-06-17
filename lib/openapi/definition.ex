defmodule Openapi.Definition do
  @default_definition %{
    "openapi" => "3.0.0",
    "info" => %{
      "title" => "API",
      "description" => "Openapi definition",
      "version" => "0.0.1"
    },
    "paths" => %{}
  }

  @doc """
  Normalizes an OpenAPI definition by merging it with default values.

  This function ensures that the resulting OpenAPI document always contains the minimum required
  structure needed for downstream processing (such as route generation and Swagger UI rendering).
  """
  def normalize(definition) do
    merge(@default_definition, definition)
  end

  @doc """
  Prefixes all OpenAPI path definitions with the given prefix.

  This function transforms the `"paths"` section of an OpenAPI definition by adding a leading scope
  (e.g. `/v1`) to every defined route.

  It preserves all HTTP operations and metadata under each path.

  This function is primarily useful when integrating OpenAPI definitions inside Phoenix routers that
  use `scope/2`.

  For example:
  ```elixir
  scope "/v1" do
    openapi "priv/swagger.yaml"
  end
  ```

  The OpenAPI file may define paths like:
  ```elixir
  /users
  /users/{id}
  ```

  But Phoenix will mount the routes under `/v1`, meaning the *actual runtime
  routes* become:
  ```elixir
  /v1/users
  /v1/users/:id
  ```
  In this case, you may want the OpenAPI document to reflect the same structure so that Swagger UI
  match the real routing layout.
  """
  def prefix_routes(definition, nil), do: definition

  def prefix_routes(definition, prefix) do
    paths =
      definition
      |> Map.get("paths", %{})
      |> Map.new(fn {path, operations} ->
        {join_paths(prefix, path), operations}
      end)

    Map.put(definition, "paths", paths)
  end

  defp join_paths(prefix, path) do
    "/" <>
      Path.join(
        String.trim_leading(prefix, "/"),
        String.trim_leading(path, "/")
      )
  end

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
        operation_id: operation_id,
        schemas: Openapi.SchemaCompiler.compile_operation(operation, definition)
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
